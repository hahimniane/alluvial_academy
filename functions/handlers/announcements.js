'use strict';

const admin = require('firebase-admin');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');

const AUDIENCE_ROLES = ['teacher', 'student', 'parent', 'admin'];
const ADMIN_ROLES = new Set(['admin', 'super_admin']);
const MULTICAST_LIMIT = 500;
const PUSH_BODY_MAX = 240;

const text = (value) => (typeof value === 'string' ? value.trim() : '');

/** The audience roles on an announcement, limited to the four known roles. */
const audienceOf = (data = {}) => {
  const list = Array.isArray(data.audience) ? data.audience : [];
  return Array.from(new Set(list.map((role) => text(role).toLowerCase())))
    .filter((role) => AUDIENCE_ROLES.includes(role));
};

/** Roles a user holds: user_type plus secondary_roles, super_admin counted as admin. */
const rolesOfUser = (data = {}) => {
  const roles = new Set();
  const add = (value) => {
    const role = text(value).toLowerCase();
    if (!role) return;
    roles.add(ADMIN_ROLES.has(role) ? 'admin' : role);
  };
  add(data.user_type);
  if (Array.isArray(data.secondary_roles)) data.secondary_roles.forEach(add);
  if (data.is_admin_teacher === true) roles.add('admin');
  return roles;
};

/** Deactivated, merged or archived accounts get no push. */
const isReachableUser = (data = {}) =>
  data.is_active !== false &&
  !data.merged_into &&
  !data.deactivated_at &&
  data.is_archived !== true &&
  !data.archived_at;

/**
 * Device tokens for the users an announcement is addressed to. `userDocs` may
 * hold the same user twice (it is the union of two queries); tokens are
 * de-duplicated across everyone.
 */
const recipientTokens = (userDocs, audience) => {
  const wanted = new Set(audience);
  const seenUsers = new Set();
  const tokens = new Set();
  for (const entry of userDocs) {
    const id = entry.id;
    const data = (typeof entry.data === 'function' ? entry.data() : entry.data) || {};
    if (id && seenUsers.has(id)) continue;
    if (id) seenUsers.add(id);
    if (!isReachableUser(data)) continue;
    const roles = rolesOfUser(data);
    if (![...roles].some((role) => wanted.has(role))) continue;
    const values = Array.isArray(data.fcmTokens) ?
      data.fcmTokens.map((item) => item && item.token).filter(Boolean) :
      [];
    if (values.length === 0 && data.fcmToken) values.push(data.fcmToken);
    values.forEach((token) => tokens.add(String(token)));
  }
  return Array.from(tokens);
};

const chunksOf = (values, size = MULTICAST_LIMIT) => {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
};

const pushBody = (body) => {
  const flat = text(body).replace(/\s+/g, ' ');
  return flat.length > PUSH_BODY_MAX ? `${flat.slice(0, PUSH_BODY_MAX - 1)}…` : flat;
};

/** Every user holding at least one of the audience roles (primary or secondary). */
const loadAudienceUsers = async (db, audience) => {
  const queryRoles = audience.includes('admin') ? [...audience, 'super_admin'] : audience;
  const [primary, secondary] = await Promise.all([
    db.collection('users').where('user_type', 'in', queryRoles).get(),
    db.collection('users').where('secondary_roles', 'array-contains-any', queryRoles).get(),
  ]);
  return [...primary.docs, ...secondary.docs];
};

/**
 * Claims the push once: a retried or duplicated create event finds
 * push_sent_at already set and stops, so nobody is notified twice.
 */
const claimPush = async (db, ref) => db.runTransaction(async (transaction) => {
  const snapshot = await transaction.get(ref);
  if (!snapshot.exists) return null;
  const data = snapshot.data() || {};
  if (data.send_push !== true || data.status !== 'published' || data.push_sent_at) return null;
  transaction.update(ref, {push_sent_at: admin.firestore.FieldValue.serverTimestamp()});
  return data;
});

const sendAnnouncementPush = async ({db, messaging, announcementId}) => {
  const ref = db.collection('announcements').doc(announcementId);
  const data = await claimPush(db, ref);
  if (!data) return {skipped: true};

  const audience = audienceOf(data);
  const tokens = audience.length ? recipientTokens(await loadAudienceUsers(db, audience), audience) : [];
  let successCount = 0;
  let failureCount = 0;
  for (const chunk of chunksOf(tokens)) {
    const response = await messaging.sendEachForMulticast({
      notification: {title: text(data.title), body: pushBody(data.body)},
      data: {type: 'announcement', announcementId},
      tokens: chunk,
      android: {priority: 'high', notification: {sound: 'default', channelId: 'high_importance_channel'}},
      apns: {payload: {aps: {sound: 'default'}}},
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
  }
  await ref.update({
    push_token_count: tokens.length,
    push_success_count: successCount,
    push_failure_count: failureCount,
  });
  return {skipped: false, tokenCount: tokens.length, successCount, failureCount};
};

const onAnnouncementCreated = onDocumentCreated('announcements/{announcementId}', async (event) => {
  const data = event.data && event.data.data();
  if (!data || data.send_push !== true) return;
  const result = await sendAnnouncementPush({
    db: admin.firestore(),
    messaging: admin.messaging(),
    announcementId: event.params.announcementId,
  });
  console.log(`[announcements] ${event.params.announcementId}`, JSON.stringify(result));
});

module.exports = {
  onAnnouncementCreated,
  __test__: {
    audienceOf,
    rolesOfUser,
    isReachableUser,
    recipientTokens,
    chunksOf,
    pushBody,
    sendAnnouncementPush,
  },
};
