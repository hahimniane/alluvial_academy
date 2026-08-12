const admin = require('firebase-admin');
const crypto = require('crypto');

const _string = (value) => (value == null ? '' : String(value).trim());

const _firstString = (data, keys) => {
  for (const key of keys) {
    const value = _string(data && data[key]);
    if (value) return value;
  }
  return '';
};

const _role = (data) =>
  _firstString(data, [
    'user_type',
    'userType',
    'role',
    'admin_type',
    'adminType',
  ]);

const _looksLikePhone = (value) =>
  /^\+?[0-9][0-9 ()-]{6,}$/.test(_string(value));

const _looksLikeEmail = (value) =>
  /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(_string(value));

const _isTechnicalActor = (value) => {
  const normalized = _string(value).toLowerCase();
  return normalized === 'system' ||
    normalized === 'automation' ||
    normalized.endsWith('.gserviceaccount.com') ||
    normalized.includes('firebase-adminsdk') ||
    normalized.includes('compute@developer');
};

const _name = (data) => {
  const stored = _firstString(data, [
    'name',
    'display_name',
    'displayName',
    'full_name',
    'fullName',
  ]);
  const first = _firstString(data, ['first_name', 'firstName']);
  const last = _firstString(data, ['last_name', 'lastName']);
  const personalName = `${first} ${last}`.trim();
  if (personalName) return personalName;
  if (stored && !_looksLikePhone(stored) && !_looksLikeEmail(stored)) {
    return stored;
  }
  return '';
};

const decisionAuditDocumentId = (entityType, entityId) =>
  `${_string(entityType).replace(/[^a-zA-Z0-9_-]/g, '_')}__${_string(entityId).replace(/\//g, '_')}`;

const _eventId = (value) =>
  _string(value).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 1400);

const resolveDecisionActor = async (
  db,
  actorUid,
  fallback = {},
) => {
  const rawUid = _string(actorUid);
  const isTechnicalActor = _isTechnicalActor(rawUid);
  const uid = isTechnicalActor ? '' : rawUid;
  let actorData = null;

  if (uid) {
    try {
      const direct = await db.collection('users').doc(uid).get();
      if (direct.exists) actorData = direct.data() || {};
    } catch (_) {}

    if (!actorData) {
      try {
        const byUid = await db
          .collection('users')
          .where('uid', '==', uid)
          .limit(1)
          .get();
        if (!byUid.empty) actorData = byUid.docs[0].data() || {};
      } catch (_) {}
    }
  }

  const fallbackName = _firstString(fallback, [
    'actor_name',
    'actorName',
    'name',
  ]);
  const fallbackEmail = _firstString(fallback, [
    'actor_email',
    'actorEmail',
    'email',
    'e-mail',
  ]);
  const fallbackRole = _firstString(fallback, [
    'actor_role',
    'actorRole',
    'role',
    'user_type',
    'userType',
  ]);
  const resolvedName =
    (actorData && _name(actorData)) ||
    (!_looksLikePhone(fallbackName) &&
    !_looksLikeEmail(fallbackName) &&
    !_isTechnicalActor(fallbackName)
      ? fallbackName
      : '');

  return {
    uid,
    name: resolvedName || (isTechnicalActor || !uid
      ? 'System automation'
      : 'Authenticated user'),
    email:
      (actorData &&
        _firstString(actorData, ['e-mail', 'email', 'user_email'])) ||
      (_isTechnicalActor(fallbackEmail) ? '' : fallbackEmail),
    role: (actorData && _role(actorData)) || fallbackRole,
    kind: isTechnicalActor || !uid ? 'system' : 'person',
  };
};

const buildDecisionAuditWrites = ({
  db,
  entityType,
  entityId,
  action,
  actor,
  entityLabel = '',
  source = 'firestore',
  metadata = {},
  eventId,
}) => {
  const auditId = decisionAuditDocumentId(entityType, entityId);
  const summaryRef = db.collection('decision_audits').doc(auditId);
  const resolvedEventId = _eventId(eventId || `${action}_${Date.now()}`);
  const eventRef = summaryRef.collection('events').doc(resolvedEventId);
  const globalEventId = crypto
    .createHash('sha256')
    .update(`${auditId}/${resolvedEventId}`)
    .digest('hex');
  const globalEventRef = db
    .collection('decision_audit_events')
    .doc(globalEventId);
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const actorSnapshot = {
    actor_uid: _string(actor && actor.uid),
    actor_name: _string(actor && actor.name) || 'System automation',
    actor_email: _string(actor && actor.email),
    actor_role: _string(actor && actor.role),
    actor_kind: _string(actor && actor.kind) || 'person',
  };

  return {
    summaryRef,
    eventRef,
    globalEventRef,
    summaryData: {
      entity_type: _string(entityType),
      entity_id: _string(entityId),
      entity_label: _string(entityLabel),
      latest_action: _string(action),
      latest_at: timestamp,
      latest_actor: actorSnapshot,
    },
    eventData: {
      entity_type: _string(entityType),
      entity_id: _string(entityId),
      entity_label: _string(entityLabel),
      action: _string(action),
      ...actorSnapshot,
      source: _string(source),
      metadata,
      recorded_at: timestamp,
    },
  };
};

const applyDecisionAuditWrites = (writer, writes) => {
  writer.set(writes.summaryRef, writes.summaryData, {merge: true});
  writer.set(writes.eventRef, writes.eventData, {merge: true});
  writer.set(writes.globalEventRef, writes.eventData, {merge: true});
};

const recordDecisionAudit = async (options) => {
  const db = options.db || admin.firestore();
  const actor =
    options.actor ||
    (await resolveDecisionActor(
      db,
      options.actorUid,
      options.actorFallback,
    ));
  const writes = buildDecisionAuditWrites({...options, db, actor});
  const batch = db.batch();
  applyDecisionAuditWrites(batch, writes);
  await batch.commit();
  return writes;
};

module.exports = {
  applyDecisionAuditWrites,
  buildDecisionAuditWrites,
  decisionAuditDocumentId,
  recordDecisionAudit,
  resolveDecisionActor,
};
