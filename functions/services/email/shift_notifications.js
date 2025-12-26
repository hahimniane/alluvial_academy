/**
 * Send shift notification emails to teachers and student parents
 * Replaces Zoom meeting emails with Alluwal Education Hub navigation instructions
 */

const admin = require('firebase-admin');
const { DateTime } = require('luxon');
const { createTransporter } = require('./transporter');

const getTeacherEmailFromUserDoc = (userData) =>
  userData?.['e-mail'] || userData?.email || userData?.Email || userData?.mail || null;

const uniqueNonEmptyStrings = (values) => {
  if (!Array.isArray(values)) return [];
  const out = [];
  const seen = new Set();
  for (const raw of values) {
    const v = typeof raw === 'string' ? raw.trim() : '';
    if (!v) continue;
    const key = v.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(v);
  }
  return out;
};

/**
 * Collect student and guardian emails from shift data
 */
const collectStudentAndGuardianEmails = async (shiftData) => {
  const db = admin.firestore();
  const studentIds = Array.isArray(shiftData.student_ids) ? shiftData.student_ids : [];
  if (studentIds.length === 0) return [];

  const emails = [];
  for (const studentId of studentIds) {
    try {
      const studentDoc = await db.collection('users').doc(studentId).get();
      if (!studentDoc.exists) continue;
      const studentData = studentDoc.data() || {};

      // Get guardian emails (parents)
      const guardianIds = Array.isArray(studentData.guardian_ids) ? studentData.guardian_ids : [];
      for (const guardianId of guardianIds) {
        try {
          const guardianDoc = await db.collection('users').doc(String(guardianId)).get();
          if (!guardianDoc.exists) continue;
          const guardianEmail = getTeacherEmailFromUserDoc(guardianDoc.data());
          if (guardianEmail) emails.push(guardianEmail);
        } catch (_) {
          // best-effort
        }
      }
    } catch (_) {
      // best-effort
    }
  }

  return uniqueNonEmptyStrings(emails);
};

/**
 * Format date/time in a specific timezone
 */
const formatInZone = (date, zone) => {
  try {
    return DateTime.fromJSDate(date, { zone: zone || 'UTC' }).toFormat("ccc, LLL d • h:mm a ZZZZ");
  } catch (_) {
    return date.toLocaleString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
  }
};

/**
 * Send shift notification email to teacher
 */
const sendTeacherShiftNotification = async (shiftId, shiftData, teacherEmail, teacherName) => {
  const transporter = createTransporter();
  
  const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
  const teacherTimezone = shiftData.teacher_timezone || 'UTC';
  
  const studentNames = Array.isArray(shiftData.student_names) ? shiftData.student_names : [];
  const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
  const startDisplay = formatInZone(shiftStart, teacherTimezone);
  const endDisplay = formatInZone(shiftEnd, teacherTimezone);

  const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>New Class Scheduled</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
    .container { max-width: 640px; margin: 0 auto; background-color: white; }
    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 28px 20px; text-align: center; }
    .content { padding: 24px 20px; color: #111827; }
    .box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .instructions { background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .instructions h3 { margin-top: 0; color: #92400e; }
    .instructions ol { margin: 8px 0; padding-left: 20px; }
    .instructions li { margin: 8px 0; color: #78350f; }
    .muted { color: #6b7280; font-size: 14px; }
    .footer { background-color: #f8fafc; padding: 16px; text-align: center; color: #6b7280; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 22px;">📅 New Class Scheduled</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95;">Alluwal Education Hub</p>
    </div>
    <div class="content">
      <p>Dear ${teacherName},</p>
      <p>A new class has been scheduled for you.</p>
      
      <div class="box">
        <p style="margin: 0 0 8px 0;"><strong>Subject:</strong> ${subject}</p>
        <p style="margin: 0 0 8px 0;"><strong>Students:</strong> ${studentNames.length > 0 ? studentNames.join(', ') : 'No students assigned'}</p>
        <p style="margin: 0 0 8px 0;"><strong>Date & Time:</strong> ${startDisplay} → ${endDisplay}</p>
      </div>

      <div class="instructions">
        <h3>📱 How to Join Your Class:</h3>
        <ol>
          <li>Log in to <strong>Alluwal Education Hub</strong> using your email and password</li>
          <li>Navigate to your <strong>Dashboard</strong> or <strong>Classes</strong> section</li>
          <li>Find this class in your schedule</li>
          <li>Click the <strong>"Join Class"</strong> or <strong>"Start Class"</strong> button</li>
          <li>The class will open directly in your browser - no external apps needed!</li>
        </ol>
        <p style="margin: 12px 0 0 0; color: #78350f;">
          <strong>Note:</strong> You can join the class starting <strong>10 minutes before</strong> the scheduled time.
        </p>
      </div>

      <p class="muted" style="margin-top: 24px;">
        All classes are conducted through the Alluwal Education Hub platform. 
        You'll have access to video, audio, screen sharing, and interactive features all in one place.
      </p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} Alluwal Education Hub — please do not reply to this email.
    </div>
  </div>
</body>
</html>
  `;

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: teacherEmail,
    subject: `📅 New class scheduled: ${subject}`,
    html: emailHtml,
  };

  await transporter.sendMail(mailOptions);
  console.log(`[ShiftNotification] Teacher email sent for shift ${shiftId} to ${teacherEmail}`);
};

/**
 * Send shift notification email to student parents/guardians
 */
const sendParentShiftNotification = async (shiftId, shiftData, parentEmail, parentName, studentNames) => {
  const transporter = createTransporter();
  
  const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
  
  const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
  const teacherName = shiftData.teacher_name || 'Teacher';
  const startDisplay = formatInZone(shiftStart, 'UTC');
  const endDisplay = formatInZone(shiftEnd, 'UTC');

  const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Class Scheduled for Your Child</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
    .container { max-width: 640px; margin: 0 auto; background-color: white; }
    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 28px 20px; text-align: center; }
    .content { padding: 24px 20px; color: #111827; }
    .box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .instructions { background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .instructions h3 { margin-top: 0; color: #92400e; }
    .instructions ol { margin: 8px 0; padding-left: 20px; }
    .instructions li { margin: 8px 0; color: #78350f; }
    .muted { color: #6b7280; font-size: 14px; }
    .footer { background-color: #f8fafc; padding: 16px; text-align: center; color: #6b7280; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 22px;">📚 Class Scheduled for Your Child</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95;">Alluwal Education Hub</p>
    </div>
    <div class="content">
      <p>Dear ${parentName},</p>
      <p>A new class has been scheduled for ${studentNames.length > 1 ? 'your children' : 'your child'}.</p>
      
      <div class="box">
        <p style="margin: 0 0 8px 0;"><strong>Subject:</strong> ${subject}</p>
        <p style="margin: 0 0 8px 0;"><strong>Teacher:</strong> ${teacherName}</p>
        <p style="margin: 0 0 8px 0;"><strong>Students:</strong> ${studentNames.join(', ')}</p>
        <p style="margin: 0 0 8px 0;"><strong>Date & Time:</strong> ${startDisplay} → ${endDisplay}</p>
      </div>

      <div class="instructions">
        <h3>📱 How Your Child Can Join the Class:</h3>
        <ol>
          <li>Log in to <strong>Alluwal Education Hub</strong> using their Student ID and password</li>
          <li>Navigate to the <strong>Classes</strong> or <strong>My Classes</strong> section</li>
          <li>Find this class in their schedule</li>
          <li>Click the <strong>"Join Class"</strong> button when the class is available</li>
          <li>The class will open directly in their browser - no downloads needed!</li>
        </ol>
        <p style="margin: 12px 0 0 0; color: #78350f;">
          <strong>Note:</strong> Students can join the class starting <strong>10 minutes before</strong> the scheduled time.
        </p>
      </div>

      <p class="muted" style="margin-top: 24px;">
        All classes are conducted through the Alluwal Education Hub platform. 
        Your child will have access to video, audio, and interactive features all in one place.
      </p>

      <p style="margin-top: 24px;">
        If you have any questions or need assistance with login credentials, please contact the school administration.
      </p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} Alluwal Education Hub — please do not reply to this email.
    </div>
  </div>
</body>
</html>
  `;

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: parentEmail,
    subject: `📚 New class scheduled for ${studentNames.join(', ')}: ${subject}`,
    html: emailHtml,
  };

  await transporter.sendMail(mailOptions);
  console.log(`[ShiftNotification] Parent email sent for shift ${shiftId} to ${parentEmail}`);
};

/**
 * Send shift notification emails to teacher and student parents
 * This replaces the Zoom meeting email functionality
 */
const sendShiftNotificationEmails = async ({ shiftId, shiftData }) => {
  try {
    // Skip if shift is cancelled or non-teaching
    if (shiftData.status === 'cancelled') {
      return { skipped: true, reason: 'cancelled' };
    }

    if (shiftData.shift_category && shiftData.shift_category !== 'teaching') {
      return { skipped: true, reason: 'non_teaching_shift' };
    }

    // Skip if new notification emails already sent
    // Note: We don't check for zoom_invite_sent_at because we want to replace those with new emails
    if (shiftData.shift_notification_sent_at) {
      return { skipped: true, reason: 'already_sent' };
    }

    const teacherId = shiftData.teacher_id;
    if (!teacherId) {
      return { skipped: true, reason: 'missing_teacher_id' };
    }

    // Get teacher info
    const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();
    const teacherData = teacherDoc.exists ? teacherDoc.data() : null;
    const teacherEmail = getTeacherEmailFromUserDoc(teacherData);
    const teacherName = shiftData.teacher_name ||
      [teacherData?.first_name, teacherData?.last_name].filter(Boolean).join(' ') || 'Teacher';

    if (!teacherEmail) {
      return { skipped: true, reason: 'missing_teacher_email' };
    }

    // Send email to teacher
    await sendTeacherShiftNotification(shiftId, shiftData, teacherEmail, teacherName);

    // Collect and send emails to student parents
    const studentIds = Array.isArray(shiftData.student_ids) ? shiftData.student_ids : [];
    if (studentIds.length > 0) {
      const parentEmails = await collectStudentAndGuardianEmails(shiftData);
      
      if (parentEmails.length > 0) {
        // Get student names for the email
        const studentNames = Array.isArray(shiftData.student_names) ? shiftData.student_names : [];
        
        // Group emails by parent (in case multiple students share a parent)
        const parentEmailMap = new Map();
        for (const parentEmail of parentEmails) {
          if (!parentEmailMap.has(parentEmail)) {
            // Get parent name
            let parentName = 'Parent';
            try {
              const parentDocs = await admin.firestore()
                .collection('users')
                .where('e-mail', '==', parentEmail.toLowerCase())
                .limit(1)
                .get();
              if (!parentDocs.empty) {
                const parentData = parentDocs.docs[0].data();
                parentName = [parentData.first_name, parentData.last_name].filter(Boolean).join(' ') || 'Parent';
              }
            } catch (_) {
              // best-effort
            }
            parentEmailMap.set(parentEmail, parentName);
          }
        }

        // Send emails to all parents
        await Promise.all(
          Array.from(parentEmailMap.entries()).map(([email, name]) =>
            sendParentShiftNotification(shiftId, shiftData, email, name, studentNames)
          )
        );

        console.log(`[ShiftNotification] Parent emails sent for shift ${shiftId} to ${parentEmails.length} recipient(s)`);
      } else {
        console.log(`[ShiftNotification] No parent emails found for shift ${shiftId}`);
      }
    }

    // Mark emails as sent
    await admin.firestore()
      .collection('teaching_shifts')
      .doc(shiftId)
      .update({
        shift_notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`[ShiftNotification] All emails sent for shift ${shiftId}`);
    return { success: true };
  } catch (error) {
    console.error(`[ShiftNotification] Error sending emails for shift ${shiftId}:`, error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  sendShiftNotificationEmails,
};

