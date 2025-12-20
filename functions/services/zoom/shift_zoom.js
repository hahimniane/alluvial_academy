const admin = require('firebase-admin');
const { DateTime } = require('luxon');
const { createTransporter } = require('../email/transporter');
const { buildFunctionUrl } = require('../tasks/config');
const { getZoomConfig, isMeetingSdkConfigured } = require('./config');
const { createMeeting, getMeetingDetails, deleteMeeting, updateMeeting } = require('./client');
const { encryptString, decryptString, signJoinToken } = require('./crypto');
const { scheduleBreakoutOpener } = require('./breakout_scheduler');
const { getActiveHosts } = require('./hosts');

/**
 * ZOOM MEETING LOGIC:
 *
 * We have ONE Zoom host account that can only host ONE meeting at a time.
 * When shifts overlap in time, they must ALL be in the SAME Zoom meeting as breakout rooms.
 *
 * Flow:
 * 1. Admin creates Shift A at 10:00 AM → Create new Zoom meeting with breakout room "Shift A"
 * 2. Admin creates Shift B at 10:00 AM (overlaps) → Add breakout room "Shift B" to existing meeting
 * 3. Teacher A clicks "Start Class" → Joins meeting → Auto-routed to their breakout room
 * 4. Teacher B clicks "Start Class" → Joins SAME meeting → Auto-routed to their breakout room
 */

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

      const studentEmail = getTeacherEmailFromUserDoc(studentData);
      if (studentEmail) emails.push(studentEmail);

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

const formatInZone = (date, zone) => {
  try {
    return DateTime.fromJSDate(date, { zone: zone || 'UTC' }).toFormat("ccc, LLL d • h:mm a ZZZZ");
  } catch (_) {
    return date.toISOString();
  }
};

/**
 * Find any existing shift that overlaps with the given time range
 * Two shifts overlap if: shiftA.start < shiftB.end AND shiftA.end > shiftB.start
 */
const findOverlappingShift = async (shiftStart, shiftEnd, excludeShiftId) => {
  const db = admin.firestore();

  // Query shifts that could potentially overlap
  // We look for shifts where shift_start < our end time
  // IMPORTANT: Include both 'scheduled' AND 'active' statuses since shifts may have already started
  const snapshot = await db.collection('teaching_shifts')
    .where('status', 'in', ['scheduled', 'active'])
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(shiftEnd))
    .get();

  for (const doc of snapshot.docs) {
    if (doc.id === excludeShiftId) continue;

    const data = doc.data();
    const otherStart = data.shift_start?.toDate ? data.shift_start.toDate() : new Date(data.shift_start);
    const otherEnd = data.shift_end?.toDate ? data.shift_end.toDate() : new Date(data.shift_end);

    // Check actual overlap: our start < their end AND our end > their start
    if (shiftStart < otherEnd && shiftEnd > otherStart) {
      // This shift overlaps AND has a Zoom meeting
      if (data.zoom_meeting_id) {
        return { id: doc.id, ...data };
      }
    }
  }

  return null;
};

/**
 * Get all shifts that share the same Zoom meeting
 */
const getShiftsWithSameMeeting = async (zoomMeetingId) => {
  const db = admin.firestore();
  // Include both scheduled and active shifts
  const snapshot = await db.collection('teaching_shifts')
    .where('zoom_meeting_id', '==', zoomMeetingId)
    .where('status', 'in', ['scheduled', 'active'])
    .get();

  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

/**
 * Build breakout room config for a shift
 */
const buildBreakoutRoom = async (shift) => {
  const db = admin.firestore();
  const shiftStart = shift.shift_start?.toDate ? shift.shift_start.toDate() : new Date(shift.shift_start);
  const time = DateTime.fromJSDate(shiftStart).toUTC().toFormat('h:mm a');
  const students = shift.student_names ? shift.student_names.join(', ') : 'Students';
  const teacherName = shift.teacher_name || 'Teacher';

  // Breakout room name format: "Teacher | Students | Time"
  const name = `${teacherName} | ${students} | ${time}`;

  // Get participant emails for pre-assignment
  const participants = [];

  // Get teacher email
  if (shift.teacher_id) {
    const teacherDoc = await db.collection('users').doc(shift.teacher_id).get();
    if (teacherDoc.exists) {
      const email = getTeacherEmailFromUserDoc(teacherDoc.data());
      if (email) participants.push(email);
    }
  }

  // Get student emails
  if (shift.student_ids && shift.student_ids.length > 0) {
    for (const studentId of shift.student_ids) {
      const studentDoc = await db.collection('users').doc(studentId).get();
      if (studentDoc.exists) {
        const email = getTeacherEmailFromUserDoc(studentDoc.data());
        if (email) participants.push(email);
      }
    }
  }

  return { name, participants };
};

const getLicensedAlternativeHostEmails = async (excludeEmails = []) => {
  try {
    const excludes = new Set(
      excludeEmails
        .filter((e) => typeof e === 'string')
        .map((e) => e.trim().toLowerCase())
        .filter(Boolean)
    );

    const hosts = await getActiveHosts();
    const emails = [];
    const seen = new Set();
    for (const host of hosts) {
      const email = typeof host?.email === 'string' ? host.email.trim() : '';
      const key = email.toLowerCase();
      if (!email || excludes.has(key) || seen.has(key)) continue;
      seen.add(key);
      emails.push(email);
    }
    return emails;
  } catch (err) {
    console.warn(`[Zoom] Could not load active hosts for alternative hosts: ${err.message}`);
    return [];
  }
};

const ensureZoomMeetingAndEmailTeacher = async ({ shiftId, shiftData, selectedHost }) => {
  // If Zoom isn't configured, skip
  let zoomConfig;
  try {
    zoomConfig = getZoomConfig();
  } catch (e) {
    console.warn(`[Zoom] Skipping: ${e.message}`);
    return { skipped: true, reason: 'missing_config' };
  }

  // Use the selected host from findAvailableHost, or fall back to env var for backward compatibility
  const hostUser = selectedHost?.email || zoomConfig.hostUser;
  console.log(`[Zoom] Using host: ${hostUser} (selectedHost: ${selectedHost?.email || 'none'}, envVar: ${zoomConfig.hostUser})`);

  const db = admin.firestore();
  const shiftRef = db.collection('teaching_shifts').doc(shiftId);

  if (!shiftData || typeof shiftData !== 'object') {
    return { skipped: true, reason: 'missing_shift' };
  }

  if (shiftData.status === 'cancelled') {
    return { skipped: true, reason: 'cancelled' };
  }

  if (shiftData.shift_category && shiftData.shift_category !== 'teaching') {
    return { skipped: true, reason: 'non_teaching_shift' };
  }

  // Already has meeting AND invites sent (teacher + students)
  if (shiftData.zoom_meeting_id && shiftData.zoom_invite_sent_at && shiftData.zoom_student_invites_sent_at) {
    return { skipped: true, reason: 'already_created' };
  }

  const teacherId = shiftData.teacher_id;
  if (!teacherId) {
    return { skipped: true, reason: 'missing_teacher_id' };
  }

  const teacherDoc = await admin.firestore().collection('users').doc(teacherId).get();
  const teacherData = teacherDoc.exists ? teacherDoc.data() : null;
  const teacherEmail = getTeacherEmailFromUserDoc(teacherData);
  const teacherName = shiftData.teacher_name ||
    [teacherData?.first_name, teacherData?.last_name].filter(Boolean).join(' ') || 'Teacher';
  const teacherTimezone = shiftData.teacher_timezone || teacherData?.timezone || 'UTC';

  if (!teacherEmail) {
    return { skipped: true, reason: 'missing_teacher_email' };
  }

  const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
  const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
  const durationMinutes = Math.max(1, Math.ceil((shiftEnd.getTime() - shiftStart.getTime()) / 60000));

  const studentNames = Array.isArray(shiftData.student_names) ? shiftData.student_names : [];
  const subject = shiftData.subject_display_name || shiftData.subject || 'Class';
  const topic = shiftData.custom_name || shiftData.auto_generated_name ||
    `${subject}${studentNames.length ? ` • ${studentNames.slice(0, 3).join(', ')}` : ''}`;

  let passcode = null;
  let meetingId = shiftData.zoom_meeting_id;
  let joinUrl = null;
  let isNewMeeting = false;
  let meetingHostEmail = hostUser;

  // If shift doesn't already have a meeting assigned
  if (!meetingId) {
    // Check for overlapping shift that already has a Zoom meeting
    const overlappingShift = await findOverlappingShift(shiftStart, shiftEnd, shiftId);

    if (overlappingShift) {
      // OVERLAP EXISTS - Create a NEW meeting with ALL breakout rooms for all overlapping shifts
      console.log(`[Zoom] Shift ${shiftId} overlaps with ${overlappingShift.id}, creating new meeting with all breakout rooms`);

      // Get all shifts using the existing meeting
      const existingMeetingId = overlappingShift.zoom_meeting_id;
      const allShiftsInMeeting = await getShiftsWithSameMeeting(existingMeetingId);
      meetingHostEmail = overlappingShift.zoom_host_email || meetingHostEmail;

      // Add current shift to the list
      const currentShiftForBreakout = { id: shiftId, ...shiftData };
      const allShifts = [...allShiftsInMeeting.filter(s => s.id !== shiftId), currentShiftForBreakout];

      // Build breakout rooms for ALL shifts
      const breakoutRoomsWithTeachers = await Promise.all(allShifts.map(async (s) => {
        const room = await buildBreakoutRoom(s);
        return { room };
      }));

      const breakoutRooms = breakoutRoomsWithTeachers.map(r => r.room);
      const alternativeHostEmails = await getLicensedAlternativeHostEmails([meetingHostEmail, hostUser]);

      console.log(`[Zoom] Creating meeting with ${breakoutRooms.length} breakout rooms for shifts: ${allShifts.map(s => s.id).join(', ')}`);
      if (alternativeHostEmails.length > 0) {
        console.log(`[Zoom] Adding ${alternativeHostEmails.length} licensed alternative hosts: ${alternativeHostEmails.join(', ')}`);
      }

      // UPDATE the EXISTING meeting with all breakout rooms and teachers as co-hosts
      const meetingOptions = {
        topic: `Alwal Academy Classes - ${DateTime.fromJSDate(shiftStart).toFormat('MMM d, h:mm a')}`,
        breakoutRooms: breakoutRooms,
        alternativeHosts: alternativeHostEmails
      };

      await updateMeeting(existingMeetingId, meetingOptions);

      meetingId = existingMeetingId;
      // We need to fetch the joinUrl if we don't have it, but usually it's already on overlappingShift
      const meetingDetails = await getMeetingDetails(existingMeetingId);
      joinUrl = meetingDetails.joinUrl;
      passcode = meetingDetails.passcode;

      console.log(`[Zoom] Updated existing meeting ${meetingId} with ${breakoutRooms.length} breakout rooms`);

      // Update ALL existing overlapping shifts to use the new meeting
      const batch = db.batch();
      for (const existingShift of allShiftsInMeeting) {
        if (existingShift.id === shiftId) continue;

        const existingShiftRef = db.collection('teaching_shifts').doc(existingShift.id);
        const existingEncryptedJoinUrl = encryptString(joinUrl, zoomConfig.encryptionKeyB64);

        const existingUpdateData = {
          zoom_meeting_id: meetingId,
          zoom_encrypted_join_url: existingEncryptedJoinUrl,
          zoom_host_email: meetingHostEmail,
        };

        if (passcode) {
          existingUpdateData.zoom_encrypted_meeting_passcode = encryptString(passcode, zoomConfig.encryptionKeyB64);
        }

        batch.update(existingShiftRef, existingUpdateData);
        console.log(`[Zoom] Updating existing shift ${existingShift.id} to use new meeting ${meetingId}`);
      }
      await batch.commit();

    } else {
      // NO OVERLAP - Create new meeting with breakout room for this shift
      console.log(`[Zoom] No overlap for shift ${shiftId}, creating new meeting`);

      const breakoutRoom = await buildBreakoutRoom({ id: shiftId, ...shiftData });

      // Alternative hosts must be licensed users on the same Zoom account; use other configured hosts.
      const alternativeHostEmails = await getLicensedAlternativeHostEmails([hostUser]);
      if (alternativeHostEmails.length > 0) {
        console.log(`[Zoom] Adding ${alternativeHostEmails.length} licensed alternative hosts: ${alternativeHostEmails.join(', ')}`);
      }

      const meeting = await createMeeting({
        topic: `Alwal Academy Classes - ${DateTime.fromJSDate(shiftStart).toFormat('MMM d, h:mm a')}`,
        startTimeIso: shiftStart.toISOString(),
        durationMinutes: Math.max(durationMinutes, 120), // At least 2 hours for potential additional shifts
        agenda: `Alluwal Academy classes`,
        timezone: 'UTC',
        hostUser: hostUser,
        breakoutRooms: [breakoutRoom],
        alternativeHosts: alternativeHostEmails
      });

      meetingId = meeting.id;
      joinUrl = meeting.joinUrl;
      passcode = meeting.passcode;
      isNewMeeting = true;
      meetingHostEmail = hostUser;

      console.log(`[Zoom] Created new meeting ${meetingId} with breakout room for shift ${shiftId}`);
    }

    // If passcode not available, fetch it
    if (!passcode) {
      try {
        const details = await getMeetingDetails(meetingId);
        passcode = details.passcode;
        if (!joinUrl) joinUrl = details.joinUrl;
      } catch (err) {
        console.warn(`[Zoom] Could not fetch meeting details: ${err.message}`);
      }
    }

    // Build breakout room name for this specific shift
    const time = DateTime.fromJSDate(shiftStart).toUTC().toFormat('h:mm a');
    const students = studentNames.length > 0 ? studentNames.join(', ') : 'Students';
    const breakoutRoomName = `${teacherName} | ${students} | ${time}`;

    // Update shift with Zoom meeting details
    const updateData = {
      zoom_meeting_id: meetingId,
      zoom_encrypted_join_url: encryptString(joinUrl, zoomConfig.encryptionKeyB64),
      zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
      zoom_host_email: meetingHostEmail,
      breakoutRoomName: breakoutRoomName,
    };

    if (passcode) {
      updateData.zoom_encrypted_meeting_passcode = encryptString(passcode, zoomConfig.encryptionKeyB64);
    }

    await shiftRef.update(updateData);
    console.log(`[Zoom] Updated shift ${shiftId} with meeting ${meetingId}, breakout room: ${breakoutRoomName}`);

    // Schedule backup breakout opener task (3 minutes after shift start)
    // This will open rooms automatically if teachers don't do it via the app
    try {
      await scheduleBreakoutOpener(shiftId, meetingId, shiftStart, 3);
    } catch (scheduleErr) {
      console.warn(`[Zoom] Could not schedule breakout opener: ${scheduleErr.message}`);
    }

  } else {
    // Meeting already exists on shift - decrypt stored data
    if (shiftData.zoom_encrypted_meeting_passcode) {
      try {
        passcode = decryptString(shiftData.zoom_encrypted_meeting_passcode, zoomConfig.encryptionKeyB64);
      } catch (err) {
        console.warn(`[Zoom] Could not decrypt passcode: ${err.message}`);
      }
    }
    if (shiftData.zoom_encrypted_join_url) {
      try {
        joinUrl = decryptString(shiftData.zoom_encrypted_join_url, zoomConfig.encryptionKeyB64);
      } catch (err) {
        console.warn(`[Zoom] Could not decrypt join URL: ${err.message}`);
      }
    }
  }

  // Generate secure join link for email
  const allowedEndMs = shiftEnd.getTime() + 10 * 60 * 1000;
  const expSeconds = Math.floor((allowedEndMs + 5 * 60 * 1000) / 1000);
  const joinToken = signJoinToken({ shiftId, teacherId, exp: expSeconds }, zoomConfig.joinTokenSecret);
  const joinLink = `${buildFunctionUrl('joinZoomMeeting')}?token=${encodeURIComponent(joinToken)}`;

  const startDisplay = formatInZone(shiftStart, teacherTimezone);
  const endDisplay = formatInZone(shiftEnd, teacherTimezone);
  const useMeetingSdk = isMeetingSdkConfigured();

  const transporter = createTransporter();

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
        <p style="margin: 0 0 8px 0;"><strong>When:</strong> ${startDisplay} → ${endDisplay}</p>
        ${passcode ? `<p style="margin: 0;"><strong>Meeting Password:</strong> ${passcode}</p>` : ''}
      </div>
      <div class="app-join">
        <h3>📱 Join from the Alluwal App</h3>
        <p>Open the Alluwal Education Hub app → Click "Start Class" → You'll be automatically placed in your breakout room</p>
      </div>
      <p class="muted" style="margin: 0;">
        The join button will appear 10 minutes before your shift starts.
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
        <p style="margin: 0 0 8px 0;"><strong>When:</strong> ${startDisplay} → ${endDisplay}</p>
        ${passcode ? `<p style="margin: 0;"><strong>Meeting Password:</strong> ${passcode}</p>` : ''}
      </div>
      <p style="margin: 18px 0 10px 0;"><a class="cta" href="${joinLink}">Join Zoom</a></p>
      <p class="muted" style="margin: 0;">
        This link only works from <strong>10 minutes before</strong> your shift until <strong>10 minutes after</strong> it ends.
        You'll be automatically placed in your breakout room.
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
  const updateInviteTimestamps = {
    zoom_invite_sent_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Best-effort: email students/guardians a join link (direct Zoom URL + passcode).
  // Note: This is separate from the teacher joinLink which uses a signed token.
  try {
    const studentRecipientEmails = await collectStudentAndGuardianEmails(shiftData);
    if (studentRecipientEmails.length > 0) {
      const studentEmailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Zoom Class Link</title>
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
      <h1 style="margin: 0; font-size: 22px;">Your class Zoom link</h1>
      <p style="margin: 8px 0 0 0; opacity: 0.95;">Alluwal Education Hub</p>
    </div>
    <div class="content">
      <p>Hello,</p>
      <div class="box">
        <p style="margin: 0 0 8px 0;"><strong>Class:</strong> ${topic}</p>
        <p style="margin: 0 0 8px 0;"><strong>When:</strong> ${startDisplay} → ${endDisplay}</p>
        ${passcode ? `<p style="margin: 0;"><strong>Meeting Password:</strong> ${passcode}</p>` : ''}
      </div>
      <p style="margin: 18px 0 10px 0;"><a class="cta" href="${joinUrl}">Join Zoom</a></p>
      <p class="muted" style="margin: 0;">
        If your class uses breakout rooms, please join using the same email address your account was registered with.
      </p>
    </div>
    <div class="footer">
      © ${new Date().getFullYear()} Alluwal Education Hub — please do not reply to this email.
    </div>
  </div>
</body>
</html>
      `;

      await Promise.all(
        studentRecipientEmails.map((to) =>
          transporter.sendMail({
            from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
            to,
            subject: `📚 Zoom class link (${subject})`,
            html: studentEmailHtml,
          })
        )
      );

      updateInviteTimestamps.zoom_student_invites_sent_at = admin.firestore.FieldValue.serverTimestamp();
      console.log(`[Zoom] Student/guardian emails sent for shift ${shiftId} to ${studentRecipientEmails.length} recipient(s)`);
    } else {
      console.log(`[Zoom] No student/guardian emails found for shift ${shiftId}`);
    }
  } catch (studentEmailErr) {
    console.warn(`[Zoom] Failed to email students/guardians for shift ${shiftId}: ${studentEmailErr.message}`);
  }

  await shiftRef.update(updateInviteTimestamps);

  console.log(`[Zoom] Email sent for shift ${shiftId} to ${teacherEmail}`);
  return { created: isNewMeeting, addedToExisting: !isNewMeeting && !shiftData.zoom_meeting_id };
};

module.exports = {
  ensureZoomMeetingAndEmailTeacher,
  getShiftsWithSameMeeting,
  buildBreakoutRoom,
};
