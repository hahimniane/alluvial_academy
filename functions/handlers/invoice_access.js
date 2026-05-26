const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
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

  const invoicesSnap = await db
    .collection('invoices')
    .where('parent_id', '==', parentId)
    .get();

  const now = new Date();
  let shouldSuspend = false;
  const invoiceStudentIds = new Set();

  for (const doc of invoicesSnap.docs) {
    const invoice = doc.data();
    _collectString(invoiceStudentIds, invoice.student_id || invoice.studentId);

    const status = _normalizeStatus(invoice.status);

    if (status === 'paid' || status === 'cancelled') continue;

    const totalAmount = _toNumber(invoice.total_amount, invoice.totalAmount);
    const paidAmount = _toNumber(invoice.paid_amount, invoice.paidAmount);
    if (totalAmount > 0 && paidAmount >= totalAmount) continue;

    const cutoffDate = _getEffectiveAccessCutoffDate(invoice);
    if (!cutoffDate) continue;

    if (cutoffDate <= now) {
      shouldSuspend = true;
      break;
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

  for (let i = 0; i < studentIdsArr.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = studentIdsArr.slice(i, i + BATCH_SIZE);
    for (const studentId of chunk) {
      const studentRef = db.collection('users').doc(studentId);
      batch.set(studentRef, {
        access_suspended: shouldSuspend,
        access_suspension_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    await batch.commit();
  }

  console.log(
    `[invoice_access] parent=${parentId}: shouldSuspend=${shouldSuspend}, ` +
      `affected students: ${studentIdsArr.join(', ')}`
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
    (beforeData && beforeData.parent_id) ||
    ''
  )
    .toString()
    .trim();

  if (!parentId) return;

  // Only recompute when relevant fields change, to avoid infinite loops.
  const relevantFields = [
    'status',
    'paid_amount',
    'total_amount',
    'access_cutoff_date',
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
    if (totalAmount > 0 && paidAmount >= totalAmount) continue;

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
    if (totalAmount > 0 && paidAmount >= totalAmount) continue;

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

module.exports = {
  onInvoiceWrite,
  checkAccessCutoffs,
  _recomputeStudentAccess,
  _getEffectiveAccessCutoffDate,
};
