const admin = require('firebase-admin');

// Mock data for a template that is missing an auto_generated_name
const mockTemplate = {
  teacher_id: 'teacher123',
  teacher_name: 'Habibu Barry',
  student_ids: ['student1', 'student2'],
  student_names: ['Khadijah Bah', 'Saidou Bah'],
  subject: 'quranStudies',
  subject_display_name: 'Quran',
  // Notice: no auto_generated_name or custom_name
};

// Re-implement the exact logic we added to shift_templates.js
const _buildGeneratedShiftId = ({templateId, shiftStartUtc}) => {
  const seconds = Math.floor(shiftStartUtc.toSeconds());
  // Avoid double tpl_ prefix if the templateId already has it
  const prefix = templateId.startsWith('tpl_') ? '' : 'tpl_';
  return `${prefix}${templateId}_${seconds}`;
};

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

async function runTests() {
  console.log("=== Testing ID Generation ===");
  // Test 1: Template ID with tpl_ prefix
  const mockStart1 = { toSeconds: () => 1712234000 };
  const id1 = _buildGeneratedShiftId({ templateId: 'tpl_1a2b3c4d', shiftStartUtc: mockStart1 });
  console.log("Input: tpl_1a2b3c4d -> Output:", id1);
  if (id1 === 'tpl_1a2b3c4d_1712234000') {
    console.log("✅ Passed!");
  } else {
    console.log("❌ Failed!");
  }

  // Test 2: Template ID without tpl_ prefix
  const mockStart2 = { toSeconds: () => 1712234000 };
  const id2 = _buildGeneratedShiftId({ templateId: '1a2b3c4d', shiftStartUtc: mockStart2 });
  console.log("Input: 1a2b3c4d -> Output:", id2);
  if (id2 === 'tpl_1a2b3c4d_1712234000') {
    console.log("✅ Passed!");
  } else {
    console.log("❌ Failed!");
  }

  console.log("\n=== Testing Name Generation ===");
  // Test 3: Standard name generation
  const name1 = _generateAutoName('Habibu Barry', 'quranStudies', ['Khadijah Bah', 'Saidou Bah']);
  console.log("Generated Name (2 students):", name1);
  if (name1 === 'Habibu Barry - Quran - Khadijah Bah, Saidou Bah') {
    console.log("✅ Passed!");
  } else {
    console.log("❌ Failed!");
  }

  // Test 4: Single student
  const name2 = _generateAutoName('Habibu Barry', 'quranStudies', ['Khadijah Bah']);
  console.log("Generated Name (1 student):", name2);
  if (name2 === 'Habibu Barry - Quran - Khadijah Bah') {
    console.log("✅ Passed!");
  } else {
    console.log("❌ Failed!");
  }

  // Test 5: Many students
  const name3 = _generateAutoName('Habibu Barry', 'quranStudies', ['Student 1', 'Student 2', 'Student 3', 'Student 4', 'Student 5']);
  console.log("Generated Name (5 students):", name3);
  if (name3 === 'Habibu Barry - Quran - Student 1, Student 2 +3 more') {
    console.log("✅ Passed!");
  } else {
    console.log("❌ Failed!");
  }
}

runTests();