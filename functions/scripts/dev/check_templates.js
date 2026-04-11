const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function checkTemplates() {
  const templates = ['tpl_07946574e2d73cb9'];
  for (const tId of templates) {
    const doc = await db.collection('shift_templates').doc(tId).get();
    if (doc.exists) {
      const data = doc.data();
      console.log(`Template ${tId}:`);
      console.log(`  auto_generated_name: ${data.auto_generated_name}`);
      console.log(`  custom_name: ${data.custom_name}`);
      console.log(`  subject: ${data.subject}`);
      console.log(`  subject_display_name: ${data.subject_display_name}`);
      console.log(`  student_names: ${data.student_names}`);
    } else {
      console.log(`Template ${tId} not found`);
    }
  }
}

checkTemplates().then(() => process.exit(0));
