const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
admin.initializeApp({ projectId: 'alluwal-academy' });

const db = admin.firestore();

// Exact logic ported from Dart TeachingShift.generateAutoName
const _generateAutoName = (teacherName, subject, studentNames) => {
  let subjectName = subject || '';
  switch (subject) {
    case 'quranStudies': subjectName = 'Quran'; break;
    case 'hadithStudies': subjectName = 'Hadith'; break;
    case 'fiqh': subjectName = 'Fiqh'; break;
    case 'arabicLanguage': subjectName = 'Arabic'; break;
    case 'islamicHistory': subjectName = 'Islamic History'; break;
    case 'aqeedah': subjectName = 'Aqeedah'; break;
    default:
      if (subjectName.length > 0) {
        subjectName = subjectName.charAt(0).toUpperCase() + subjectName.slice(1);
      }
      break;
  }
  
  if (!studentNames || studentNames.length === 0) {
    return `${teacherName} - ${subjectName}`;
  } else if (studentNames.length === 1) {
    return `${teacherName} - ${subjectName} - ${studentNames[0]}`;
  } else if (studentNames.length <= 3) {
    return `${teacherName} - ${subjectName} - ${studentNames.join(', ')}`;
  } else {
    return `${teacherName} - ${subjectName} - ${studentNames.slice(0, 2).join(', ')} +${studentNames.length - 2} more`;
  }
};

async function fixMissingNames() {
  const isDryRun = !process.argv.includes('--execute');
  
  if (isDryRun) {
    console.log("=== DRY RUN MODE: No changes will be saved to the database. Use --execute to apply changes. ===\n");
  } else {
    console.log("=== EXECUTE MODE: Changes WILL be saved to the database. ===\n");
  }

  let templateUpdates = 0;
  let shiftUpdates = 0;

  try {
    // 1. Fix Templates
    console.log("Fetching shift templates...");
    const templatesSnapshot = await db.collection('shift_templates').get();
    console.log(`Found ${templatesSnapshot.size} total templates.`);
    
    for (const doc of templatesSnapshot.docs) {
      const data = doc.data();
      const autoName = data.auto_generated_name;
      const customName = data.custom_name;

      if ((!autoName || autoName.trim() === '') && (!customName || customName.trim() === '')) {
        const generatedName = _generateAutoName(data.teacher_name, data.subject, data.student_names);
        console.log(`[Template] ID: ${doc.id} | New Name: "${generatedName}"`);
        
        if (!isDryRun) {
          await doc.ref.update({
            auto_generated_name: generatedName
          });
        }
        templateUpdates++;
      }
    }

    // 2. Fix Shifts
    console.log("\nFetching teaching shifts...");
    // Since there could be thousands of shifts, we'll process in batches if needed, but a single get() is usually fine for <10k docs.
    const shiftsSnapshot = await db.collection('teaching_shifts').get();
    console.log(`Found ${shiftsSnapshot.size} total shifts.`);
    
    // Using batches for shifts since there might be many
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of shiftsSnapshot.docs) {
      const data = doc.data();
      const autoName = data.auto_generated_name;
      const customName = data.custom_name;

      // Also fix IDs starting with tpl_tpl_ if they exist (optional, but requested implicitly by "fix the other classes")
      // Let's stick to just the names first to be safe as requested.

      if ((!autoName || autoName.trim() === '') && (!customName || customName.trim() === '')) {
        const generatedName = _generateAutoName(data.teacher_name, data.subject, data.student_names);
        
        if (shiftUpdates < 10) { // Only log the first 10 to avoid spamming the console
           console.log(`[Shift] ID: ${doc.id} | Teacher: ${data.teacher_name} | New Name: "${generatedName}"`);
        } else if (shiftUpdates === 10) {
           console.log(`[Shift] ... and more shifts ...`);
        }
        
        if (!isDryRun) {
          batch.update(doc.ref, { auto_generated_name: generatedName });
          batchCount++;

          if (batchCount === 500) {
            console.log(`Committing batch of 500 shifts...`);
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
        shiftUpdates++;
      }
    }

    if (!isDryRun && batchCount > 0) {
      console.log(`Committing final batch of ${batchCount} shifts...`);
      await batch.commit();
    }

    console.log(`\n=== SUMMARY ===`);
    console.log(`Templates needing fix: ${templateUpdates}`);
    console.log(`Shifts needing fix: ${shiftUpdates}`);
    if (isDryRun) {
      console.log(`Run with \`node functions/scripts/dev/fix_missing_names.js --execute\` to apply these fixes.`);
    } else {
      console.log(`Successfully fixed in database!`);
    }

  } catch (err) {
    console.error("Error during execution:", err);
  }
}

fixMissingNames();