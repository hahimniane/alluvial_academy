const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

function buildAutoName(teacherName, subjectDisplay, studentNames) {
  const teacher = teacherName || 'Unknown Teacher';
  const subject = subjectDisplay || 'Subject';
  let students = '';
  
  if (Array.isArray(studentNames) && studentNames.length > 0) {
    if (studentNames.length === 1) {
      students = studentNames[0];
    } else if (studentNames.length <= 3) {
      students = studentNames.join(', ');
    } else {
      students = `${studentNames.slice(0, 2).join(', ')} +${studentNames.length - 2} more`;
    }
  } else {
    students = 'No students';
  }
  
  if (students === 'No students') {
    return `${teacher} - ${subject}`;
  }
  return `${teacher} - ${subject} - ${students}`;
}

async function fixMissingNames() {
  console.log('Fixing templates...');
  const templatesSnap = await db.collection('shift_templates').get();
  let templatesUpdated = 0;
  
  const templateBatch = db.batch();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    if (!data.auto_generated_name || data.auto_generated_name.trim() === '') {
      const autoName = buildAutoName(data.teacher_name, data.subject_display_name || data.subject, data.student_names);
      templateBatch.update(doc.ref, { auto_generated_name: autoName });
      templatesUpdated++;
    }
  }
  
  if (templatesUpdated > 0) {
    await templateBatch.commit();
    console.log(`Updated ${templatesUpdated} templates.`);
  } else {
    console.log('No templates needed updating.');
  }
  
  console.log('Fixing shifts...');
  const shiftsSnap = await db.collection('teaching_shifts').get();
  let shiftsUpdated = 0;
  
  // Batch updates for shifts (could be > 500, so we chunk them)
  let currentBatch = db.batch();
  let batchCount = 0;
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    if (!data.auto_generated_name || data.auto_generated_name.trim() === '') {
      const autoName = buildAutoName(data.teacher_name, data.subject_display_name || data.subject, data.student_names);
      currentBatch.update(doc.ref, { auto_generated_name: autoName });
      shiftsUpdated++;
      batchCount++;
      
      if (batchCount === 450) {
        await currentBatch.commit();
        currentBatch = db.batch();
        batchCount = 0;
      }
    }
  }
  
  if (batchCount > 0) {
    await currentBatch.commit();
  }
  
  console.log(`Updated ${shiftsUpdated} shifts.`);
}

fixMissingNames()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });
