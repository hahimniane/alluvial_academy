/**
 * Temporary test function to check Zoom integration for a specific shift
 * This will be deployed and can be called from the app or Firebase Console
 */

const admin = require('firebase-admin');
const {onCall, onRequest} = require('firebase-functions/v2/https');
const {ensureZoomMeetingAndEmailTeacher} = require('../services/zoom/shift_zoom');
const {findAvailableHost} = require('../services/zoom/hosts');

const testZoomForShift = onCall(async (request) => {
  const {shiftId} = request.data || {};
  
  if (!shiftId) {
    throw new Error('shiftId is required');
  }

  if (!request.auth) {
    throw new Error('Authentication required');
  }

  console.log(`[TestZoom] Testing Zoom integration for shift: ${shiftId}`);

  try {
    const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
    
    if (!shiftDoc.exists) {
      return {
        success: false,
        error: 'Shift not found',
        shiftId,
      };
    }

    const shiftData = shiftDoc.data();
    
    // Log all relevant shift data
    const diagnostic = {
      shiftId,
      status: shiftData.status,
      category: shiftData.shift_category || 'teaching',
      teacherId: shiftData.teacher_id,
      hasExistingMeeting: Boolean(shiftData.zoom_meeting_id && shiftData.zoom_encrypted_join_url),
      inviteSent: Boolean(shiftData.zoom_invite_sent_at),
      previousError: shiftData.zoom_error || null,
    };

    // Check teacher
    if (shiftData.teacher_id) {
      const teacherDoc = await admin.firestore().collection('users').doc(shiftData.teacher_id).get();
      if (teacherDoc.exists) {
        const teacherData = teacherDoc.data();
        diagnostic.teacherEmail = teacherData?.['e-mail'] || teacherData?.email || teacherData?.Email || teacherData?.mail || null;
        diagnostic.teacherName = [teacherData?.first_name, teacherData?.last_name].filter(Boolean).join(' ') || 'Unknown';
      } else {
        diagnostic.teacherEmail = null;
        diagnostic.teacherNotFound = true;
      }
    }

    console.log('[TestZoom] Diagnostic:', JSON.stringify(diagnostic, null, 2));

    // Find an available host
    const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
    const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
    const {host: selectedHost, error: hostError} = await findAvailableHost(shiftStart, shiftEnd, shiftId);

    console.log('[TestZoom] Selected host:', selectedHost?.email || 'none', hostError ? `Error: ${hostError.message}` : '');
    diagnostic.selectedHost = selectedHost?.email || null;
    diagnostic.hostError = hostError?.message || null;

    // Try to create Zoom meeting
    const result = await ensureZoomMeetingAndEmailTeacher({shiftId, shiftData, selectedHost});

    // Re-fetch to see updates
    const updatedDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
    const updatedData = updatedDoc.data();

    return {
      success: true,
      diagnostic,
      result,
      updated: {
        zoomMeetingId: updatedData.zoom_meeting_id || null,
        hasEncryptedUrl: Boolean(updatedData.zoom_encrypted_join_url),
        meetingCreatedAt: updatedData.zoom_meeting_created_at?.toDate?.()?.toISOString() || null,
        inviteSentAt: updatedData.zoom_invite_sent_at?.toDate?.()?.toISOString() || null,
        error: updatedData.zoom_error || null,
      },
    };
  } catch (error) {
    console.error('[TestZoom] Error:', error);
    return {
      success: false,
      error: error.message,
      stack: error.stack,
      shiftId,
    };
  }
});

// HTTP version for easy testing (no auth required)
const testZoomForShiftHttp = onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const shiftId = req.query.shiftId || req.body?.shiftId || 'smEKLyl0MUqC8xRMHHdO';

  console.log(`[TestZoom] Testing Zoom integration for shift: ${shiftId}`);

  try {
    const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
    
    if (!shiftDoc.exists) {
      res.status(404).json({
        success: false,
        error: 'Shift not found',
        shiftId,
      });
      return;
    }

    const shiftData = shiftDoc.data();
    
    // Log all relevant shift data
    const diagnostic = {
      shiftId,
      status: shiftData.status,
      category: shiftData.shift_category || 'teaching',
      teacherId: shiftData.teacher_id,
      hasExistingMeeting: Boolean(shiftData.zoom_meeting_id && shiftData.zoom_encrypted_join_url),
      inviteSent: Boolean(shiftData.zoom_invite_sent_at),
      previousError: shiftData.zoom_error || null,
    };

    // Check teacher
    if (shiftData.teacher_id) {
      const teacherDoc = await admin.firestore().collection('users').doc(shiftData.teacher_id).get();
      if (teacherDoc.exists) {
        const teacherData = teacherDoc.data();
        diagnostic.teacherEmail = teacherData?.['e-mail'] || teacherData?.email || teacherData?.Email || teacherData?.mail || null;
        diagnostic.teacherName = [teacherData?.first_name, teacherData?.last_name].filter(Boolean).join(' ') || 'Unknown';
      } else {
        diagnostic.teacherEmail = null;
        diagnostic.teacherNotFound = true;
      }
    }

    console.log('[TestZoom] Diagnostic:', JSON.stringify(diagnostic, null, 2));

    // Find an available host
    const shiftStart = shiftData.shift_start?.toDate ? shiftData.shift_start.toDate() : new Date(shiftData.shift_start);
    const shiftEnd = shiftData.shift_end?.toDate ? shiftData.shift_end.toDate() : new Date(shiftData.shift_end);
    const {host: selectedHost, error: hostError} = await findAvailableHost(shiftStart, shiftEnd, shiftId);

    console.log('[TestZoom] Selected host:', selectedHost?.email || 'none', hostError ? `Error: ${hostError.message}` : '');
    diagnostic.selectedHost = selectedHost?.email || null;
    diagnostic.hostError = hostError?.message || null;

    // Try to create Zoom meeting
    const result = await ensureZoomMeetingAndEmailTeacher({shiftId, shiftData, selectedHost});

    // Re-fetch to see updates
    const updatedDoc = await admin.firestore().collection('teaching_shifts').doc(shiftId).get();
    const updatedData = updatedDoc.data();

    res.json({
      success: true,
      diagnostic,
      result,
      updated: {
        zoomMeetingId: updatedData.zoom_meeting_id || null,
        hasEncryptedUrl: Boolean(updatedData.zoom_encrypted_join_url),
        meetingCreatedAt: updatedData.zoom_meeting_created_at?.toDate?.()?.toISOString() || null,
        inviteSentAt: updatedData.zoom_invite_sent_at?.toDate?.()?.toISOString() || null,
        error: updatedData.zoom_error || null,
      },
    });
  } catch (error) {
    console.error('[TestZoom] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack,
      shiftId,
    });
  }
});

module.exports = {
  testZoomForShift,
  testZoomForShiftHttp,
};

