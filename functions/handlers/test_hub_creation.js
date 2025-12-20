/**
 * Test Handler: Create Hub Meeting with Breakout Room for a Shift
 *
 * This endpoint allows testing the hub meeting creation flow.
 * Call via: curl https://us-central1-alluwal-academy.cloudfunctions.net/createHubForShift?shiftId=xxx
 */

const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { DateTime } = require('luxon');
const { scheduleHubMeetings, validateParticipantEmail, processShiftParticipants } = require('../services/shifts/schedule_hubs');

const db = admin.firestore();

/**
 * HTTP endpoint to manually trigger hub creation for a specific shift
 */
exports.createHubForShift = onRequest(async (req, res) => {
  const shiftId = req.query.shiftId;

  if (!shiftId) {
    return res.status(400).json({
      success: false,
      error: 'Missing shiftId parameter. Usage: ?shiftId=xxx'
    });
  }

  console.log(`[TestHub] Processing shift: ${shiftId}`);

  try {
    // Get the shift
    const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
    if (!shiftDoc.exists) {
      return res.status(404).json({
        success: false,
        error: `Shift ${shiftId} not found`
      });
    }

    const shiftData = shiftDoc.data();

    // OPTIONAL: Update shift time to be "soon" (next 1 hour) to ensure scheduler picks it up
    if (req.query.setTime === 'true') {
      const now = DateTime.utc();
      // Round up to next hour for cleaner blocks
      const nextHour = now.plus({ hours: 1 }).startOf('hour');

      await db.collection('teaching_shifts').doc(shiftId).update({
        shift_start: admin.firestore.Timestamp.fromDate(nextHour.toJSDate()),
        shift_end: admin.firestore.Timestamp.fromDate(nextHour.plus({ hours: 2 }).toJSDate()),
        status: 'scheduled',
        hubMeetingId: admin.firestore.FieldValue.delete(), // Clear existing hub
        breakoutRoomName: admin.firestore.FieldValue.delete()
      });
      console.log(`[TestHub] Updated shift ${shiftId} to start at ${nextHour.toISO()}`);

      // Refresh data
      const refreshed = await db.collection('teaching_shifts').doc(shiftId).get();
      Object.assign(shiftData, refreshed.data());
    }

    // Check if already has hub meeting
    if (shiftData.hubMeetingId) {
      return res.json({
        success: true,
        message: 'Shift already has a hub meeting',
        hubMeetingId: shiftData.hubMeetingId,
        breakoutRoomName: shiftData.breakoutRoomName,
      });
    }

    // Process participant validation
    const participants = await processShiftParticipants({
      id: shiftId,
      ...shiftData
    }, []);

    console.log('[TestHub] Participant validation:', JSON.stringify(participants, null, 2));

    // Run the hub scheduler (will process all pending shifts)
    console.log('[TestHub] Running hub scheduler...');
    await scheduleHubMeetings();

    // Re-fetch shift to see results
    const updatedDoc = await db.collection('teaching_shifts').doc(shiftId).get();
    const updated = updatedDoc.data();

    const result = {
      success: true,
      shift: {
        id: shiftId,
        teacherName: updated.teacher_name,
        studentNames: updated.student_names,
        status: updated.status,
      },
      hubMeeting: {
        hubMeetingId: updated.hubMeetingId || null,
        breakoutRoomName: updated.breakoutRoomName || null,
        breakoutRoomKey: updated.breakoutRoomKey || null,
        zoomRoutingMode: updated.zoomRoutingMode || null,
      },
      routing: {
        hasRoutingRisk: updated.hasRoutingRisk || false,
        routingRiskParticipants: updated.routingRiskParticipants || [],
        preAssignedParticipants: updated.preAssignedParticipants || [],
      },
      validation: {
        teacherEmail: participants.teacherEmail,
        studentEmails: participants.studentEmails,
        validParticipants: participants.validParticipants?.length || 0,
        routingRiskCount: participants.routingRiskParticipants?.length || 0,
      }
    };

    // If hub was created, get hub details
    if (updated.hubMeetingId) {
      const hubDoc = await db.collection('hub_meetings').doc(updated.hubMeetingId).get();
      if (hubDoc.exists) {
        const hub = hubDoc.data();
        result.hubDetails = {
          zoomMeetingId: hub.meetingId,
          status: hub.status,
          totalParticipants: hub.totalExpectedParticipants,
          shiftsInHub: hub.shifts?.length || 0,
        };
      }
    }

    res.json(result);

  } catch (error) {
    console.error('[TestHub] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack,
    });
  }
});

/**
 * HTTP endpoint to list all shifts and their hub status
 */
exports.listShiftHubStatus = onRequest(async (req, res) => {
  try {
    const shiftsSnapshot = await db.collection('teaching_shifts')
      .orderBy('shift_start', 'desc')
      .limit(20)
      .get();

    const shifts = [];
    shiftsSnapshot.forEach(doc => {
      const d = doc.data();
      shifts.push({
        id: doc.id,
        teacherName: d.teacher_name,
        studentNames: d.student_names,
        status: d.status,
        shiftStart: d.shift_start?.toDate?.().toISOString() || null,
        hasZoomMeeting: !!d.zoom_meeting_id,
        zoomMeetingId: d.zoom_meeting_id || null,
        hasHubMeeting: !!d.hubMeetingId,
        hubMeetingId: d.hubMeetingId || null,
        breakoutRoomName: d.breakoutRoomName || null,
        zoomRoutingMode: d.zoomRoutingMode || null,
      });
    });

    res.json({ success: true, shifts });

  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Manually run the hub scheduler
 */
exports.runHubScheduler = onRequest(async (req, res) => {
  try {
    console.log('[HubScheduler] Manual trigger starting...');
    await scheduleHubMeetings();
    console.log('[HubScheduler] Completed.');

    res.json({ success: true, message: 'Hub scheduler completed' });
  } catch (error) {
    console.error('[HubScheduler] Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
