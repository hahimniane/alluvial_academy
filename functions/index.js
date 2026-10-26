const functions = require('firebase-functions');
const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const emailHandlers = require('./handlers/emails');
const userHandlers = require('./handlers/users');
const studentHandlers = require('./handlers/students');
const taskHandlers = require('./handlers/tasks');
const shiftHandlers = require('./handlers/shifts');
const shiftTemplateHandlers = require('./handlers/shift_templates');
const shiftArchiveHandlers = require('./handlers/shift_archive');
const timezoneHandlers = require('./handlers/timezone');
const notificationHandlers = require('./handlers/notifications');
const enrollmentHandlers = require('./handlers/enrollments');
const enrollmentRepublishHandlers = require('./handlers/enrollment_republish');
const financeStaffHandlers = require('./handlers/finance_staff');
const rescheduleRequestHandlers = require('./handlers/reschedule_requests');
const shiftRateGuard = require('./handlers/shift_rate_guard');
const aiTutorVoice = require('./handlers/ai_tutor_voice');
const jobHandlers = require('./handlers/jobs');
const formHandlers = require('./handlers/forms');
// Legacy Zoom handlers removed. Classroom video calls now use RealtimeKit;
// LiveKit exports remain for rollback/history and non-class surfaces.
const livekitHandlers = require('./handlers/livekit');
const realtimekitHandlers = require('./handlers/realtimekit');
const zoomHandlers = require('./handlers/zoom');
const zoomHubBotHandlers = require('./handlers/zoom_hub_bot');
const presenceReportHandlers = require('./handlers/presence_reports');
const testLivekitHandlers = require('./handlers/test_livekit');
const migrationLivekitHandlers = require('./handlers/migration_livekit');
const passwordHandlers = require('./handlers/password');
const paymentHandlers = require('./handlers/payments');
const paymentLinkHandlers = require('./handlers/payment_links');
const invoiceAccessHandlers = require('./handlers/invoice_access');
const noShowHandlers = require('./handlers/no_show');
const chatHandlers = require('./handlers/chat');
const directCallHandlers = require('./handlers/direct_calls');
const aiTutorHandlers = require('./handlers/ai_tutor');
const attendanceHandlers = require('./handlers/attendance');
const quranAsrHandlers = require('./handlers/quran_asr');
const quranPhonemeHandlers = require('./handlers/quran_phoneme');
const circleHandlers = require('./handlers/circles');
const githubReportingHandlers = require('./handlers/github_reporting');
const quizGenerationHandlers = require('./handlers/quiz_generation');
const quizCompetitionHandlers = require('./handlers/quiz_competition');
const bayanahHandlers = require('./handlers/bayanah');
const quizReviewHandlers = require('./handlers/quiz_review');
const publicSitePublicReadHandlers = require('./handlers/public_site_public_read');
const adminClaimHandlers = require('./handlers/admin_claims');
const decisionAuditHandlers = require('./handlers/decision_audits');
const classContactHandlers = require('./handlers/class_contacts');
const financeBankHandlers = require('./handlers/finance_bank');
// Temporarily commented out to allow deployment
// const { fixDecemberForms } = require('./fix_december_forms');
const newImplementation = require('./new_implementation');

admin.initializeApp();

exports.sendTaskAssignmentNotification = functions.https.onCall(
  taskHandlers.sendTaskAssignmentNotification
);
exports.sendWelcomeEmail = functions.https.onCall(
  emailHandlers.sendWelcomeEmail
);
exports.createUserWithEmail = functions.https.onCall(
  userHandlers.createUserWithEmail
);
exports.createMultipleUsers = functions.https.onCall(
  userHandlers.createMultipleUsers
);
exports.createUser = functions.https.onCall(userHandlers.createUser);
exports.deleteUserAccount = functions.https.onCall(
  userHandlers.deleteUserAccount
);
// Keeps a device push token owned by exactly one account, so a phone stops
// receiving notifications for accounts that previously signed in on it.
exports.syncFcmTokenOwnership =
  require('./handlers/fcm_token_ownership').syncFcmTokenOwnership;

exports.findUserByEmailOrCode = functions.https.onCall(
  userHandlers.findUserByEmailOrCode
);
exports.adminSearchDirectoryUsers = functions.https.onCall(
  userHandlers.adminSearchDirectoryUsers
);
exports.syncPublicSiteAdminClaim = adminClaimHandlers.syncPublicSiteAdminClaim;
exports.createStudentAccount = functions.https.onCall(
  studentHandlers.createStudentAccount
);
exports.sendCustomPasswordResetEmail = functions.https.onCall(
  emailHandlers.sendCustomPasswordResetEmail
);
exports.sendTestEmail = functions.https.onCall(emailHandlers.sendTestEmail);
exports.sendAdminNotification = functions.https.onCall(
  notificationHandlers.sendAdminNotification
);
exports.sendAuditNotification = functions.https.onCall(
  notificationHandlers.sendAuditNotification
);
exports.sendTeacherAuditDecisionNotification = functions.https.onCall(
  notificationHandlers.sendTeacherAuditDecisionNotification
);

exports.sendTaskStatusUpdateNotification = onCall(
  taskHandlers.sendTaskStatusUpdateNotification
);
exports.updateAssignedTaskStatus = onCall(
  taskHandlers.updateAssignedTaskStatus
);
exports.sendTaskCommentNotification = onCall(
  taskHandlers.sendTaskCommentNotification
);
exports.sendTaskDeletionNotification = onCall(
  taskHandlers.sendTaskDeletionNotification
);
exports.sendTaskEditNotification = onCall(
  taskHandlers.sendTaskEditNotification
);
exports.sendRecurringTaskReminders = taskHandlers.sendRecurringTaskReminders;

exports.processTaskCommentEmail = taskHandlers.processTaskCommentEmail;

exports.scheduleShiftLifecycle = shiftHandlers.scheduleShiftLifecycle;
exports.handleShiftStartTask = shiftHandlers.handleShiftStartTask;
exports.handleShiftEndTask = shiftHandlers.handleShiftEndTask;
exports.onShiftCreated = shiftHandlers.onShiftCreated;
exports.onShiftUpdated = shiftHandlers.onShiftUpdated;
exports.onShiftCancelled = shiftHandlers.onShiftCancelled;
exports.onShiftDeleted = shiftHandlers.onShiftDeleted;
exports.onTimesheetWritten = shiftHandlers.onTimesheetWritten;
exports.onFormResponseWritten = shiftHandlers.onFormResponseWritten;
exports.sendScheduledShiftReminders = shiftHandlers.sendScheduledShiftReminders;
exports.scheduleUpcomingShiftLifecycleTasks =
  shiftHandlers.scheduleUpcomingShiftLifecycleTasks;
exports.teacherRescheduleShift = shiftHandlers.teacherRescheduleShift;
exports.teacherRescheduleFutureShifts =
  shiftHandlers.teacherRescheduleFutureShifts;
exports.handleShiftNotificationTask = shiftHandlers.handleShiftNotificationTask;

// Dev-only template-based shift generation (rolling window)
exports.generateDailyShifts = shiftTemplateHandlers.generateDailyShifts;
exports.archiveOldShifts = shiftArchiveHandlers.archiveOldShifts;
const payIntegrityHandlers = require('./handlers/pay_integrity');
exports.checkPayIntegrity = payIntegrityHandlers.checkPayIntegrity;
exports.createShiftTemplate = shiftTemplateHandlers.createShiftTemplate;
exports.generateShiftsForTemplate =
  shiftTemplateHandlers.generateShiftsForTemplateCallable;
exports.updateShiftTemplate = shiftTemplateHandlers.updateShiftTemplate;
exports.excludeShiftTemplateDate =
  shiftTemplateHandlers.excludeShiftTemplateDate;
exports.onGeneratedShiftDeleted =
  shiftTemplateHandlers.onGeneratedShiftDeleted;
exports.onTeacherDeleted = shiftTemplateHandlers.onTeacherDeleted;
// Zoom functions removed - all video calls now use LiveKit
exports.fixActiveShiftsStatus = shiftHandlers.fixActiveShiftsStatus;
exports.fixTimesheetsPayAndStatus = shiftHandlers.fixTimesheetsPayAndStatus;
exports.fixTimesheetsPayment = shiftHandlers.fixTimesheetsPayment;
// Shift trade: native app claims a published shift through this callable.
exports.claimShift = shiftHandlers.claimShift;

// Parent billing (invoices & payments)
exports.createInvoice = onCall(paymentHandlers.createInvoice);
exports.onInvoiceCreated = paymentHandlers.onInvoiceCreated;
exports.onUserDecisionWritten = decisionAuditHandlers.onUserDecisionWritten;
exports.onShiftDecisionWritten = decisionAuditHandlers.onShiftDecisionWritten;
exports.onInvoiceDecisionWritten =
  decisionAuditHandlers.onInvoiceDecisionWritten;
exports.onPaymentDecisionWritten =
  decisionAuditHandlers.onPaymentDecisionWritten;
exports.onTimesheetDecisionWritten =
  decisionAuditHandlers.onTimesheetDecisionWritten;
exports.onTeacherApplicationDecisionWritten =
  decisionAuditHandlers.onTeacherApplicationDecisionWritten;
exports.onTaskDecisionWritten = decisionAuditHandlers.onTaskDecisionWritten;
exports.onFormResponseDecisionWritten =
  decisionAuditHandlers.onFormResponseDecisionWritten;
exports.onNoShowDecisionWritten =
  decisionAuditHandlers.onNoShowDecisionWritten;
exports.onClassAttendanceAlertDecisionWritten =
  decisionAuditHandlers.onClassAttendanceAlertDecisionWritten;
exports.onEnrollmentDecisionWritten =
  decisionAuditHandlers.onEnrollmentDecisionWritten;
exports.onTeacherAuditDecisionWritten =
  decisionAuditHandlers.onTeacherAuditDecisionWritten;
exports.onAdminAuditDecisionWritten =
  decisionAuditHandlers.onAdminAuditDecisionWritten;
exports.onSettingDecisionWritten =
  decisionAuditHandlers.onSettingDecisionWritten;

// Invoice access control (student suspension)
exports.onInvoiceWrite = invoiceAccessHandlers.onInvoiceWrite;
exports.checkAccessCutoffs = invoiceAccessHandlers.checkAccessCutoffs;
exports.extendStudentAccessCutoff = onCall(
  invoiceAccessHandlers.extendStudentAccessCutoff
);
exports.getParentInvoices = onCall(paymentHandlers.getParentInvoices);
exports.createPaymentSession = onCall(paymentHandlers.createPaymentSession);
exports.createPaymentIntent = onCall(paymentHandlers.createPaymentIntent);
exports.recordManualPayment = onCall(paymentHandlers.recordManualPayment);
exports.deleteInvoice = onCall(paymentHandlers.deleteInvoice);
exports.getPaymentHistory = onCall(paymentHandlers.getPaymentHistory);
exports.handlePayoneerWebhook = functions.https.onRequest(
  paymentHandlers.handlePayoneerWebhook
);
exports.handleStripeWebhook = functions.https.onRequest(
  paymentHandlers.handleStripeWebhook
);
// Public, unauthenticated: /pay/:token — see firebase.json hosting rewrites.
exports.handlePaymentLink = functions.https.onRequest(
  paymentLinkHandlers.handlePaymentLink
);
exports.getInvoicePaymentLink = onCall(
  paymentLinkHandlers.getInvoicePaymentLink
);
exports.cancelInvoicePaymentLink = onCall(
  paymentLinkHandlers.cancelInvoicePaymentLink
);
exports.generateInvoicesForPeriod = paymentHandlers.generateInvoicesForPeriod;
exports.onCircleActivated = circleHandlers.onCircleActivated;
exports.onContributionStatusChanged =
  circleHandlers.onContributionStatusChanged;
exports.onCycleCompleted = circleHandlers.onCycleCompleted;
exports.onMemberJoined = circleHandlers.onMemberJoined;
exports.onInviteCreated = circleHandlers.onInviteCreated;
exports.onOpenCircleCreated = circleHandlers.onOpenCircleCreated;
exports.onOpenCircleMemberAdded = circleHandlers.onOpenCircleMemberAdded;
exports.resendCircleInvite = circleHandlers.resendCircleInvite;

// Zoom host management removed - all video calls now use LiveKit

// Form management functions
exports.checkIncompleteReadinessForms =
  formHandlers.checkIncompleteReadinessForms;
exports.ingestGitHubActivity = functions.https.onRequest(
  githubReportingHandlers.ingestGitHubActivity
);
exports.runCtoWeeklyReportNow = functions.https.onRequest(
  githubReportingHandlers.runCtoWeeklyReportHttp
);
exports.generateWeeklyCtoReport =
  githubReportingHandlers.generateWeeklyCtoReport;

// AI quiz question generation (admin-reviewed before students see them)
exports.generateQuizQuestionsWeekly =
  quizGenerationHandlers.generateQuizQuestionsWeekly;
exports.generateQuizQuestionsNow =
  quizGenerationHandlers.generateQuizQuestionsNow;
exports.recordQuizCompetitionAnswer =
  quizCompetitionHandlers.recordQuizCompetitionAnswer;
exports.getQuizCompetitionLeaderboard =
  quizCompetitionHandlers.getQuizCompetitionLeaderboard;
exports.finalizeQuizCompetition =
  quizCompetitionHandlers.finalizeQuizCompetition;
exports.setQuizCompetitionWindow =
  quizCompetitionHandlers.setQuizCompetitionWindow;
exports.setQuizCompetitionDivision =
  quizCompetitionHandlers.setQuizCompetitionDivision;
exports.setOwnQuizCompetitionAge =
  quizCompetitionHandlers.setOwnQuizCompetitionAge;
exports.onQuizQuestionApproved =
  quizCompetitionHandlers.onQuizQuestionApproved;

// Bayanah live event (host-run, Kahoot-style)
exports.createBayanahEvent = bayanahHandlers.createBayanahEvent;
exports.saveBayanahQuestion = bayanahHandlers.saveBayanahQuestion;
exports.saveBayanahQuestionsBatch = bayanahHandlers.saveBayanahQuestionsBatch;
exports.draftBayanahQuestions = bayanahHandlers.draftBayanahQuestions;
exports.deleteBayanahQuestion = bayanahHandlers.deleteBayanahQuestion;
exports.setBayanahStatus = bayanahHandlers.setBayanahStatus;
exports.nextBayanahQuestion = bayanahHandlers.nextBayanahQuestion;
exports.revealBayanahAnswer = bayanahHandlers.revealBayanahAnswer;
exports.joinBayanah = bayanahHandlers.joinBayanah;
exports.submitBayanahAnswer = bayanahHandlers.submitBayanahAnswer;
exports.getQuizReviewQueue = quizReviewHandlers.getQuizReviewQueue;
exports.reviewQuizQuestion = quizReviewHandlers.reviewQuizQuestion;
exports.setQuizReviewers = quizReviewHandlers.setQuizReviewers;
exports.sendQuizReviewBatchNow = quizReviewHandlers.sendQuizReviewBatchNow;
exports.sendQuizStudentApprovalBatchNow =
  quizReviewHandlers.sendQuizStudentApprovalBatchNow;
exports.sendQuizReviewBatchesHourly =
  quizReviewHandlers.sendQuizReviewBatchesHourly;
exports.sendQuizStudentApprovalBatchesHourly =
  quizReviewHandlers.sendQuizStudentApprovalBatchesHourly;

// Timezone management functions
exports.updateUserTimezone = timezoneHandlers.updateUserTimezone;
exports.updateNotificationPreferences =
  timezoneHandlers.updateNotificationPreferences;
exports.getUserTimezone = timezoneHandlers.getUserTimezone;

// No-show reporting
exports.reportNoShow = noShowHandlers.reportNoShow;
exports.reportClassTechnicalIssue = noShowHandlers.reportClassTechnicalIssue;
exports.detectClassAttendanceNoShows =
  attendanceHandlers.detectClassAttendanceNoShows;
exports.generateWeeklyStudentAttendanceReports =
  attendanceHandlers.generateWeeklyStudentAttendanceReports;
exports.generateMonthlyStudentAttendanceReports =
  attendanceHandlers.generateMonthlyStudentAttendanceReports;
exports.getClassContacts = classContactHandlers.getClassContacts;
exports.getStudentAttendanceReport =
  attendanceHandlers.getStudentAttendanceReport;
exports.getAdminStudentAttendanceOverview =
  attendanceHandlers.getAdminStudentAttendanceOverview;
exports.getPublicSiteMarketingBundle =
  publicSitePublicReadHandlers.getPublicSiteMarketingBundle;
exports.getPublicSiteMarketingBundleHttp =
  publicSitePublicReadHandlers.getPublicSiteMarketingBundleHttp;

// Chat notifications and permissions
exports.onChatMessageCreated = chatHandlers.onChatMessageCreated;
exports.updateChatNotificationPreference =
  chatHandlers.updateChatNotificationPreference;
exports.onShiftStatusChangeChat = chatHandlers.onShiftStatusChange;
exports.onShiftCreatedChat = chatHandlers.onShiftCreated;

// Direct calls (audio/video calls from chat)
exports.createDirectCall = directCallHandlers.createDirectCall;
exports.joinDirectCall = directCallHandlers.joinDirectCall;
exports.endDirectCall = directCallHandlers.endDirectCall;

// Enrollment management functions
exports.onEnrollmentCreated = enrollmentHandlers.onEnrollmentCreated;
// Callable version - note: may have IAM issues on some projects
exports.publishEnrollmentToJobBoard = onCall(
  { cors: true },
  enrollmentHandlers.publishEnrollmentToJobBoard
);
exports.inviteParentForEnrollment = functions.https.onCall(
  enrollmentHandlers.inviteParentForEnrollment
);
exports.unlinkGuardianFromStudent = functions.https.onCall(
  enrollmentHandlers.unlinkGuardianFromStudent
);
exports.lookupParentByEmail = functions.https.onCall(
  enrollmentHandlers.lookupParentByEmail
);
// Puts a matched student back on the teacher job board; admin-only, gated in
// the handler. Leaves the account, parent link and classes untouched.
exports.republishEnrollmentJob = onCall(
  { cors: true, invoker: 'public' },
  (request) => enrollmentRepublishHandlers.republishEnrollmentJob(request)
);
// Approves (schedules one makeup class) or declines a teacher's makeup
// request for a missed class; admin-only, gated in the handler.
// Every upcoming class pays its subject's rate (no $0 classes; a subject change brings its rate).
exports.enforceShiftSubjectRate = shiftRateGuard.enforceShiftSubjectRate;
exports.reviewRescheduleRequest = onCall(
  { cors: true, invoker: 'public' },
  (request) => rescheduleRequestHandlers.reviewRescheduleRequest(request)
);
// Use v1 callables. When context.auth is null (e.g. App Check placeholder), we use idToken from the request body.
exports.acceptJob = functions.https.onCall(async (data, context) => {
  let auth = context.auth;
  if (!auth && data && data.idToken) {
    try {
      const decoded = await admin.auth().verifyIdToken(data.idToken);
      auth = { uid: decoded.uid };
    } catch (_) {}
  }
  return jobHandlers.acceptJob({ data: data || {}, auth });
});
exports.withdrawFromJob = functions.https.onCall(async (data, context) => {
  let auth = context.auth;
  const hasIdToken = !!(data && data.idToken);
  console.log(
    '[index] withdrawFromJob: context.auth=',
    !!auth,
    'data.idToken present=',
    hasIdToken
  );
  if (!auth && data && data.idToken) {
    try {
      const decoded = await admin.auth().verifyIdToken(data.idToken);
      auth = { uid: decoded.uid };
      console.log(
        '[index] withdrawFromJob: auth from idToken fallback, uid=',
        decoded.uid
      );
    } catch (e) {
      console.warn(
        '[index] withdrawFromJob: idToken verify failed',
        e.code || e.message,
        e.message
      );
    }
  } else if (!auth) {
    console.warn(
      '[index] withdrawFromJob: no context.auth and no data.idToken - cannot authenticate'
    );
  }
  return jobHandlers.withdrawFromJob({ data: data || {}, auth });
});

// Application management functions (Leader & Teacher)
const applicationHandlers = require('./handlers/applications');
exports.onLeadershipApplicationCreated =
  applicationHandlers.onLeadershipApplicationCreated;
exports.onTeacherApplicationCreated =
  applicationHandlers.onTeacherApplicationCreated;

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
    const snapshot = await admin
      .firestore()
      .collection('landing_page_content')
      .doc('main')
      .get();

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
exports.executeProgrammedClockIns = functions.https.onCall(
  clockinSchedulerHandlers.executeProgrammedClockIns
);

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
    const kiosqueSnapshot = await db
      .collection('users')
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
    const parentsSnapshot = await db
      .collection('users')
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
    const specificCodeSnapshot = await db
      .collection('users')
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

// Zoom Hub/Breakout test functions removed.

// Kiosque code migration function
const migrateKiosqueCodesHandlers = require('./handlers/migrate_kiosque_codes');
exports.migrateKiosqueCodes = functions.https.onCall(
  migrateKiosqueCodesHandlers.migrateKiosqueCodes
);

// Zoom check, breakout, and hybrid test functions removed.

// Legacy LiveKit Video Functions
exports.getLiveKitJoinToken = livekitHandlers.getLiveKitJoinToken;
exports.ensureLiveKitShiftRecording =
  livekitHandlers.ensureLiveKitShiftRecording;
exports.checkLiveKitAvailability = livekitHandlers.checkLiveKitAvailability;
exports.getLiveKitRoomPresence = livekitHandlers.getLiveKitRoomPresence;
exports.muteLiveKitParticipant = livekitHandlers.muteLiveKitParticipant;
exports.muteAllLiveKitParticipants = livekitHandlers.muteAllLiveKitParticipants;
exports.kickLiveKitParticipant = livekitHandlers.kickLiveKitParticipant;
exports.setLiveKitRoomLock = livekitHandlers.setLiveKitRoomLock;
exports.getLiveKitGuestJoin = livekitHandlers.getLiveKitGuestJoin;
exports.listClassRecordings = livekitHandlers.listClassRecordings;
exports.getClassRecordingPlaybackUrl =
  livekitHandlers.getClassRecordingPlaybackUrl;
exports.cleanupExpiredClassRecordings =
  livekitHandlers.cleanupExpiredClassRecordings;

// Cloudflare RealtimeKit Classroom Video Functions
exports.getRealtimeKitJoinToken = realtimekitHandlers.getRealtimeKitJoinToken;
exports.getRealtimeKitRoomPresence =
  realtimekitHandlers.getRealtimeKitRoomPresence;
exports.kickRealtimeKitParticipant =
  realtimekitHandlers.kickRealtimeKitParticipant;
exports.setRealtimeKitRoomLock = realtimekitHandlers.setRealtimeKitRoomLock;
exports.setRealtimeKitRecordingEnabled =
  realtimekitHandlers.setRealtimeKitRecordingEnabled;
exports.bulkSetRealtimeKitRecordingEnabled =
  realtimekitHandlers.bulkSetRealtimeKitRecordingEnabled;
exports.getRealtimeKitGuestJoin = realtimekitHandlers.getRealtimeKitGuestJoin;

// Zoom classroom pilot
exports.getZoomJoinInfo = zoomHandlers.getZoomJoinInfo;
exports.recordClassPresence = zoomHandlers.recordClassPresence;
exports.recordClassPresenceBeacon = zoomHandlers.recordClassPresenceBeacon;
exports.getZoomHubCapacityForecast = zoomHandlers.getZoomHubCapacityForecast;
exports.getZoomHubRoutingStatus = zoomHandlers.getZoomHubRoutingStatus;
exports.recordZoomHubGuardrailAttempt = zoomHandlers.recordZoomHubGuardrailAttempt;
exports.validateZoomShiftCapacity = zoomHandlers.validateZoomShiftCapacity;
exports.setTeacherZoomEnabled = zoomHandlers.setTeacherZoomEnabled;
exports.zoomWebhook = zoomHandlers.zoomWebhook;
exports.prepareZoomHubs = zoomHandlers.prepareZoomHubs;
exports.watchZoomHubCapacityForecast = zoomHandlers.watchZoomHubCapacityForecast;
exports.watchZoomHubBots = zoomHandlers.watchZoomHubBots;
exports.onTeachingShiftWritten = zoomHandlers.onTeachingShiftWritten;
exports.zoomHubBotDirectives = zoomHubBotHandlers.zoomHubBotDirectives;
exports.zoomHubBotAssignments = zoomHubBotHandlers.zoomHubBotAssignments;
exports.zoomHubBotState = zoomHubBotHandlers.zoomHubBotState;
exports.onZoomHubMemberWritten = zoomHubBotHandlers.onZoomHubMemberWritten;
exports.summariseClassPresence = presenceReportHandlers.summariseClassPresence;
exports.generateWeeklyPresenceReports = presenceReportHandlers.generateWeeklyPresenceReports;
exports.generateMonthlyPresenceReports = presenceReportHandlers.generateMonthlyPresenceReports;
exports.getPresenceReport = presenceReportHandlers.getPresenceReport;
exports.getPresenceOverview = presenceReportHandlers.getPresenceOverview;
exports.reviewPresenceDrop = presenceReportHandlers.reviewPresenceDrop;

// LiveKit Test Function (for development/testing)
exports.testLiveKit = testLivekitHandlers.testLiveKit;

// LiveKit Migration Functions (one-time use)
exports.migrateShiftsToLiveKit =
  migrationLivekitHandlers.migrateShiftsToLiveKit;
exports.revertLiveKitMigration =
  migrationLivekitHandlers.revertLiveKitMigration;

// Password Management Functions
exports.resetStudentPassword = passwordHandlers.resetStudentPassword;
exports.syncAllStudentPasswords = passwordHandlers.syncAllStudentPasswords;

// AI Tutor Functions
exports.getAITutorToken = aiTutorHandlers.getAITutorToken;
exports.endAITutorSession = aiTutorHandlers.endAITutorSession;
exports.transcribeRecitation = quranAsrHandlers.transcribeRecitation;
exports.checkPronunciation = quranPhonemeHandlers.checkPronunciation;

// Student AI tutor, phone-based: the device listens and speaks, these see text.
exports.aiTutorGetAvailability = aiTutorVoice.aiTutorGetAvailability;
exports.aiTutorBookSlot = aiTutorVoice.aiTutorBookSlot;
exports.aiTutorCancelBooking = aiTutorVoice.aiTutorCancelBooking;
exports.aiTutorStartSession = aiTutorVoice.aiTutorStartSession;
exports.aiTutorEndSession = aiTutorVoice.aiTutorEndSession;
exports.aiTutorTurn = aiTutorVoice.aiTutorTurn;
exports.aiTutorSweep = aiTutorVoice.aiTutorSweep;

// Finance overview: month numbers for every finance page, closing a month,
// and the finance switches. Admin-only, gated in the handlers.
const financeSummaryHandlers = require('./handlers/finance_summary');
const financeMonthsHandlers = require('./handlers/finance_months');
const financeSettingsHandlers = require('./handlers/finance_settings');
exports.getFinanceMonthSummary = onCall({ cors: true, invoker: 'public' }, (request) => financeSummaryHandlers.getFinanceMonthSummary(request));
exports.getFinancePenaltyAudits = onCall({ cors: true, invoker: 'public' }, (request) => financeSummaryHandlers.getFinancePenaltyAudits(request));
exports.closeFinanceMonth = onCall({ cors: true, invoker: 'public' }, (request) => financeMonthsHandlers.closeFinanceMonth(request));
exports.reopenFinanceMonth = onCall({ cors: true, invoker: 'public' }, (request) => financeMonthsHandlers.reopenFinanceMonth(request));
exports.updateFinanceSettings = onCall({ cors: true, invoker: 'public' }, (request) => financeSettingsHandlers.updateFinanceSettings(request));
// Finance: staff pay (admin-only, gated in the handler; closed months locked).
exports.recordStaffPayouts = financeStaffHandlers.recordStaffPayoutsCallable;
exports.voidStaffPayout = financeStaffHandlers.voidStaffPayoutCallable;
exports.setAdminPayTerms = financeStaffHandlers.setAdminPayTermsCallable;
exports.pauseAdminPay = financeStaffHandlers.pauseAdminPayCallable;
exports.resumeAdminPay = financeStaffHandlers.resumeAdminPayCallable;
// Pauses an administrator's pay when their account is deactivated.
exports.onAdminUserDeactivated = financeStaffHandlers.onAdminUserDeactivated;
// Finance: expenses, recurring costs, family credits, discount totals.
// Admin-only, gated in the handler; every mutation checks the closed-month lock.
const financeExpensesHandlers = require('./handlers/finance_expenses');
exports.addFinanceExpense = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.addFinanceExpense(request)
);
exports.deleteFinanceExpense = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.deleteFinanceExpense(request)
);
exports.restoreFinanceExpense = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.restoreFinanceExpense(request)
);
exports.confirmRecurringCost = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.confirmRecurringCost(request)
);
exports.stopRecurringCost = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.stopRecurringCost(request)
);
exports.resolveFamilyCredit = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.resolveFamilyCredit(request)
);
exports.getFinanceDiscountTotals = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeExpensesHandlers.getFinanceDiscountTotals(request)
);
// Finance billing engine (docs/finance/SPEC.md): first invoice, monthly amount,
// monthly generator (OFF until finance_settings/main.auto_billing_enabled) and reminders.
const financeBillingHandlers = require('./handlers/finance_billing');
exports.createFirstInvoice = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeBillingHandlers.createFirstInvoice(request)
);
exports.setFamilyMonthlyAmount = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeBillingHandlers.setFamilyMonthlyAmount(request)
);
exports.setEnrollmentMonthlyAmount = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeBillingHandlers.setEnrollmentMonthlyAmount(request)
);
exports.previewMonthlyBilling = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeBillingHandlers.previewMonthlyBilling(request)
);
exports.generateMonthlyFamilyInvoices =
  financeBillingHandlers.generateMonthlyFamilyInvoices;
exports.sendInvoiceReminders = financeBillingHandlers.sendInvoiceReminders;
exports.createFirstInvoiceOnFirstClass =
  financeBillingHandlers.createFirstInvoiceOnFirstClass;
const financeInvoiceHandlers = require('./handlers/finance_invoices');
// Finance: invoice edit / cancel / reminder (admin-only, closed months refused;
// see docs/finance/SPEC.md). Money changes never go through client writes.
exports.editInvoice = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeInvoiceHandlers.editInvoice(request)
);
exports.cancelInvoice = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeInvoiceHandlers.cancelInvoice(request)
);
exports.sendInvoiceReminder = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeInvoiceHandlers.sendInvoiceReminder(request)
);
// Finance: bank deposits (Plaid) and WhatsApp payment proofs. Inactive until
// the owner sets the Plaid / WhatsApp secrets (docs/finance/BANK_AND_WHATSAPP_SETUP.md);
// the callables are admin-gated in the handler. Plaid and WhatsApp secrets are
// read at run time, not bound, so deploying without them never fails.
exports.linkBankAccount = onCall(
  { cors: true, invoker: 'public' },
  (request) => financeBankHandlers.linkBankAccount(request)
);
exports.syncBankTransactions = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 300, memory: '512MiB' },
  (request) => financeBankHandlers.syncBankTransactions(request)
);
exports.decideBankMatch = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 120 },
  (request) => financeBankHandlers.decideBankMatch(request)
);
exports.decidePaymentProof = onCall(
  { cors: true, invoker: 'public', timeoutSeconds: 120 },
  (request) => financeBankHandlers.decidePaymentProof(request)
);
exports.scheduledBankSync = financeBankHandlers.scheduledBankSync;
exports.plaidWebhook = financeBankHandlers.plaidWebhook;
exports.whatsappWebhook = financeBankHandlers.whatsappWebhook;
