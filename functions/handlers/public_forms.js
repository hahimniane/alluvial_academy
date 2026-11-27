/**
 * Form links: one link per form (alluwaleducationhub.org/form/?id=<templateId>)
 * that the school shares outside the platform, e.g. on WhatsApp.
 *
 * When an admin turns on `public_link_enabled` for a form_templates document,
 * anyone with the link can read the form's questions and send answers without
 * an account. Both go through these callables (Admin SDK), so Firestore rules
 * stay closed to signed-out visitors.
 */
const crypto = require('crypto');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const TEMPLATES = 'form_templates';
const RESPONSES = 'form_responses';
const COUNTERS = 'public_form_submission_counts';

const DISPLAY_TYPES = new Set(['heading', 'section', 'image', 'video']);
const FILE_TYPES = new Set(['image_upload', 'imageUpload', 'signature', 'file', 'file_upload', 'fileUpload']);
const CONDITION_KEYS = ['dependsOnFieldId', 'condition', 'expectedValue', 'expectedValues', 'isVisible'];

const LIMITS = {
  nameMin: 2,
  nameMax: 100,
  phoneMin: 6,
  phoneMax: 25,
  phoneDigitsMin: 6,
  answerMax: 5000,
  listMax: 100,
  payloadMax: 100000,
  perPhonePerDay: 5,
  perFormPerDay: 500,
};

const str = (value) => (typeof value === 'string' ? value : '');
const isPlainObject = (value) => Boolean(value) && typeof value === 'object' && !Array.isArray(value);

/** The questions of a template as a list (stored either as a list or as a map keyed by id). */
function templateFields(raw) {
  let entries = [];
  if (Array.isArray(raw)) {
    entries = raw.map((item, index) => [str(item && item.id) || `field_${index}`, item]);
  } else if (isPlainObject(raw)) {
    entries = Object.entries(raw);
  }
  return entries
    .map(([id, item]) => {
      const map = isPlainObject(item) ? item : {};
      const field = {
        id,
        label: str(map.label),
        type: str(map.type) || 'text',
        placeholder: str(map.placeholder),
        required: map.required === true,
        order: Number.isInteger(map.order) ? map.order : 0,
        options: Array.isArray(map.options) ? map.options.filter((option) => typeof option === 'string') : [],
      };
      if (isPlainObject(map.conditionalLogic)) {
        const logic = {};
        for (const key of CONDITION_KEYS) {
          if (map.conditionalLogic[key] !== undefined) logic[key] = map.conditionalLogic[key];
        }
        field.conditionalLogic = logic;
      }
      return field;
    })
    .map((field, index) => ({field, index}))
    .sort((a, b) => a.field.order - b.field.order || a.index - b.index)
    .map(({field}) => field);
}

function audienceOf(data) {
  for (const key of ['allowedRoles', 'audience', 'targetRoles', 'roles']) {
    const value = data[key];
    if (Array.isArray(value)) return value.map((item) => String(item || '').trim()).filter(Boolean);
    if (typeof value === 'string' && value.trim()) return value.split(/[,;|]/).map((part) => part.trim()).filter(Boolean);
  }
  return [];
}

const versionOf = (data) => (Number.isInteger(data.version) ? data.version : 1);
const millisOf = (value) => (value && typeof value.toMillis === 'function' ? value.toMillis() : 0);

/**
 * The template a link points at. Saving a form in the builder can retire the
 * linked document for a newer copy with the same name; the link then follows
 * to that copy, so a link already shared keeps working.
 */
async function resolveLinkedTemplate(db, id) {
  const snap = await db.collection(TEMPLATES).doc(id).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (data.isActive !== false) return {id: snap.id, data, publicLink: data.public_link_enabled === true};

  const name = str(data.name);
  if (!name) return null;
  const copies = await db.collection(TEMPLATES).where('name', '==', name).where('isActive', '==', true).get();
  if (copies.empty) return null;
  const newest = copies.docs
    .map((doc) => ({id: doc.id, data: doc.data() || {}}))
    .sort((a, b) => versionOf(b.data) - versionOf(a.data) || millisOf(b.data.updatedAt) - millisOf(a.data.updatedAt))[0];
  // The newer copy's own switch wins once an admin has set it.
  const publicLink = typeof newest.data.public_link_enabled === 'boolean' ?
    newest.data.public_link_enabled :
    data.public_link_enabled === true;
  return {id: newest.id, data: newest.data, publicLink};
}

function formIdFrom(data) {
  const id = str(data && data.id).trim();
  if (!id || id.length > 200 || id.includes('/')) throw new HttpsError('invalid-argument', 'A form id is required.');
  return id;
}

/** Public-safe view of a form: its title, description and questions. */
async function getPublicForm(request) {
  const id = formIdFrom(request.data);
  const resolved = await resolveLinkedTemplate(admin.firestore(), id);
  if (!resolved) return {found: false, available: false};
  const {data} = resolved;
  const summary = {
    found: true,
    id: resolved.id,
    title: str(data.name) || 'Untitled',
    category: str(data.category),
    frequency: str(data.frequency),
    audience: audienceOf(data),
  };
  if (!resolved.publicLink) return {...summary, available: false};
  return {
    ...summary,
    available: true,
    description: str(data.description),
    fields: templateFields(data.fields),
  };
}

function cleanName(value) {
  const name = str(value).trim().replace(/\s+/g, ' ');
  if (name.length < LIMITS.nameMin || name.length > LIMITS.nameMax) {
    throw new HttpsError('invalid-argument', 'Enter your full name.');
  }
  return name;
}

function cleanPhone(value) {
  const phone = str(value).trim().replace(/\s+/g, ' ');
  const digits = phone.replace(/\D/g, '');
  if (
    phone.length < LIMITS.phoneMin ||
    phone.length > LIMITS.phoneMax ||
    !/^\+?[\d\s-]+$/.test(phone) ||
    digits.length < LIMITS.phoneDigitsMin
  ) {
    throw new HttpsError('invalid-argument', 'Enter a valid phone or WhatsApp number.');
  }
  return {phone, digits};
}

/** Answers keyed by question id: text, Yes/No (true/false) or a list of ticked options. */
function cleanResponses(value, fields) {
  if (!isPlainObject(value)) throw new HttpsError('invalid-argument', 'The answers could not be read.');
  if (JSON.stringify(value).length > LIMITS.payloadMax) throw new HttpsError('invalid-argument', 'The answers are too long.');
  const byId = new Map(fields.map((field) => [field.id, field]));
  const out = {};
  for (const [key, answer] of Object.entries(value)) {
    const field = byId.get(key);
    if (!field || DISPLAY_TYPES.has(field.type)) throw new HttpsError('invalid-argument', 'The answers do not match this form.');
    if (FILE_TYPES.has(field.type)) throw new HttpsError('invalid-argument', 'Files can\'t be attached on this page.');
    if (typeof answer === 'boolean') {
      out[key] = answer;
    } else if (typeof answer === 'string') {
      if (answer.length > LIMITS.answerMax) throw new HttpsError('invalid-argument', 'An answer is too long.');
      out[key] = answer;
    } else if (Array.isArray(answer)) {
      if (answer.length > LIMITS.listMax || !answer.every((item) => typeof item === 'string' && item.length <= LIMITS.answerMax)) {
        throw new HttpsError('invalid-argument', 'An answer could not be read.');
      }
      out[key] = answer;
    } else {
      throw new HttpsError('invalid-argument', 'An answer could not be read.');
    }
  }
  return out;
}

function formTypeFor(frequency) {
  if (frequency === 'perSession') return 'daily';
  if (frequency === 'weekly' || frequency === 'monthly') return frequency;
  return 'onDemand';
}

function counterKey(value) {
  return value.replace(/[^A-Za-z0-9_-]/g, '_');
}

/**
 * Stores one answer sheet sent through a form link. The document matches the
 * one a signed-in submission writes, plus `public_submission`, the sender's
 * name and phone, and a `userId` that belongs to no account (it groups one
 * sender's answers in All Submissions).
 */
async function submitPublicFormResponse(request) {
  const input = request.data || {};
  const id = formIdFrom(input);
  const name = cleanName(input.name);
  const {phone, digits} = cleanPhone(input.phone);

  const db = admin.firestore();
  const resolved = await resolveLinkedTemplate(db, id);
  if (!resolved || !resolved.publicLink) {
    throw new HttpsError('failed-precondition', 'This form is no longer available.');
  }
  const {data} = resolved;
  const responses = cleanResponses(input.responses, templateFields(data.fields));

  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const senderKey = crypto.createHash('sha256').update(digits).digest('hex').slice(0, 20);
  const formName = str(data.name) || 'Untitled';
  const frequency = str(data.frequency) || 'onDemand';
  const [firstName, ...rest] = name.split(' ');
  const lastName = rest.join(' ');

  const senderCounter = db.collection(COUNTERS).doc(counterKey(`${resolved.id}_${day}_${senderKey}`));
  const formCounter = db.collection(COUNTERS).doc(counterKey(`${resolved.id}_${day}`));
  const responseRef = db.collection(RESPONSES).doc();
  const FieldValue = admin.firestore.FieldValue;
  // Counters only matter for their day; expire_at lets a TTL policy clear them.
  const expireAt = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000));

  await db.runTransaction(async (tx) => {
    const [senderSnap, formSnap] = await Promise.all([tx.get(senderCounter), tx.get(formCounter)]);
    const senderCount = senderSnap.exists ? Number(senderSnap.data().count) || 0 : 0;
    const formCount = formSnap.exists ? Number(formSnap.data().count) || 0 : 0;
    if (senderCount >= LIMITS.perPhonePerDay || formCount >= LIMITS.perFormPerDay) {
      throw new HttpsError('resource-exhausted', 'This number has sent this form the most times allowed today. Try again tomorrow.');
    }
    tx.set(senderCounter, {formId: resolved.id, day, count: senderCount + 1, expire_at: expireAt});
    tx.set(formCounter, {formId: resolved.id, day, count: formCount + 1, expire_at: expireAt});
    tx.set(responseRef, {
      formId: resolved.id,
      formName,
      formTitle: formName,
      formType: formTypeFor(frequency),
      templateId: resolved.id,
      frequency,
      userId: `public_link_${senderKey}`,
      userEmail: null,
      firstName,
      lastName,
      userFirstName: firstName,
      userLastName: lastName,
      status: 'completed',
      yearMonth: day.slice(0, 7),
      responses,
      public_submission: true,
      submitter_name: name,
      submitter_phone: phone,
      reportingContext: {platform: 'web', channel: 'public_link', clientTimestamp: now.toISOString(), recentBreadcrumbs: []},
      submittedAt: FieldValue.serverTimestamp(),
      lastUpdated: FieldValue.serverTimestamp(),
    });
  });

  return {success: true, id: responseRef.id};
}

const options = {cors: true, invoker: 'public', region: 'us-central1', maxInstances: 10};

module.exports = {
  getPublicForm: onCall(options, getPublicForm),
  submitPublicFormResponse: onCall(options, submitPublicFormResponse),
  _internals: {templateFields, resolveLinkedTemplate, cleanName, cleanPhone, cleanResponses, LIMITS},
};
