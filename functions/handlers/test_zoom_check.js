const { onCall } = require('firebase-functions/v2/https');
const { getMeetingDetails } = require('../services/zoom/client');

exports.checkZoomMeeting = onCall(async (request) => {
    const meetingId = request.data.meetingId;
    if (!meetingId) {
        return { success: false, error: 'Missing meetingId' };
    }

    try {
        const details = await getMeetingDetails(meetingId);
        return { success: true, details };
    } catch (e) {
        return { success: false, error: e.message };
    }
});
