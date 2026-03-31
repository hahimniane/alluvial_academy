#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const DAY_ORDER = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const DAY_NAMES_LUXON = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};

async function getAllSchedules() {
  // Get all teachers with active templates
  const templatesSnap = await db.collection('shift_templates')
    .where('is_active', '==', true)
    .get();
  
  if (templatesSnap.empty) {
    console.log('No active templates found.');
    return;
  }
  
  // Group templates by teacher
  const teacherTemplates = new Map();
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const teacherId = data.teacher_id;
    
    if (!teacherTemplates.has(teacherId)) {
      teacherTemplates.set(teacherId, []);
    }
    teacherTemplates.get(teacherId).push({ id: doc.id, ...data });
  }
  
  // Get all teacher and student info
  const allUserIds = new Set();
  teacherTemplates.forEach((templates, teacherId) => {
    allUserIds.add(teacherId);
    templates.forEach(t => {
      (t.student_ids || []).forEach(sid => allUserIds.add(sid));
    });
  });
  
  const userMap = new Map();
  for (const uid of allUserIds) {
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      userMap.set(uid, {
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        timezone: data.timezone || data.time_zone || 'America/New_York',
        studentCode: data.student_code || data.studentId || data.student_id,
      });
    }
  }
  
  // Process each teacher
  const outputs = [];
  
  for (const [teacherId, templates] of teacherTemplates) {
    const teacherInfo = userMap.get(teacherId);
    if (!teacherInfo) continue;
    
    // Organize by day
    const scheduleByDay = new Map();
    
    for (const template of templates) {
      const selectedWeekdays = template.enhanced_recurrence?.selectedWeekdays || [];
      
      for (const dayNum of selectedWeekdays) {
        const dayName = DAY_NAMES_LUXON[dayNum];
        if (!dayName) continue;
        
        if (!scheduleByDay.has(dayName)) {
          scheduleByDay.set(dayName, []);
        }
        
        // Convert time to NYC timezone
        const [startHour, startMin] = (template.start_time || '').split(':').map(Number);
        const [endHour, endMin] = (template.end_time || '').split(':').map(Number);
        
        const adminTz = template.admin_timezone || 'America/New_York';
        
        const startDateTime = DateTime.now().setZone(adminTz).set({
          hour: startHour,
          minute: startMin,
          second: 0,
        }).setZone(NYC_TZ);
        
        const endDateTime = DateTime.now().setZone(adminTz).set({
          hour: endHour,
          minute: endMin,
          second: 0,
        }).setZone(NYC_TZ);
        
        const formatTime = (dt) => {
          const hour = dt.hour;
          const min = dt.minute;
          const meridiem = hour >= 12 ? 'PM' : 'AM';
          const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
          return `${displayHour}:${String(min).padStart(2, '0')} ${meridiem}`;
        };
        
        // Build student info with IDs
        const studentInfo = (template.student_ids || []).map(sid => {
          const info = userMap.get(sid);
          return info ? `${info.name} (${info.studentCode})` : sid;
        });
        
        // Determine class type
        let classType = 'IC'; // Individual Class
        const studentCount = (template.student_ids || []).length;
        
        if (studentCount > 1) {
          // Check notes for class type hints
          const notes = (template.notes || '').toLowerCase();
          if (notes.includes('fgc') || notes.includes('family')) {
            classType = 'FGC'; // Family Group Class
          } else {
            classType = 'MGC'; // Manual Group Class
          }
        }
        
        scheduleByDay.get(dayName).push({
          startTime: formatTime(startDateTime),
          endTime: formatTime(endDateTime),
          startHour: startDateTime.hour,
          startMin: startDateTime.minute,
          students: studentInfo.join(', '),
          classType: classType,
          studentCount: studentCount,
        });
      }
    }
    
    // Sort each day by time
    for (const [day, classes] of scheduleByDay) {
      classes.sort((a, b) => {
        if (a.startHour !== b.startHour) return a.startHour - b.startHour;
        return a.startMin - b.startMin;
      });
    }
    
    // Build output
    let output = `Schedule for ${teacherInfo.name} (NYC Time)\n\n`;
    
    for (const day of DAY_ORDER) {
      if (scheduleByDay.has(day)) {
        output += `${day.toUpperCase()}:\n`;
        for (const cls of scheduleByDay.get(day)) {
          output += `• ${cls.startTime} - ${cls.endTime} [${cls.classType}] — ${cls.students}\n`;
        }
        output += '\n';
      }
    }
    
    output += 'Please confirm if this schedule is correct.';
    
    outputs.push({
      name: teacherInfo.name,
      output: output,
    });
  }
  
  // Sort by teacher name
  outputs.sort((a, b) => a.name.localeCompare(b.name));
  
  // Print all schedules
  for (const item of outputs) {
    console.log('============================================================');
    console.log(item.output);
    console.log('');
  }
  
  console.log('============================================================');
  console.log(`\nTotal: ${outputs.length} teachers`);
  console.log('\nClass Type Legend:');
  console.log('IC = Individual Class (1 student)');
  console.log('MGC = Manual Group Class (2+ students)');
  console.log('FGC = Family Group Class (2+ students from same family)');
}

getAllSchedules()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
