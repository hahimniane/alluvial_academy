/**
 * Script to create mock invoices for testing the beautiful invoice design
 * 
 * Usage: node functions/create_mock_invoices.js <parentEmail>
 * Example: node functions/create_mock_invoices.js nenenane2@gmail.com
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  // Try to initialize with serviceAccountKey.json if it exists
  // Otherwise, use default credentials or environment variables
  try {
    const serviceAccount = require('./serviceAccountKey.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } catch (e) {
    // Fallback to default credentials (e.g., from environment or gcloud CLI)
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || process.env.FIREBASE_PROJECT_ID || 'alluwal-academy';
    admin.initializeApp({
      projectId: projectId,
    });
  }
}

const db = admin.firestore();

async function createMockInvoices(parentEmail) {
  try {
    console.log(`🔍 Looking up parent with email: ${parentEmail}`);
    
    // Find parent user by email
    const userSnapshot = await db
      .collection('users')
      .where('e-mail', '==', parentEmail)
      .limit(1)
      .get();

    if (userSnapshot.empty) {
      console.error(`❌ No user found with email: ${parentEmail}`);
      process.exit(1);
    }

    const parentDoc = userSnapshot.docs[0];
    const parentId = parentDoc.id;
    const parentData = parentDoc.data();
    console.log(`✅ Found parent: ${parentData.first_name} ${parentData.last_name} (${parentId})`);

    // Find a student linked to this parent
    const studentsSnapshot = await db
      .collection('users')
      .where('user_type', '==', 'student')
      .where('guardian_ids', 'array-contains', parentId)
      .limit(1)
      .get();

    let studentId;
    let studentName = 'Test Student';

    if (studentsSnapshot.empty) {
      console.log('⚠️  No students found linked to this parent. Creating invoice without student reference.');
      studentId = 'mock-student-id';
    } else {
      const studentDoc = studentsSnapshot.docs[0];
      studentId = studentDoc.id;
      const studentData = studentDoc.data();
      studentName = `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim() || 'Test Student';
      console.log(`✅ Found student: ${studentName} (${studentId})`);
    }

    // Create 3 mock invoices with different statuses
    const mockInvoices = [
      {
        invoice_number: `INV-${Date.now()}-001`,
        parent_id: parentId,
        student_id: studentId,
        status: 'pending',
        total_amount: 150.00,
        paid_amount: 0.00,
        currency: 'USD',
        issued_date: admin.firestore.Timestamp.fromDate(new Date()),
        due_date: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
        ),
        items: [
          {
            description: 'Mathematics Class • 2024-01-15',
            quantity: 1,
            unit_price: 50.00,
            total: 50.00,
            shift_ids: [],
          },
          {
            description: 'Science Class • 2024-01-16',
            quantity: 1,
            unit_price: 50.00,
            total: 50.00,
            shift_ids: [],
          },
          {
            description: 'Quran Class • 2024-01-17',
            quantity: 1,
            unit_price: 50.00,
            total: 50.00,
            shift_ids: [],
          },
        ],
        shift_ids: [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        invoice_number: `INV-${Date.now()}-002`,
        parent_id: parentId,
        student_id: studentId,
        status: 'paid',
        total_amount: 200.00,
        paid_amount: 200.00,
        currency: 'USD',
        issued_date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 60 * 24 * 60 * 60 * 1000)), // 60 days ago
        due_date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)), // 30 days ago
        items: [
          {
            description: 'Arabic Class • 2024-01-10',
            quantity: 2,
            unit_price: 50.00,
            total: 100.00,
            shift_ids: [],
          },
          {
            description: 'Islamic Studies • 2024-01-12',
            quantity: 2,
            unit_price: 50.00,
            total: 100.00,
            shift_ids: [],
          },
        ],
        shift_ids: [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        invoice_number: `INV-${Date.now()}-003`,
        parent_id: parentId,
        student_id: studentId,
        status: 'pending',
        total_amount: 75.00,
        paid_amount: 25.00,
        currency: 'USD',
        issued_date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 15 * 24 * 60 * 60 * 1000)), // 15 days ago
        due_date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 24 * 60 * 60 * 1000)), // 5 days ago (overdue)
        items: [
          {
            description: 'History Class • 2024-01-20',
            quantity: 1,
            unit_price: 50.00,
            total: 50.00,
            shift_ids: [],
          },
          {
            description: 'Geography Class • 2024-01-21',
            quantity: 1,
            unit_price: 25.00,
            total: 25.00,
            shift_ids: [],
          },
        ],
        shift_ids: [],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    console.log('\n📝 Creating mock invoices...\n');

    const batch = db.batch();
    for (const invoiceData of mockInvoices) {
      const invoiceRef = db.collection('invoices').doc();
      batch.set(invoiceRef, invoiceData);
      console.log(`✅ Created invoice: ${invoiceData.invoice_number} - $${invoiceData.total_amount} (${invoiceData.status})`);
    }

    await batch.commit();

    console.log(`\n🎉 Successfully created ${mockInvoices.length} mock invoices for ${parentEmail}`);
    console.log('📱 You can now view them in the parent dashboard!');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating mock invoices:', error);
    process.exit(1);
  }
}

// Get parent email from command line arguments
const parentEmail = process.argv[2];

if (!parentEmail) {
  console.error('❌ Please provide a parent email address');
  console.log('Usage: node functions/create_mock_invoices.js <parentEmail>');
  console.log('Example: node functions/create_mock_invoices.js nenenane2@gmail.com');
  process.exit(1);
}

createMockInvoices(parentEmail);

