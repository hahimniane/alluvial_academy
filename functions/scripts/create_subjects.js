#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

// Initialize Firebase
admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const REQUIRED_SUBJECTS = [
  {
    name: 'islamic',
    displayName: 'Islamic',
    description: 'Islamic studies and Quran instruction',
    defaultWage: 4,
    sortOrder: 100,
  },
  {
    name: 'afrolingual',
    displayName: 'AfroLingual',
    description: 'African language instruction',
    defaultWage: 4,
    sortOrder: 101,
  },
  {
    name: 'adult_class',
    displayName: 'Adult Class',
    description: 'Adult education and learning',
    defaultWage: 5,
    sortOrder: 102,
  },
  {
    name: 'after_learning',
    displayName: 'After Learning',
    description: 'After school learning programs',
    defaultWage: 5,
    sortOrder: 103,
  },
];

const normalizeSubjectName = (name) => 
  (name || '').toString().toLowerCase().trim().replace(/\s+/g, '_');

async function createSubjects() {
  console.log('Checking and creating required subjects...\n');
  
  // Get all existing subjects
  const subjectsSnap = await db.collection('subjects').get();
  
  const existingSubjects = new Map();
  subjectsSnap.docs.forEach(doc => {
    const data = doc.data();
    const normalizedName = normalizeSubjectName(data.name);
    existingSubjects.set(normalizedName, {
      id: doc.id,
      ...data
    });
  });
  
  console.log(`Found ${existingSubjects.size} existing subjects:`);
  existingSubjects.forEach((subject, name) => {
    console.log(`  - ${subject.displayName} (${name}): $${subject.defaultWage || 'N/A'}/hour`);
  });
  
  console.log('\n' + '='.repeat(80));
  console.log('Checking required subjects...\n');
  
  const toCreate = [];
  const existing = [];
  
  for (const requiredSubject of REQUIRED_SUBJECTS) {
    const normalized = normalizeSubjectName(requiredSubject.name);
    
    if (existingSubjects.has(normalized)) {
      const existingData = existingSubjects.get(normalized);
      existing.push({
        ...requiredSubject,
        id: existingData.id,
        existingWage: existingData.defaultWage
      });
      console.log(`✓ "${requiredSubject.displayName}" already exists`);
      console.log(`  ID: ${existingData.id}`);
      console.log(`  Current Wage: $${existingData.defaultWage || 'N/A'}/hour`);
      console.log(`  Expected Wage: $${requiredSubject.defaultWage}/hour`);
      
      if (existingData.defaultWage !== requiredSubject.defaultWage) {
        console.log(`  ⚠️  WAGE MISMATCH!`);
      }
      console.log('');
    } else {
      toCreate.push(requiredSubject);
      console.log(`✗ "${requiredSubject.displayName}" NOT FOUND - will create`);
      console.log(`  Name: ${requiredSubject.name}`);
      console.log(`  Wage: $${requiredSubject.defaultWage}/hour`);
      console.log('');
    }
  }
  
  console.log('='.repeat(80));
  console.log(`Summary: ${existing.length} exist, ${toCreate.length} to create\n`);
  
  if (toCreate.length === 0) {
    console.log('✅ All required subjects already exist!');
    return;
  }
  
  console.log('Creating missing subjects...\n');
  
  for (const subject of toCreate) {
    const docRef = db.collection('subjects').doc();
    await docRef.set({
      name: subject.name,
      displayName: subject.displayName,
      description: subject.description,
      defaultWage: subject.defaultWage,
      sortOrder: subject.sortOrder,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Created: ${subject.displayName} (${docRef.id})`);
  }
  
  console.log('\n✅ All subjects created successfully!');
  
  // Display final subject list with IDs for reference
  console.log('\n' + '='.repeat(80));
  console.log('FINAL SUBJECT LIST (for reference)');
  console.log('='.repeat(80));
  
  const updatedSnap = await db.collection('subjects').get();
  const allSubjects = [];
  updatedSnap.docs.forEach(doc => {
    const data = doc.data();
    const normalized = normalizeSubjectName(data.name);
    // Only show the required subjects
    const isRequired = REQUIRED_SUBJECTS.some(s => normalizeSubjectName(s.name) === normalized);
    if (isRequired) {
      allSubjects.push({
        id: doc.id,
        name: data.name,
        displayName: data.displayName,
        defaultWage: data.defaultWage,
      });
    }
  });
  
  allSubjects.sort((a, b) => a.displayName.localeCompare(b.displayName));
  
  console.log('');
  allSubjects.forEach(s => {
    console.log(`${s.displayName}:`);
    console.log(`  ID: ${s.id}`);
    console.log(`  Name: ${s.name}`);
    console.log(`  Default Wage: $${s.defaultWage}/hour`);
    console.log('');
  });
}

createSubjects()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
