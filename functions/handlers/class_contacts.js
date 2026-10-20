const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {displayName} = require('../utils/parent_link');

const WINDOW_DAYS = 60;
const DAY_MS = 24 * 60 * 60 * 1000;

const _lower = (value) => String(value == null ? '' : value).trim().toLowerCase();

const _roles = (data) => {
  const record = data && typeof data === 'object' ? data : {};
  const roles = new Set();
  [record.user_type, record.userType, record.role].forEach((r) => {
    if (_lower(r)) roles.add(_lower(r));
  });
  if (Array.isArray(record.secondary_roles)) {
    record.secondary_roles.forEach((r) => {
      if (_lower(r)) roles.add(_lower(r));
    });
  }
  if (roles.has('guardian')) roles.add('parent');
  return roles;
};

const _isActive = (data) => !!data && data.is_active !== false;

/**
 * A dialable number from a users doc. `phone_number` is the only phone field in
 * use; it is stored either already international ("+224 621…") or national
 * with the country separately in `country_code` ("+44" + "0798…").
 *
 * @returns {{phone: string, tel: string}|null}
 */
const normalizePhone = (data) => {
  const raw = String((data && (data.phone_number || data.phoneNumber || data.phone)) || '').trim();
  const digits = raw.replace(/\D/g, '');
  if (digits.length < 6) return null;

  if (raw.startsWith('+') || raw.startsWith('00')) {
    const international = raw.startsWith('00') ? digits.slice(2) : digits;
    if (international.length < 6) return null;
    const tel = `+${international}`;
    return {phone: raw.startsWith('+') ? raw.replace(/\s+/g, ' ') : tel, tel};
  }

  const ccDigits = String((data && (data.country_code || data.countryCode)) || '').replace(/\D/g, '');
  if (ccDigits) {
    if (digits.startsWith(ccDigits) && digits.length >= ccDigits.length + 8) {
      return {phone: `+${digits}`, tel: `+${digits}`};
    }
    const national = digits.replace(/^0+/, '');
    return {phone: `+${ccDigits} ${national}`, tel: `+${ccDigits}${national}`};
  }

  // No country on file: 11+ digits without a trunk 0 are already international.
  if (digits.length >= 11 && !digits.startsWith('0')) {
    return {phone: `+${digits}`, tel: `+${digits}`};
  }
  return {phone: raw, tel: digits};
};

const _contactFor = (id, data, relationship) => {
  if (!_isActive(data)) return null;
  const phone = normalizePhone(data);
  if (!phone) return null;
  return {name: displayName(data) || '', relationship, phone: phone.phone, tel: phone.tel};
};

const _byName = (a, b) => (a.name || '').localeCompare(b.name || '');

const _uniqueStrings = (values) => {
  const out = new Set();
  (Array.isArray(values) ? values : []).forEach((v) => {
    const s = String(v || '').trim();
    if (s) out.add(s);
  });
  return Array.from(out);
};

const _makeUserReader = (db) => {
  const cache = new Map();
  return (id) => {
    if (!cache.has(id)) {
      cache.set(
        id,
        db.collection('users').doc(id).get()
          .then((snap) => (snap.exists ? snap.data() || {} : null))
          .catch(() => null)
      );
    }
    return cache.get(id);
  };
};

const _shiftsInWindow = async (db, field, op, value, from, to) => {
  const snap = await db.collection('teaching_shifts')
    .where(field, op, value)
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(from))
    .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(to))
    .get();
  return snap.docs
    .map((doc) => doc.data() || {})
    .filter((shift) => _lower(shift.status) !== 'cancelled');
};

const _teacherContacts = async ({readUser, shifts}) => {
  const teacherIds = _uniqueStrings(shifts.map((s) => s.teacher_id));
  const contacts = await Promise.all(teacherIds.map(async (id) =>
    _contactFor(id, await readUser(id), 'teacher')));
  return contacts.filter(Boolean).sort(_byName);
};

/**
 * Phone contacts for the people the caller has classes with. A teacher gets
 * the parents of each student they teach; a parent gets each child's teachers;
 * a student gets their own teachers. Nothing else about anyone is returned.
 */
const buildClassContacts = async ({db, uid, now = new Date()}) => {
  const empty = {students: [], children: [], teachers: []};
  if (!uid) return empty;

  const readUser = _makeUserReader(db);
  const caller = await readUser(uid);
  if (!_isActive(caller)) return empty;
  const roles = _roles(caller);
  if (roles.has('admin') || roles.has('super_admin')) return empty;

  const from = new Date(now.getTime() - WINDOW_DAYS * DAY_MS);
  const to = new Date(now.getTime() + WINDOW_DAYS * DAY_MS);
  const result = {students: [], children: [], teachers: []};

  if (roles.has('teacher')) {
    const shifts = await _shiftsInWindow(db, 'teacher_id', '==', uid, from, to);
    const studentIds = _uniqueStrings(shifts.flatMap((s) => s.student_ids || []));
    const groups = await Promise.all(studentIds.map(async (studentId) => {
      const student = await readUser(studentId);
      if (!_isActive(student)) return null;
      const guardianIds = _uniqueStrings(student.guardian_ids || student.guardianIds)
        .filter((id) => id !== studentId);
      const guardians = (await Promise.all(guardianIds.map(async (id) =>
        _contactFor(id, await readUser(id), 'parent')))).filter(Boolean);
      let contacts = guardians;
      if (contacts.length === 0) {
        const own = _contactFor(studentId, student, 'student');
        contacts = own ? [own] : [];
      }
      const seen = new Set();
      contacts = contacts.filter((c) => (seen.has(c.tel) ? false : seen.add(c.tel)));
      return {studentName: displayName(student), contacts: contacts.sort(_byName)};
    }));
    result.students = groups.filter(Boolean).sort((a, b) => a.studentName.localeCompare(b.studentName));
  }

  if (roles.has('parent')) {
    const childSnap = await db.collection('users').where('guardian_ids', 'array-contains', uid).get();
    const children = childSnap.docs
      .filter((doc) => doc.id !== uid)
      .map((doc) => ({id: doc.id, data: doc.data() || {}}))
      .filter((child) => _roles(child.data).has('student') && _isActive(child.data));
    const groups = await Promise.all(children.map(async (child) => {
      const shifts = await _shiftsInWindow(db, 'student_ids', 'array-contains', child.id, from, to);
      const teachers = await _teacherContacts({readUser, shifts});
      return {studentName: displayName(child.data), contacts: teachers};
    }));
    result.children = groups.sort((a, b) => a.studentName.localeCompare(b.studentName));
  }

  if (roles.has('student')) {
    const shifts = await _shiftsInWindow(db, 'student_ids', 'array-contains', uid, from, to);
    result.teachers = await _teacherContacts({readUser, shifts});
  }

  return result;
};

const getClassContacts = onCall({cors: true, invoker: 'public'}, async (request) => {
  const uid = request && request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }
  return buildClassContacts({db: admin.firestore(), uid});
});

module.exports = {getClassContacts, buildClassContacts, normalizePhone};
