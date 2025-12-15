const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const {createTransporter} = require('../email/transporter');
const {buildFunctionUrl} = require('../tasks/config');
const {getZoomConfig, isMeetingSdkConfigured} = require('./config');
const {createMeeting, getMeetingDetails} = require('./client');
const {encryptString, signJoinToken} = require('./crypto');

const getTeacherEmailFromUserDoc = (userData) =>
  userData?.['e-mail'] || userData?.email || userData?.Email || userData?.mail || null;

const formatInZone = (date, zone) => {
  try {
    return DateTime.fromJSDate(date, {zone: zone || 'UTC'}).toFormat("ccc, LLL d • h:mm a ZZZZ");
  } catch (_) {
    return date.toISOString();
  }
};

const ensureZoomMeetingAndEmailTeacher = async ({shiftId, shiftData}) => {
  // If Zoom isn't configured, no-op (don't break shift creation).
  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    console.warn(`[Zoom] Skipping Zoom meeting creation for shift ${shiftId}: ${e.message}`);
    return {skipped: true, reason: 'missing_config'};
  }

  const shiftRef = admin.firestore().collection('teaching_shifts').doc(shiftId);

  if (!shiftData || typeof shiftData !== 'object') {
    console.warn(`[Zoom] Missing shiftData for ${shiftId}`);
    return {skipped: true, reason: 'missing_shift'};
  }

  if (shiftData.status === 'cancelled') {
    return {skipped: true, reason: 'cancelled'};
  }

  const shiftCategory = shiftData.shift_category || 'teaching';
  if (shiftCategory !== 'teaching') {
    return {skipped: true, reason: 'non_teaching_shift'};
  }

  const hasExistingMeeting = Boolean(shiftData.zoom_meeting_id && shiftData.zoom_encrypted_join_url);
  if (hasExistingMeeting && shiftData.zoom_invite_sent_at) {
    return {skipped: true, reason: 'already_created'};
  }

  const teacherId = shiftData.teacher_id;
  if (!teacherId) {
    console.warn(`[Zoom] Shift ${shiftId} missing teacher_id`);
    return {skipped: true, reason: 'missing_teacher_id'};
  }

  const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();
  const teacherData = teacherDoc.exists ? teacherDoc.data() : null;
  const teacherEmail = getTeacherEmailFromUserDoc(teacherData);
  const teacherName =
    shiftData.teacher_name ||
    [teacherData?.first_name, teacherData?.last_name].filter(Boolean).join(' ') ||
    'Teacher';
  const teacherTimezone = shiftData.teacher_timezone || teacherData?.timezone || 'UTC';

  if (!teacherEmail) {
    console.warn(`[Zoom] Teacher ${teacherId} missing email, cannot send invite (shift ${shiftId})`);
    return {skipped: true, reason: 'missing_teacher_email'};
  }

  const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);

  const durationMinutes = Math.max(1, Math.ceil((shiftEnd.getTime() - shiftStart.getTime()) / 60000));

  const studentNames = Array.isArray(shiftData.student_names) ? shiftData.student_names : [];
  const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
  const topic =
    shiftData.custom_name ||
    shiftData.auto_generated_name ||
    `${subject}${studentNames.length ? ` • ${studentNames.slice(0, 3).join(', ')}` : ''}`;

  const agenda = `Alluwal Academy shift: ${topic}`;

  if (!hasExistingMeeting) {
    const startTimeIso = shiftStart.toISOString();
    const meeting = await createMeeting({
      topic,
      startTimeIso,
      durationMinutes,
      agenda,
      timezone: 'UTC',
    });

    const encryptedJoinUrl = encryptString(meeting.joinUrl, zoomConfig.encryptionKeyB64);
    
    // Prepare update data
    const updateData = {
      zoom_meeting_id: meeting.id,
      zoom_encrypted_join_url: encryptedJoinUrl,
      zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Store encrypted passcode for Meeting SDK join (if passcode is available)
    let passcode = meeting.passcode;
    
    // If passcode not in create response, fetch from meeting details
    if (!passcode) {
      try {
        const details = await getMeetingDetails(meeting.id);
        passcode = details.passcode;
      } catch (fetchErr) {
        console.warn(`[Zoom] Could not fetch meeting details for passcode: ${fetchErr.message}`);
      }
    }
    
    if (passcode) {
      // Encrypt passcode before storing (never store plaintext)
      updateData.zoom_encrypted_meeting_passcode = encryptString(passcode, zoomConfig.encryptionKeyB64);
      updateData.zoom_meeting_passcode_created_at = admin.firestore.FieldValue.serverTimestamp();
    }

    await shiftRef.update(updateData);
  }

  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;
  const expSeconds = Math.floor((allowedEndMs + 5 * 60 * 1000) / 1000);

  const joinToken = signJoinToken({shiftId, teacherId, exp: expSeconds}, zoomConfig.joinTokenSecret);
  const joinLink = `${buildFunctionUrl('joinZoomMeeting')}?token=${encodeURIComponent(joinToken)}`;

  const startDisplay = formatInZone(shiftStart, teacherTimezone);
  const endDisplay = formatInZone(shiftEnd, teacherTimezone);

  // Determine if Meeting SDK is configured (prefer in-app join)
  const useMeetingSdk = isMeetingSdkConfigured();
  
  const transporter = createTransporter();
  
  // Email HTML - different based on whether Meeting SDK is enabled
  const emailHtml = useMeetingSdk ? `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Zoom Meeting Scheduled</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
    .container { max-width: 640px; margin: 0 auto; background-color: white; }
    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 28px 20px; text-align: center; }
    .content { padding: 24px 20px; color: #111827; }
    .box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .app-join { background-color: #10B981; border-radius: 8px; padding: 16px; margin: 16px 0; }
    .app-join h3 { margin: 0 0 8px 0; color: white; font-size: 16px; }
    .app-join p { margin: 0; color: rgba(255,255,255,0.9); font-size: 14px; }
    .muted { color: #6b7280; font-size: 14px; }
    .cta-secondary { display: inline-block; background-color: #6b7280; color: white; padding: 10px 16px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 14px; }
    .footer { background-color: #f8fafc; padding: 16px; text-align: center; color: #6b7280; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 22px;">Your Zoom meeting is ready</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95;">Alluwal Education Hub</p>
    </div>
    <div class="content">
      <p>Dear ${teacherName},</p>
      <div class="box">
        <p style="margin: 0 0 8px 0;"><strong>Shift:</strong> ${topic}</p>
        <p style="margin: 0;"><strong>When:</strong> ${startDisplay} → ${endDisplay}</p>
      </div>
      <div class="app-join">
        <h3>📱 Join from the Alluwal App</h3>
        <p>Open the Alluwal Education Hub app → Zoom tab → Join your shift</p>
      </div>
      <p class="muted" style="margin: 0;">
        For the best experience, join directly from the app. The join button will appear 10 minutes before your shift starts.
      </p>
      <hr style="margin: 20px 0; border: none; border-top: 1px solid #e5e7eb;" />
      <p class="muted" style="margin: 0 0 10px 0;"><strong>Alternative:</strong> If you can't use the app:</p>
      <p style="margin: 10px 0;"><a class="cta-secondary" href="${joinLink}">Join via Browser</a></p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} Alluwal Education Hub — please do not reply to this email.
    </div>
  </div>
</body>
</html>
  ` : `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Zoom Meeting Link</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
    .container { max-width: 640px; margin: 0 auto; background-color: white; }
    .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 28px 20px; text-align: center; }
    .content { padding: 24px 20px; color: #111827; }
    .box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 16px; border-radius: 0 8px 8px 0; margin: 16px 0; }
    .cta { display: inline-block; background-color: #0386FF; color: white; padding: 12px 18px; text-decoration: none; border-radius: 8px; font-weight: 700; }
    .muted { color: #6b7280; font-size: 14px; }
    .footer { background-color: #f8fafc; padding: 16px; text-align: center; color: #6b7280; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 22px;">Your Zoom meeting is ready</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95;">Alluwal Education Hub</p>
    </div>
    <div class="content">
      <p>Dear ${teacherName},</p>
      <div class="box">
        <p style="margin: 0 0 8px 0;"><strong>Shift:</strong> ${topic}</p>
        <p style="margin: 0;"><strong>When:</strong> ${startDisplay} → ${endDisplay}</p>
      </div>
      <p style="margin: 18px 0 10px 0;"><a class="cta" href="${joinLink}">Join Zoom</a></p>
      <p class="muted" style="margin: 0;">
        This link only works from <strong>10 minutes before</strong> your shift until <strong>10 minutes after</strong> it ends.
      </p>
      <p class="muted" style="margin: 14px 0 0 0;">
        If the button doesn't work, copy/paste this link:
        <br />
        <span style="word-break: break-all;">${joinLink}</span>
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
    subject: `📅 Zoom meeting scheduled for your shift (${subject})`,
    html: emailHtml,
  };

  await transporter.sendMail(mailOptions);
  await shiftRef.update({
    zoom_invite_sent_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`[Zoom] Zoom meeting ensured and email sent for shift ${shiftId} to ${teacherEmail}`);
  return {created: !hasExistingMeeting};
};

module.exports = {
  ensureZoomMeetingAndEmailTeacher,
};
