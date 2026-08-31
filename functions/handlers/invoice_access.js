const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const BATCH_SIZE = 400;

const _normalizeStatus = (raw) => (raw || '').toString().trim().toLowerCase();

const _toNumber = (...values) => {
  for (const value of values) {
    const number = Number(value);
    if (Number.isFinite(number)) return number;
  }
  return 0;
};

const _toDate = (value) => {
  if (!value) return null;
  if (value.toDate) return value.toDate();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const _getEffectiveAccessCutoffDate = (invoice) => {
  const explicitCutoff = _toDate(invoice.access_cutoff_date || invoice.accessCutoffDate);
  if (explicitCutoff) return explicitCutoff;

  const dueDate = _toDate(invoice.due_date || invoice.dueDate);
  if (!dueDate) return null;

  return new Date(dueDate.getTime() + 24 * 60 * 60 * 1000);
};

const _collectString = (target, value) => {
  const normalized = (value || '').toString().trim();
  if (normalized) target.add(normalized);
};

const _collectStrings = (target, values) => {
  if (!Array.isArray(values)) return;
  values.forEach((value) => _collectString(target, value));
};

/**
 * The children an invoice bills. Prefers the explicit student_ids array, then
 * per-line student_id, and returns [] when the invoice predates per-child
 * attribution — callers treat that as "applies to the whole family".
 */
const _invoiceStudentIds = (invoice = {}) => {
  const ids = new Set();
  _collectStrings(ids, invoice.student_ids || invoice.studentIds);
  if (Array.isArray(invoice.items)) {
    invoice.items.forEach((item) =>
      _collectString(ids, item && (item.student_id || item.studentId))
    );
  }
  return Array.from(ids);
};

const _throwCallableError = (code, message, details) => {
  throw new HttpsError(code, message, details);
};

const _isAdminRole = (data) => {
  if (!data) return false;
  const role = _normalizeStatus(data.role);
  const userType = _normalizeStatus(data.user_type);
  const camelUserType = _normalizeStatus(data.userType);
  return (
    role === 'admin' ||
    role === 'super_admin' ||
    userType === 'admin' ||
    userType === 'super_admin' ||
    camelUserType === 'admin' ||
    camelUserType === 'super_admin' ||
    data.is_admin === true ||
    data.isAdmin === true ||
    data.is_super_admin === true ||
    data.isSuperAdmin === true ||
    data.is_admin_teacher === true
  );
};

const _isAdminUid = async (uid) => {
  if (!uid) return false;
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return false;
  return _isAdminRole(doc.data());
};

const _isBlockingInvoice = (invoice, now = new Date()) => {
  const status = _normalizeStatus(invoice.status);
  if (status === 'paid' || status === 'cancelled') return false;

  const totalAmount = _toNumber(invoice.total_amount, invoice.totalAmount);
  const paidAmount = _toNumber(invoice.paid_amount, invoice.paidAmount);
  if (totalAmount <= 0 || paidAmount >= totalAmount) return false;

  const cutoffDate = _getEffectiveAccessCutoffDate(invoice);
  return !!cutoffDate && cutoffDate <= now;
};

/**
 * Recomputes access_suspended for all students linked to a parent.
 *
 * Suspension logic:
 *   A student is suspended if ANY invoice for their parent has:
 *     - status != 'paid' and status != 'cancelled'
 *     - paid_amount < total_amount (not fully paid)
 *     - access_cutoff_date != null AND access_cutoff_date <= now
 *
 * Access is restored immediately when all such conditions are cleared.
 */
const _recomputeStudentAccess = async (db, parentId) => {
  if (!parentId) return;

  const invoiceDocsById = new Map();
  const addInvoiceDocs = (snap) => {
    snap.docs.forEach((doc) => invoiceDocsById.set(doc.id, doc));
  };

  const [snakeParentSnap, camelParentSnap] = await Promise.all([
    db
      .collection('invoices')
      .where('parent_id', '==', parentId)
      .get(),
    db
      .collection('invoices')
      .where('parentId', '==', parentId)
      .get(),
  ]);
  addInvoiceDocs(snakeParentSnap);
  addInvoiceDocs(camelParentSnap);

  const now = new Date();
  const invoiceStudentIds = new Set();

  // Suspension is decided per child. An invoice that names the children it
  // bills (student_ids) suspends only those; a sibling who is not on it keeps
  // access. Invoices created before per-child attribution existed carry no
  // student_ids, so they still suspend the whole family — deploying this
  // changes nobody's access until new invoices are raised.
  const blockedStudentIds = new Set();
  let blocksWholeFamily = false;

  for (const doc of invoiceDocsById.values()) {
    const invoice = doc.data();
    _collectString(invoiceStudentIds, invoice.student_id || invoice.studentId);
    _collectStrings(invoiceStudentIds, invoice.student_ids || invoice.studentIds);

    if (!_isBlockingInvoice(invoice, now)) continue;

    const billed = _invoiceStudentIds(invoice);
    if (billed.length === 0) {
      blocksWholeFamily = true;
    } else {
      billed.forEach((id) => blockedStudentIds.add(id));
    }
  }

  // Collect all student IDs linked to this parent.
  // Two sources: student docs with guardian_ids containing parentId,
  // and the parent doc's children_ids array.
  const studentIds = new Set();

  const [byGuardian, parentDoc] = await Promise.all([
    db
      .collection('users')
      .where('guardian_ids', 'array-contains', parentId)
      .get(),
    db.collection('users').doc(parentId).get(),
  ]);

  byGuardian.docs.forEach((d) => studentIds.add(d.id));
  invoiceStudentIds.forEach((id) => studentIds.add(id));

  if (parentDoc.exists) {
    const parentData = parentDoc.data() || {};
    const childrenIds = [
      ...(Array.isArray(parentData.children_ids) ? parentData.children_ids : []),
      ...(Array.isArray(parentData.childrenIds) ? parentData.childrenIds : []),
    ];
    childrenIds.forEach((id) => _collectString(studentIds, id));
  }

  if (studentIds.size === 0) return;

  const studentIdsArr = Array.from(studentIds);

  const suspendedIds = [];
  for (let i = 0; i < studentIdsArr.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = studentIdsArr.slice(i, i + BATCH_SIZE);
    for (const studentId of chunk) {
      const suspend = blocksWholeFamily || blockedStudentIds.has(studentId);
      if (suspend) suspendedIds.push(studentId);
      const studentRef = db.collection('users').doc(studentId);
      batch.set(studentRef, {
        access_suspended: suspend,
        access_suspension_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    await batch.commit();
  }

  console.log(
    `[invoice_access] parent=${parentId}: ` +
      `wholeFamily=${blocksWholeFamily}, ` +
      `suspended: ${suspendedIds.join(', ') || 'none'}, ` +
      `evaluated: ${studentIdsArr.join(', ')}`
  );
};

/**
 * Firestore trigger: fires whenever an invoice is created, updated, or deleted.
 * Re-evaluates student access for the affected parent.
 */
const onInvoiceWrite = onDocumentWritten('invoices/{invoiceId}', async (event) => {
  const before = event.data.before;
  const after = event.data.after;

  const afterData = after.exists ? after.data() : null;
  const beforeData = before.exists ? before.data() : null;

  const parentId = (
    (afterData && afterData.parent_id) ||
    (afterData && afterData.parentId) ||
    (beforeData && beforeData.parent_id) ||
    (beforeData && beforeData.parentId) ||
    ''
  )
    .toString()
    .trim();

  if (!parentId) return;

  // Only recompute when relevant fields change, to avoid infinite loops.
  const relevantFields = [
    'status',
    'paid_amount',
    'paidAmount',
    'total_amount',
    'totalAmount',
    'access_cutoff_date',
    'accessCutoffDate',
  ];

  let changed = !before.exists || !after.exists; // create or delete always triggers

  if (!changed && beforeData && afterData) {
    for (const field of relevantFields) {
      // Timestamps need special comparison
      const bRaw = beforeData[field];
      const aRaw = afterData[field];
      const bVal = bRaw && bRaw.toDate ? bRaw.toMillis() : JSON.stringify(bRaw);
      const aVal = aRaw && aRaw.toDate ? aRaw.toMillis() : JSON.stringify(aRaw);
      if (bVal !== aVal) {
        changed = true;
        break;
      }
    }
  }

  if (!changed) return;

  const db = admin.firestore();
  await _recomputeStudentAccess(db, parentId);
});

/**
 * Scheduled function: runs every hour to catch time-based access cutoffs
 * that weren't caught by the document trigger.
 *
 * Also re-checks parents of currently-suspended students, so access is
 * restored correctly if it was suspended in error.
 */
const checkAccessCutoffs = onSchedule('every 60 minutes', async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const parentIds = new Set();

  // 1. Find invoices whose cutoff date has arrived.
  const cutoffSnap = await db
    .collection('invoices')
    .where('access_cutoff_date', '<=', now)
    .get();

  for (const doc of cutoffSnap.docs) {
    const invoice = doc.data();
    const status = _normalizeStatus(invoice.status);
    if (status === 'paid' || status === 'cancelled') continue;

    const totalAmount = _toNumber(invoice.total_amount, invoice.totalAmount);
    const paidAmount = _toNumber(invoice.paid_amount, invoice.paidAmount);
    if (totalAmount <= 0 || paidAmount >= totalAmount) continue;

    const parentId = (invoice.parent_id || '').toString().trim();
    if (parentId) parentIds.add(parentId);
  }

  // 1b. Older invoices may not have access_cutoff_date. Match the client model:
  // effective cutoff is due_date + 1 day.
  const dueCutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 24 * 60 * 60 * 1000)
  );
  const dueSnap = await db
    .collection('invoices')
    .where('due_date', '<=', dueCutoff)
    .get();

  for (const doc of dueSnap.docs) {
    const invoice = doc.data();
    if (invoice.access_cutoff_date || invoice.accessCutoffDate) continue;

    const status = _normalizeStatus(invoice.status);
    if (status === 'paid' || status === 'cancelled') continue;

    const totalAmount = _toNumber(invoice.total_amount, invoice.totalAmount);
    const paidAmount = _toNumber(invoice.paid_amount, invoice.paidAmount);
    if (totalAmount <= 0 || paidAmount >= totalAmount) continue;

    const parentId = (invoice.parent_id || invoice.parentId || '').toString().trim();
    if (parentId) parentIds.add(parentId);
  }

  // 2. Also check parents of students who are already suspended,
  //    in case access should be restored (e.g. admin changed cutoff to future).
  const suspendedSnap = await db
    .collection('users')
    .where('access_suspended', '==', true)
    .get();

  for (const doc of suspendedSnap.docs) {
    const data = doc.data();
    const guardianIds = [
      ...(Array.isArray(data.guardian_ids) ? data.guardian_ids : []),
      ...(Array.isArray(data.guardianIds) ? data.guardianIds : []),
    ];
    guardianIds.forEach((id) => _collectString(parentIds, id));

    // Also check via parent doc's children_ids if we know the parent ID.
    // (guardian_ids on the student doc is the source of truth here.)
  }

  console.log(
    `[checkAccessCutoffs] recomputing access for ${parentIds.size} parent(s)`
  );

  for (const parentId of parentIds) {
    await _recomputeStudentAccess(db, parentId);
  }
});

const extendStudentAccessCutoff = async (request) => {
  if (!request.auth) {
    _throwCallableError('unauthenticated', 'Authentication required');
  }

  const isAdmin = await _isAdminUid(request.auth.uid);
  if (!isAdmin) {
    _throwCallableError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const studentId = (data.studentId || data.student_id || '').toString().trim();
  const parentId = (data.parentId || data.parent_id || '').toString().trim();
  const scope = (data.scope || '').toString().trim().toLowerCase();
  const extendTo = _toDate(data.extendTo || data.extend_to || data.accessCutoffDate);

  if (!studentId && !parentId) {
    _throwCallableError(
      'invalid-argument',
      'Missing studentId or parentId'
    );
  }
  if (!extendTo || extendTo <= new Date()) {
    _throwCallableError(
      'invalid-argument',
      'New cutoff date must be in the future'
    );
  }

  const db = admin.firestore();
  const parentIds = new Set();
  _collectString(parentIds, parentId);

  const invoiceRefs = new Map();
  const collectBlockingInvoices = (snap) => {
    const now = new Date();
    snap.docs.forEach((doc) => {
      const invoice = doc.data();
      if (!_isBlockingInvoice(invoice, now)) return;
      invoiceRefs.set(doc.id, {ref: doc.ref, data: invoice});
      _collectString(parentIds, invoice.parent_id || invoice.parentId);
    });
  };

  if (parentId && scope === 'parent') {
    const byParent = await db
      .collection('invoices')
      .where('parent_id', '==', parentId)
      .get();
    collectBlockingInvoices(byParent);
    const byCamelParent = await db
      .collection('invoices')
      .where('parentId', '==', parentId)
      .get();
    collectBlockingInvoices(byCamelParent);
  } else {
    if (!studentId) {
      _throwCallableError(
        'invalid-argument',
        'Missing studentId for individual extension'
      );
    }

    const studentSnap = await db.collection('users').doc(studentId).get();
    if (!studentSnap.exists) {
      _throwCallableError('not-found', 'Student not found');
    }

    const student = studentSnap.data() || {};
    [
      ...(Array.isArray(student.guardian_ids) ? student.guardian_ids : []),
      ...(Array.isArray(student.guardianIds) ? student.guardianIds : []),
      student.parent_id,
      student.parentId,
    ].forEach((id) => _collectString(parentIds, id));

    const byStudent = await db
      .collection('invoices')
      .where('student_id', '==', studentId)
      .get();
    collectBlockingInvoices(byStudent);
    const byCamelStudent = await db
      .collection('invoices')
      .where('studentId', '==', studentId)
      .get();
    collectBlockingInvoices(byCamelStudent);

    const adultStudentInvoices = await db
      .collection('invoices')
      .where('parent_id', '==', studentId)
      .get();
    collectBlockingInvoices(adultStudentInvoices);
    const adultStudentCamelInvoices = await db
      .collection('invoices')
      .where('parentId', '==', studentId)
      .get();
    collectBlockingInvoices(adultStudentCamelInvoices);
  }

  if (invoiceRefs.size === 0) {
    return {success: true, updatedInvoices: 0, recomputedParents: 0};
  }

  const invoiceEntries = Array.from(invoiceRefs.entries());
  for (let i = 0; i < invoiceEntries.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = invoiceEntries.slice(i, i + BATCH_SIZE);
    for (const [, item] of chunk) {
      batch.set(
        item.ref,
        {
          access_cutoff_date: admin.firestore.Timestamp.fromDate(extendTo),
          access_extended_at: admin.firestore.FieldValue.serverTimestamp(),
          access_extended_by: request.auth.uid,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    }
    await batch.commit();
  }

  for (const parentId of Array.from(parentIds)) {
    await _recomputeStudentAccess(db, parentId);
  }

  return {
    success: true,
    updatedInvoices: invoiceRefs.size,
    recomputedParents: parentIds.size,
  };
};

module.exports = {
  onInvoiceWrite,
  checkAccessCutoffs,
  extendStudentAccessCutoff,
  _recomputeStudentAccess,
  _getEffectiveAccessCutoffDate,
  _isBlockingInvoice,
  _invoiceStudentIds,
};
