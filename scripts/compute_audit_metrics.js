/**
 * Script to compute audit metrics for teachers with DETAILED REPORT
 * 
 * Usage:
 *   node scripts/compute_audit_metrics.js [yearMonth] [userId]
 * 
 * Examples:
 *   node scripts/compute_audit_metrics.js 2026-01                  # All teachers for January 2026
 *   node scripts/compute_audit_metrics.js 2026-01 Thz8PIVUGpS5...  # Specific teacher (pilot)
 *   node scripts/compute_audit_metrics.js                          # Current month, all teachers
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');

if (fs.existsSync(serviceAccountPath)) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
  console.log('✅ Initialized Firebase Admin with service account key');
} else {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT,
  });
  console.log('✅ Initialized Firebase Admin with application default credentials');
}

const db = admin.firestore();

// Pilot user ID (Aliou)
const PILOT_USER_ID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

// Get yearMonth from args or use current
function getYearMonth() {
  if (process.argv[2] && /^\d{4}-\d{2}$/.test(process.argv[2])) {
    return process.argv[2];
  }
  const now = new Date();
  return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;
}

// Get specific user ID from args
function getSpecificUserId() {
  if (process.argv[3]) {
    return process.argv[3];
  }
  return null;
}

// Parse yearMonth to date range
function parseYearMonth(yearMonth) {
  const [year, month] = yearMonth.split('-').map(Number);
  const startDate = new Date(year, month - 1, 1);
  const endDate = new Date(year, month, 0, 23, 59, 59);
  return { startDate, endDate };
}

// Calculate performance tier
function getPerformanceTier(score) {
  if (score >= 90) return { tier: 'excellent', emoji: '🏆', color: '\x1b[32m' };
  if (score >= 75) return { tier: 'good', emoji: '✅', color: '\x1b[34m' };
  if (score >= 60) return { tier: 'needsImprovement', emoji: '⚠️', color: '\x1b[33m' };
  return { tier: 'critical', emoji: '🔴', color: '\x1b[31m' };
}

// Format date for display
function formatDate(date) {
  if (!date) return 'N/A';
  return date.toLocaleString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// Format duration in minutes
function formatMinutes(minutes) {
  if (minutes < 0) return `${Math.abs(minutes).toFixed(0)} min early`;
  if (minutes === 0) return 'on time';
  return `${minutes.toFixed(0)} min late`;
}

// Print separator
function printSeparator(char = '─', length = 80) {
  console.log(char.repeat(length));
}

// Print section header
function printSection(title) {
  console.log('');
  printSeparator('═');
  console.log(`  ${title}`);
  printSeparator('═');
}

// Check if user is pilot
async function isPilotUser(userId) {
  try {
    const configDoc = await db.collection('settings').doc('pilot_flags').get();
    if (configDoc.exists) {
      const pilotUserIds = configDoc.data().pilotEnabledForUserIds || [];
      return pilotUserIds.includes(userId);
    }
  } catch (e) {
    console.error('Error checking pilot status:', e);
  }
  return userId === PILOT_USER_ID;
}

// Compute metrics for a single teacher with DETAILED OUTPUT
async function computeMetricsForTeacher(userId, userEmail, userName, yearMonth, isPilot) {
  const { startDate, endDate } = parseYearMonth(yearMonth);
  const flags = [];
  const detailedShifts = [];
  const detailedTimesheets = [];
  const detailedForms = [];
  const oderId = userId; // Alias for backward compatibility

  printSection(`📊 AUDIT REPORT: ${userName}`);
  console.log(`  Email: ${userEmail}`);
  console.log(`  User ID: ${userId}`);
  console.log(`  Period: ${yearMonth} (${startDate.toDateString()} → ${endDate.toDateString()})`);
  console.log(`  Pilot Mode: ${isPilot ? 'YES 🧪' : 'NO'}`);

  // ════════════════════════════════════════════════════════════════════════
  // 1. SCHEDULE ANALYSIS
  // ════════════════════════════════════════════════════════════════════════
  printSection('📅 SCHEDULE ANALYSIS');

  const shiftsSnapshot = await db.collection('teaching_shifts')
    .where('teacher_id', '==', userId)
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(startDate))
    .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(endDate))
    .get();

  let scheduledClasses = shiftsSnapshot.docs.length;
  let completedClasses = 0;
  let missedClasses = 0;
  let cancelledClasses = 0;
  let activeClasses = 0;
  let scheduledStatusClasses = 0;

  console.log(`\n  Found ${scheduledClasses} shifts in this period:\n`);
  console.log('  ┌────┬────────────────────────────────────┬─────────────────────┬──────────────────┬────────────┐');
  console.log('  │ #  │ Class Name                         │ Date/Time           │ Duration         │ Status     │');
  console.log('  ├────┼────────────────────────────────────┼─────────────────────┼──────────────────┼────────────┤');

  let shiftIndex = 1;
  for (const doc of shiftsSnapshot.docs) {
    const data = doc.data();
    const status = data.status || 'unknown';
    const shiftStart = data.shift_start?.toDate();
    const shiftEnd = data.shift_end?.toDate();
    const className = data.custom_name || data.auto_generated_name || 'Unnamed Class';
    const duration = shiftStart && shiftEnd 
      ? ((shiftEnd - shiftStart) / (1000 * 60 * 60)).toFixed(1) + 'h'
      : 'N/A';

    let statusEmoji = '❓';
    switch (status) {
      case 'completed':
      case 'fullyCompleted':
        completedClasses++;
        statusEmoji = '✅';
        break;
      case 'partiallyCompleted':
        completedClasses++;
        statusEmoji = '⚠️';
        break;
      case 'missed':
        missedClasses++;
        statusEmoji = '❌';
        flags.push({
          type: 'missedClass',
          description: `Missed: ${className}`,
          date: shiftStart?.toISOString(),
          shiftId: doc.id,
        });
        break;
      case 'cancelled':
        cancelledClasses++;
        statusEmoji = '🚫';
        break;
      case 'active':
        activeClasses++;
        statusEmoji = '▶️';
        break;
      case 'scheduled':
        scheduledStatusClasses++;
        statusEmoji = '📅';
        break;
    }

    detailedShifts.push({
      id: doc.id,
      name: className,
      start: shiftStart,
      end: shiftEnd,
      status,
      duration,
    });

    const dateStr = shiftStart 
      ? shiftStart.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
      : 'N/A';
    const timeStr = shiftStart
      ? shiftStart.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
      : '';

    console.log(`  │ ${String(shiftIndex).padStart(2)} │ ${className.substring(0, 34).padEnd(34)} │ ${(dateStr + ' ' + timeStr).padEnd(19)} │ ${duration.padEnd(16)} │ ${statusEmoji} ${status.padEnd(8)} │`);
    shiftIndex++;
  }

  console.log('  └────┴────────────────────────────────────┴─────────────────────┴──────────────────┴────────────┘');

  const completionRate = scheduledClasses > 0 
    ? (completedClasses / scheduledClasses) * 100 
    : 0;

  console.log('\n  📊 Schedule Summary:');
  console.log(`     ├─ Total Scheduled:    ${scheduledClasses}`);
  console.log(`     ├─ ✅ Completed:       ${completedClasses}`);
  console.log(`     ├─ ❌ Missed:          ${missedClasses}`);
  console.log(`     ├─ 🚫 Cancelled:       ${cancelledClasses}`);
  console.log(`     ├─ ▶️ Active:          ${activeClasses}`);
  console.log(`     ├─ 📅 Scheduled:       ${scheduledStatusClasses}`);
  console.log(`     └─ 📈 Completion Rate: ${completionRate.toFixed(1)}%`);

  // ════════════════════════════════════════════════════════════════════════
  // 2. PUNCTUALITY ANALYSIS (CLOCK-INS)
  // ════════════════════════════════════════════════════════════════════════
  printSection('⏰ PUNCTUALITY ANALYSIS (Clock-Ins)');

  // Query by teacher_id (the actual field name in timesheet_entries)
  const timesheetSnapshot = await db.collection('timesheet_entries')
    .where('teacher_id', '==', userId)
    .get();

  // Filter by date in memory
  const timesheetDocs = timesheetSnapshot.docs.filter(doc => {
    const createdAt = doc.data().created_at;
    if (!createdAt) return false;
    const docDate = createdAt.toDate();
    return docDate >= startDate && docDate <= endDate;
  });

  let totalClockIns = timesheetDocs.length;
  let onTimeClockIns = 0;
  let lateClockIns = 0;
  let earlyClockIns = 0;
  let totalDeltaMinutes = 0;

  console.log(`\n  Found ${totalClockIns} clock-ins in this period:\n`);

  if (totalClockIns > 0) {
    console.log('  ┌────┬────────────────────────────────────┬─────────────────────┬─────────────────────┬──────────────┐');
    console.log('  │ #  │ Shift                              │ Shift Start         │ Clock-In Time       │ Delta        │');
    console.log('  ├────┼────────────────────────────────────┼─────────────────────┼─────────────────────┼──────────────┤');
  }

  let timesheetIndex = 1;
  for (const doc of timesheetDocs) {
    const data = doc.data();
    const clockInTimestamp = data.clock_in_timestamp;
    const shiftId = data.shift_id;
    const shiftTitle = data.shift_title || 'Unknown';

    let shiftStart = null;
    let deltaMinutes = 0;
    let deltaStatus = '❓';

    if (clockInTimestamp && shiftId) {
      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
      if (shiftDoc.exists) {
        shiftStart = shiftDoc.data().shift_start?.toDate();
        if (shiftStart) {
          const clockInTime = clockInTimestamp.toDate();
          deltaMinutes = (clockInTime - shiftStart) / (1000 * 60);
          totalDeltaMinutes += deltaMinutes;

          if (deltaMinutes <= -5) {
            earlyClockIns++;
            onTimeClockIns++;
            deltaStatus = '🟢';
          } else if (deltaMinutes <= 0) {
            onTimeClockIns++;
            deltaStatus = '🟢';
          } else if (deltaMinutes <= 5) {
            onTimeClockIns++;
            deltaStatus = '🟡';
          } else {
            lateClockIns++;
            deltaStatus = '🔴';
            flags.push({
              type: 'lateClockIn',
              description: `Late by ${Math.round(deltaMinutes)} min: ${shiftTitle}`,
              date: clockInTime.toISOString(),
              shiftId: shiftId,
            });
          }

          detailedTimesheets.push({
            id: doc.id,
            shiftId,
            shiftTitle,
            shiftStart,
            clockIn: clockInTime,
            clockOut: data.clock_out_timestamp?.toDate(),
            deltaMinutes,
            status: deltaStatus,
          });

          const shiftStartStr = formatDate(shiftStart);
          const clockInStr = formatDate(clockInTime);
          const deltaStr = formatMinutes(deltaMinutes);

          console.log(`  │ ${String(timesheetIndex).padStart(2)} │ ${shiftTitle.substring(0, 34).padEnd(34)} │ ${shiftStartStr.padEnd(19)} │ ${clockInStr.padEnd(19)} │ ${deltaStatus} ${deltaStr.padEnd(10)} │`);
          timesheetIndex++;
        }
      }
    }
  }

  if (totalClockIns > 0) {
    console.log('  └────┴────────────────────────────────────┴─────────────────────┴─────────────────────┴──────────────┘');
  } else {
    console.log('  (No clock-ins found for this period)');
  }

  const avgClockInDeltaMinutes = totalClockIns > 0 ? totalDeltaMinutes / totalClockIns : 0;
  const punctualityRate = totalClockIns > 0 ? (onTimeClockIns / totalClockIns) * 100 : 100;

  console.log('\n  ⏰ Punctuality Summary:');
  console.log(`     ├─ Total Clock-Ins:      ${totalClockIns}`);
  console.log(`     ├─ 🟢 On-Time (≤5 min):  ${onTimeClockIns}`);
  console.log(`     ├─ 🟢 Early (>5 min):    ${earlyClockIns}`);
  console.log(`     ├─ 🔴 Late (>5 min):     ${lateClockIns}`);
  console.log(`     ├─ ⏱️ Avg Delta:         ${formatMinutes(avgClockInDeltaMinutes)}`);
  console.log(`     └─ 📈 Punctuality Rate:  ${punctualityRate.toFixed(1)}%`);

  // ════════════════════════════════════════════════════════════════════════
  // 3. FORM COMPLIANCE ANALYSIS
  // ════════════════════════════════════════════════════════════════════════
  printSection('📝 FORM COMPLIANCE ANALYSIS');

  const formsSnapshot = await db.collection('form_responses')
    .where('userId', '==', userId)
    .where('yearMonth', '==', yearMonth)
    .get();

  let formsSubmitted = formsSnapshot.docs.length;
  let formsRequired = completedClasses + missedClasses;
  let formsOnTime = 0;
  let formsMissing = Math.max(0, formsRequired - formsSubmitted);

  console.log(`\n  Found ${formsSubmitted} form submissions in this period:\n`);

  if (formsSubmitted > 0) {
    console.log('  ┌────┬────────────────────────────────────┬─────────────────────┬─────────────────────┬──────────────┐');
    console.log('  │ #  │ Linked Shift                       │ Submitted At        │ Shift End           │ Delay        │');
    console.log('  ├────┼────────────────────────────────────┼─────────────────────┼─────────────────────┼──────────────┤');
  }

  let formIndex = 1;
  for (const doc of formsSnapshot.docs) {
    const data = doc.data();
    const submittedAt = data.submittedAt?.toDate();
    const shiftId = data.shiftId;
    let shiftTitle = 'Not linked';
    let shiftEnd = null;
    let delayHours = 0;
    let delayStatus = '❓';

    if (shiftId) {
      const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
      if (shiftDoc.exists) {
        shiftTitle = shiftDoc.data().custom_name || shiftDoc.data().auto_generated_name || 'Unnamed';
        shiftEnd = shiftDoc.data().shift_end?.toDate();
        if (submittedAt && shiftEnd) {
          delayHours = (submittedAt - shiftEnd) / (1000 * 60 * 60);
          if (delayHours <= 24) {
            formsOnTime++;
            delayStatus = '🟢';
          } else if (delayHours <= 48) {
            delayStatus = '🟡';
          } else {
            delayStatus = '🔴';
          }
        }
      }
    }

    detailedForms.push({
      id: doc.id,
      shiftId,
      shiftTitle,
      submittedAt,
      shiftEnd,
      delayHours,
      responses: data.responses || {},
    });

    const submittedStr = formatDate(submittedAt);
    const shiftEndStr = formatDate(shiftEnd);
    const delayStr = delayHours <= 0 ? 'Before end' : `+${delayHours.toFixed(1)}h`;

    console.log(`  │ ${String(formIndex).padStart(2)} │ ${shiftTitle.substring(0, 34).padEnd(34)} │ ${submittedStr.padEnd(19)} │ ${shiftEndStr.padEnd(19)} │ ${delayStatus} ${delayStr.padEnd(10)} │`);
    formIndex++;
  }

  if (formsSubmitted > 0) {
    console.log('  └────┴────────────────────────────────────┴─────────────────────┴─────────────────────┴──────────────┘');
  } else {
    console.log('  (No forms submitted for this period)');
  }

  if (formsMissing > 0) {
    flags.push({
      type: 'missingForm',
      description: `${formsMissing} form(s) not submitted`,
      date: new Date().toISOString(),
    });
  }

  const formComplianceRate = formsRequired > 0 
    ? (formsSubmitted / formsRequired) * 100 
    : 100;

  console.log('\n  📝 Form Compliance Summary:');
  console.log(`     ├─ Forms Required:      ${formsRequired} (completed + missed classes)`);
  console.log(`     ├─ Forms Submitted:     ${formsSubmitted}`);
  console.log(`     ├─ 🟢 On-Time (≤24h):   ${formsOnTime}`);
  console.log(`     ├─ ❌ Missing:          ${formsMissing}`);
  console.log(`     └─ 📈 Compliance Rate:  ${formComplianceRate.toFixed(1)}%`);

  // ════════════════════════════════════════════════════════════════════════
  // 4. FORM RESPONSES DETAILS
  // ════════════════════════════════════════════════════════════════════════
  if (detailedForms.length > 0) {
    printSection('📋 FORM RESPONSES DETAILS');
    
    for (let i = 0; i < detailedForms.length; i++) {
      const form = detailedForms[i];
      console.log(`\n  📄 Form #${i + 1}: ${form.shiftTitle}`);
      console.log(`     ├─ Form ID: ${form.id}`);
      console.log(`     ├─ Shift ID: ${form.shiftId || 'Not linked'}`);
      console.log(`     ├─ Submitted: ${formatDate(form.submittedAt)}`);
      console.log(`     └─ Responses:`);
      
      const responses = form.responses;
      if (Object.keys(responses).length > 0) {
        const keys = Object.keys(responses);
        for (let j = 0; j < keys.length; j++) {
          const key = keys[j];
          const value = responses[key];
          const prefix = j === keys.length - 1 ? '└─' : '├─';
          const displayValue = typeof value === 'string' ? value : JSON.stringify(value);
          console.log(`        ${prefix} ${key}: ${displayValue.substring(0, 50)}${displayValue.length > 50 ? '...' : ''}`);
        }
      } else {
        console.log('        (No response data)');
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 5. FLAGS & ALERTS
  // ════════════════════════════════════════════════════════════════════════
  printSection('🚩 FLAGS & ALERTS');

  if (flags.length === 0) {
    console.log('\n  ✅ No issues detected! Great performance.\n');
  } else {
    console.log(`\n  Found ${flags.length} issue(s):\n`);
    for (let i = 0; i < flags.length; i++) {
      const flag = flags[i];
      let emoji = '❓';
      switch (flag.type) {
        case 'missedClass': emoji = '❌'; break;
        case 'lateClockIn': emoji = '⏰'; break;
        case 'missingForm': emoji = '📝'; break;
      }
      console.log(`  ${i + 1}. ${emoji} [${flag.type}] ${flag.description}`);
      if (flag.date) {
        console.log(`     └─ Date: ${new Date(flag.date).toLocaleString()}`);
      }
    }
    console.log('');
  }

  // ════════════════════════════════════════════════════════════════════════
  // 6. OVERALL SCORE CALCULATION
  // ════════════════════════════════════════════════════════════════════════
  printSection('🏆 OVERALL PERFORMANCE SCORE');

  // Student outcomes (placeholder for now)
  const avgQuizScore = 0;
  const assignmentCompletionRate = 0;
  const attendanceRate = 0;

  // Calculate weighted score
  const studentOutcomes = (avgQuizScore + assignmentCompletionRate + attendanceRate) / 3;
  const overallScore = 
    (completionRate * 0.30) +
    (punctualityRate * 0.20) +
    (formComplianceRate * 0.15) +
    (studentOutcomes * 0.35);

  const tierInfo = getPerformanceTier(overallScore);

  console.log('\n  Score Breakdown:');
  console.log('  ┌────────────────────────┬──────────┬────────┬─────────────┐');
  console.log('  │ Category               │ Score    │ Weight │ Contribution│');
  console.log('  ├────────────────────────┼──────────┼────────┼─────────────┤');
  console.log(`  │ 📅 Completion Rate     │ ${completionRate.toFixed(1).padStart(6)}%  │   30%  │ ${(completionRate * 0.30).toFixed(1).padStart(6)} pts  │`);
  console.log(`  │ ⏰ Punctuality Rate    │ ${punctualityRate.toFixed(1).padStart(6)}%  │   20%  │ ${(punctualityRate * 0.20).toFixed(1).padStart(6)} pts  │`);
  console.log(`  │ 📝 Form Compliance     │ ${formComplianceRate.toFixed(1).padStart(6)}%  │   15%  │ ${(formComplianceRate * 0.15).toFixed(1).padStart(6)} pts  │`);
  console.log(`  │ 📚 Student Outcomes    │ ${studentOutcomes.toFixed(1).padStart(6)}%  │   35%  │ ${(studentOutcomes * 0.35).toFixed(1).padStart(6)} pts  │`);
  console.log('  ├────────────────────────┼──────────┼────────┼─────────────┤');
  console.log(`  │ ${tierInfo.emoji} OVERALL SCORE       │ ${overallScore.toFixed(1).padStart(6)}%  │  100%  │ ${tierInfo.tier.toUpperCase().padStart(11)} │`);
  console.log('  └────────────────────────┴──────────┴────────┴─────────────┘');

  console.log(`\n  ${tierInfo.emoji} Performance Tier: ${tierInfo.tier.toUpperCase()}`);
  
  if (tierInfo.tier === 'excellent') {
    console.log('  🎉 Outstanding performance! Keep up the great work!');
  } else if (tierInfo.tier === 'good') {
    console.log('  👍 Good performance. Room for minor improvements.');
  } else if (tierInfo.tier === 'needsImprovement') {
    console.log('  ⚠️ Performance needs attention. Review the flags above.');
  } else {
    console.log('  🚨 Critical performance issues. Immediate action required.');
  }

  // ════════════════════════════════════════════════════════════════════════
  // 7. SAVE TO FIRESTORE
  // ════════════════════════════════════════════════════════════════════════
  const metrics = {
    id: `${userId}_${yearMonth}`,
    oderId: oderId,
    userId: userId,
    teacherEmail: userEmail,
    teacherName: userName,
    yearMonth: yearMonth,
    scheduledClasses,
    completedClasses,
    missedClasses,
    cancelledClasses,
    completionRate,
    totalClockIns,
    onTimeClockIns,
    lateClockIns,
    earlyClockIns,
    avgClockInDeltaMinutes,
    punctualityRate,
    formsRequired,
    formsSubmitted,
    formsOnTime,
    formsMissing,
    formComplianceRate,
    avgQuizScore,
    totalQuizzesTaken: 0,
    assignmentCompletionRate,
    totalAssignmentsGiven: 0,
    totalAssignmentsSubmitted: 0,
    attendanceRate,
    totalStudentsEnrolled: 0,
    avgStudentsPresent: 0,
    overallScore,
    performanceTier: tierInfo.tier,
    flags,
    detailedShifts,
    detailedTimesheets,
    detailedForms,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    periodStart: admin.firestore.Timestamp.fromDate(startDate),
    periodEnd: admin.firestore.Timestamp.fromDate(endDate),
  };

  const collection = isPilot ? 'pilot_audit_metrics' : 'audit_metrics';
  await db.collection(collection).doc(metrics.id).set(metrics);

  printSection('💾 DATA SAVED');
  console.log(`\n  ✅ Metrics saved to: ${collection}/${metrics.id}`);
  console.log(`  📊 Ready for dashboard viewing\n`);

  return metrics;
}

// Get all teachers from users collection
async function getAllTeachers() {
  const snapshot = await db.collection('users')
    .where('role', '==', 'teacher')
    .get();

  return snapshot.docs.map(doc => ({
    userId: doc.id,
    email: doc.data().email || '',
    name: `${doc.data().first_name || ''} ${doc.data().last_name || ''}`.trim() || doc.data().email,
  }));
}

// Main execution
async function main() {
  console.log('');
  console.log('╔════════════════════════════════════════════════════════════════════════════╗');
  console.log('║                    🏫 TEACHER AUDIT METRICS SYSTEM                         ║');
  console.log('║                         Detailed Report Generator                          ║');
  console.log('╚════════════════════════════════════════════════════════════════════════════╝');
  console.log(`\n  Started at: ${new Date().toISOString()}`);

  const yearMonth = getYearMonth();
  const specificUserId = getSpecificUserId();

  console.log(`  Computing metrics for period: ${yearMonth}`);

  let teachers = [];
  let isPilot = false;

  if (specificUserId) {
    const userDoc = await db.collection('users').doc(specificUserId).get();
    if (!userDoc.exists) {
      console.error(`\n  ❌ User not found: ${specificUserId}`);
      process.exit(1);
    }
    const userData = userDoc.data();
    // Debug: show user fields
    console.log(`  User fields: ${Object.keys(userData).join(', ')}`);
    teachers = [{
      userId: specificUserId,
      email: userData.email || userData.e_mail || userData.userEmail || '',
      name: `${userData.first_name || userData.firstName || ''} ${userData.last_name || userData.lastName || ''}`.trim() || userData.email || userData.e_mail || 'Unknown',
    }];
    isPilot = await isPilotUser(specificUserId);
    console.log(`  Mode: Single teacher - ${teachers[0].name}`);
    console.log(`  Pilot: ${isPilot ? 'YES 🧪' : 'NO'}`);
  } else {
    teachers = await getAllTeachers();
    console.log(`  Mode: All teachers (${teachers.length} found)`);
  }

  let successCount = 0;
  let errorCount = 0;

  for (const teacher of teachers) {
    try {
      const teacherIsPilot = specificUserId ? isPilot : await isPilotUser(teacher.userId);
      await computeMetricsForTeacher(
        teacher.userId,
        teacher.email,
        teacher.name,
        yearMonth,
        teacherIsPilot
      );
      successCount++;
    } catch (e) {
      console.error(`\n  ❌ Error computing metrics for ${teacher.email}:`, e.message);
      errorCount++;
    }
  }

  console.log('');
  console.log('╔════════════════════════════════════════════════════════════════════════════╗');
  console.log('║                              FINAL SUMMARY                                 ║');
  console.log('╚════════════════════════════════════════════════════════════════════════════╝');
  console.log(`  ✅ Successfully computed: ${successCount}`);
  console.log(`  ❌ Errors: ${errorCount}`);
  console.log(`  Completed at: ${new Date().toISOString()}`);
  console.log('');
}

main().then(() => process.exit(0)).catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
