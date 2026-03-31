#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

const TEMPLATE_IDS = [
  'tpl_4f4f466eeddd70e0',
  'tpl_9b7cda14c778a3fa',
];

async function check() {
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  
  for (const templateId of TEMPLATE_IDS) {
    console.log('='.repeat(80));
    console.log(`Template: ${templateId}\n`);
    
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', templateId)
      .limit(3)
      .get();
    
    console.log(`Showing first 3 shifts:\n`);
    
    for (const doc of shiftsSnap.docs) {
      const data = doc.data();
      console.log(`Shift: ${doc.id}`);
      console.log(`  start_time: ${JSON.stringify(data.start_time)}`);
      console.log(`  end_time: ${JSON.stringify(data.end_time)}`);
      console.log(`  status: ${data.status}`);
      console.log(`  teacher_name: ${data.teacher_name}`);
      console.log(`  All keys: ${Object.keys(data).join(', ')}`);
      console.log('');
    }
  }
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
