#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function check() {
  const studentUid = 'v6xRIFMbZvdQp9tAiM35dmyrtx72';
  const teacherId = 'SQetTfLDFGTir9WZ4ivWVRboHpZ2';
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('student_ids', 'array-contains', studentUid)
    .where('teacher_id', '==', teacherId)
    .get();
  
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    if (!data.template_id) {
      const start = data.shift_start?.toDate();
      const startDt = start ? DateTime.fromJSDate(start).setZone(NYC_TZ) : null;
      
      console.log('Old-style shift without template:');
      console.log(`  ID: ${doc.id}`);
      console.log(`  Status: ${data.status}`);
      console.log(`  Time: ${startDt?.toFormat('fff') || 'unknown'}`);
      console.log(`  Is past: ${startDt && startDt < now ? 'YES' : 'NO'}`);
    }
  }
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
