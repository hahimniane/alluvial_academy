const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { RRule, RRuleSet, rrulestr } = require('rrule');
const { DateTime } = require('luxon');
const ExcelJS = require('exceljs');

// Note: admin.initializeApp() is called in index.js before this module is loaded
// We'll get the db instance inside each function to ensure it's initialized

/**
 * Helper: Format shift date/time for notifications
 */
function formatShiftDateTime(timestamp) {
  if (!timestamp) return 'Unknown time';
  const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
  return date.toLocaleString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });
}

/**
 * Helper: Send FCM notification to a teacher
 */
async function sendFCMNotificationToTeacher(teacherId, notification, data) {
  try {
    const db = admin.firestore();
    console.log(`📱 Sending FCM notification to teacher: ${teacherId}`);

    const teacherDoc = await db.collection('users').doc(teacherId).get();

    if (!teacherDoc.exists) {
      console.log(`Teacher ${teacherId} not found`);
      return { success: false, reason: 'Teacher not found' };
    }

    const teacherData = teacherDoc.data();
    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
    const fcmTokens = teacherData.fcmTokens || [];

    console.log(`=== Shift Notification for: ${teacherName} (${teacherId}) ===`);
    console.log(`FCM Tokens found: ${fcmTokens.length}`);

    if (fcmTokens.length === 0) {
      console.log(`⚠️ No FCM tokens found for teacher ${teacherId}`);
      return { success: false, reason: 'No FCM tokens' };
    }

    const tokens = fcmTokens.map((tokenObj) => tokenObj.token).filter((t) => t);
    console.log(`Valid tokens extracted: ${tokens.length}`);

    if (tokens.length === 0) {
      console.log(`⚠️ No valid tokens found for teacher ${teacherId}`);
      return { success: false, reason: 'No valid tokens' };
    }

    const message = {
      notification,
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`📱 Shift Notification Result for ${teacherName}:`);
    console.log(`  Success: ${response.successCount}/${tokens.length}`);
    console.log(`  Failed: ${response.failureCount}/${tokens.length}`);

    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        console.log(`  ✅ Token ${idx}: SUCCESS`);
      } else {
        console.log(`  ❌ Token ${idx}: FAILED - ${resp.error?.code}`);
      }
    });

    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error sending FCM notification:', error);
    return { success: false, reason: error.message };
  }
}

/**
 * Triggered when a new shift is created in shifts_new.
 * Handles recurrence generation AND sends notification to teacher.
 */
exports.onShiftCreateNew = onDocumentCreated(
  {
    document: 'shifts_new/{shiftId}',
  },
  async (event) => {
    const db = admin.firestore();
    const shiftData = event.data.data();
    const shiftId = event.params.shiftId;

    // ========== SEND NOTIFICATION TO TEACHER ==========
    try {
      const teacherId = shiftData.assigned_to;
      if (teacherId) {
        const teacherName = shiftData.teacher_name || 'Teacher';
        const studentNames = (shiftData.student_names || []).join(', ') || 'students';
        const subject = shiftData.subject_name || shiftData.shift_title || 'Class';
        const shiftDateTime = formatShiftDateTime(shiftData.start_utc);

        const notification = {
          title: '🎓 New Shift Assigned',
          body: `${subject} with ${studentNames} on ${shiftDateTime}`,
        };

        const data = {
          type: 'shift_new',
          action: 'created',
          shiftId: shiftId,
          teacherId: teacherId,
        };

        await sendFCMNotificationToTeacher(teacherId, notification, data);
        console.log(`✅ New shift notification sent to ${teacherName} for shift ${shiftId}`);
      }
    } catch (notifError) {
      console.error('Error sending shift created notification:', notifError);
      // Don't throw - notification failure shouldn't stop shift creation
    }

    // Only generate recurrences if this is the "master" shift (index 0) and has a rule
    if (!shiftData.recurrence_rule || shiftData.recurrence_instance_index !== 0) {
      return null;
    }

    console.log(`Generating recurrences for shift ${shiftId}`);

    const ruleString = shiftData.recurrence_rule;
    const startUtc = shiftData.start_utc.toDate(); // Firestore Timestamp to JS Date
    const endUtc = shiftData.end_utc.toDate();
    const durationMs = endUtc.getTime() - startUtc.getTime();
    const timezone = shiftData.timezone || 'UTC';

    // Parse the RRULE
    // Note: RRule library works with local times usually, or UTC.
    // We need to be careful with DST.
    // Strategy:
    // 1. Convert startUtc to "Local Wall Time" (e.g. 10:00 AM) using the timezone.
    // 2. Generate occurrences based on Wall Time.
    // 3. Convert each occurrence back to UTC using the timezone (handling DST).

    // Using Luxon for Timezone conversions
    const startZoned = DateTime.fromJSDate(startUtc).setZone(timezone);
    
    // Create an RRule options object
    // We need to strip the timezone offset for RRule to treat it as "floating" local time
    const dtstart = new Date(Date.UTC(
        startZoned.year,
        startZoned.month - 1,
        startZoned.day,
        startZoned.hour,
        startZoned.minute,
        startZoned.second
    ));

    const rule = rrulestr(ruleString, { dtstart: dtstart });

    // Generate dates for the next 6 months (or as specified in rule)
    // If the rule has COUNT or UNTIL, RRule handles it.
    // If infinite, we limit to 6 months.
    const now = new Date();
    const sixMonthsLater = new Date(now.setMonth(now.getMonth() + 6));
    
    // If rule doesn't have COUNT/UNTIL, force a limit? 
    // rrulestr usually respects the string. If it's infinite, we need 'between'.
    // Let's use 'all()' if it has count/until, or 'between' if infinite.
    // Safest is to use 'between' with a max date if we want to limit generation batch.
    // But requirements say "Pre-generate ... for a configurable future period".
    
    const occurrences = rule.between(dtstart, sixMonthsLater, true); // true to include start if matches

    let batch = db.batch();
    let batchCount = 0;

    // Skip the first one because it's already created (index 0)
    // Wait, RRule.between(inclusive=true) includes the start date.
    // We should check if the generated date matches the original start date.
    
    let instanceIndex = 1;

    for (const date of occurrences) {
        // 'date' is the "floating" local time in UTC representation (from RRule)
        // Convert back to real UTC timestamp for this timezone
        
        // Components from the RRule date (which are effectively local wall time components)
        const localComponents = {
            year: date.getUTCFullYear(),
            month: date.getUTCMonth() + 1,
            day: date.getUTCDate(),
            hour: date.getUTCHours(),
            minute: date.getUTCMinutes(),
            second: date.getUTCSeconds()
        };

        // Create Luxon DateTime in the target timezone with these components
        const occStartZoned = DateTime.fromObject(localComponents, { zone: timezone });
        const occStartUtc = occStartZoned.toJSDate();
        
        // Check if this is the original shift (approximate check)
        if (Math.abs(occStartUtc.getTime() - startUtc.getTime()) < 1000) {
            continue; // Skip the original shift
        }

        const occEndUtc = new Date(occStartUtc.getTime() + durationMs);

        const newShiftRef = db.collection('shifts_new').doc();
        const newShiftData = {
            ...shiftData,
            start_utc: admin.firestore.Timestamp.fromDate(occStartUtc),
            end_utc: admin.firestore.Timestamp.fromDate(occEndUtc),
            recurrence_instance_index: instanceIndex,
            // Link to template or original?
            // Maybe add 'recurrence_master_id': shiftId
        };

        batch.set(newShiftRef, newShiftData);
        batchCount++;
        instanceIndex++;

        if (batchCount >= 400) {
            await batch.commit();
            batch = db.batch(); // Create new batch after commit
            batchCount = 0;
        }
    }

    if (batchCount > 0) {
        await batch.commit();
    }

    console.log(`Generated ${instanceIndex - 1} occurrences.`);
  }
);

/**
 * Triggered when a shift is updated in shifts_new.
 * Sends notifications for status changes (confirmed, claimed, cancelled, etc.)
 */
exports.onShiftUpdateNew = onDocumentUpdated(
  {
    document: 'shifts_new/{shiftId}',
  },
  async (event) => {
    try {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const shiftId = event.params.shiftId;

      const teacherId = afterData.assigned_to;
      if (!teacherId) return null;

      const displayName = afterData.shift_title || afterData.subject_name || 'Your shift';
      const shiftDateTime = formatShiftDateTime(afterData.start_utc);

      // Status change notifications
      if (afterData.status !== beforeData.status) {
        let notification = null;
        let data = {
          type: 'shift_new',
          shiftId: shiftId,
          teacherId: teacherId,
        };

        switch (afterData.status) {
          case 'confirmed':
            notification = {
              title: '✅ Shift Confirmed',
              body: `${displayName} on ${shiftDateTime} has been confirmed`,
            };
            data.action = 'confirmed';
            break;

          case 'cancelled':
            notification = {
              title: '❌ Shift Cancelled',
              body: `${displayName} on ${shiftDateTime} has been cancelled`,
            };
            data.action = 'cancelled';
            break;

          case 'claimed':
            // Notify the original teacher that someone claimed their shift
            if (afterData.original_teacher_id && afterData.claimed_by) {
              notification = {
                title: '🙋 Shift Claimed',
                body: `Someone has claimed ${displayName} - awaiting approval`,
              };
              data.action = 'claimed';
            }
            break;

          case 'published':
            notification = {
              title: '📢 Shift Available',
              body: `${displayName} on ${shiftDateTime} is now open for claiming`,
            };
            data.action = 'published';
            break;

          case 'active':
            // Don't send notification for clock-in (teacher knows they clocked in)
            break;

          case 'completed':
            notification = {
              title: '✅ Shift Completed',
              body: `${displayName} has been marked as completed`,
            };
            data.action = 'completed';
            break;

          case 'missed':
            notification = {
              title: '⚠️ Shift Missed',
              body: `You missed ${displayName} scheduled for ${shiftDateTime}`,
            };
            data.action = 'missed';
            break;
        }

        if (notification) {
          await sendFCMNotificationToTeacher(teacherId, notification, data);
          console.log(`✅ Shift ${afterData.status} notification sent for ${shiftId}`);
        }
      }

      // Time/details change notification (not just status)
      if (afterData.status === beforeData.status) {
        const changes = [];
        
        if (beforeData.start_utc?.toDate().getTime() !== afterData.start_utc?.toDate().getTime()) {
          changes.push('time changed');
        }
        if (JSON.stringify(beforeData.student_ids) !== JSON.stringify(afterData.student_ids)) {
          changes.push('students updated');
        }
        if (beforeData.subject_id !== afterData.subject_id) {
          changes.push('subject changed');
        }

        if (changes.length > 0) {
          const notification = {
            title: '📝 Shift Updated',
            body: `${displayName} on ${shiftDateTime} - ${changes.join(', ')}`,
          };

          const data = {
            type: 'shift_new',
            action: 'updated',
            shiftId: shiftId,
            teacherId: teacherId,
            changes: changes.join(', '),
          };

          await sendFCMNotificationToTeacher(teacherId, notification, data);
          console.log(`✅ Shift updated notification sent for ${shiftId}`);
        }
      }

      return null;
    } catch (error) {
      console.error('Error in onShiftUpdateNew:', error);
      return null;
    }
  }
);

/**
 * Export Timesheet to Excel
 * Callable Function
 * Params: { startDate: ISOString, endDate: ISOString, timeZone: String }
 */
exports.exportTimesheet = onCall(async (request) => {
    if (!request.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    }

    const db = admin.firestore();
    const startDate = new Date(request.data.startDate);
    const endDate = new Date(request.data.endDate);
    const exportTimezone = request.data.timeZone || 'UTC';

    // Fetch shifts and time entries
    // This needs to be efficient. Ideally queries.
    // For this example, fetching shifts in range.
    
    const shiftsSnapshot = await db.collection('shifts_new')
        .where('start_utc', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('start_utc', '<=', admin.firestore.Timestamp.fromDate(endDate))
        .get();

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Timesheet');

    worksheet.columns = [
        { header: 'Employee ID', key: 'employee_id', width: 30 },
        { header: 'First Name', key: 'first_name', width: 15 },
        { header: 'Last Name', key: 'last_name', width: 15 },
        { header: 'Role', key: 'role', width: 10 },
        { header: 'Shift ID', key: 'shift_id', width: 30 },
        { header: 'Shift Title', key: 'shift_title', width: 20 },
        { header: 'Start UTC', key: 'start_utc', width: 25 },
        { header: 'End UTC', key: 'end_utc', width: 25 },
        { header: 'Timezone', key: 'timezone', width: 20 },
        { header: 'Start Local', key: 'start_local', width: 25 },
        { header: 'End Local', key: 'end_local', width: 25 },
        { header: 'Duration (Hrs)', key: 'duration_hours', width: 15 },
        { header: 'Clock In UTC', key: 'clock_in_utc', width: 25 },
        { header: 'Clock Out UTC', key: 'clock_out_utc', width: 25 },
        { header: 'Clock In Device', key: 'clock_in_device', width: 15 },
        { header: 'Clock Out Device', key: 'clock_out_device', width: 15 },
        { header: 'Clock In Location', key: 'clock_in_location', width: 20 },
        { header: 'Notes', key: 'notes', width: 30 },
        { header: 'Zoom Link', key: 'zoom_link', width: 30 },
        { header: 'Created By', key: 'created_by', width: 30 },
        { header: 'Created At UTC', key: 'created_at_utc', width: 25 },
        { header: 'Recurrence Rule', key: 'recurrence_rule', width: 30 },
        { header: 'Instance Index', key: 'recurrence_instance_index', width: 15 },
        { header: 'Status', key: 'status', width: 15 }
    ];

    // Helper to format date
    const fmt = (d) => d ? d.toISOString() : '';
    const fmtLocal = (d, tz) => d ? DateTime.fromJSDate(d).setZone(tz).toString() : '';

    for (const doc of shiftsSnapshot.docs) {
        const shift = doc.data();
        
        // Fetch User details (Optimization: cache users)
        let user = {};
        if (shift.assigned_to) {
            // Try users_new first
            let userSnap = await db.collection('users_new').doc(shift.assigned_to).get();
            
            // Fallback to production users if not found in new collection (for testing)
            if (!userSnap.exists) {
                userSnap = await db.collection('users').doc(shift.assigned_to).get();
            }

            if (userSnap.exists) user = userSnap.data();
        }

        // Fetch Time Entry for this shift (Optimization: fetch all entries in range beforehand)
        // Assuming one entry per shift for simplicity
        const entriesSnap = await db.collection('time_entries_new')
            .where('shift_id', '==', doc.id)
            .limit(1)
            .get();
        
        const entry = !entriesSnap.empty ? entriesSnap.docs[0].data() : {};

        const startUtcDate = shift.start_utc.toDate();
        const endUtcDate = shift.end_utc.toDate();

        worksheet.addRow({
            employee_id: shift.assigned_to,
            first_name: user.first_name || '',
            last_name: user.last_name || '',
            role: user.role || '',
            shift_id: doc.id,
            shift_title: shift.shift_title,
            start_utc: fmt(startUtcDate),
            end_utc: fmt(endUtcDate),
            timezone: shift.timezone,
            start_local: fmtLocal(startUtcDate, shift.timezone), // Display in Shift's timezone
            end_local: fmtLocal(endUtcDate, shift.timezone),
            duration_hours: shift.duration_hours,
            clock_in_utc: entry.clock_in_utc ? fmt(entry.clock_in_utc.toDate()) : '',
            clock_out_utc: entry.clock_out_utc ? fmt(entry.clock_out_utc.toDate()) : '',
            clock_in_device: entry.clock_in_device,
            clock_out_device: entry.clock_out_device,
            clock_in_location: entry.location,
            notes: shift.notes,
            zoom_link: shift.zoom_link,
            created_by: shift.created_by,
            created_at_utc: fmt(shift.created_at_utc.toDate()),
            recurrence_rule: shift.recurrence_rule,
            recurrence_instance_index: shift.recurrence_instance_index,
            status: shift.status
        });
    }

    // Generate buffer
    const buffer = await workbook.xlsx.writeBuffer();
    
    // Upload to Storage (Bucket) and get URL
    // This requires Storage bucket configuration
    const bucket = admin.storage().bucket();
    const filename = `exports/timesheet_${Date.now()}.xlsx`;
    const file = bucket.file(filename);
    
    await file.save(buffer, {
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    });

    const [url] = await file.getSignedUrl({
        action: 'read',
        expires: '03-01-2500' // Long expiry
    });

    return { url };
});

