'use strict';

/**
 * The rules of shift trading, kept free of Firestore so they can be tested.
 *
 * A class or duty is "offered" while `is_published` is true. Whoever takes it
 * becomes its teacher (`teacher_id`), so the clock-in, the timesheet and the
 * pay all belong to the person who actually does the work.
 */

const ADMIN_ROLES = new Set(['admin', 'super_admin']);

const lower = (value) => String(value || '').trim().toLowerCase();

/** A leadership duty or meeting, as opposed to a class that is taught. */
function isLeadershipDuty(shiftData) {
  const category = lower(shiftData && shiftData.shift_category) || 'teaching';
  return category !== 'teaching';
}

function isAdminUser(userData) {
  if (!userData) return false;
  return ADMIN_ROLES.has(lower(userData.user_type)) || ADMIN_ROLES.has(lower(userData.role));
}

function isTeacherUser(userData) {
  if (!userData) return false;
  return lower(userData.user_type) === 'teacher' || userData.is_admin_teacher === true;
}

/**
 * A leader is an admin, an admin-teacher, or anyone who already holds a
 * leadership duty of their own.
 */
function isLeader(userData, holdsLeadershipDuty) {
  if (!userData) return false;
  return isAdminUser(userData) || userData.is_admin_teacher === true || holdsLeadershipDuty === true;
}

/**
 * Why this person may not take this class or duty, or null when they may.
 * A class goes to a teacher (or an admin who teaches); a leadership duty goes
 * only to a leader, never to a teacher who is not one.
 */
function takeRefusal({shiftData, userData, holdsLeadershipDuty}) {
  if (!userData) return 'User profile not found';
  if (userData.is_active === false) return 'This account is not active';
  if (isLeadershipDuty(shiftData)) {
    return isLeader(userData, holdsLeadershipDuty) ?
      null :
      'Only leaders can take a leadership duty';
  }
  return isTeacherUser(userData) || isAdminUser(userData) ?
    null :
    'Only teachers can take a class';
}

/** Why this class or duty cannot be offered right now, or null when it can. */
function offerRefusal(shiftData, nowMs) {
  if (!shiftData) return 'Shift not found';
  if (lower(shiftData.status) !== 'scheduled') return 'Only a class that has not started can be offered';
  const start = shiftData.shift_start && shiftData.shift_start.toDate ? shiftData.shift_start.toDate() : null;
  if (!start || start.getTime() <= nowMs) return 'This class has already started';
  return null;
}

const shiftName = (data) =>
  (data && (data.custom_name || data.auto_generated_name || data.subject_display_name || data.subject)) || 'A class';

/**
 * What happened to a shift's offer between two versions of the document, for
 * the trade record: offered, withdrawn, claimed (taken by the new teacher
 * themselves) or assigned (given to them by an admin). Null when the change
 * has nothing to do with trading.
 */
function tradeEventFromChange(before, after) {
  if (!before || !after) return null;
  const wasOffered = before.is_published === true;
  const isOffered = after.is_published === true;
  const base = {
    shift_name: shiftName(after),
    shift_category: lower(after.shift_category) || 'teaching',
    shift_start: after.shift_start || null,
    shift_end: after.shift_end || null,
  };

  if (!wasOffered && isOffered) {
    const owner = after.teacher_id || null;
    return {
      ...base,
      action: 'offered',
      actor_id: after.published_by || owner,
      from_teacher_id: owner,
      from_teacher_name: after.teacher_name || '',
      to_teacher_id: null,
      to_teacher_name: '',
    };
  }

  if (wasOffered && !isOffered) {
    const teacherChanged = before.teacher_id !== after.teacher_id;
    if (!teacherChanged) {
      return {
        ...base,
        action: 'withdrawn',
        actor_id: after.shift_trade_withdrawn_by || before.published_by || before.teacher_id || null,
        from_teacher_id: before.teacher_id || null,
        from_teacher_name: before.teacher_name || '',
        to_teacher_id: null,
        to_teacher_name: '',
      };
    }
    const assignedBy = after.shift_trade_assigned_by || null;
    return {
      ...base,
      action: assignedBy ? 'assigned' : 'claimed',
      actor_id: assignedBy || after.teacher_id || null,
      from_teacher_id: before.teacher_id || null,
      from_teacher_name: before.teacher_name || '',
      to_teacher_id: after.teacher_id || null,
      to_teacher_name: after.teacher_name || '',
    };
  }

  return null;
}

/**
 * Who hears about a new offer: for a class, the teachers; for a leadership
 * duty, only the leaders. Never the person who offered it nor its current
 * holder.
 */
function offerAudience({shiftData, users, excludeUids}) {
  const exclude = new Set((excludeUids || []).filter(Boolean));
  const duty = isLeadershipDuty(shiftData);
  return users
    .filter((user) => user && user.id && !exclude.has(user.id))
    .filter((user) => (user.data || {}).is_active !== false)
    .filter((user) => (duty ? isLeader(user.data, false) : lower((user.data || {}).user_type) === 'teacher'))
    .map((user) => user.id);
}

module.exports = {
  isLeadershipDuty,
  isAdminUser,
  isTeacherUser,
  isLeader,
  takeRefusal,
  offerRefusal,
  shiftName,
  tradeEventFromChange,
  offerAudience,
};
