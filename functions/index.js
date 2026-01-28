const functions = require('firebase-functions');
const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const emailHandlers = require('./handlers/emails');
const userHandlers = require('./handlers/users');
const studentHandlers = require('./handlers/students');
const taskHandlers = require('./handlers/tasks');
const shiftHandlers = require('./handlers/shifts');
const shiftTemplateHandlers = require('./handlers/shift_templates');
const timezoneHandlers = require('./handlers/timezone');
const notificationHandlers = require('./handlers/notifications');
const enrollmentHandlers = require('./handlers/enrollments');
const jobHandlers = require('./handlers/jobs');
const formHandlers = require('./handlers/forms');
// Zoom handlers removed - all video calls now use LiveKit
const livekitHandlers = require('./handlers/livekit');
const testLivekitHandlers = require('./handlers/test_livekit');
const migrationLivekitHandlers = require('./handlers/migration_livekit');
const passwordHandlers = require('./handlers/password');
const paymentHandlers = require('./handlers/payments');
const noShowHandlers = require('./handlers/no_show');
const chatHandlers = require('./handlers/chat');
const directCallHandlers = require('./handlers/direct_calls');
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
exports.scheduleUpcomingShiftLifecycleTasks =
  shiftHandlers.scheduleUpcomingShiftLifecycleTasks;
exports.teacherRescheduleShift = shiftHandlers.teacherRescheduleShift;
exports.handleShiftNotificationTask = shiftHandlers.handleShiftNotificationTask;

// Dev-only template-based shift generation (rolling window)
exports.generateDailyShifts = shiftTemplateHandlers.generateDailyShifts;
exports.createShiftTemplate = shiftTemplateHandlers.createShiftTemplate;
exports.generateShiftsForTemplate = shiftTemplateHandlers.generateShiftsForTemplateCallable;
exports.updateShiftTemplate = shiftTemplateHandlers.updateShiftTemplate;
exports.excludeShiftTemplateDate = shiftTemplateHandlers.excludeShiftTemplateDate;
exports.onTeacherDeleted = shiftTemplateHandlers.onTeacherDeleted;
// Zoom functions removed - all video calls now use LiveKit
exports.fixActiveShiftsStatus = shiftHandlers.fixActiveShiftsStatus;
exports.fixTimesheetsPayAndStatus = shiftHandlers.fixTimesheetsPayAndStatus;

// Parent billing (invoices & payments)
exports.createInvoice = onCall(paymentHandlers.createInvoice);
exports.getParentInvoices = onCall(paymentHandlers.getParentInvoices);
exports.createPaymentSession = onCall(paymentHandlers.createPaymentSession);
exports.getPaymentHistory = onCall(paymentHandlers.getPaymentHistory);
exports.handlePayoneerWebhook = functions.https.onRequest(paymentHandlers.handlePayoneerWebhook);
exports.generateInvoicesForPeriod = paymentHandlers.generateInvoicesForPeriod;

// Zoom host management removed - all video calls now use LiveKit

// Form management functions
exports.checkIncompleteReadinessForms = formHandlers.checkIncompleteReadinessForms;

// Timezone management functions
exports.updateUserTimezone = timezoneHandlers.updateUserTimezone;
exports.updateNotificationPreferences = timezoneHandlers.updateNotificationPreferences;
exports.getUserTimezone = timezoneHandlers.getUserTimezone;

// No-show reporting
exports.reportNoShow = noShowHandlers.reportNoShow;

// Chat notifications and permissions
exports.onChatMessageCreated = chatHandlers.onChatMessageCreated;
exports.updateChatNotificationPreference = chatHandlers.updateChatNotificationPreference;
exports.onShiftStatusChangeChat = chatHandlers.onShiftStatusChange;
exports.onShiftCreatedChat = chatHandlers.onShiftCreated;

// Direct calls (audio/video calls from chat)
exports.createDirectCall = directCallHandlers.createDirectCall;
exports.joinDirectCall = directCallHandlers.joinDirectCall;
exports.endDirectCall = directCallHandlers.endDirectCall;

// Enrollment management functions
exports.onEnrollmentCreated = enrollmentHandlers.onEnrollmentCreated;
// Callable version - note: may have IAM issues on some projects
exports.publishEnrollmentToJobBoard = onCall({ cors: true }, enrollmentHandlers.publishEnrollmentToJobBoard);
exports.acceptJob = onCall({ cors: true }, jobHandlers.acceptJob);
exports.withdrawFromJob = onCall({ cors: true }, jobHandlers.withdrawFromJob);

// Application management functions (Leader & Teacher)
const applicationHandlers = require('./handlers/applications');
exports.onLeadershipApplicationCreated = applicationHandlers.onLeadershipApplicationCreated;
exports.onTeacherApplicationCreated = applicationHandlers.onTeacherApplicationCreated;

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

// Zoom host allocation and hub meeting tests removed - all video calls now use LiveKit

// Programmed Clock-in Executor (HTTP callable for cron jobs)
const clockinSchedulerHandlers = require('./handlers/clockin_scheduler');
exports.executeProgrammedClockIns = functions.https.onCall(clockinSchedulerHandlers.executeProgrammedClockIns);

// Debug function to check kiosque codes (HTTP version for easy testing)
const checkKiosqueCodesHttp = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const admin = require('firebase-admin');
  const db = admin.firestore();

  console.log('🔍 Checking kiosque codes in users collection (HTTP)...');

  try {
    // Get all users with kiosque_code
    const kiosqueSnapshot = await db.collection('users')
      .where('kiosque_code', '!=', null)
      .get();

    const results = {
      kiosqueCodes: [],
      parents: [],
      specificCodeSearch: null,
      allFieldsSearch: []
    };

    // Collect kiosque codes
    kiosqueSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      results.kiosqueCodes.push({
        id: doc.id,
        name: `${data.first_name || 'N/A'} ${data.last_name || 'N/A'}`,
        type: data.user_type || 'N/A',
        kiosqueCode: data.kiosque_code
      });
    });

    // Get all parents
    const parentsSnapshot = await db.collection('users')
      .where('user_type', '==', 'parent')
      .get();

    parentsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      results.parents.push({
        id: doc.id,
        name: `${data.first_name || 'N/A'} ${data.last_name || 'N/A'}`,
        kiosqueCode: data.kiosque_code || null,
        hasKiosqueCode: !!data.kiosque_code
      });
    });

    // Check for specific code
    const specificCodeSnapshot = await db.collection('users')
      .where('kiosque_code', '==', 'YKPR49182773')
      .get();

    if (!specificCodeSnapshot.empty) {
      const doc = specificCodeSnapshot.docs[0];
      const data = doc.data();
      results.specificCodeSearch = {
        found: true,
        user: {
          id: doc.id,
          name: `${data.first_name} ${data.last_name}`,
          email: data['e-mail'],
          type: data.user_type,
          kiosqueCode: data.kiosque_code
        }
      };
    } else {
      results.specificCodeSearch = { found: false };

      // Search in all fields
      const allUsersSnapshot = await db.collection('users').get();
      allUsersSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        for (const [key, value] of Object.entries(data)) {
          if (value === 'YKPR49182773') {
            results.allFieldsSearch.push({
              userId: doc.id,
              userName: `${data.first_name || 'N/A'} ${data.last_name || 'N/A'}`,
              field: key,
              value: value
            });
          }
        }
      });
    }

    res.status(200).json(results);
  } catch (error) {
    console.error('❌ Error checking kiosque codes:', error);
    res.status(500).json({ error: error.message });
  }
});

exports.checkKiosqueCodesHttp = checkKiosqueCodesHttp;

// Zoom Hub/Breakout test functions removed - all video calls now use LiveKit

// Kiosque code migration function
const migrateKiosqueCodesHandlers = require('./handlers/migrate_kiosque_codes');
exports.migrateKiosqueCodes = functions.https.onCall(migrateKiosqueCodesHandlers.migrateKiosqueCodes);

// Zoom check, breakout, and hybrid test functions removed - all video calls now use LiveKit

// LiveKit Video Functions
exports.getLiveKitJoinToken = livekitHandlers.getLiveKitJoinToken;
exports.checkLiveKitAvailability = livekitHandlers.checkLiveKitAvailability;
exports.getLiveKitRoomPresence = livekitHandlers.getLiveKitRoomPresence;
exports.muteLiveKitParticipant = livekitHandlers.muteLiveKitParticipant;
exports.muteAllLiveKitParticipants = livekitHandlers.muteAllLiveKitParticipants;
exports.kickLiveKitParticipant = livekitHandlers.kickLiveKitParticipant;
exports.setLiveKitRoomLock = livekitHandlers.setLiveKitRoomLock;
exports.getLiveKitGuestJoin = livekitHandlers.getLiveKitGuestJoin;

// LiveKit Test Function (for development/testing)
exports.testLiveKit = testLivekitHandlers.testLiveKit;

// LiveKit Migration Functions (one-time use)
exports.migrateShiftsToLiveKit = migrationLivekitHandlers.migrateShiftsToLiveKit;
exports.revertLiveKitMigration = migrationLivekitHandlers.revertLiveKitMigration;

// Password Management Functions
exports.resetStudentPassword = passwordHandlers.resetStudentPassword;
exports.syncAllStudentPasswords = passwordHandlers.syncAllStudentPasswords;
