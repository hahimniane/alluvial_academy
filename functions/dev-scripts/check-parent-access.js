/**
 * dev-script: check-parent-access.js
 * Usage: GOOGLE_APPLICATION_CREDENTIALS=~/.config/firebase/nenenane2_gmail_com_application_default_credentials.json \
 *        node functions/dev-scripts/check-parent-access.js nenenane2@gmail.com
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });

const db = admin.firestore();
const email = process.argv[2] || 'nenenane2@gmail.com';

async function main() {
  // 1. Find parent by email
  const snap = await db.collection('users')
    .where('e-mail', '==', email)
    .limit(1)
    .get();

  let parentDoc = snap.empty ? null : snap.docs[0];

  if (!parentDoc) {
    // try lowercase email field
    const snap2 = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();
    parentDoc = snap2.empty ? null : snap2.docs[0];
  }

  if (!parentDoc) {
    console.error(`No user found for email: ${email}`);
    process.exit(1);
  }

  const parentId = parentDoc.id;
  const parentData = parentDoc.data();
  console.log(`\n=== Parent: ${parentData.first_name} ${parentData.last_name} (${email}) ===`);
  console.log(`ID: ${parentId}`);
  console.log(`children_ids: ${JSON.stringify(parentData.children_ids || [])}`);

  // 2. Load invoices for this parent
  const invoicesSnap = await db.collection('invoices')
    .where('parent_id', '==', parentId)
    .get();

  const now = new Date();
  console.log(`\n=== Invoices (${invoicesSnap.size} total) ===`);

  let shouldSuspend = false;
  const blockingInvoices = [];

  for (const doc of invoicesSnap.docs) {
    const inv = doc.data();
    const status = inv.status || 'unknown';
    const total = Number(inv.total_amount) || 0;
    const paid = Number(inv.paid_amount) || 0;
    const remaining = total - paid;
    const dueDate = inv.due_date?.toDate?.() || null;
    const cutoffDate = inv.access_cutoff_date?.toDate?.() || null;

    const isFullyPaid = total > 0 && paid >= total;
    const isPaidOrCancelled = status === 'paid' || status === 'cancelled' || isFullyPaid;
    const cutoffPassed = cutoffDate && cutoffDate <= now;

    console.log(`\n  Invoice: ${inv.invoice_number || doc.id}`);
    console.log(`    Status: ${status} | Total: $${total} | Paid: $${paid} | Remaining: $${remaining.toFixed(2)}`);
    console.log(`    Due date:    ${dueDate ? dueDate.toLocaleDateString() : 'none'}`);
    console.log(`    Cutoff date: ${cutoffDate ? cutoffDate.toLocaleDateString() : 'NOT SET (old invoice)'}`);
    console.log(`    Fully paid:  ${isFullyPaid}`);
    console.log(`    Cutoff passed: ${cutoffPassed}`);

    if (!isPaidOrCancelled && cutoffPassed) {
      shouldSuspend = true;
      blockingInvoices.push(inv.invoice_number || doc.id);
      console.log(`    *** BLOCKING: This invoice triggers suspension ***`);
    } else if (!isPaidOrCancelled && !cutoffDate) {
      console.log(`    NOTE: Unpaid but no access_cutoff_date set (was created before the feature). No suspension triggered.`);
    }
  }

  // 3. Find linked students
  const studentsByGuardian = await db.collection('users')
    .where('guardian_ids', 'array-contains', parentId)
    .get();

  const studentIds = new Set();
  studentsByGuardian.docs.forEach(d => studentIds.add(d.id));
  (parentData.children_ids || []).forEach(id => studentIds.add(id));

  console.log(`\n=== Students linked to parent (${studentIds.size}) ===`);
  for (const studentId of studentIds) {
    const studentDoc = await db.collection('users').doc(studentId).get();
    if (!studentDoc.exists) {
      console.log(`  ${studentId}: NOT FOUND in Firestore`);
      continue;
    }
    const sd = studentDoc.data();
    const name = `${sd.first_name || ''} ${sd.last_name || ''}`.trim();
    const suspended = sd.access_suspended === true;
    console.log(`  ${name} (${studentId}): access_suspended=${suspended}`);
  }

  console.log(`\n=== Verdict ===`);
  console.log(`Should suspend: ${shouldSuspend}`);
  if (shouldSuspend) {
    console.log(`Blocking invoices: ${blockingInvoices.join(', ')}`);
    console.log(`\nRun with FIX=true to apply suspension to all linked students.`);
    if (process.env.FIX === 'true') {
      console.log('\nApplying suspension...');
      const batch = db.batch();
      for (const studentId of studentIds) {
        batch.update(db.collection('users').doc(studentId), {
          access_suspended: true,
          access_suspension_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      console.log(`Done. ${studentIds.size} student(s) suspended.`);
    }
  } else {
    console.log(`No active cutoff violations found. Students should NOT be suspended.`);
    if (process.env.FIX === 'true' && studentIds.size > 0) {
      console.log('\nClearing any stale suspensions...');
      const batch = db.batch();
      for (const studentId of studentIds) {
        batch.update(db.collection('users').doc(studentId), {
          access_suspended: false,
          access_suspension_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      console.log(`Done.`);
    }
  }

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
