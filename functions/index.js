const functions = require('firebase-functions');
const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const emailHandlers = require('./handlers/emails');
const userHandlers = require('./handlers/users');
const studentHandlers = require('./handlers/students');
const taskHandlers = require('./handlers/tasks');
const shiftHandlers = require('./handlers/shifts');
const timezoneHandlers = require('./handlers/timezone');
const notificationHandlers = require('./handlers/notifications');
const enrollmentHandlers = require('./handlers/enrollments');
const jobHandlers = require('./handlers/jobs');
const formHandlers = require('./handlers/forms');
const zoomHandlers = require('./handlers/zoom');
const testZoomHandlers = require('./handlers/test_zoom_shift');
const zoomHostHandlers = require('./handlers/zoom_hosts');
const testHostAllocationHandlers = require('./handlers/test_host_allocation');
const testOverlappingShiftsHandlers = require('./handlers/test_overlapping_shifts');
// Temporarily commented out to allow deployment
// const { fixDecemberForms } = require('./fix_december_forms');
const newImplementation = require('./new_implementation');

admin.initializeApp();

exports.sendTaskAssignmentNotification = functions.https.onCall(
  taskHandlers.sendTaskAssignmentNotification
);
exports.sendWelcomeEmail = functions.https.onCall(emailHandlers.sendWelcomeEmail);
exports.createUserWithEmail = functions.https.onCall(userHandlers.createUserWithEmail);
exports.createMultipleUsers = functions.https.onCall(userHandlers.createMultipleUsers);
exports.createUser = functions.https.onCall(userHandlers.createUser);
exports.deleteUserAccount = functions.https.onCall(userHandlers.deleteUserAccount);
exports.findUserByEmailOrCode = functions.https.onCall(userHandlers.findUserByEmailOrCode);
exports.createStudentAccount = functions.https.onCall(studentHandlers.createStudentAccount);
exports.sendCustomPasswordResetEmail = functions.https.onCall(
  emailHandlers.sendCustomPasswordResetEmail
);
exports.sendTestEmail = functions.https.onCall(emailHandlers.sendTestEmail);
exports.sendAdminNotification = functions.https.onCall(notificationHandlers.sendAdminNotification);

exports.sendTaskStatusUpdateNotification = onCall(taskHandlers.sendTaskStatusUpdateNotification);
exports.sendTaskCommentNotification = onCall(taskHandlers.sendTaskCommentNotification);
exports.sendTaskDeletionNotification = onCall(taskHandlers.sendTaskDeletionNotification);
exports.sendTaskEditNotification = onCall(taskHandlers.sendTaskEditNotification);
exports.sendRecurringTaskReminders = taskHandlers.sendRecurringTaskReminders;

exports.processTaskCommentEmail = taskHandlers.processTaskCommentEmail;

exports.scheduleShiftLifecycle = shiftHandlers.scheduleShiftLifecycle;
exports.handleShiftStartTask = shiftHandlers.handleShiftStartTask;
exports.handleShiftEndTask = shiftHandlers.handleShiftEndTask;
exports.onShiftCreated = shiftHandlers.onShiftCreated;
exports.onShiftUpdated = shiftHandlers.onShiftUpdated;
exports.onShiftCancelled = shiftHandlers.onShiftCancelled;
exports.onShiftDeleted = shiftHandlers.onShiftDeleted;
exports.sendScheduledShiftReminders = shiftHandlers.sendScheduledShiftReminders;
exports.joinZoomMeeting = zoomHandlers.joinZoomMeeting;
exports.getZoomJoinUrl = zoomHandlers.getZoomJoinUrl;
exports.getZoomMeetingSdkJoinPayload = zoomHandlers.getZoomMeetingSdkJoinPayload;
exports.testZoomForShift = testZoomHandlers.testZoomForShift;
exports.testZoomForShiftHttp = testZoomHandlers.testZoomForShiftHttp;
exports.fixActiveShiftsStatus = shiftHandlers.fixActiveShiftsStatus;
exports.fixTimesheetsPayAndStatus = shiftHandlers.fixTimesheetsPayAndStatus;

// Zoom host management functions (multi-host meeting distribution)
exports.listZoomHosts = zoomHostHandlers.listZoomHosts;
exports.addZoomHost = zoomHostHandlers.addZoomHost;
exports.updateZoomHost = zoomHostHandlers.updateZoomHost;
exports.removeZoomHost = zoomHostHandlers.removeZoomHost;
exports.revalidateZoomHost = zoomHostHandlers.revalidateZoomHost;
exports.checkHostAvailability = zoomHostHandlers.checkHostAvailability;


// Form management functions
exports.checkIncompleteReadinessForms = formHandlers.checkIncompleteReadinessForms;

// Timezone management functions
exports.updateUserTimezone = timezoneHandlers.updateUserTimezone;
exports.getUserTimezone = timezoneHandlers.getUserTimezone;

// Enrollment management functions
exports.onEnrollmentCreated = enrollmentHandlers.onEnrollmentCreated;
// Callable version - note: may have IAM issues on some projects
exports.publishEnrollmentToJobBoard = onCall({ cors: true }, enrollmentHandlers.publishEnrollmentToJobBoard);
exports.acceptJob = onCall({ cors: true }, jobHandlers.acceptJob);


exports.getLandingPageContent = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const snapshot = await admin.firestore().collection('landing_page_content').doc('main').get();

    if (!snapshot.exists) {
      res.status(404).json({ error: 'Landing page content not found' });
      return;
    }

    res.set('Cache-Control', 'public, max-age=300, s-maxage=300');
    res.status(200).json(snapshot.data());
  } catch (err) {
    console.error('getLandingPageContent error:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// One-time data fix function: Link December 2025 forms to timesheets
// Temporarily commented out to allow deployment
// exports.fixDecemberForms = functions.https.onRequest(fixDecemberForms);

// New shift management functions (recurrence generation and notifications)
exports.onShiftCreateNew = newImplementation.onShiftCreateNew;
exports.onShiftUpdateNew = newImplementation.onShiftUpdateNew;

// Timesheet export function
exports.exportTimesheet = newImplementation.exportTimesheet;

// Test function for host allocation (HTTP callable)
exports.testHostAllocation = testHostAllocationHandlers.testHostAllocation;
exports.testCreateOverlappingShifts = testOverlappingShiftsHandlers.testCreateOverlappingShifts;
exports.debugShifts = testHostAllocationHandlers.debugShifts;

// Host config check (HTTP callable)
const getHostConfigHandlers = require('./handlers/get_host_config');
exports.getHostConfig = getHostConfigHandlers.getHostConfig;

// Hub Meeting Scheduler (HTTP callable for testing/cron)
const { scheduleHubMeetings } = require('./services/shifts/schedule_hubs');
exports.scheduleHubMeetings = functions.https.onCall(async () => {
  return await scheduleHubMeetings();
});

// Hub Meeting Test/Manual Triggers
const testHubCreationHandlers = require('./handlers/test_hub_creation');
exports.createHubForShift = testHubCreationHandlers.createHubForShift;
exports.listShiftHubStatus = testHubCreationHandlers.listShiftHubStatus;
exports.runHubScheduler = testHubCreationHandlers.runHubScheduler;

// Professional Test Suite for Hub Architecture
const { testHubArchitecture } = require('./handlers/test_hub_architecture');
exports.testHubArchitecture = testHubArchitecture;

const testBreakoutHandlers = require('./handlers/test_breakout');
exports.testBreakoutCreation = testBreakoutHandlers.testBreakoutCreation;
exports.listUsers = testBreakoutHandlers.listUsers;

// Zoom Check Test
const testZoomCheckHandlers = require('./handlers/test_zoom_check');
exports.checkZoomMeeting = testZoomCheckHandlers.checkZoomMeeting;

// Breakout Room Opener (Cloud Task handler + helper functions)
const breakoutOpenerHandlers = require('./handlers/breakout_opener');
exports.openBreakoutRooms = breakoutOpenerHandlers.openBreakoutRooms;
exports.markBreakoutRoomsOpened = breakoutOpenerHandlers.markBreakoutRoomsOpened;
exports.getZoomHostKey = breakoutOpenerHandlers.getZoomHostKey;

// Hybrid Zoom Test Functions
const testHybridZoomHandlers = require('./handlers/test_hybrid_zoom');
exports.testHybridZoomFlow = testHybridZoomHandlers.testHybridZoomFlow;
exports.verifyHostKeyConfig = testHybridZoomHandlers.verifyHostKeyConfig;
exports.getShiftForTesting = testHybridZoomHandlers.getShiftForTesting;
exports.clearAllZoomMeetings = testHybridZoomHandlers.clearAllZoomMeetings;
exports.createTestClassForTeacher = testHybridZoomHandlers.createTestClassForTeacher;
