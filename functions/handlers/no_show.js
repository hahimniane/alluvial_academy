const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall} = require('firebase-functions/v2/https');
const {createTransporter} = require('../services/email/transporter');

function cleanString(value, fallback = null) {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : fallback;
}

function parseClientTimestamp(value) {
  if (!value) return admin.firestore.FieldValue.serverTimestamp();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime())
    ? admin.firestore.FieldValue.serverTimestamp()
    : parsed;
}

async function getShiftDetails(shiftId) {
  const db = admin.firestore();
  const teachingShiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
  if (teachingShiftDoc.exists) {
    return {
      collection: 'teaching_shifts',
      data: teachingShiftDoc.data(),
    };
  }

  const legacyShiftDoc = await db.collection('shifts').doc(shiftId).get();
  return {
    collection: legacyShiftDoc.exists ? 'shifts' : null,
    data: legacyShiftDoc.exists ? legacyShiftDoc.data() : null,
  };
}

function normalizeShiftDetails(shiftData) {
  if (!shiftData) {
    return {
      shiftName: null,
      teacherId: null,
      teacherName: null,
      studentIds: [],
      studentNames: [],
    };
  }

  return {
    shiftName: cleanString(
      shiftData.shift_name ||
        shiftData.shiftName ||
        shiftData.subject_name ||
        shiftData.subjectName
    ),
    teacherId: cleanString(shiftData.teacher_id || shiftData.teacherId),
    teacherName: cleanString(shiftData.teacher_name || shiftData.teacherName),
    studentIds: Array.isArray(shiftData.student_ids)
      ? shiftData.student_ids
      : (Array.isArray(shiftData.studentIds) ? shiftData.studentIds : []),
    studentNames: Array.isArray(shiftData.student_names)
      ? shiftData.student_names
      : (Array.isArray(shiftData.studentNames) ? shiftData.studentNames : []),
  };
}

function trimDiagnostics(diagnostics) {
  if (!diagnostics || typeof diagnostics !== 'object' || Array.isArray(diagnostics)) {
    return null;
  }

  const encoded = JSON.stringify(diagnostics);
  if (encoded.length <= 900000) return diagnostics;

  return {
    schemaVersion: diagnostics.schemaVersion || 1,
    truncated: true,
    diagnosticSnapshot: diagnostics.diagnosticSnapshot || null,
    shiftId: diagnostics.shiftId || null,
    roomName: diagnostics.roomName || null,
    issueType: diagnostics.issueType || null,
    reporterRole: diagnostics.reporterRole || null,
    platform: diagnostics.platform || null,
    canPlaybackAudio: diagnostics.canPlaybackAudio ?? null,
    audioPlaybackAllowedState: diagnostics.audioPlaybackAllowedState ?? null,
    micEnabledInUi: diagnostics.micEnabledInUi ?? null,
    remoteParticipantCount: diagnostics.remoteParticipantCount ?? null,
  };
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function hasAudibleAudioPublication(participant) {
  return asArray(participant?.audioPublications).some((pub) =>
    pub &&
    pub.muted !== true &&
    pub.subscribed !== false &&
    pub.hasTrack === true &&
    pub.trackMuted !== true
  );
}

function buildAudioDiagnosticSummary(diagnostics) {
  if (!diagnostics || typeof diagnostics !== 'object') {
    return {
      suspectedCauses: ['missing_client_diagnostics'],
      severity: 'unknown',
      nextSteps: ['Ask the participant to submit the report from inside the class again.'],
    };
  }

  const suspectedCauses = new Set();
  const nextSteps = new Set();
  const clientFindings = asArray(diagnostics.clientAudioFindings)
    .map((value) => String(value));
  clientFindings.forEach((finding) => suspectedCauses.add(finding));

  const local = diagnostics.localParticipant || null;
  const remotes = asArray(diagnostics.remoteParticipants);

  if (diagnostics.canPlaybackAudio === false ||
      diagnostics.audioPlaybackAllowedState === false) {
    suspectedCauses.add('receiver_audio_playback_blocked');
    nextSteps.add('Have the affected participant click Enable audio, then refresh/rejoin if audio remains blocked.');
  }

  if (diagnostics.micLockedByHost === true ||
      diagnostics.studentMicrophonesLocked === true) {
    suspectedCauses.add('microphone_lock_enabled');
    nextSteps.add('Check whether the host locked participant microphones or muted everyone.');
  }

  if (diagnostics.reconnecting === true || diagnostics.connecting === true) {
    suspectedCauses.add('connection_not_stable');
    nextSteps.add('Check connection quality and ask the participant to rejoin after the room fully reconnects.');
  }

  if (local) {
    const localAudioPublications = asArray(local.audioPublications);
    if (diagnostics.micEnabledInUi === true && localAudioPublications.length === 0) {
      suspectedCauses.add('sender_mic_enabled_but_not_published');
      nextSteps.add('Ask the sender to toggle mic off/on, check browser microphone permission, then rejoin.');
    } else if (diagnostics.micEnabledInUi === true && !hasAudibleAudioPublication(local)) {
      suspectedCauses.add('sender_mic_track_not_active');
      nextSteps.add('Ask the sender to select another microphone or rejoin; the mic button can be on while the track is unavailable.');
    }

    if (local.connectionQuality === 'poor' || local.connectionQuality === 'lost') {
      suspectedCauses.add(`reporter_connection_${local.connectionQuality}`);
      nextSteps.add('Check the reporter network quality, VPN, browser tab throttling, and Wi-Fi stability.');
    }

    localAudioPublications.forEach((pub) => {
      const stats = pub?.webRtcStats || {};
      if (stats.direction !== 'outbound') return;
      if ((Number(stats.bytesSent) || 0) <= 0 || (Number(stats.packetsSent) || 0) <= 0) {
        suspectedCauses.add('sender_webrtc_not_sending_audio_packets');
        nextSteps.add('Ask the speaker to toggle mic, verify browser mic permission/device selection, and rejoin if outbound packets stay at zero.');
      }
      const source = stats.audioSourceStats || {};
      if (source.totalAudioEnergy != null && Number(source.totalAudioEnergy) <= 0) {
        suspectedCauses.add('sender_microphone_capturing_silence');
        nextSteps.add('Ask the speaker to check the selected input device and OS/browser input level.');
      }
    });
  }

  if (remotes.length === 0) {
    suspectedCauses.add('no_remote_participants_visible_to_reporter');
    nextSteps.add('Verify both participants are in the same LiveKit room and not using duplicate accounts/tabs.');
  }

  const remoteWithoutAudio = [];
  const remoteMuted = [];
  const remoteNotSubscribed = [];
  const remoteNoTrack = [];
  const remotePoorQuality = [];

  remotes.forEach((participant) => {
    const identity = participant?.identity || 'unknown';
    const publications = asArray(participant?.audioPublications);
    if (publications.length === 0) remoteWithoutAudio.push(identity);
    if (participant?.connectionQuality === 'poor' || participant?.connectionQuality === 'lost') {
      remotePoorQuality.push(`${identity}:${participant.connectionQuality}`);
    }

    publications.forEach((pub) => {
      if (pub?.muted === true) remoteMuted.push(identity);
      if (pub?.subscribed === false) remoteNotSubscribed.push(identity);
      if (pub?.hasTrack !== true) remoteNoTrack.push(identity);
      const stats = pub?.webRtcStats || {};
      if (stats.direction === 'inbound') {
        if ((Number(stats.bytesReceived) || 0) <= 0 || (Number(stats.packetsReceived) || 0) <= 0) {
          suspectedCauses.add('receiver_webrtc_not_receiving_audio_packets');
          nextSteps.add(`The reporter is subscribed but receiving no audio packets from ${identity}; inspect LiveKit/TURN/network path and ask the reporter to rejoin.`);
        }
        if ((Number(stats.packetsLost) || 0) > 0) {
          suspectedCauses.add('receiver_audio_packet_loss');
          nextSteps.add(`Audio packet loss detected from ${identity}; check network quality, VPN, Wi-Fi, and TURN relay health.`);
        }
        if ((Number(stats.concealedSamples) || 0) > 0) {
          suspectedCauses.add('receiver_audio_concealment');
          nextSteps.add(`Browser is concealing lost/late audio from ${identity}; check jitter/packet loss and network stability.`);
        }
      }
    });
  });

  if (remoteWithoutAudio.length > 0) {
    suspectedCauses.add('remote_participant_not_publishing_audio');
    nextSteps.add(`Ask these participants to toggle mic/rejoin: ${[...new Set(remoteWithoutAudio)].join(', ')}`);
  }
  if (remoteMuted.length > 0) {
    suspectedCauses.add('remote_audio_muted');
    nextSteps.add(`Check mute state for: ${[...new Set(remoteMuted)].join(', ')}`);
  }
  if (remoteNotSubscribed.length > 0) {
    suspectedCauses.add('receiver_not_subscribed_to_remote_audio');
    nextSteps.add('Ask the affected listener to refresh/rejoin; if repeated, inspect LiveKit subscription/network logs.');
  }
  if (remoteNoTrack.length > 0) {
    suspectedCauses.add('remote_audio_publication_missing_track');
    nextSteps.add('Ask the remote speaker to reselect microphone or rejoin; the publication exists but no usable track reached the listener.');
  }
  if (remotePoorQuality.length > 0) {
    suspectedCauses.add('remote_connection_quality_issue');
    nextSteps.add(`Check network quality for: ${remotePoorQuality.join(', ')}`);
  }

  if (suspectedCauses.size === 0) {
    suspectedCauses.add('no_obvious_client_side_failure');
    nextSteps.add('Compare this report with the other participant report from the same appSessionId/shift; one-sided reports may miss sender-side failures.');
  }

  const severeCauses = [
    'receiver_audio_playback_blocked',
    'sender_mic_enabled_but_not_published',
    'sender_webrtc_not_sending_audio_packets',
    'receiver_webrtc_not_receiving_audio_packets',
    'receiver_not_subscribed_to_remote_audio',
    'remote_audio_publication_missing_track',
  ];
  const severity = [...suspectedCauses].some((cause) =>
    severeCauses.some((severe) => cause.includes(severe))
  ) ? 'high' : 'medium';

  return {
    suspectedCauses: [...suspectedCauses],
    severity,
    nextSteps: [...nextSteps],
  };
}

function getIssueCategory(issueType) {
  const issue = cleanString(issueType, 'technical_issue');
  const audioIssues = new Set([
    'mutual_audio_issue',
    'cannot_hear_other',
    'other_cannot_hear_me',
    'audio_cuts_out',
    'echo_feedback_noise',
    'mic_permission_or_device',
  ]);
  const videoIssues = new Set([
    'camera_not_working',
    'cannot_see_other',
    'other_cannot_see_me',
    'frozen_video',
    'video_quality_lag',
  ]);
  const screenShareIssues = new Set([
    'screen_share_not_working',
    'cannot_see_screen_share',
    'screen_share_quality',
  ]);
  const whiteboardIssues = new Set([
    'whiteboard_not_loading',
    'whiteboard_drawing_not_working',
    'whiteboard_not_syncing',
  ]);
  const roomIssues = new Set([
    'cannot_join_class',
    'participant_missing',
    'wrong_room_or_duplicate_tab',
  ]);
  const connectionIssues = new Set([
    'disconnected_or_reconnecting',
    'class_lagging',
  ]);
  const controlIssues = new Set([
    'controls_not_working',
    'mute_lock_problem',
  ]);

  if (audioIssues.has(issue) || issue.includes('audio')) return 'audio';
  if (videoIssues.has(issue) || issue.includes('video') || issue.includes('camera')) return 'video';
  if (screenShareIssues.has(issue) || issue.includes('screen_share')) return 'screen_share';
  if (whiteboardIssues.has(issue) || issue.includes('whiteboard')) return 'whiteboard';
  if (roomIssues.has(issue)) return 'room';
  if (connectionIssues.has(issue) || issue.includes('disconnect') || issue.includes('lag')) return 'connection';
  if (controlIssues.has(issue) || issue.includes('control') || issue.includes('lock')) return 'controls';
  if (issue === 'recording_problem') return 'recording';
  if (issue === 'chat_or_messages_problem') return 'chat';
  if (issue === 'materials_or_links_problem') return 'materials';
  return 'technical';
}

function buildClassDiagnosticSummary(diagnostics, issueCategory) {
  const audioSummary = buildAudioDiagnosticSummary(diagnostics);
  const suspectedCauses = new Set(audioSummary.suspectedCauses);
  const nextSteps = new Set(audioSummary.nextSteps);
  const classFindings = asArray(diagnostics?.clientClassFindings)
    .map((value) => String(value));
  classFindings.forEach((finding) => suspectedCauses.add(finding));

  if (diagnostics?.roomLocked === true) {
    suspectedCauses.add('room_locked');
    nextSteps.add('Check whether the class room was locked before the affected participant joined.');
  }
  if (diagnostics?.screenShareEnabledInUi === true) {
    nextSteps.add('If screen share is involved, ask the sharer to stop sharing and start again from the browser share picker.');
  }
  if (diagnostics?.whiteboardEnabled === true) {
    nextSteps.add('If whiteboard is involved, have the teacher close and reopen the whiteboard to resync state.');
  }

  const severeCategories = new Set(['audio', 'video', 'screen_share', 'room', 'connection']);
  const severity = audioSummary.severity === 'high' || severeCategories.has(issueCategory)
    ? 'high'
    : audioSummary.severity;

  return {
    suspectedCauses: [...suspectedCauses],
    severity,
    nextSteps: [...nextSteps],
  };
}

function buildNoShowReportData(data, authUid, shiftMeta) {
  const shiftDetails = normalizeShiftDetails(shiftMeta.data);
  const reportedBy = cleanString(data.reportedBy) || authUid;
  const reporterRole = cleanString(data.reporterRole);
  const diagnostics = trimDiagnostics(data.diagnostics);

  return {
    reportType: 'no_show',
    shiftId: data.shiftId,
    shiftName: cleanString(data.shiftName) ||
      shiftDetails.shiftName ||
      'Unknown Class',
    roomName: cleanString(data.roomName),
    reportedBy,
    reporterName: cleanString(data.reporterName, 'Unknown User'),
    reporterRole,
    isTeacherNoShow: data.isTeacherNoShow === true,
    timestamp: parseClientTimestamp(data.timestamp),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
    appSessionId: cleanString(data.appSessionId) ||
      cleanString(diagnostics?.appSessionId),
    shiftCollection: shiftMeta.collection,
    teacherId: shiftDetails.teacherId,
    teacherName: shiftDetails.teacherName,
    studentIds: shiftDetails.studentIds,
    studentNames: shiftDetails.studentNames,
    diagnostics,
    hasDiagnostics: diagnostics != null,
  };
}

function buildClassTechnicalIssueReportData(data, authUid, shiftMeta) {
  const shiftDetails = normalizeShiftDetails(shiftMeta.data);
  const diagnostics = trimDiagnostics(data.diagnostics);
  const issueTypes = asArray(data.issueTypes)
    .map((value) => cleanString(value))
    .filter(Boolean);
  const issueType = cleanString(data.issueType) ||
    issueTypes[0] ||
    'technical_issue';
  if (!issueTypes.includes(issueType)) {
    issueTypes.unshift(issueType);
  }
  const issueCategory = getIssueCategory(issueType);
  const issueCategories = [...new Set(issueTypes.map(getIssueCategory))];
  const diagnosticSummary = buildClassDiagnosticSummary(
    diagnostics,
    issueCategories.includes('audio') ? 'audio' : issueCategory
  );

  return {
    reportType: 'technical_issue',
    issueCategory,
    issueCategories,
    issueType,
    issueTypes,
    note: cleanString(data.note),
    shiftId: data.shiftId,
    shiftName: cleanString(data.shiftName) ||
      shiftDetails.shiftName ||
      'Unknown Class',
    roomName: cleanString(data.roomName),
    reportedBy: cleanString(data.reportedBy) || authUid,
    reporterName: cleanString(data.reporterName, 'Unknown User'),
    reporterRole: cleanString(data.reporterRole),
    timestamp: parseClientTimestamp(data.timestamp),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
    appSessionId: cleanString(data.appSessionId) ||
      cleanString(diagnostics?.appSessionId),
    shiftCollection: shiftMeta.collection,
    teacherId: shiftDetails.teacherId,
    teacherName: shiftDetails.teacherName,
    studentIds: shiftDetails.studentIds,
    studentNames: shiftDetails.studentNames,
    diagnostics,
    hasDiagnostics: diagnostics != null,
    audioDiagnosticSummary: buildAudioDiagnosticSummary(diagnostics),
    diagnosticSummary,
    suspectedCauses: diagnosticSummary.suspectedCauses,
    diagnosticSeverity: diagnosticSummary.severity,
    recommendedNextSteps: diagnosticSummary.nextSteps,
  };
}

/**
 * Report a no-show (teacher or student didn't arrive for class)
 * Called from the mobile app when detecting no-show
 */
const reportNoShow = onCall(async (request) => {
  const data = request.data || {};
  
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  
  const {
    shiftId,
    isTeacherNoShow,
  } = data;
  
  if (!shiftId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Shift ID is required'
    );
  }
  
  try {
    const shiftMeta = await getShiftDetails(shiftId);

    const {emails: adminEmails, tokens: adminTokens} =
      await resolveNoShowRecipients();

    const reportData = buildNoShowReportData(
      data,
      request.auth.uid,
      shiftMeta
    );
    
    await admin.firestore()
      .collection('no_show_reports')
      .add(reportData);
    
    console.log(`[NO-SHOW] Report created for shift ${shiftId}, isTeacherNoShow: ${isTeacherNoShow}`);
    
    // Send email notifications to admins
    if (adminEmails.length > 0) {
      await sendNoShowEmail(adminEmails, reportData, isTeacherNoShow);
    }
    
    // Send push notifications to admins
    if (adminTokens.length > 0) {
      await sendNoShowPushNotification(adminTokens, reportData, isTeacherNoShow);
    }
    
    return {
      success: true,
      message: 'No-show report submitted successfully',
    };
  } catch (error) {
    console.error('[NO-SHOW] Error creating report:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to submit no-show report'
    );
  }
});

const reportClassTechnicalIssue = onCall(async (request) => {
  const data = request.data || {};

  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  if (!data.shiftId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Shift ID is required'
    );
  }

  try {
    const shiftMeta = await getShiftDetails(data.shiftId);
    const reportData = buildClassTechnicalIssueReportData(
      data,
      request.auth.uid,
      shiftMeta
    );

    const reportRef = await admin.firestore()
      .collection('class_issue_reports')
      .add(reportData);

    await admin.firestore()
      .collection('livekit_class_issue_reports')
      .doc(reportRef.id)
      .set(reportData);

    if (reportData.issueCategories.includes('audio')) {
      await admin.firestore()
        .collection('livekit_audio_reports')
        .doc(reportRef.id)
        .set(reportData);
    }

    for (const category of reportData.issueCategories) {
      if (category === 'audio') continue;
      await admin.firestore()
        .collection(`livekit_${category}_reports`)
        .doc(reportRef.id)
        .set(reportData);
    }

    console.log(
      `[CLASS-ISSUE] Report created for shift ${data.shiftId}, ` +
      `issueType: ${reportData.issueType}, id: ${reportRef.id}`
    );

    return {
      success: true,
      reportId: reportRef.id,
      message: 'Class issue report submitted successfully',
    };
  } catch (error) {
    console.error('[CLASS-ISSUE] Error creating report:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to submit class issue report'
    );
  }
});

/**
 * Resolve which admins should receive no-show notifications.
 * Reads settings/admin: no_show_notify_all_admins (default true) and
 * no_show_recipient_admin_ids. Falls back to all admins when unset.
 */
async function resolveNoShowRecipients() {
  const db = admin.firestore();
  let notifyAll = true;
  let recipientIds = [];
  try {
    const settingsDoc = await db.collection('settings').doc('admin').get();
    if (settingsDoc.exists) {
      const settings = settingsDoc.data() || {};
      if (settings.no_show_notify_all_admins === false) notifyAll = false;
      if (Array.isArray(settings.no_show_recipient_admin_ids)) {
        recipientIds = settings.no_show_recipient_admin_ids.filter(Boolean);
      }
    }
  } catch (error) {
    console.warn('[NO-SHOW] Failed to read notification settings, notifying all admins:', error);
  }

  const usersById = new Map();
  if (!notifyAll && recipientIds.length > 0) {
    const snaps = await Promise.all(
      recipientIds.map((id) => db.collection('users').doc(id).get())
    );
    snaps.forEach((snap) => {
      if (snap.exists) usersById.set(snap.id, snap.data());
    });
  } else {
    const [primaryAdmins, secondaryAdmins, adminTeachers] = await Promise.all([
      db.collection('users').where('user_type', '==', 'admin').get(),
      db.collection('users').where('secondary_roles', 'array-contains', 'admin').get(),
      db.collection('users').where('is_admin_teacher', '==', true).get(),
    ]);
    [primaryAdmins, secondaryAdmins, adminTeachers].forEach((snap) => {
      snap.docs.forEach((doc) => usersById.set(doc.id, doc.data()));
    });
  }

  const emails = [];
  const tokens = [];
  usersById.forEach((userData) => {
    if (userData.is_active === false) return;
    const email = userData['e-mail'] || userData.email;
    if (email) emails.push(email);
    if (Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens.forEach((entry) => {
        const token = typeof entry === 'string' ? entry : entry && entry.token;
        if (token) tokens.push(token);
      });
    }
    if (userData.fcmToken) tokens.push(userData.fcmToken);
  });

  console.log(
    `[NO-SHOW] Notifying ${usersById.size} admins ` +
    `(notifyAll=${notifyAll}, emails=${emails.length}, tokens=${tokens.length})`
  );
  return {emails, tokens};
}

/**
 * Send email notification to admins about no-show
 */
async function sendNoShowEmail(adminEmails, reportData, isTeacherNoShow) {
  const transporter = createTransporter();
  
  const subject = isTeacherNoShow
    ? `⚠️ Teacher No-Show Alert: ${reportData.shiftName}`
    : `⚠️ Student No-Show Alert: ${reportData.shiftName}`;
  
  const reportType = isTeacherNoShow ? 'Teacher' : 'Student';
  const reportedByType = isTeacherNoShow ? 'student' : 'teacher';
  
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>No-Show Alert - Alluwal Education Hub</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">⚠️ No-Show Alert</h1>
        <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">${reportType} Did Not Arrive</p>
      </div>
      
      <div style="background: #ffffff; padding: 40px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <h2 style="color: #2D3748; margin: 0 0 20px 0; font-size: 24px;">Class Attendance Issue</h2>
        
        <p style="margin: 0 0 20px 0; font-size: 16px; color: #4A5568;">
          A ${reportType.toLowerCase()} no-show has been reported for a scheduled class. Please review the details below and take appropriate action.
        </p>
        
        <div style="background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 20px; border-radius: 0 8px 8px 0; margin: 20px 0;">
          <h3 style="color: #92400E; margin: 0 0 15px 0; font-size: 18px;">📋 Report Details</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Class Name:</td>
              <td style="padding: 8px 0; color: #1C1917; font-weight: 600;">${reportData.shiftName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Issue Type:</td>
              <td style="padding: 8px 0; color: #DC2626; font-weight: 600;">${reportType} No-Show</td>
            </tr>
            ${isTeacherNoShow && reportData.teacherName ? `
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Missing Teacher:</td>
              <td style="padding: 8px 0; color: #1C1917;">${reportData.teacherName}</td>
            </tr>
            ` : ''}
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Reported By:</td>
              <td style="padding: 8px 0; color: #1C1917;">${reportData.reporterName} (${reportedByType})</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Report Time:</td>
              <td style="padding: 8px 0; color: #1C1917;">${new Date().toLocaleString()}</td>
            </tr>
          </table>
        </div>
        
        <div style="background: #F7FAFC; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #2D3748; margin: 0 0 10px 0; font-size: 16px;">Recommended Actions:</h3>
          <ul style="margin: 0; padding-left: 20px; color: #4A5568;">
            ${isTeacherNoShow ? `
            <li>Contact the teacher to understand the situation</li>
            <li>Notify affected students about the class status</li>
            <li>Consider rescheduling the class if needed</li>
            ` : `
            <li>Check if students are having technical issues</li>
            <li>Contact parents/guardians if students are minors</li>
            <li>Document the absence for records</li>
            `}
          </ul>
        </div>
        
        <p style="margin: 30px 0 0 0; font-size: 14px; color: #718096;">
          This is an automated notification from Alluwal Education Hub's attendance monitoring system.
        </p>
      </div>
      
      <div style="text-align: center; padding: 20px; color: #718096; font-size: 12px;">
        <p style="margin: 0;">© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
        <p style="margin: 5px 0 0 0;">Quran Education Management System</p>
      </div>
    </body>
    </html>
  `;
  
  try {
    await transporter.sendMail({
      from: 'support@alluwaleducationhub.org',
      to: adminEmails.join(', '),
      subject,
      html: htmlContent,
    });
    console.log(`[NO-SHOW] Email sent to ${adminEmails.length} admins`);
  } catch (error) {
    console.error('[NO-SHOW] Failed to send email:', error);
  }
}

/**
 * Send push notification to admins about no-show
 */
async function sendNoShowPushNotification(tokens, reportData, isTeacherNoShow) {
  const title = isTeacherNoShow
    ? '⚠️ Teacher No-Show'
    : '⚠️ Student No-Show';
  
  const body = isTeacherNoShow
    ? `Teacher didn't arrive for ${reportData.shiftName}. Reported by ${reportData.reporterName}.`
    : `No students joined ${reportData.shiftName}. Reported by ${reportData.reporterName}.`;
  
  const message = {
    notification: {
      title,
      body,
    },
    data: {
      type: 'no_show_report',
      shiftId: reportData.shiftId,
      isTeacherNoShow: String(isTeacherNoShow),
    },
    tokens,
  };
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[NO-SHOW] Push notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);
  } catch (error) {
    console.error('[NO-SHOW] Failed to send push notifications:', error);
  }
}

module.exports = {
  reportNoShow,
  reportClassTechnicalIssue,
  __test__: {
    buildNoShowReportData,
    buildClassTechnicalIssueReportData,
    buildAudioDiagnosticSummary,
    buildClassDiagnosticSummary,
    getIssueCategory,
    normalizeShiftDetails,
    trimDiagnostics,
    resolveNoShowRecipients,
    sendNoShowEmail,
    sendNoShowPushNotification,
  },
};
