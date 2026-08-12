const admin = require('firebase-admin');
const {
  resolveDecisionActor,
} = require('../services/decision_audit');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const projectFlag = args.indexOf('--project');
const projectId = projectFlag >= 0 ? args[projectFlag + 1] : '';

if (!projectId) {
  throw new Error('Pass an explicit Firebase project with --project <id>');
}

admin.initializeApp({projectId});
const db = admin.firestore();

const string = (value) => (value == null ? '' : String(value).trim());

const isTechnicalActor = (value) => {
  const normalized = string(value).toLowerCase();
  return normalized === 'system' ||
    normalized === 'automation' ||
    normalized.endsWith('.gserviceaccount.com') ||
    normalized.includes('firebase-adminsdk') ||
    normalized.includes('compute@developer');
};

const first = (data, keys) => {
  for (const key of keys) {
    const value = string(data && data[key]);
    if (value) return value;
  }
  return '';
};

const userLabel = (data = {}, id = '') => {
  const fullName = [
    first(data, ['first_name', 'firstName']),
    first(data, ['last_name', 'lastName']),
  ].filter(Boolean).join(' ').trim();
  return fullName ||
    first(data, [
      'display_name',
      'displayName',
      'full_name',
      'fullName',
      'name',
      'e-mail',
      'email',
    ]) ||
    (id ? `User ${id}` : 'User');
};

const entityCollections = {
  user: 'users',
  shift: 'teaching_shifts',
  invoice: 'invoices',
  timesheet: 'timesheet_entries',
  application: 'teacher_applications',
  task: 'tasks',
  form_response: 'form_responses',
  enrollment: 'enrollments',
};

const documentCache = new Map();
const actorCache = new Map();

const getDocument = async (collection, id) => {
  const key = `${collection}/${id}`;
  if (!id) return null;
  if (!documentCache.has(key)) {
    documentCache.set(
      key,
      db.collection(collection).doc(id).get().then(
        (snapshot) => snapshot.exists ? snapshot.data() || {} : null,
      ),
    );
  }
  return documentCache.get(key);
};

const resolveActor = (uid, fallback = {}) => {
  const normalizedUid = string(uid);
  if (Object.keys(fallback).length > 0) {
    return resolveDecisionActor(db, normalizedUid, fallback);
  }
  if (!actorCache.has(normalizedUid)) {
    actorCache.set(
      normalizedUid,
      resolveDecisionActor(db, normalizedUid),
    );
  }
  return actorCache.get(normalizedUid);
};

const entityLabel = async (event) => {
  const entityType = string(event.entity_type);
  const entityId = string(event.entity_id);
  const collection = entityCollections[entityType];
  if (!collection) return string(event.entity_label);
  const entity = await getDocument(collection, entityId);
  if (!entity) return string(event.entity_label);

  if (entityType === 'user') return userLabel(entity, entityId);
  if (entityType === 'shift') {
    return first(entity, [
      'custom_name',
      'auto_generated_name',
      'subject_display_name',
      'subject',
    ]) || 'Shift';
  }
  if (entityType === 'invoice') {
    return first(entity, ['invoice_number', 'invoiceNumber']) || 'Invoice';
  }
  if (entityType === 'task') {
    return first(entity, ['title', 'name']) || 'Task';
  }
  return string(event.entity_label);
};

const businessActorUid = async (event) => {
  const action = string(event.action);
  const entityType = string(event.entity_type);
  const entityId = string(event.entity_id);
  const metadata = event.metadata || {};

  if (action === 'invoice.payment_recorded') {
    const payment = await getDocument(
      'payments',
      string(metadata.payment_id),
    );
    return first(payment, [
      'recorded_by_uid',
      'recorded_by',
      'created_by',
      'payer_id',
    ]);
  }

  const collection = entityCollections[entityType];
  const entity = collection
    ? await getDocument(collection, entityId)
    : null;
  if (!entity) return '';

  if (action === 'invoice.paid') {
    return first(entity, ['last_payment_by_uid', 'lastPaymentByUid']);
  }
  if (action.endsWith('.created')) {
    return first(entity, [
      'created_by_uid',
      'created_by',
      'createdBy',
      'created_by_admin_id',
    ]);
  }
  return first(entity, [
    'updated_by_uid',
    'updated_by',
    'updatedBy',
  ]);
};

const normalizeEvent = async (event) => {
  const currentUid = string(event.actor_uid);
  const entityType = string(event.entity_type);
  const entityId = string(event.entity_id);
  let actorUid = currentUid;
  if (!actorUid || isTechnicalActor(actorUid)) {
    actorUid = await businessActorUid(event);
  }
  if (isTechnicalActor(actorUid)) actorUid = '';

  let fallback = {};
  if (
    entityType === 'user' &&
    string(event.action) === 'user.created' &&
    actorUid === entityId
  ) {
    const user = await getDocument('users', entityId);
    fallback = {actor_name: userLabel(user || {}, entityId)};
  }

  const actor = await resolveActor(actorUid, fallback);
  const label = await entityLabel(event);
  return {
    entity_label: label,
    actor_uid: actor.uid,
    actor_name: actor.name,
    actor_email: actor.email,
    actor_role: actor.role,
    actor_kind: actor.kind,
  };
};

const changed = (data, patch) =>
  Object.entries(patch).some(([key, value]) => string(data[key]) !== string(value));

const pendingWrites = [];

const queueUpdate = (ref, data, patch, stats, key) => {
  if (!changed(data, patch)) return;
  stats[key] += 1;
  if (apply) pendingWrites.push({ref, patch});
};

const flushWrites = async () => {
  while (pendingWrites.length > 0) {
    const batch = db.batch();
    pendingWrites.splice(0, 400).forEach(({ref, patch}) => {
      batch.set(ref, patch, {merge: true});
    });
    await batch.commit();
  }
};

const backfillEvents = async (stats) => {
  const globalEvents = await db.collection('decision_audit_events').get();
  for (const document of globalEvents.docs) {
    const data = document.data() || {};
    const patch = await normalizeEvent(data);
    queueUpdate(document.ref, data, patch, stats, 'globalEvents');
  }
  console.error(`Scanned ${globalEvents.size} global decision events`);

  const audits = await db.collection('decision_audits').get();
  for (const document of audits.docs) {
    const events = await document.ref.collection('events').get();
    for (const eventDocument of events.docs) {
      const eventData = eventDocument.data() || {};
      const eventPatch = await normalizeEvent(eventData);
      queueUpdate(
        eventDocument.ref,
        eventData,
        eventPatch,
        stats,
        'nestedEvents',
      );
    }
    const latest = await document.ref
      .collection('events')
      .orderBy('recorded_at', 'desc')
      .limit(1)
      .get();
    if (latest.empty) continue;
    const latestData = latest.docs[0].data() || {};
    const normalized = await normalizeEvent(latestData);
    const patch = {
      entity_label: normalized.entity_label,
      latest_actor: {
        actor_uid: normalized.actor_uid,
        actor_name: normalized.actor_name,
        actor_email: normalized.actor_email,
        actor_role: normalized.actor_role,
        actor_kind: normalized.actor_kind,
      },
    };
    const current = document.data() || {};
    const currentActor = current.latest_actor || {};
    if (
      string(current.entity_label) === string(patch.entity_label) &&
      !changed(currentActor, patch.latest_actor)
    ) {
      continue;
    }
    stats.summaries += 1;
    if (apply) pendingWrites.push({ref: document.ref, patch});
  }
  console.error(`Scanned ${audits.size} decision summaries`);
};

const backfillCreatorSnapshots = async (stats) => {
  const targets = [
    {
      collection: 'teaching_shifts',
      uidKeys: ['created_by_admin_id'],
      nameKey: 'created_by_name',
      emailKey: 'created_by_email',
      kindKey: null,
      stat: 'shifts',
    },
    {
      collection: 'invoices',
      uidKeys: ['created_by', 'createdBy'],
      nameKey: 'created_by_name',
      emailKey: 'created_by_email',
      kindKey: 'created_by_kind',
      stat: 'invoices',
    },
  ];

  for (const target of targets) {
    const snapshot = await db.collection(target.collection).get();
    for (const document of snapshot.docs) {
      const data = document.data() || {};
      if (
        string(data[target.nameKey]) &&
        string(data[target.emailKey]) &&
        (!target.kindKey || string(data[target.kindKey]))
      ) {
        continue;
      }
      const uid = first(data, target.uidKeys);
      const actor = await resolveActor(uid);
      const patch = {
        [target.nameKey]: actor.name,
        [target.emailKey]: actor.email,
        ...(target.kindKey ? {[target.kindKey]: actor.kind} : {}),
      };
      queueUpdate(document.ref, data, patch, stats, target.stat);
    }
    console.error(
      `Scanned ${snapshot.size} ${target.collection} records`,
    );
  }
};

const main = async () => {
  const stats = {
    globalEvents: 0,
    nestedEvents: 0,
    summaries: 0,
    shifts: 0,
    invoices: 0,
  };
  await backfillEvents(stats);
  await backfillCreatorSnapshots(stats);
  await flushWrites();
  console.log(JSON.stringify({
    projectId,
    mode: apply ? 'apply' : 'dry-run',
    ...stats,
  }, null, 2));
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
