const admin = require('firebase-admin');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const {
  collectRoomPresence,
  _deriveShiftDisplayName,
  REALTIMEKIT_REQUIRED_SECRETS,
} = require('./realtimekit');

// How long after a class starts before a missing party is flagged, and how often
// the alert repeats while the class is still missing someone.
const GRACE_MINUTES = 5;
const REPEAT_MINUTES = 5;
// Only look back far enough to cover any reasonable class length.
const LOOKBACK_MS = 6 * 60 * 60 * 1000;
const ALERTS_COLLECTION = 'class_attendance_alerts';
const CLOSED_STATUSES = new Set([
  'cancelled',
  'completed',
  'fullyCompleted',
  'fully_completed',
]);
const ADMIN_ROLE_VALUES = ['admin', 'super_admin', 'admin_teacher'];

const _isAdminRole = (data) => {
  if (!data) return false;
  return (
    ADMIN_ROLE_VALUES.includes(data.role) ||
    ADMIN_ROLE_VALUES.includes(data.user_type) ||
    ADMIN_ROLE_VALUES.includes(data.userType) ||
    data.is_admin === true ||
    data.isAdmin === true ||
    data.is_admin_teacher === true
  );
};

const _tokensForUser = (userData) => {
  const tokenSet = new Set();
  const fcmTokens = Array.isArray(userData?.fcmTokens) ? userData.fcmTokens : [];
  for (const tokenData of fcmTokens) {
    if (tokenData?.token) tokenSet.add(tokenData.token);
  }
  if (userData?.fcmToken) tokenSet.add(userData.fcmToken);
  return [...tokenSet];
};

const _toDate = (value) => {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isFinite(parsed.getTime()) ? parsed : null;
};

const _normalizeIds = (rawList) => {
  if (!Array.isArray(rawList)) return [];
  const seen = new Set();
  const out = [];
  for (const item of rawList) {
    const value = (item ?? '').toString().trim();
    if (!value || seen.has(value)) continue;
    seen.add(value);
    out.push(value);
  }
  return out;
};

/**
 * Pure attendance decision. `present` is the list of user ids currently in the room.
 * Returns whether a class needs an alert and who is missing.
 * @returns {{ problem: boolean, missing: ('teacher'|'students'|'both'|null), withinGrace: boolean }}
 */
const evaluateClassAttendance = ({
  teacherId,
  studentIds,
  present,
  minutesSinceStart,
  graceMinutes = GRACE_MINUTES,
}) => {
  if (minutesSinceStart < graceMinutes) {
    return { problem: false, missing: null, withinGrace: true };
  }

  const presentSet = new Set(
    (present || []).map((id) => (id ?? '').toString().trim()).filter(Boolean)
  );
  const teacherPresent = !!teacherId && presentSet.has(teacherId.toString().trim());
  const studentPresent = (studentIds || []).some(
    (id) => presentSet.has((id ?? '').toString().trim())
  );

  if (teacherPresent && studentPresent) {
    return { problem: false, missing: null, withinGrace: false };
  }

  let missing = 'students';
  if (!teacherPresent && !studentPresent) {
    missing = 'both';
  } else if (!teacherPresent) {
    missing = 'teacher';
  }
  return { problem: true, missing, withinGrace: false };
};

const _alertMessage = (missing, className, minutes) => {
  const base = `${className} started ${minutes} min ago`;
  switch (missing) {
    case 'teacher':
      return {
        title: '⚠️ Teacher missing from class',
        body: `${base}, but the teacher hasn't joined.`,
      };
    case 'students':
      return {
        title: '⚠️ No students in class',
        body: `${base}, but no student has joined.`,
      };
    case 'both':
    default:
      return {
        title: '⚠️ Class unattended',
        body: `${base}, but nobody has joined.`,
      };
  }
};

const _getAllAdmins = async (db) => {
  const queries = [
    db.collection('users').where('role', 'in', ADMIN_ROLE_VALUES).get(),
    db.collection('users').where('user_type', 'in', ADMIN_ROLE_VALUES).get(),
    db.collection('users').where('is_admin', '==', true).get(),
  ];
  const snaps = await Promise.all(queries.map((q) => q.catch(() => ({ docs: [] }))));
  const byId = new Map();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      if (!byId.has(doc.id) && _isAdminRole(doc.data())) byId.set(doc.id, doc);
    }
  }
  return [...byId.values()];
};

/**
 * Recipients for attendance alerts: the configured "class monitor" admin
 * (settings/admin.class_monitor_admin_id) if set and still an admin, otherwise all admins.
 */
const resolveAlertRecipients = async (db) => {
  const settingsSnap = await db.collection('settings').doc('admin').get();
  const monitorId = settingsSnap.exists
    ? (settingsSnap.data().class_monitor_admin_id || '').toString().trim()
    : '';

  if (monitorId) {
    const userSnap = await db.collection('users').doc(monitorId).get();
    if (userSnap.exists && _isAdminRole(userSnap.data())) {
      return {
        recipientIds: [monitorId],
        tokens: _tokensForUser(userSnap.data()),
        designated: true,
      };
    }
  }

  const admins = await _getAllAdmins(db);
  const recipientIds = [];
  const tokens = new Set();
  for (const doc of admins) {
    recipientIds.push(doc.id);
    for (const token of _tokensForUser(doc.data())) tokens.add(token);
  }
  return { recipientIds, tokens: [...tokens], designated: false };
};

const _sendPush = async (tokens, title, body, data) => {
  if (!tokens || tokens.length === 0) {
    return { sent: false, successCount: 0, failureCount: 0 };
  }
  try {
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: { channelId: 'high_importance_channel', sound: 'default' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return {
      sent: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (err) {
    console.error('[class-monitor] push send failed:', err.message);
    return { sent: false, successCount: 0, failureCount: tokens.length };
  }
};

const _writeNotificationHistory = async ({
  db,
  recipients,
  title,
  body,
  shiftId,
  type,
  missing,
  minutesSinceStart,
  pushResult,
}) => {
  try {
    await db.collection('notification_history').add({
      sentBy: 'system',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientType: recipients.designated ? 'individual' : 'group',
      recipientIds: recipients.recipientIds,
      title,
      body,
      additionalData: {
        type,
        shiftId,
        missing: missing || null,
        minutesSinceStart: minutesSinceStart ?? null,
      },
      emailRequested: false,
      results: {
        totalRecipients: recipients.recipientIds.length,
        fcmSuccess: pushResult.successCount || 0,
        fcmFailed: pushResult.failureCount || 0,
        emailsSent: 0,
        emailsFailed: 0,
      },
    });
  } catch (err) {
    console.error(`[class-monitor] notification_history write failed for ${shiftId}:`, err.message);
  }
};

const monitorActiveClassAttendance = onSchedule(
  { schedule: 'every 5 minutes', secrets: REALTIMEKIT_REQUIRED_SECRETS },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const graceCutoff = new Date(now.getTime() - GRACE_MINUTES * 60 * 1000);
    const lookbackStart = new Date(now.getTime() - LOOKBACK_MS);

    // Classes that started at least GRACE ago (within the lookback window).
    // The shift_end > now check is applied in memory (Firestore allows a range on
    // only one field — same approach as sendScheduledShiftReminders).
    const snap = await db
      .collection('teaching_shifts')
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(lookbackStart))
      .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(graceCutoff))
      .get();

    if (snap.empty) {
      console.log('[class-monitor] no classes past grace in window');
      return;
    }

    // Recipients are the same for every alert this run — resolve once, lazily.
    let recipientsPromise = null;
    const getRecipients = () => {
      if (!recipientsPromise) recipientsPromise = resolveAlertRecipients(db);
      return recipientsPromise;
    };

    let alertsSent = 0;
    let resolved = 0;

    for (const doc of snap.docs) {
      const shiftId = doc.id;
      try {
        const shift = doc.data();
        const category = (shift.category || '').toString();
        if (category && category !== 'teaching') continue;
        if (CLOSED_STATUSES.has((shift.status || '').toString())) continue;

        const shiftStart = _toDate(shift.shift_start || shift.shiftStart);
        const shiftEnd = _toDate(shift.shift_end || shift.shiftEnd);
        if (!shiftStart || !shiftEnd) continue;

        const alertRef = db.collection(ALERTS_COLLECTION).doc(shiftId);

        // Class has ended — stop alerting; close any open alert for hygiene.
        if (shiftEnd.getTime() <= now.getTime()) {
          const openSnap = await alertRef.get();
          if (openSnap.exists && openSnap.data().closed !== true) {
            await alertRef.set(
              {
                closed: true,
                closed_at: admin.firestore.FieldValue.serverTimestamp(),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          }
          continue;
        }

        const meetingId = (
          shift.realtimekit_meeting_id || shift.realtimekitMeetingId || ''
        )
          .toString()
          .trim();
        const teacherId = (shift.teacher_id || shift.teacherId || '').toString().trim();
        const studentIds = _normalizeIds(shift.student_ids || shift.studentIds);
        // Nothing to expect (unassigned placeholder shift) — skip.
        if (!teacherId && studentIds.length === 0) continue;
        const minutesSinceStart = Math.floor((now.getTime() - shiftStart.getTime()) / 60000);

        const { participants } = await collectRoomPresence({ shiftId, meetingId });
        const present = participants
          .map((p) => (p.identity || '').toString().trim())
          .filter(Boolean);

        const verdict = evaluateClassAttendance({
          teacherId,
          studentIds,
          present,
          minutesSinceStart,
          graceMinutes: GRACE_MINUTES,
        });

        const alertSnap = await alertRef.get();
        const alert = alertSnap.exists ? alertSnap.data() : null;
        const className = _deriveShiftDisplayName(shift);

        if (!verdict.problem) {
          // Both sides present now — send a single "resolved" notice if we had alerted.
          if (alert && alert.resolved !== true && alert.closed !== true && (alert.alert_count || 0) > 0) {
            const recipients = await getRecipients();
            const title = '✅ Class attendance resolved';
            const body = `${className}: the teacher and a student are now both in the class.`;
            const pushResult = await _sendPush(recipients.tokens, title, body, {
              type: 'class_attendance_resolved',
              shiftId,
            });
            await _writeNotificationHistory({
              db,
              recipients,
              title,
              body,
              shiftId,
              type: 'class_attendance_resolved',
              missing: null,
              minutesSinceStart,
              pushResult,
            });
            await alertRef.set(
              {
                resolved: true,
                resolved_at: admin.firestore.FieldValue.serverTimestamp(),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
            resolved += 1;
          }
          continue;
        }

        // Problem persists — throttle to ~every REPEAT_MINUTES. Allow a small jitter
        // tolerance so scheduler drift doesn't skip a cycle.
        const lastAlertAt = alert && alert.resolved !== true ? _toDate(alert.last_alert_at) : null;
        const dueAgain =
          !lastAlertAt ||
          now.getTime() - lastAlertAt.getTime() >= REPEAT_MINUTES * 60 * 1000 - 30 * 1000;
        if (!dueAgain) continue;

        const recipients = await getRecipients();
        const { title, body } = _alertMessage(verdict.missing, className, minutesSinceStart);
        const pushResult = await _sendPush(recipients.tokens, title, body, {
          type: 'class_attendance_alert',
          shiftId,
          missing: verdict.missing,
        });
        await _writeNotificationHistory({
          db,
          recipients,
          title,
          body,
          shiftId,
          type: 'class_attendance_alert',
          missing: verdict.missing,
          minutesSinceStart,
          pushResult,
        });

        const regressed = alert && alert.resolved === true;
        await alertRef.set(
          {
            shift_id: shiftId,
            class_name: className,
            teacher_id: teacherId,
            missing: verdict.missing,
            minutes_since_start: minutesSinceStart,
            first_detected_at:
              alert && !regressed && alert.first_detected_at
                ? alert.first_detected_at
                : admin.firestore.FieldValue.serverTimestamp(),
            last_alert_at: admin.firestore.FieldValue.serverTimestamp(),
            alert_count: (regressed ? 0 : alert?.alert_count || 0) + 1,
            resolved: false,
            closed: false,
            recipient_ids: recipients.recipientIds,
            designated_recipient: recipients.designated,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        alertsSent += 1;
      } catch (err) {
        console.error(`[class-monitor] error processing shift ${shiftId}:`, err.message);
      }
    }

    console.log(
      `[class-monitor] checked ${snap.size} shift(s); alerts sent: ${alertsSent}, resolved: ${resolved}`
    );
  }
);

module.exports = {
  monitorActiveClassAttendance,
  __test__: {
    evaluateClassAttendance,
    _alertMessage,
    _isAdminRole,
    _normalizeIds,
    GRACE_MINUTES,
    REPEAT_MINUTES,
  },
};
