import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Alluwal Academy'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get commonCopied;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSignInContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSignInContinue;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginStudentId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get loginStudentId;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginEnterStudentId.
  ///
  /// In en, this message translates to:
  /// **'Enter your student ID'**
  String get loginEnterStudentId;

  /// No description provided for @loginEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get loginEnterEmail;

  /// No description provided for @loginEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginEnterPassword;

  /// No description provided for @loginFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get loginFieldRequired;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get loginInvalidEmail;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get loginPasswordRequired;

  /// No description provided for @loginAccountArchived.
  ///
  /// In en, this message translates to:
  /// **'Your account has been archived. Please contact an administrator for assistance.'**
  String get loginAccountArchived;

  /// No description provided for @loginNoAccountStudentId.
  ///
  /// In en, this message translates to:
  /// **'No account found with this Student ID.'**
  String get loginNoAccountStudentId;

  /// No description provided for @loginNoAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get loginNoAccountEmail;

  /// No description provided for @loginIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get loginIncorrectPassword;

  /// No description provided for @loginInvalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get loginInvalidEmailFormat;

  /// No description provided for @loginAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get loginAccountDisabled;

  /// No description provided for @loginTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please wait and try again.'**
  String get loginTooManyAttempts;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @loginUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get loginUnexpectedError;

  /// No description provided for @loginAlluvialHub.
  ///
  /// In en, this message translates to:
  /// **'Alluvial Education Hub'**
  String get loginAlluvialHub;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get settingsViewProfile;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsTakeAppTour.
  ///
  /// In en, this message translates to:
  /// **'Take App Tour'**
  String get settingsTakeAppTour;

  /// No description provided for @settingsLearnApp.
  ///
  /// In en, this message translates to:
  /// **'Learn how to use the app'**
  String get settingsLearnApp;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsSignOutConfirm;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we protect your data'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app appearance'**
  String get settingsThemeSubtitle;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get settingsLightMode;

  /// No description provided for @settingsSystemMode.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystemMode;

  /// No description provided for @profileHeader.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileHeader;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profileTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get profileTimezone;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileTitle;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profileExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get profileExperience;

  /// No description provided for @profileSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get profileSpecialties;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// No description provided for @profileCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get profileCompleteProfile;

  /// No description provided for @profileHelpParents.
  ///
  /// In en, this message translates to:
  /// **'Help parents and students learn about your expertise'**
  String get profileHelpParents;

  /// No description provided for @profileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get profileFullName;

  /// No description provided for @profileProfessionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional Title'**
  String get profileProfessionalTitle;

  /// No description provided for @profileBiography.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get profileBiography;

  /// No description provided for @profileYearsExperience.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get profileYearsExperience;

  /// No description provided for @profileEducationCerts.
  ///
  /// In en, this message translates to:
  /// **'Education & Certifications'**
  String get profileEducationCerts;

  /// No description provided for @profileSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileSaving;

  /// No description provided for @profileSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get profileSaveProfile;

  /// No description provided for @profileSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile saved successfully!'**
  String get profileSavedSuccess;

  /// No description provided for @profilePercentComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile {percent}% complete'**
  String profilePercentComplete(int percent);

  /// No description provided for @appSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'APP SETTINGS'**
  String get appSettingsHeader;

  /// No description provided for @supportHeader.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get supportHeader;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences'**
  String get notificationsSubtitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get selectLanguageTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get navShifts;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navForms.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get navForms;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get navClasses;

  /// No description provided for @navNotify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get navNotify;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get navQuiz;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navTimeClock.
  ///
  /// In en, this message translates to:
  /// **'Time Clock'**
  String get navTimeClock;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greetingEvening;

  /// No description provided for @dashboardThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get dashboardThisWeek;

  /// No description provided for @dashboardClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get dashboardClasses;

  /// No description provided for @dashboardApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get dashboardApproved;

  /// No description provided for @dashboardToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardToday;

  /// No description provided for @dashboardWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dashboardWeek;

  /// No description provided for @dashboardMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dashboardMonth;

  /// No description provided for @dashboardQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get dashboardQuickAccess;

  /// No description provided for @dashboardMyForms.
  ///
  /// In en, this message translates to:
  /// **'My Forms'**
  String get dashboardMyForms;

  /// No description provided for @dashboardAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get dashboardAssignments;

  /// No description provided for @dashboardIslamicResources.
  ///
  /// In en, this message translates to:
  /// **'Islamic Resources'**
  String get dashboardIslamicResources;

  /// No description provided for @dashboardActiveSession.
  ///
  /// In en, this message translates to:
  /// **'Active Session'**
  String get dashboardActiveSession;

  /// No description provided for @dashboardInProgress.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get dashboardInProgress;

  /// No description provided for @dashboardViewSession.
  ///
  /// In en, this message translates to:
  /// **'View Session'**
  String get dashboardViewSession;

  /// No description provided for @dashboardMyTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get dashboardMyTasks;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get dashboardSeeAll;

  /// No description provided for @dashboardDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dashboardDueDate(String date);

  /// No description provided for @dashboardNextClass.
  ///
  /// In en, this message translates to:
  /// **'Next Class'**
  String get dashboardNextClass;

  /// No description provided for @dashboardTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dashboardTomorrow;

  /// No description provided for @dashboardNoUpcomingClasses.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Classes'**
  String get dashboardNoUpcomingClasses;

  /// No description provided for @dashboardEnjoyFreeTime.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your free time!'**
  String get dashboardEnjoyFreeTime;

  /// No description provided for @readinessFormRequired.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Readiness Form Required} other{{count} Readiness Forms Required}}'**
  String readinessFormRequired(int count);

  /// No description provided for @readinessFormComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete your forms from recent shifts'**
  String get readinessFormComplete;

  /// No description provided for @readinessFormPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Readiness Forms'**
  String get readinessFormPending;

  /// No description provided for @readinessFormSelectShift.
  ///
  /// In en, this message translates to:
  /// **'Select a shift to fill out its form'**
  String get readinessFormSelectShift;

  /// No description provided for @readinessFormAllComplete.
  ///
  /// In en, this message translates to:
  /// **'All forms completed!'**
  String get readinessFormAllComplete;

  /// No description provided for @clockInNow.
  ///
  /// In en, this message translates to:
  /// **'Clock In Now'**
  String get clockInNow;

  /// No description provided for @clockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get clockOut;

  /// No description provided for @clockInProgram.
  ///
  /// In en, this message translates to:
  /// **'Program Clock-In'**
  String get clockInProgram;

  /// No description provided for @clockInProgrammed.
  ///
  /// In en, this message translates to:
  /// **'Programmed...'**
  String get clockInProgrammed;

  /// No description provided for @clockInCancelProgramming.
  ///
  /// In en, this message translates to:
  /// **'Cancel Programming'**
  String get clockInCancelProgramming;

  /// No description provided for @clockInAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Clock-in available in {time}'**
  String clockInAvailableIn(String time);

  /// No description provided for @clockInTooEarly.
  ///
  /// In en, this message translates to:
  /// **'Too early to clock in. Please wait for the programming window (1 minute before shift).'**
  String get clockInTooEarly;

  /// No description provided for @clockInStartingIn.
  ///
  /// In en, this message translates to:
  /// **'Starting in {time}'**
  String clockInStartingIn(String time);

  /// No description provided for @clockInProgrammedFor.
  ///
  /// In en, this message translates to:
  /// **'Clock-in programmed for {time}'**
  String clockInProgrammedFor(String time);

  /// No description provided for @clockInClockingIn.
  ///
  /// In en, this message translates to:
  /// **'Clocking In...'**
  String get clockInClockingIn;

  /// No description provided for @clockInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Programming cancelled'**
  String get clockInCancelled;

  /// No description provided for @clockInNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get clockInNotAuthenticated;

  /// No description provided for @clockInLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Auto clock-in - location unavailable'**
  String get clockInLocationUnavailable;

  /// No description provided for @clockInLocationError.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location. Please enable location services.'**
  String get clockInLocationError;

  /// No description provided for @clockInAutoSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto clock-in successful!'**
  String get clockInAutoSuccess;

  /// No description provided for @clockInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Clocked in successfully!'**
  String get clockInSuccess;

  /// No description provided for @clockInFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clock in'**
  String get clockInFailed;

  /// No description provided for @clockOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Clocked out successfully!'**
  String get clockOutSuccess;

  /// No description provided for @clockOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clock out'**
  String get clockOutFailed;

  /// No description provided for @shiftStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get shiftStudent;

  /// No description provided for @shiftStudents.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get shiftStudents;

  /// No description provided for @shiftStudentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Student} other{{count} Students}}'**
  String shiftStudentCount(int count);

  /// No description provided for @shiftTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get shiftTeacher;

  /// No description provided for @shiftSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get shiftSubject;

  /// No description provided for @shiftSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get shiftSchedule;

  /// No description provided for @shiftDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get shiftDuration;

  /// No description provided for @shiftHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get shiftHours;

  /// No description provided for @shiftHrs.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get shiftHrs;

  /// No description provided for @shiftMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get shiftMinutes;

  /// No description provided for @shiftMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get shiftMissed;

  /// No description provided for @shiftCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get shiftCompleted;

  /// No description provided for @shiftCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shiftCancelled;

  /// No description provided for @shiftScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get shiftScheduled;

  /// No description provided for @shiftActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shiftActive;

  /// No description provided for @shiftUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get shiftUpcoming;

  /// No description provided for @shiftPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get shiftPartial;

  /// No description provided for @shiftReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get shiftReady;

  /// No description provided for @shiftNoShiftsToday.
  ///
  /// In en, this message translates to:
  /// **'No shifts on this day'**
  String get shiftNoShiftsToday;

  /// No description provided for @shiftEnjoyFreeTime.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your free time or check available shifts to pick up extra classes.'**
  String get shiftEnjoyFreeTime;

  /// No description provided for @shiftDetails.
  ///
  /// In en, this message translates to:
  /// **'Shift Details'**
  String get shiftDetails;

  /// No description provided for @shiftViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get shiftViewDetails;

  /// No description provided for @shiftEditShift.
  ///
  /// In en, this message translates to:
  /// **'Edit shift'**
  String get shiftEditShift;

  /// No description provided for @shiftReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule shift'**
  String get shiftReschedule;

  /// No description provided for @shiftFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Showing shifts for {name}. Use ← → above to view other weeks, or switch to List to scroll all {count} shifts'**
  String shiftFilterHint(String name, int count);

  /// No description provided for @shiftReassignTeacher.
  ///
  /// In en, this message translates to:
  /// **'Reassign to another teacher'**
  String get shiftReassignTeacher;

  /// No description provided for @shiftReassignTitle.
  ///
  /// In en, this message translates to:
  /// **'Reassign Shift'**
  String get shiftReassignTitle;

  /// No description provided for @shiftReassignConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reassign this shift to {teacherName}?'**
  String shiftReassignConfirm(String teacherName);

  /// No description provided for @shiftReassignSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shift reassigned successfully'**
  String get shiftReassignSuccess;

  /// No description provided for @shiftReassignError.
  ///
  /// In en, this message translates to:
  /// **'Failed to reassign shift'**
  String get shiftReassignError;

  /// No description provided for @shiftSelectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Select a teacher'**
  String get shiftSelectTeacher;

  /// No description provided for @shiftSearchTeacher.
  ///
  /// In en, this message translates to:
  /// **'Search teachers...'**
  String get shiftSearchTeacher;

  /// No description provided for @shiftNoTeachersFound.
  ///
  /// In en, this message translates to:
  /// **'No teachers found'**
  String get shiftNoTeachersFound;

  /// No description provided for @shiftOriginalTeacher.
  ///
  /// In en, this message translates to:
  /// **'Original: {teacherName}'**
  String shiftOriginalTeacher(String teacherName);

  /// No description provided for @shiftReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report schedule issue'**
  String get shiftReportIssue;

  /// No description provided for @shiftDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get shiftDate;

  /// No description provided for @shiftTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get shiftTime;

  /// No description provided for @shiftStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get shiftStartTime;

  /// No description provided for @shiftEndTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get shiftEndTime;

  /// No description provided for @shiftHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get shiftHourlyRate;

  /// No description provided for @shiftNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get shiftNotes;

  /// No description provided for @shiftAddNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes...'**
  String get shiftAddNotes;

  /// No description provided for @chatMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatMessages;

  /// No description provided for @chatConnectTeam.
  ///
  /// In en, this message translates to:
  /// **'Connect and collaborate with your team'**
  String get chatConnectTeam;

  /// No description provided for @chatRecentChats.
  ///
  /// In en, this message translates to:
  /// **'Recent Chats'**
  String get chatRecentChats;

  /// No description provided for @chatMyContacts.
  ///
  /// In en, this message translates to:
  /// **'My Contacts'**
  String get chatMyContacts;

  /// No description provided for @chatSearchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations and users...'**
  String get chatSearchConversations;

  /// No description provided for @chatNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatNoConversations;

  /// No description provided for @chatStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation by browsing all users'**
  String get chatStartConversation;

  /// No description provided for @chatNoChatsFound.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get chatNoChatsFound;

  /// No description provided for @chatTryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get chatTryDifferentSearch;

  /// No description provided for @chatNoContactsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No contacts available'**
  String get chatNoContactsAvailable;

  /// No description provided for @chatContactsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your teachers, students, or administrators will appear here based on your classes'**
  String get chatContactsAppearHere;

  /// No description provided for @chatNoContactsMatch.
  ///
  /// In en, this message translates to:
  /// **'No contacts match your search'**
  String get chatNoContactsMatch;

  /// No description provided for @chatCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get chatCreateGroup;

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnline;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatOffline;

  /// No description provided for @chatLastSent.
  ///
  /// In en, this message translates to:
  /// **'Last sent {time}'**
  String chatLastSent(String time);

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}...'**
  String chatReplyTo(String name);

  /// No description provided for @chatPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhoto;

  /// No description provided for @chatCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// No description provided for @chatDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get chatDocument;

  /// No description provided for @chatLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatLocation;

  /// No description provided for @chatRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get chatRecording;

  /// No description provided for @chatHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record a voice message'**
  String get chatHoldToRecord;

  /// No description provided for @chatVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get chatVoiceMessage;

  /// No description provided for @chatStartConversationWith.
  ///
  /// In en, this message translates to:
  /// **'Send a message to begin chatting with {name}'**
  String chatStartConversationWith(String name);

  /// No description provided for @chatDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get chatDeleteMessage;

  /// No description provided for @chatDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get chatDeleteMessageConfirm;

  /// No description provided for @chatClearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat'**
  String get chatClearChat;

  /// No description provided for @chatClearChatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear this chat? This action cannot be undone.'**
  String get chatClearChatConfirm;

  /// No description provided for @chatBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get chatBlockUser;

  /// No description provided for @chatBlockUserConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block {name}? They will no longer be able to send you messages.'**
  String chatBlockUserConfirm(String name);

  /// No description provided for @chatGroupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group Information'**
  String get chatGroupInfo;

  /// No description provided for @chatAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add Members'**
  String get chatAddMembers;

  /// No description provided for @chatReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get chatReact;

  /// No description provided for @chatReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatReply;

  /// No description provided for @chatForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatForward;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard'**
  String get chatCopied;

  /// No description provided for @chatSendingImage.
  ///
  /// In en, this message translates to:
  /// **'Sending image...'**
  String get chatSendingImage;

  /// No description provided for @chatImageSent.
  ///
  /// In en, this message translates to:
  /// **'Image sent!'**
  String get chatImageSent;

  /// No description provided for @chatSendingFile.
  ///
  /// In en, this message translates to:
  /// **'Sending file...'**
  String get chatSendingFile;

  /// No description provided for @chatFileSent.
  ///
  /// In en, this message translates to:
  /// **'File sent!'**
  String get chatFileSent;

  /// No description provided for @chatLocationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Location sharing coming soon'**
  String get chatLocationComingSoon;

  /// No description provided for @chatFailedSendAttachment.
  ///
  /// In en, this message translates to:
  /// **'Failed to send attachment'**
  String get chatFailedSendAttachment;

  /// No description provided for @chatFailedSendImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send image'**
  String get chatFailedSendImage;

  /// No description provided for @chatFailedSendFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to send file'**
  String get chatFailedSendFile;

  /// No description provided for @chatFailedSendVoice.
  ///
  /// In en, this message translates to:
  /// **'Failed to send voice message'**
  String get chatFailedSendVoice;

  /// No description provided for @chatFailedStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording'**
  String get chatFailedStartRecording;

  /// No description provided for @chatMicPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required'**
  String get chatMicPermissionRequired;

  /// No description provided for @chatRecordingTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording too short'**
  String get chatRecordingTooShort;

  /// No description provided for @chatNoPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to message this user'**
  String get chatNoPermissionMessage;

  /// No description provided for @chatTeachingRelationshipOnly.
  ///
  /// In en, this message translates to:
  /// **'You can only message users you have a teaching relationship with'**
  String get chatTeachingRelationshipOnly;

  /// No description provided for @chatGroupCallsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Group calls are not supported yet'**
  String get chatGroupCallsNotSupported;

  /// No description provided for @chatErrorLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Error loading messages'**
  String get chatErrorLoadingMessages;

  /// No description provided for @chatGroupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get chatGroupCreateTitle;

  /// No description provided for @chatGroupAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members and create a group chat'**
  String get chatGroupAddMembers;

  /// No description provided for @chatGroupSetNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Set a name and description for your group'**
  String get chatGroupSetNameDesc;

  /// No description provided for @chatGroupSelectMembers.
  ///
  /// In en, this message translates to:
  /// **'Select users to add to the group'**
  String get chatGroupSelectMembers;

  /// No description provided for @chatGroupMembersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} member(s) selected'**
  String chatGroupMembersSelected(int count);

  /// No description provided for @chatGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name *'**
  String get chatGroupName;

  /// No description provided for @chatGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get chatGroupDescription;

  /// No description provided for @chatGroupEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get chatGroupEnterName;

  /// No description provided for @chatGroupEnterDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter group description'**
  String get chatGroupEnterDesc;

  /// No description provided for @chatGroupSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get chatGroupSearchUsers;

  /// No description provided for @chatGroupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get chatGroupCreate;

  /// No description provided for @chatGroupNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users available'**
  String get chatGroupNoUsers;

  /// No description provided for @chatGroupNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get chatGroupNoUsersFound;

  /// No description provided for @chatGroupCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" created successfully!'**
  String chatGroupCreatedSuccess(String name);

  /// No description provided for @chatGroupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group. Please try again.'**
  String get chatGroupCreateFailed;

  /// No description provided for @chatGroupAdminsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only administrators can create group chats'**
  String get chatGroupAdminsOnly;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUser;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String timeDaysAgo(int count);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @formClassReport.
  ///
  /// In en, this message translates to:
  /// **'Class Report'**
  String get formClassReport;

  /// No description provided for @formSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get formSkip;

  /// No description provided for @formSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get formSubmitReport;

  /// No description provided for @formAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Auto-filled (no need to enter)'**
  String get formAutoFilled;

  /// No description provided for @formVerifyDuration.
  ///
  /// In en, this message translates to:
  /// **'Verify Duration'**
  String get formVerifyDuration;

  /// No description provided for @formBillableHours.
  ///
  /// In en, this message translates to:
  /// **'Billable Hours'**
  String get formBillableHours;

  /// No description provided for @formSelectOption.
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get formSelectOption;

  /// No description provided for @formSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Class Report submitted successfully!'**
  String get formSubmittedSuccess;

  /// No description provided for @formMySubmissions.
  ///
  /// In en, this message translates to:
  /// **'My Form Submissions'**
  String get formMySubmissions;

  /// No description provided for @formAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get formAllTime;

  /// No description provided for @formSelectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get formSelectMonth;

  /// No description provided for @formCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get formCurrentMonth;

  /// No description provided for @formSubmission.
  ///
  /// In en, this message translates to:
  /// **'submission'**
  String get formSubmission;

  /// No description provided for @formSubmissions.
  ///
  /// In en, this message translates to:
  /// **'submissions'**
  String get formSubmissions;

  /// No description provided for @formThisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get formThisMonth;

  /// No description provided for @formViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get formViewAll;

  /// No description provided for @formSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by form name or status'**
  String get formSearchByName;

  /// No description provided for @formNoSubmissionsYet.
  ///
  /// In en, this message translates to:
  /// **'No form submissions yet'**
  String get formNoSubmissionsYet;

  /// No description provided for @adminAllSubmissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'All Submissions (Admin)'**
  String get adminAllSubmissionsTitle;

  /// No description provided for @adminSubmissionsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get adminSubmissionsTotal;

  /// No description provided for @adminSubmissionsTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get adminSubmissionsTeachers;

  /// No description provided for @adminSubmissionsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get adminSubmissionsCompleted;

  /// No description provided for @adminSubmissionsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminSubmissionsPending;

  /// No description provided for @adminSubmissionsSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by teacher or form...'**
  String get adminSubmissionsSearchPlaceholder;

  /// No description provided for @adminSubmissionsTeachersAll.
  ///
  /// In en, this message translates to:
  /// **'Teachers (All)'**
  String get adminSubmissionsTeachersAll;

  /// No description provided for @adminSubmissionsFilterTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get adminSubmissionsFilterTeachers;

  /// No description provided for @adminSubmissionsFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get adminSubmissionsFilterMonth;

  /// No description provided for @adminSubmissionsFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminSubmissionsFilterStatus;

  /// No description provided for @adminSubmissionsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get adminSubmissionsAllTime;

  /// No description provided for @adminSubmissionsAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All Status'**
  String get adminSubmissionsAllStatus;

  /// No description provided for @adminSubmissionsAllForms.
  ///
  /// In en, this message translates to:
  /// **'All forms'**
  String get adminSubmissionsAllForms;

  /// No description provided for @adminSubmissionsFilterByForm.
  ///
  /// In en, this message translates to:
  /// **'Filter by form'**
  String get adminSubmissionsFilterByForm;

  /// No description provided for @adminSubmissionsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get adminSubmissionsClearFilters;

  /// No description provided for @adminSubmissionsViewByForm.
  ///
  /// In en, this message translates to:
  /// **'View by Form'**
  String get adminSubmissionsViewByForm;

  /// No description provided for @adminSubmissionsViewByTeacher.
  ///
  /// In en, this message translates to:
  /// **'View by Teacher'**
  String get adminSubmissionsViewByTeacher;

  /// No description provided for @adminSubmissionsSelectTeachers.
  ///
  /// In en, this message translates to:
  /// **'Select Teachers'**
  String get adminSubmissionsSelectTeachers;

  /// No description provided for @adminSubmissionsSelectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Month'**
  String get adminSubmissionsSelectMonth;

  /// No description provided for @adminSubmissionsFilterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by Status'**
  String get adminSubmissionsFilterByStatus;

  /// No description provided for @adminSubmissionsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get adminSubmissionsSelectAll;

  /// No description provided for @adminSubmissionsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get adminSubmissionsClearAll;

  /// No description provided for @adminSubmissionsFavoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites Only'**
  String get adminSubmissionsFavoritesOnly;

  /// No description provided for @adminSubmissionsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminSubmissionsApply;

  /// No description provided for @adminSubmissionsNoSubmissions.
  ///
  /// In en, this message translates to:
  /// **'No submissions found'**
  String get adminSubmissionsNoSubmissions;

  /// No description provided for @adminSubmissionsTryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get adminSubmissionsTryAdjustingFilters;

  /// No description provided for @adminSubmissionsAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get adminSubmissionsAddToFavorites;

  /// No description provided for @adminSubmissionsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminSubmissionsLoadMore;

  /// No description provided for @adminSubmissionsLoadOtherForms.
  ///
  /// In en, this message translates to:
  /// **'Load other forms'**
  String get adminSubmissionsLoadOtherForms;

  /// No description provided for @adminSubmissionsPriorityForm.
  ///
  /// In en, this message translates to:
  /// **'Priority Form'**
  String get adminSubmissionsPriorityForm;

  /// No description provided for @adminSubmissionsGroupedByTeacher.
  ///
  /// In en, this message translates to:
  /// **'Grouped by Teacher'**
  String get adminSubmissionsGroupedByTeacher;

  /// No description provided for @adminSubmissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} submission(s)'**
  String adminSubmissionsCount(int count);

  /// No description provided for @adminSubmissionsShiftDetail.
  ///
  /// In en, this message translates to:
  /// **'{date} • {students}'**
  String adminSubmissionsShiftDetail(String date, String students);

  /// No description provided for @adminSubmissionsGeneralUnknown.
  ///
  /// In en, this message translates to:
  /// **'General / Unknown'**
  String get adminSubmissionsGeneralUnknown;

  /// No description provided for @formDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get formDefaultTitle;

  /// No description provided for @adminPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Preferences'**
  String get adminPreferencesTitle;

  /// No description provided for @adminPreferencesDefaultViewMode.
  ///
  /// In en, this message translates to:
  /// **'Default View Mode'**
  String get adminPreferencesDefaultViewMode;

  /// No description provided for @adminPreferencesByTeacher.
  ///
  /// In en, this message translates to:
  /// **'By Teacher'**
  String get adminPreferencesByTeacher;

  /// No description provided for @adminPreferencesByForm.
  ///
  /// In en, this message translates to:
  /// **'By Form'**
  String get adminPreferencesByForm;

  /// No description provided for @adminPreferencesShowAllMonthsDefault.
  ///
  /// In en, this message translates to:
  /// **'Show All Months by Default'**
  String get adminPreferencesShowAllMonthsDefault;

  /// No description provided for @adminPreferencesFavoriteTeachers.
  ///
  /// In en, this message translates to:
  /// **'Favorite Teachers'**
  String get adminPreferencesFavoriteTeachers;

  /// No description provided for @adminPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get adminPreferencesSaved;

  /// No description provided for @adminPreferencesFavoriteCount.
  ///
  /// In en, this message translates to:
  /// **'{count} teacher(s) marked as favorite'**
  String adminPreferencesFavoriteCount(int count);

  /// No description provided for @adminPreferencesUseStarHint.
  ///
  /// In en, this message translates to:
  /// **'Use the star icon on teacher cards to add favorites'**
  String get adminPreferencesUseStarHint;

  /// No description provided for @adminPreferencesDefaultTeachersHint.
  ///
  /// In en, this message translates to:
  /// **'When you set favorite teachers, they are shown by default. Clear the teacher filter on the screen to see all submissions.'**
  String get adminPreferencesDefaultTeachersHint;

  /// No description provided for @formNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get formNoResults;

  /// No description provided for @formSubmittedFormsAppear.
  ///
  /// In en, this message translates to:
  /// **'Your submitted forms will appear here'**
  String get formSubmittedFormsAppear;

  /// No description provided for @formTryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search'**
  String get formTryAdjustingSearch;

  /// No description provided for @formCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get formCompleted;

  /// No description provided for @formDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get formDraft;

  /// No description provided for @formPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get formPending;

  /// No description provided for @formSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted on {date}'**
  String formSubmittedOn(String date);

  /// No description provided for @formResponses.
  ///
  /// In en, this message translates to:
  /// **'responses'**
  String get formResponses;

  /// No description provided for @formTapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get formTapToView;

  /// No description provided for @formReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get formReadOnly;

  /// No description provided for @formNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'(No answer)'**
  String get formNoAnswer;

  /// No description provided for @formQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get formQuestion;

  /// No description provided for @timesheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Timesheet'**
  String get timesheetTitle;

  /// No description provided for @timesheetMyTimesheet.
  ///
  /// In en, this message translates to:
  /// **'My Timesheet'**
  String get timesheetMyTimesheet;

  /// No description provided for @timesheetDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get timesheetDate;

  /// No description provided for @timesheetStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timesheetStart;

  /// No description provided for @timesheetEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get timesheetEnd;

  /// No description provided for @timesheetTotalHours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours: {hours}'**
  String timesheetTotalHours(Object hours);

  /// No description provided for @timesheetClockInLocation.
  ///
  /// In en, this message translates to:
  /// **'Clock-in Location'**
  String get timesheetClockInLocation;

  /// No description provided for @timesheetClockOutLocation.
  ///
  /// In en, this message translates to:
  /// **'Clock-out Location'**
  String get timesheetClockOutLocation;

  /// No description provided for @timesheetStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get timesheetStatus;

  /// No description provided for @timesheetActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get timesheetActions;

  /// No description provided for @timesheetDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get timesheetDraft;

  /// No description provided for @timesheetPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get timesheetPending;

  /// No description provided for @timesheetApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get timesheetApproved;

  /// No description provided for @timesheetRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get timesheetRejected;

  /// No description provided for @timesheetAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get timesheetAll;

  /// No description provided for @timesheetThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get timesheetThisWeek;

  /// No description provided for @timesheetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get timesheetThisMonth;

  /// No description provided for @timesheetAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get timesheetAllTime;

  /// No description provided for @timesheetNoEntries.
  ///
  /// In en, this message translates to:
  /// **'No timesheet entries found'**
  String get timesheetNoEntries;

  /// No description provided for @timesheetClockInFirst.
  ///
  /// In en, this message translates to:
  /// **'Clock in to create your first entry'**
  String get timesheetClockInFirst;

  /// No description provided for @timesheetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get timesheetSubmit;

  /// No description provided for @timesheetSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get timesheetSubmitForReview;

  /// No description provided for @timesheetSubmitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Submit this timesheet for admin review?'**
  String get timesheetSubmitConfirm;

  /// No description provided for @timesheetSubmitNote.
  ///
  /// In en, this message translates to:
  /// **'Once submitted, you cannot edit this entry until it\'s reviewed.'**
  String get timesheetSubmitNote;

  /// No description provided for @timesheetSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Timesheet submitted for review successfully!'**
  String get timesheetSubmittedSuccess;

  /// No description provided for @timesheetEditTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Edit Timesheet'**
  String get timesheetEditTimesheet;

  /// No description provided for @timesheetEditNote.
  ///
  /// In en, this message translates to:
  /// **'Changes will be submitted for admin approval.'**
  String get timesheetEditNote;

  /// No description provided for @timesheetApprovedLocked.
  ///
  /// In en, this message translates to:
  /// **'This timesheet has been approved and cannot be edited'**
  String get timesheetApprovedLocked;

  /// No description provided for @timesheetClockInTime.
  ///
  /// In en, this message translates to:
  /// **'Clock In Time'**
  String get timesheetClockInTime;

  /// No description provided for @timesheetClockOutTime.
  ///
  /// In en, this message translates to:
  /// **'Clock Out Time'**
  String get timesheetClockOutTime;

  /// No description provided for @timesheetPaymentCalculation.
  ///
  /// In en, this message translates to:
  /// **'Payment Calculation'**
  String get timesheetPaymentCalculation;

  /// No description provided for @timesheetProvideReason.
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason for editing this timesheet'**
  String get timesheetProvideReason;

  /// No description provided for @timesheetProvideMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Please provide more details (at least 10 characters)'**
  String get timesheetProvideMoreDetails;

  /// No description provided for @timesheetSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get timesheetSaveChanges;

  /// No description provided for @timesheetUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Timesheet updated successfully. Awaiting admin approval.'**
  String get timesheetUpdatedSuccess;

  /// No description provided for @timesheetDetails.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Entry Details'**
  String get timesheetDetails;

  /// No description provided for @timesheetLocationLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading location...'**
  String get timesheetLocationLoading;

  /// No description provided for @timesheetLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get timesheetLocationUnavailable;

  /// No description provided for @timesheetLocationNotCaptured.
  ///
  /// In en, this message translates to:
  /// **'Not captured'**
  String get timesheetLocationNotCaptured;

  /// No description provided for @userManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagementTitle;

  /// No description provided for @userSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get userSearchUsers;

  /// No description provided for @userUsersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} users'**
  String userUsersCount(int count);

  /// No description provided for @userActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get userActive;

  /// No description provided for @userInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get userInactive;

  /// No description provided for @userNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get userNoUsersFound;

  /// No description provided for @userFilterUsers.
  ///
  /// In en, this message translates to:
  /// **'Filter Users'**
  String get userFilterUsers;

  /// No description provided for @userRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get userRole;

  /// No description provided for @userStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get userStatus;

  /// No description provided for @userApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get userApplyFilters;

  /// No description provided for @userViewCredentials.
  ///
  /// In en, this message translates to:
  /// **'View Login Credentials'**
  String get userViewCredentials;

  /// No description provided for @userStudentIdPassword.
  ///
  /// In en, this message translates to:
  /// **'Student ID & Password'**
  String get userStudentIdPassword;

  /// No description provided for @userDeactivateUser.
  ///
  /// In en, this message translates to:
  /// **'Deactivate User'**
  String get userDeactivateUser;

  /// No description provided for @userActivateUser.
  ///
  /// In en, this message translates to:
  /// **'Activate User'**
  String get userActivateUser;

  /// No description provided for @userPromoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to Admin'**
  String get userPromoteToAdmin;

  /// No description provided for @userEditUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get userEditUser;

  /// No description provided for @userDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get userDeleteUser;

  /// No description provided for @userLoginCredentials.
  ///
  /// In en, this message translates to:
  /// **'Login Credentials'**
  String get userLoginCredentials;

  /// No description provided for @userEmailForApp.
  ///
  /// In en, this message translates to:
  /// **'Email (for app)'**
  String get userEmailForApp;

  /// No description provided for @userStudentLoginNote.
  ///
  /// In en, this message translates to:
  /// **'Students login using their Student ID and password'**
  String get userStudentLoginNote;

  /// No description provided for @userResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get userResetPassword;

  /// No description provided for @userPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Password Reset'**
  String get userPasswordReset;

  /// No description provided for @userNewPasswordFor.
  ///
  /// In en, this message translates to:
  /// **'New password for {name}:'**
  String userNewPasswordFor(Object name);

  /// No description provided for @userEmailSentToParent.
  ///
  /// In en, this message translates to:
  /// **'Email sent to parent with new credentials'**
  String get userEmailSentToParent;

  /// No description provided for @userShareCredentials.
  ///
  /// In en, this message translates to:
  /// **'Please share this password with the student or their parent.'**
  String get userShareCredentials;

  /// No description provided for @userPasswordNotStored.
  ///
  /// In en, this message translates to:
  /// **'Password not stored'**
  String get userPasswordNotStored;

  /// No description provided for @userResetPasswordFor.
  ///
  /// In en, this message translates to:
  /// **'Reset password for {name}'**
  String userResetPasswordFor(String name);

  /// No description provided for @userCustomPassword.
  ///
  /// In en, this message translates to:
  /// **'Custom password (optional)'**
  String get userCustomPassword;

  /// No description provided for @userLeaveBlankGenerate.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to generate a password'**
  String get userLeaveBlankGenerate;

  /// No description provided for @userPasswordMinChars.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters. Avoid leading/trailing spaces.'**
  String get userPasswordMinChars;

  /// No description provided for @userPasswordGenerateNote.
  ///
  /// In en, this message translates to:
  /// **'If left blank, a secure password will be generated and saved.'**
  String get userPasswordGenerateNote;

  /// No description provided for @userParentEmailNote.
  ///
  /// In en, this message translates to:
  /// **'If the student has a parent linked, they will receive an email with the new credentials.'**
  String get userParentEmailNote;

  /// No description provided for @userPasswordNoSpaces.
  ///
  /// In en, this message translates to:
  /// **'Password cannot start or end with spaces'**
  String get userPasswordNoSpaces;

  /// No description provided for @userPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get userPasswordMinLength;

  /// No description provided for @userPasswordMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be 128 characters or less'**
  String get userPasswordMaxLength;

  /// No description provided for @userResettingPassword.
  ///
  /// In en, this message translates to:
  /// **'Resetting password...'**
  String get userResettingPassword;

  /// No description provided for @userArchived.
  ///
  /// In en, this message translates to:
  /// **'User archived'**
  String get userArchived;

  /// No description provided for @userRestored.
  ///
  /// In en, this message translates to:
  /// **'User restored'**
  String get userRestored;

  /// No description provided for @userPromoteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to promote {name} to admin?'**
  String userPromoteConfirm(Object name);

  /// No description provided for @userPromote.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get userPromote;

  /// No description provided for @userPromotedSuccess.
  ///
  /// In en, this message translates to:
  /// **'User promoted to admin'**
  String get userPromotedSuccess;

  /// No description provided for @userCannotDeleteSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot delete your own account.'**
  String get userCannotDeleteSelf;

  /// No description provided for @userDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this user?'**
  String userDeleteConfirm(String name);

  /// No description provided for @userDeleteCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get userDeleteCannotUndo;

  /// No description provided for @userDeleteTeacherClasses.
  ///
  /// In en, this message translates to:
  /// **'Also delete this teacher\'s classes'**
  String get userDeleteTeacherClasses;

  /// No description provided for @userDeleteStudentClasses.
  ///
  /// In en, this message translates to:
  /// **'Also delete this student\'s classes'**
  String get userDeleteStudentClasses;

  /// No description provided for @userGroupClassesRemain.
  ///
  /// In en, this message translates to:
  /// **'Group classes will remain for other students.'**
  String get userGroupClassesRemain;

  /// No description provided for @userDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been permanently deleted'**
  String userDeletedSuccess(Object name);

  /// No description provided for @userDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete user.'**
  String get userDeleteFailed;

  /// No description provided for @userAddNewUsers.
  ///
  /// In en, this message translates to:
  /// **'Add New Users'**
  String get userAddNewUsers;

  /// No description provided for @userCreateAccounts.
  ///
  /// In en, this message translates to:
  /// **'Create user accounts and assign roles for your organization'**
  String get userCreateAccounts;

  /// No description provided for @userFirstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get userFirstName;

  /// No description provided for @userLastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get userLastName;

  /// No description provided for @userEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get userEmail;

  /// No description provided for @userPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get userPhone;

  /// No description provided for @userUserType.
  ///
  /// In en, this message translates to:
  /// **'User Type'**
  String get userUserType;

  /// No description provided for @userKioskCode.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Code'**
  String get userKioskCode;

  /// No description provided for @userJobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get userJobTitle;

  /// No description provided for @userCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country Code'**
  String get userCountryCode;

  /// No description provided for @userAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get userAdult;

  /// No description provided for @userMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get userMinor;

  /// No description provided for @userSelectParent.
  ///
  /// In en, this message translates to:
  /// **'Select Parent/Guardian'**
  String get userSelectParent;

  /// No description provided for @userNoParentsFound.
  ///
  /// In en, this message translates to:
  /// **'No Parents Found'**
  String get userNoParentsFound;

  /// No description provided for @userCreateParentFirst.
  ///
  /// In en, this message translates to:
  /// **'Create parent first'**
  String get userCreateParentFirst;

  /// No description provided for @userStudentLoginPreview.
  ///
  /// In en, this message translates to:
  /// **'Student Login Preview'**
  String get userStudentLoginPreview;

  /// No description provided for @userReviewCredentials.
  ///
  /// In en, this message translates to:
  /// **'Review login credentials before creating account'**
  String get userReviewCredentials;

  /// No description provided for @userStudentInfo.
  ///
  /// In en, this message translates to:
  /// **'Student Information'**
  String get userStudentInfo;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get userName;

  /// No description provided for @userType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get userType;

  /// No description provided for @userAdultStudent.
  ///
  /// In en, this message translates to:
  /// **'Adult Student'**
  String get userAdultStudent;

  /// No description provided for @userMinorStudent.
  ///
  /// In en, this message translates to:
  /// **'Minor Student'**
  String get userMinorStudent;

  /// No description provided for @userGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get userGuardian;

  /// No description provided for @userStudentId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get userStudentId;

  /// No description provided for @userLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Login Email'**
  String get userLoginEmail;

  /// No description provided for @userCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get userCreateAccount;

  /// No description provided for @helpNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? We\'re here for you.'**
  String get helpNeedHelp;

  /// No description provided for @helpEmailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get helpEmailSupport;

  /// No description provided for @helpLiveChat.
  ///
  /// In en, this message translates to:
  /// **'Live Chat'**
  String get helpLiveChat;

  /// No description provided for @helpAvailableHours.
  ///
  /// In en, this message translates to:
  /// **'Available 9 AM - 5 PM'**
  String get helpAvailableHours;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get errorTryAgain;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// No description provided for @errorSavingData.
  ///
  /// In en, this message translates to:
  /// **'Error saving data'**
  String get errorSavingData;

  /// No description provided for @errorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetworkError;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You are not authorized to perform this action.'**
  String get errorUnauthorized;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested item was not found.'**
  String get errorNotFound;

  /// No description provided for @errorAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get errorAccessDenied;

  /// No description provided for @errorPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get errorPleaseSignIn;

  /// No description provided for @errorAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get errorAuthRequired;

  /// No description provided for @jobNewStudentOpportunities.
  ///
  /// In en, this message translates to:
  /// **'New Student Opportunities'**
  String get jobNewStudentOpportunities;

  /// No description provided for @jobAcceptNewStudents.
  ///
  /// In en, this message translates to:
  /// **'Accept new students to fill your schedule'**
  String get jobAcceptNewStudents;

  /// No description provided for @jobNoOpportunities.
  ///
  /// In en, this message translates to:
  /// **'No opportunities right now'**
  String get jobNoOpportunities;

  /// No description provided for @jobFilledOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Filled Opportunities'**
  String get jobFilledOpportunities;

  /// No description provided for @jobFilled.
  ///
  /// In en, this message translates to:
  /// **'FILLED'**
  String get jobFilled;

  /// No description provided for @jobAge.
  ///
  /// In en, this message translates to:
  /// **'Age: {age}'**
  String jobAge(String age);

  /// No description provided for @jobSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject: {subject}'**
  String jobSubject(String subject);

  /// No description provided for @jobGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade: {grade}'**
  String jobGrade(String grade);

  /// No description provided for @jobTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone: {timezone}'**
  String jobTimezone(String timezone);

  /// No description provided for @jobPreferredTimes.
  ///
  /// In en, this message translates to:
  /// **'Preferred Times:'**
  String get jobPreferredTimes;

  /// No description provided for @jobDays.
  ///
  /// In en, this message translates to:
  /// **'Days: {days}'**
  String jobDays(String days);

  /// No description provided for @jobTimes.
  ///
  /// In en, this message translates to:
  /// **'Times: {times}'**
  String jobTimes(String times);

  /// No description provided for @jobAcceptedOn.
  ///
  /// In en, this message translates to:
  /// **'Accepted on {date}'**
  String jobAcceptedOn(String date);

  /// No description provided for @jobAlreadyFilled.
  ///
  /// In en, this message translates to:
  /// **'Already Filled'**
  String get jobAlreadyFilled;

  /// No description provided for @jobAcceptStudent.
  ///
  /// In en, this message translates to:
  /// **'Accept Student'**
  String get jobAcceptStudent;

  /// No description provided for @jobAcceptedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Job accepted! Admin will finalize the schedule and contact you.'**
  String get jobAcceptedSuccess;

  /// No description provided for @zeroResults.
  ///
  /// In en, this message translates to:
  /// **'0 Results'**
  String get zeroResults;

  /// No description provided for @time1000Am.
  ///
  /// In en, this message translates to:
  /// **'10:00 AM'**
  String get time1000Am;

  /// No description provided for @time1200Pm.
  ///
  /// In en, this message translates to:
  /// **'12:00:00 PM'**
  String get time1200Pm;

  /// No description provided for @aComputer.
  ///
  /// In en, this message translates to:
  /// **'A Computer'**
  String get aComputer;

  /// No description provided for @aNewVersionOfAlluvialAcademy.
  ///
  /// In en, this message translates to:
  /// **'A New Version Of Alluvial Academy'**
  String get aNewVersionOfAlluvialAcademy;

  /// No description provided for @aNewVersionOfAlluvialAcademy2.
  ///
  /// In en, this message translates to:
  /// **'A New Version Of Alluvial Academy2'**
  String get aNewVersionOfAlluvialAcademy2;

  /// No description provided for @aPhone.
  ///
  /// In en, this message translates to:
  /// **'A Phone'**
  String get aPhone;

  /// No description provided for @aTablet.
  ///
  /// In en, this message translates to:
  /// **'A Tablet'**
  String get aTablet;

  /// No description provided for @abilityToSwitchBetweenAdminAnd.
  ///
  /// In en, this message translates to:
  /// **'Ability To Switch Between Admin And'**
  String get abilityToSwitchBetweenAdminAnd;

  /// No description provided for @about35OrLess.
  ///
  /// In en, this message translates to:
  /// **'About35Or Less'**
  String get about35OrLess;

  /// No description provided for @about50OrMore.
  ///
  /// In en, this message translates to:
  /// **'About50Or More'**
  String get about50OrMore;

  /// No description provided for @accessRestricted.
  ///
  /// In en, this message translates to:
  /// **'Access Restricted'**
  String get accessRestricted;

  /// No description provided for @accessToUserManagementAndSystem.
  ///
  /// In en, this message translates to:
  /// **'Access To User Management And System'**
  String get accessToUserManagementAndSystem;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Account Not Set Up'**
  String get accountNotSetUp;

  /// No description provided for @accountSettingsBuildInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Settings Build Info'**
  String get accountSettingsBuildInfo;

  /// No description provided for @actionFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Action Feature Coming Soon'**
  String get actionFeatureComingSoon;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @activeForms.
  ///
  /// In en, this message translates to:
  /// **'Active Forms'**
  String get activeForms;

  /// No description provided for @activeTemplateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Active Template Updated'**
  String get activeTemplateUpdated;

  /// No description provided for @activeUsers.
  ///
  /// In en, this message translates to:
  /// **'Active Users'**
  String get activeUsers;

  /// No description provided for @activityWillAppearHereAsYour.
  ///
  /// In en, this message translates to:
  /// **'Activity Will Appear Here As Your'**
  String get activityWillAppearHereAsYour;

  /// No description provided for @actualPaymentsBackgroundLoad.
  ///
  /// In en, this message translates to:
  /// **'Actual Payments Background Load'**
  String get actualPaymentsBackgroundLoad;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAndManageSubjectsForShifts.
  ///
  /// In en, this message translates to:
  /// **'Add And Manage Subjects For Shifts'**
  String get addAndManageSubjectsForShifts;

  /// No description provided for @addAnotherShift.
  ///
  /// In en, this message translates to:
  /// **'Add Another Shift'**
  String get addAnotherShift;

  /// No description provided for @addAnotherShift2.
  ///
  /// In en, this message translates to:
  /// **'Add Another Shift2'**
  String get addAnotherShift2;

  /// No description provided for @addAnotherStudent.
  ///
  /// In en, this message translates to:
  /// **'Add Another Student'**
  String get addAnotherStudent;

  /// No description provided for @addAnotherTask.
  ///
  /// In en, this message translates to:
  /// **'Add Another Task'**
  String get addAnotherTask;

  /// No description provided for @addAnotherUser.
  ///
  /// In en, this message translates to:
  /// **'Add Another User'**
  String get addAnotherUser;

  /// No description provided for @addAnyAdditionalNotesOrInstructions.
  ///
  /// In en, this message translates to:
  /// **'Add Any Additional Notes Or Instructions'**
  String get addAnyAdditionalNotesOrInstructions;

  /// No description provided for @addAnyCommentsOrCorrections.
  ///
  /// In en, this message translates to:
  /// **'Add Any Comments Or Corrections'**
  String get addAnyCommentsOrCorrections;

  /// No description provided for @addAssignment.
  ///
  /// In en, this message translates to:
  /// **'Add Assignment'**
  String get addAssignment;

  /// No description provided for @addAtLeastOneField.
  ///
  /// In en, this message translates to:
  /// **'Add At Least One Field'**
  String get addAtLeastOneField;

  /// No description provided for @addDate.
  ///
  /// In en, this message translates to:
  /// **'Add Date'**
  String get addDate;

  /// No description provided for @addDetailsSubtasksOrFiles.
  ///
  /// In en, this message translates to:
  /// **'Add Details Subtasks Or Files'**
  String get addDetailsSubtasksOrFiles;

  /// No description provided for @addField.
  ///
  /// In en, this message translates to:
  /// **'Add Field'**
  String get addField;

  /// No description provided for @addFile.
  ///
  /// In en, this message translates to:
  /// **'Add File'**
  String get addFile;

  /// No description provided for @addFilesToShareResourcesOr.
  ///
  /// In en, this message translates to:
  /// **'Add Files To Share Resources Or'**
  String get addFilesToShareResourcesOr;

  /// No description provided for @addFirstRate.
  ///
  /// In en, this message translates to:
  /// **'Add First Rate'**
  String get addFirstRate;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get addImage;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Label'**
  String get addLabel;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add Location'**
  String get addLocation;

  /// No description provided for @addLocationTags.
  ///
  /// In en, this message translates to:
  /// **'Add Location Tags'**
  String get addLocationTags;

  /// No description provided for @addMoreDetailsAboutThisTask.
  ///
  /// In en, this message translates to:
  /// **'Add More Details About This Task'**
  String get addMoreDetailsAboutThisTask;

  /// No description provided for @addMultipleTasks.
  ///
  /// In en, this message translates to:
  /// **'Add Multiple Tasks'**
  String get addMultipleTasks;

  /// No description provided for @addMultipleTasksInOneGo.
  ///
  /// In en, this message translates to:
  /// **'Add Multiple Tasks In One Go'**
  String get addMultipleTasksInOneGo;

  /// No description provided for @addNewSubject.
  ///
  /// In en, this message translates to:
  /// **'Add New Subject'**
  String get addNewSubject;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addOption;

  /// No description provided for @addOption2.
  ///
  /// In en, this message translates to:
  /// **'Add Option2'**
  String get addOption2;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestion;

  /// No description provided for @addSection.
  ///
  /// In en, this message translates to:
  /// **'Add Section'**
  String get addSection;

  /// No description provided for @addSingleTask.
  ///
  /// In en, this message translates to:
  /// **'Add Single Task'**
  String get addSingleTask;

  /// No description provided for @addSubject.
  ///
  /// In en, this message translates to:
  /// **'Add Subject'**
  String get addSubject;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get addTag;

  /// No description provided for @addTag2.
  ///
  /// In en, this message translates to:
  /// **'Add Tag2'**
  String get addTag2;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @addTask2.
  ///
  /// In en, this message translates to:
  /// **'Add Task2'**
  String get addTask2;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Title'**
  String get addTitle;

  /// No description provided for @addUsers.
  ///
  /// In en, this message translates to:
  /// **'Add Users'**
  String get addUsers;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get addVideo;

  /// No description provided for @additionalInformation.
  ///
  /// In en, this message translates to:
  /// **'Additional Information'**
  String get additionalInformation;

  /// No description provided for @additionalNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes Optional'**
  String get additionalNotesOptional;

  /// No description provided for @adjustPayment.
  ///
  /// In en, this message translates to:
  /// **'Adjust Payment'**
  String get adjustPayment;

  /// No description provided for @adjustPayment2.
  ///
  /// In en, this message translates to:
  /// **'Adjust Payment2'**
  String get adjustPayment2;

  /// No description provided for @adjustmentAmount.
  ///
  /// In en, this message translates to:
  /// **'Adjustment Amount'**
  String get adjustmentAmount;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminApproved.
  ///
  /// In en, this message translates to:
  /// **'Admin Approved'**
  String get adminApproved;

  /// No description provided for @adminCreated.
  ///
  /// In en, this message translates to:
  /// **'Admin Created'**
  String get adminCreated;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminPrivilegesHaveBeenRevoked.
  ///
  /// In en, this message translates to:
  /// **'Admin Privileges Have Been Revoked'**
  String get adminPrivilegesHaveBeenRevoked;

  /// No description provided for @adminResponse.
  ///
  /// In en, this message translates to:
  /// **'Admin Response'**
  String get adminResponse;

  /// No description provided for @adminReview.
  ///
  /// In en, this message translates to:
  /// **'Admin Review'**
  String get adminReview;

  /// No description provided for @adminRoleManagement.
  ///
  /// In en, this message translates to:
  /// **'Admin Role Management'**
  String get adminRoleManagement;

  /// No description provided for @adminSchoolEdu.
  ///
  /// In en, this message translates to:
  /// **'Admin School Edu'**
  String get adminSchoolEdu;

  /// No description provided for @adminSettings.
  ///
  /// In en, this message translates to:
  /// **'Admin Settings'**
  String get adminSettings;

  /// No description provided for @adminType.
  ///
  /// In en, this message translates to:
  /// **'Admin Type'**
  String get adminType;

  /// No description provided for @admins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @admins1.
  ///
  /// In en, this message translates to:
  /// **'Admins1'**
  String get admins1;

  /// No description provided for @adminsTabContent.
  ///
  /// In en, this message translates to:
  /// **'Admins Tab Content'**
  String get adminsTabContent;

  /// No description provided for @adultEnglishLiteracyProgram.
  ///
  /// In en, this message translates to:
  /// **'Adult English Literacy Program'**
  String get adultEnglishLiteracyProgram;

  /// No description provided for @adultStudent.
  ///
  /// In en, this message translates to:
  /// **'Adult Student'**
  String get adultStudent;

  /// No description provided for @aeh.
  ///
  /// In en, this message translates to:
  /// **'Aeh'**
  String get aeh;

  /// No description provided for @afterSchoolTutoring.
  ///
  /// In en, this message translates to:
  /// **'After School Tutoring'**
  String get afterSchoolTutoring;

  /// No description provided for @allAdmins.
  ///
  /// In en, this message translates to:
  /// **'All Admins'**
  String get allAdmins;

  /// No description provided for @allAssociatedDataIncludingTimesheetsForms.
  ///
  /// In en, this message translates to:
  /// **'All Associated Data Including Timesheets Forms'**
  String get allAssociatedDataIncludingTimesheetsForms;

  /// No description provided for @allClasses.
  ///
  /// In en, this message translates to:
  /// **'All Classes'**
  String get allClasses;

  /// No description provided for @allDepartments.
  ///
  /// In en, this message translates to:
  /// **'All Departments'**
  String get allDepartments;

  /// No description provided for @allForms.
  ///
  /// In en, this message translates to:
  /// **'All Forms'**
  String get allForms;

  /// No description provided for @allFutureShiftsInThisSeries.
  ///
  /// In en, this message translates to:
  /// **'All Future Shifts In This Series'**
  String get allFutureShiftsInThisSeries;

  /// No description provided for @allParents.
  ///
  /// In en, this message translates to:
  /// **'All Parents'**
  String get allParents;

  /// No description provided for @allPriorities.
  ///
  /// In en, this message translates to:
  /// **'All Priorities'**
  String get allPriorities;

  /// No description provided for @allRecordsNowReflectTheNew.
  ///
  /// In en, this message translates to:
  /// **'All Records Now Reflect The New'**
  String get allRecordsNowReflectTheNew;

  /// No description provided for @allRoles.
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get allRoles;

  /// No description provided for @allSchedules.
  ///
  /// In en, this message translates to:
  /// **'All Schedules'**
  String get allSchedules;

  /// No description provided for @allSelectedShiftsDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'All Selected Shifts Deleted Successfully'**
  String get allSelectedShiftsDeletedSuccessfully;

  /// No description provided for @allStatus.
  ///
  /// In en, this message translates to:
  /// **'All Status'**
  String get allStatus;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get allStatuses;

  /// No description provided for @allStudents.
  ///
  /// In en, this message translates to:
  /// **'All Students'**
  String get allStudents;

  /// No description provided for @allSystemsOperational.
  ///
  /// In en, this message translates to:
  /// **'All Systems Operational'**
  String get allSystemsOperational;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All Tasks'**
  String get allTasks;

  /// No description provided for @allTeachers.
  ///
  /// In en, this message translates to:
  /// **'All Teachers'**
  String get allTeachers;

  /// No description provided for @allTiers.
  ///
  /// In en, this message translates to:
  /// **'All Tiers'**
  String get allTiers;

  /// No description provided for @allUsers.
  ///
  /// In en, this message translates to:
  /// **'All Users'**
  String get allUsers;

  /// No description provided for @allUsersGlobal.
  ///
  /// In en, this message translates to:
  /// **'All Users Global'**
  String get allUsersGlobal;

  /// No description provided for @allUsersInRole.
  ///
  /// In en, this message translates to:
  /// **'All Users In Role'**
  String get allUsersInRole;

  /// No description provided for @allowParticipantsToUnmute.
  ///
  /// In en, this message translates to:
  /// **'Allow Participants To Unmute'**
  String get allowParticipantsToUnmute;

  /// No description provided for @allowRestorationAtAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Allow Restoration At Any Time'**
  String get allowRestorationAtAnyTime;

  /// No description provided for @allowThemToLogInAgain.
  ///
  /// In en, this message translates to:
  /// **'Allow Them To Log In Again'**
  String get allowThemToLogInAgain;

  /// No description provided for @alluwal.
  ///
  /// In en, this message translates to:
  /// **'Alluwal'**
  String get alluwal;

  /// No description provided for @alluwalAcademyIsAQuranEducation.
  ///
  /// In en, this message translates to:
  /// **'Alluwal Academy Is AQuran Education'**
  String get alluwalAcademyIsAQuranEducation;

  /// No description provided for @alluwalEducationHub.
  ///
  /// In en, this message translates to:
  /// **'Alluwal Education Hub'**
  String get alluwalEducationHub;

  /// No description provided for @alreadyAdminTeacher.
  ///
  /// In en, this message translates to:
  /// **'Already Admin Teacher'**
  String get alreadyAdminTeacher;

  /// No description provided for @alreadyClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Already Clocked In'**
  String get alreadyClockedIn;

  /// No description provided for @alsoSendAsEmailNotification.
  ///
  /// In en, this message translates to:
  /// **'Also Send As Email Notification'**
  String get alsoSendAsEmailNotification;

  /// No description provided for @always247.
  ///
  /// In en, this message translates to:
  /// **'Always247'**
  String get always247;

  /// No description provided for @annuler.
  ///
  /// In en, this message translates to:
  /// **'Annuler'**
  String get annuler;

  /// No description provided for @appTour.
  ///
  /// In en, this message translates to:
  /// **'App Tour'**
  String get appTour;

  /// No description provided for @applicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Application Details'**
  String get applicationDetails;

  /// No description provided for @applicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted'**
  String get applicationSubmitted;

  /// No description provided for @applyAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Apply Adjustment'**
  String get applyAdjustment;

  /// No description provided for @applyAnyway.
  ///
  /// In en, this message translates to:
  /// **'Apply Anyway'**
  String get applyAnyway;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply Changes'**
  String get applyChanges;

  /// No description provided for @applyChangesToAllShiftsAnd.
  ///
  /// In en, this message translates to:
  /// **'Apply Changes To All Shifts And'**
  String get applyChangesToAllShiftsAnd;

  /// No description provided for @applyForLeadership.
  ///
  /// In en, this message translates to:
  /// **'Apply For Leadership'**
  String get applyForLeadership;

  /// No description provided for @applyTo.
  ///
  /// In en, this message translates to:
  /// **'Apply To'**
  String get applyTo;

  /// No description provided for @applyToRole.
  ///
  /// In en, this message translates to:
  /// **'Apply To Role'**
  String get applyToRole;

  /// No description provided for @applyToTeach.
  ///
  /// In en, this message translates to:
  /// **'Apply To Teach'**
  String get applyToTeach;

  /// No description provided for @applyWageChangesToRecords.
  ///
  /// In en, this message translates to:
  /// **'Apply Wage Changes To Records'**
  String get applyWageChangesToRecords;

  /// No description provided for @applyWageToRole.
  ///
  /// In en, this message translates to:
  /// **'Apply Wage To Role'**
  String get applyWageToRole;

  /// No description provided for @applyingWageChangesToAllRecords.
  ///
  /// In en, this message translates to:
  /// **'Applying Wage Changes To All Records'**
  String get applyingWageChangesToAllRecords;

  /// No description provided for @approvalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Approval Earnings'**
  String get approvalEarnings;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @approve2.
  ///
  /// In en, this message translates to:
  /// **'Approve2'**
  String get approve2;

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve All'**
  String get approveAll;

  /// No description provided for @approveCalculatePayment.
  ///
  /// In en, this message translates to:
  /// **'Approve Calculate Payment'**
  String get approveCalculatePayment;

  /// No description provided for @approveConsolidatedShift.
  ///
  /// In en, this message translates to:
  /// **'Approve Consolidated Shift'**
  String get approveConsolidatedShift;

  /// No description provided for @approveEditContinue.
  ///
  /// In en, this message translates to:
  /// **'Approve Edit Continue'**
  String get approveEditContinue;

  /// No description provided for @approveTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Approve Timesheet'**
  String get approveTimesheet;

  /// No description provided for @arabicNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Arabic Name Optional'**
  String get arabicNameOptional;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archivePermanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Archive Permanently Delete'**
  String get archivePermanentlyDelete;

  /// No description provided for @archiveTheirAccountNotPermanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Archive Their Account Not Permanently Delete'**
  String get archiveTheirAccountNotPermanentlyDelete;

  /// No description provided for @archiveUser.
  ///
  /// In en, this message translates to:
  /// **'Archive User'**
  String get archiveUser;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @archivedUsers.
  ///
  /// In en, this message translates to:
  /// **'Archived Users'**
  String get archivedUsers;

  /// No description provided for @areYouSureYouWantTo.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To'**
  String get areYouSureYouWantTo;

  /// No description provided for @areYouSureYouWantTo10.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To10'**
  String get areYouSureYouWantTo10;

  /// No description provided for @areYouSureYouWantTo11.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To11'**
  String get areYouSureYouWantTo11;

  /// No description provided for @areYouSureYouWantTo12.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To12'**
  String get areYouSureYouWantTo12;

  /// No description provided for @areYouSureYouWantTo13.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To13'**
  String get areYouSureYouWantTo13;

  /// No description provided for @areYouSureYouWantTo14.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To14'**
  String get areYouSureYouWantTo14;

  /// No description provided for @areYouSureYouWantTo2.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To2'**
  String get areYouSureYouWantTo2;

  /// No description provided for @areYouSureYouWantTo3.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To3'**
  String get areYouSureYouWantTo3;

  /// No description provided for @areYouSureYouWantTo4.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To4'**
  String get areYouSureYouWantTo4;

  /// No description provided for @areYouSureYouWantTo5.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To5'**
  String get areYouSureYouWantTo5;

  /// No description provided for @areYouSureYouWantTo6.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To6'**
  String get areYouSureYouWantTo6;

  /// No description provided for @areYouSureYouWantTo7.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To7'**
  String get areYouSureYouWantTo7;

  /// No description provided for @areYouSureYouWantTo8.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To8'**
  String get areYouSureYouWantTo8;

  /// No description provided for @areYouSureYouWantTo9.
  ///
  /// In en, this message translates to:
  /// **'Are You Sure You Want To9'**
  String get areYouSureYouWantTo9;

  /// No description provided for @assalamuAlaikum.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum'**
  String get assalamuAlaikum;

  /// No description provided for @assalamuAlaikumFirstname.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum Firstname'**
  String get assalamuAlaikumFirstname;

  /// No description provided for @assignTo.
  ///
  /// In en, this message translates to:
  /// **'Assign To'**
  String get assignTo;

  /// No description provided for @assignTo2.
  ///
  /// In en, this message translates to:
  /// **'Assign To2'**
  String get assignTo2;

  /// No description provided for @assignToStudents.
  ///
  /// In en, this message translates to:
  /// **'Assign To Students'**
  String get assignToStudents;

  /// No description provided for @assignedByAssignedbyname.
  ///
  /// In en, this message translates to:
  /// **'Assigned By Assignedbyname'**
  String get assignedByAssignedbyname;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned To'**
  String get assignedTo;

  /// No description provided for @assignedTo2.
  ///
  /// In en, this message translates to:
  /// **'Assigned To2'**
  String get assignedTo2;

  /// No description provided for @assignee.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get assignee;

  /// No description provided for @assignmentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Assignment Deleted'**
  String get assignmentDeleted;

  /// No description provided for @assignmentDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Assignment Deleted Successfully'**
  String get assignmentDeletedSuccessfully;

  /// No description provided for @atLeast6CharactersLongN.
  ///
  /// In en, this message translates to:
  /// **'At Least6Characters Long N'**
  String get atLeast6CharactersLongN;

  /// No description provided for @attachedFiles.
  ///
  /// In en, this message translates to:
  /// **'Attached Files'**
  String get attachedFiles;

  /// No description provided for @attachedFiles2.
  ///
  /// In en, this message translates to:
  /// **'Attached Files2'**
  String get attachedFiles2;

  /// No description provided for @attachmentRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Attachment Removed Successfully'**
  String get attachmentRemovedSuccessfully;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @attachments2.
  ///
  /// In en, this message translates to:
  /// **'Attachments2'**
  String get attachments2;

  /// No description provided for @attachmentsOptional.
  ///
  /// In en, this message translates to:
  /// **'Attachments Optional'**
  String get attachmentsOptional;

  /// No description provided for @attendancepercent.
  ///
  /// In en, this message translates to:
  /// **'Attendancepercent'**
  String get attendancepercent;

  /// No description provided for @aucunLogPourLeMoment.
  ///
  /// In en, this message translates to:
  /// **'Aucun Log Pour Le Moment'**
  String get aucunLogPourLeMoment;

  /// No description provided for @auditGenerationErrors.
  ///
  /// In en, this message translates to:
  /// **'Audit Generation Errors'**
  String get auditGenerationErrors;

  /// No description provided for @auditManagement.
  ///
  /// In en, this message translates to:
  /// **'Audit Management'**
  String get auditManagement;

  /// No description provided for @auditSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Audit Submitted Successfully'**
  String get auditSubmittedSuccessfully;

  /// No description provided for @auditUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Audit Under Review'**
  String get auditUnderReview;

  /// No description provided for @authenticationError.
  ///
  /// In en, this message translates to:
  /// **'Authentication Error'**
  String get authenticationError;

  /// No description provided for @authenticationService.
  ///
  /// In en, this message translates to:
  /// **'Authentication Service'**
  String get authenticationService;

  /// No description provided for @autoClockedOutShiftTimeEnded.
  ///
  /// In en, this message translates to:
  /// **'Auto Clocked Out Shift Time Ended'**
  String get autoClockedOutShiftTimeEnded;

  /// No description provided for @autoFilledFromSubjectOrLeave.
  ///
  /// In en, this message translates to:
  /// **'Auto Filled From Subject Or Leave'**
  String get autoFilledFromSubjectOrLeave;

  /// No description provided for @autoGenerated.
  ///
  /// In en, this message translates to:
  /// **'Auto Generated'**
  String get autoGenerated;

  /// No description provided for @autoLogoutInTimeuntilautologout.
  ///
  /// In en, this message translates to:
  /// **'Auto Logout In Timeuntilautologout'**
  String get autoLogoutInTimeuntilautologout;

  /// No description provided for @autoSendingReportIn30Seconds.
  ///
  /// In en, this message translates to:
  /// **'Auto Sending Report In30Seconds'**
  String get autoSendingReportIn30Seconds;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @availableForms.
  ///
  /// In en, this message translates to:
  /// **'Available Forms'**
  String get availableForms;

  /// No description provided for @availableFunctions.
  ///
  /// In en, this message translates to:
  /// **'Available Functions'**
  String get availableFunctions;

  /// No description provided for @availableOptions.
  ///
  /// In en, this message translates to:
  /// **'Available Options'**
  String get availableOptions;

  /// No description provided for @availableShifts.
  ///
  /// In en, this message translates to:
  /// **'Available Shifts'**
  String get availableShifts;

  /// No description provided for @availableSubjectsClickToConfigure.
  ///
  /// In en, this message translates to:
  /// **'Available Subjects Click To Configure'**
  String get availableSubjectsClickToConfigure;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @avgResponseResponserate.
  ///
  /// In en, this message translates to:
  /// **'Avg Response Responserate'**
  String get avgResponseResponserate;

  /// No description provided for @avgResponseTimeResponsetimeMs.
  ///
  /// In en, this message translates to:
  /// **'Avg Response Time Responsetime Ms'**
  String get avgResponseTimeResponsetimeMs;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back To Home'**
  String get backToHome;

  /// No description provided for @backupCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Backup Created Successfully'**
  String get backupCreatedSuccessfully;

  /// No description provided for @backupSettings.
  ///
  /// In en, this message translates to:
  /// **'Backup Settings'**
  String get backupSettings;

  /// No description provided for @badgeText.
  ///
  /// In en, this message translates to:
  /// **'Badge Text'**
  String get badgeText;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @banForm.
  ///
  /// In en, this message translates to:
  /// **'Ban Form'**
  String get banForm;

  /// No description provided for @banShift.
  ///
  /// In en, this message translates to:
  /// **'Ban Shift'**
  String get banShift;

  /// No description provided for @beTheFirstToLeaveA.
  ///
  /// In en, this message translates to:
  /// **'Be The First To Leave A'**
  String get beTheFirstToLeaveA;

  /// No description provided for @becomeATeacher.
  ///
  /// In en, this message translates to:
  /// **'Become ATeacher'**
  String get becomeATeacher;

  /// No description provided for @becomeATutor.
  ///
  /// In en, this message translates to:
  /// **'Become ATutor'**
  String get becomeATutor;

  /// No description provided for @beginYourLanguageJourney.
  ///
  /// In en, this message translates to:
  /// **'Begin Your Language Journey'**
  String get beginYourLanguageJourney;

  /// No description provided for @beta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get beta;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @blueTaskStatusUpdateNotification.
  ///
  /// In en, this message translates to:
  /// **'Blue Task Status Update Notification'**
  String get blueTaskStatusUpdateNotification;

  /// No description provided for @bonusPerExcellence.
  ///
  /// In en, this message translates to:
  /// **'Bonus Per Excellence'**
  String get bonusPerExcellence;

  /// No description provided for @bookFreeTrialClass.
  ///
  /// In en, this message translates to:
  /// **'Book Free Trial Class'**
  String get bookFreeTrialClass;

  /// No description provided for @breakDuration.
  ///
  /// In en, this message translates to:
  /// **'Break Duration'**
  String get breakDuration;

  /// No description provided for @briefDescriptionOfTheSubject.
  ///
  /// In en, this message translates to:
  /// **'Brief Description Of The Subject'**
  String get briefDescriptionOfTheSubject;

  /// No description provided for @broadcastLiveTeachersCanNowSee.
  ///
  /// In en, this message translates to:
  /// **'Broadcast Live Teachers Can Now See'**
  String get broadcastLiveTeachersCanNowSee;

  /// No description provided for @broadcastNow.
  ///
  /// In en, this message translates to:
  /// **'Broadcast Now'**
  String get broadcastNow;

  /// No description provided for @broadcastToTeachers.
  ///
  /// In en, this message translates to:
  /// **'Broadcast To Teachers'**
  String get broadcastToTeachers;

  /// No description provided for @browserCacheIssueDetectedPleaseRefresh.
  ///
  /// In en, this message translates to:
  /// **'Browser Cache Issue Detected Please Refresh'**
  String get browserCacheIssueDetectedPleaseRefresh;

  /// No description provided for @buildTheFutureWithCode.
  ///
  /// In en, this message translates to:
  /// **'Build The Future With Code'**
  String get buildTheFutureWithCode;

  /// No description provided for @bulkApproveTimesheets.
  ///
  /// In en, this message translates to:
  /// **'Bulk Approve Timesheets'**
  String get bulkApproveTimesheets;

  /// No description provided for @bulkEditEveryClassForThe.
  ///
  /// In en, this message translates to:
  /// **'Bulk Edit Every Class For The'**
  String get bulkEditEveryClassForThe;

  /// No description provided for @bulkEditShifts.
  ///
  /// In en, this message translates to:
  /// **'Bulk Edit Shifts'**
  String get bulkEditShifts;

  /// No description provided for @bulkRejectTimesheets.
  ///
  /// In en, this message translates to:
  /// **'Bulk Reject Timesheets'**
  String get bulkRejectTimesheets;

  /// No description provided for @bulkUpdateFailedE.
  ///
  /// In en, this message translates to:
  /// **'Bulk Update Failed E'**
  String get bulkUpdateFailedE;

  /// No description provided for @byApprovingYouAcceptTheEdited.
  ///
  /// In en, this message translates to:
  /// **'By Approving You Accept The Edited'**
  String get byApprovingYouAcceptTheEdited;

  /// No description provided for @byContinuingYouWillApproveBoth.
  ///
  /// In en, this message translates to:
  /// **'By Continuing You Will Approve Both'**
  String get byContinuingYouWillApproveBoth;

  /// No description provided for @byRole.
  ///
  /// In en, this message translates to:
  /// **'By Role'**
  String get byRole;

  /// No description provided for @cacheClearedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Cache Cleared Successfully'**
  String get cacheClearedSuccessfully;

  /// No description provided for @callToAction.
  ///
  /// In en, this message translates to:
  /// **'Call To Action'**
  String get callToAction;

  /// No description provided for @cameraAndMicrophoneAccessAreNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera And Microphone Access Are Needed'**
  String get cameraAndMicrophoneAccessAreNeeded;

  /// No description provided for @cameraAndMicrophonePermissionsAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera And Microphone Permissions Are Required'**
  String get cameraAndMicrophonePermissionsAreRequired;

  /// No description provided for @cannotEditClockOutTimeYou.
  ///
  /// In en, this message translates to:
  /// **'Cannot Edit Clock Out Time You'**
  String get cannotEditClockOutTimeYou;

  /// No description provided for @career.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get career;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @ceFormulaireNAPasDe.
  ///
  /// In en, this message translates to:
  /// **'Ce Formulaire NAPas De'**
  String get ceFormulaireNAPasDe;

  /// No description provided for @ceo.
  ///
  /// In en, this message translates to:
  /// **'Ceo'**
  String get ceo;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePriority.
  ///
  /// In en, this message translates to:
  /// **'Change Priority'**
  String get changePriority;

  /// No description provided for @changeProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Picture'**
  String get changeProfilePicture;

  /// No description provided for @changeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get changeStatus;

  /// No description provided for @changeTheAssignedTeacherForAll.
  ///
  /// In en, this message translates to:
  /// **'Change The Assigned Teacher For All'**
  String get changeTheAssignedTeacherForAll;

  /// No description provided for @changeTheSubjectForAllSelected.
  ///
  /// In en, this message translates to:
  /// **'Change The Subject For All Selected'**
  String get changeTheSubjectForAllSelected;

  /// No description provided for @changesToApply.
  ///
  /// In en, this message translates to:
  /// **'Changes To Apply'**
  String get changesToApply;

  /// No description provided for @changesWillBeAppliedImmediatelyThe.
  ///
  /// In en, this message translates to:
  /// **'Changes Will Be Applied Immediately The'**
  String get changesWillBeAppliedImmediatelyThe;

  /// No description provided for @changesWillUpdateTheRecurringTemplate.
  ///
  /// In en, this message translates to:
  /// **'Changes Will Update The Recurring Template'**
  String get changesWillUpdateTheRecurringTemplate;

  /// No description provided for @chatFeature.
  ///
  /// In en, this message translates to:
  /// **'Chat Feature'**
  String get chatFeature;

  /// No description provided for @chatMessages2.
  ///
  /// In en, this message translates to:
  /// **'Chat Messages2'**
  String get chatMessages2;

  /// No description provided for @checkOurFrequentlyAskedQuestionsFor.
  ///
  /// In en, this message translates to:
  /// **'Check Our Frequently Asked Questions For'**
  String get checkOurFrequentlyAskedQuestionsFor;

  /// No description provided for @checkPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Payment Status'**
  String get checkPaymentStatus;

  /// No description provided for @checkingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking Connection'**
  String get checkingConnection;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking For Updates'**
  String get checkingForUpdates;

  /// No description provided for @checkingRecurringSeries.
  ///
  /// In en, this message translates to:
  /// **'Checking Recurring Series'**
  String get checkingRecurringSeries;

  /// No description provided for @checkpoints.
  ///
  /// In en, this message translates to:
  /// **'Checkpoints'**
  String get checkpoints;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @childrenSPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Children SPrivacy'**
  String get childrenSPrivacy;

  /// No description provided for @chooseAFormFromTheSidebar.
  ///
  /// In en, this message translates to:
  /// **'Choose AForm From The Sidebar'**
  String get chooseAFormFromTheSidebar;

  /// No description provided for @chooseAParentForThisMinor.
  ///
  /// In en, this message translates to:
  /// **'Choose AParent For This Minor'**
  String get chooseAParentForThisMinor;

  /// No description provided for @chooseAParentToViewTheir.
  ///
  /// In en, this message translates to:
  /// **'Choose AParent To View Their'**
  String get chooseAParentToViewTheir;

  /// No description provided for @chooseARole.
  ///
  /// In en, this message translates to:
  /// **'Choose ARole'**
  String get chooseARole;

  /// No description provided for @chooseAnAdminOrPromotedTeacher.
  ///
  /// In en, this message translates to:
  /// **'Choose An Admin Or Promoted Teacher'**
  String get chooseAnAdminOrPromotedTeacher;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose From Gallery'**
  String get chooseFromGallery;

  /// No description provided for @chooseUsersToAssignThisTask.
  ///
  /// In en, this message translates to:
  /// **'Choose Users To Assign This Task'**
  String get chooseUsersToAssignThisTask;

  /// No description provided for @chooseYourPreferredExportFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Preferred Export Format'**
  String get chooseYourPreferredExportFormat;

  /// No description provided for @chooseYourProgram.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Program'**
  String get chooseYourProgram;

  /// No description provided for @claimShift.
  ///
  /// In en, this message translates to:
  /// **'Claim Shift'**
  String get claimShift;

  /// No description provided for @classCards.
  ///
  /// In en, this message translates to:
  /// **'Class Cards'**
  String get classCards;

  /// No description provided for @classReportNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Class Report Not Submitted'**
  String get classReportNotSubmitted;

  /// No description provided for @classReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Class Report Submitted'**
  String get classReportSubmitted;

  /// No description provided for @classReportSubmittedMissedShift.
  ///
  /// In en, this message translates to:
  /// **'Class Report Submitted Missed Shift'**
  String get classReportSubmittedMissedShift;

  /// No description provided for @classSignUp.
  ///
  /// In en, this message translates to:
  /// **'Class Sign Up'**
  String get classSignUp;

  /// No description provided for @classSignUp2.
  ///
  /// In en, this message translates to:
  /// **'Class Sign Up2'**
  String get classSignUp2;

  /// No description provided for @classcount.
  ///
  /// In en, this message translates to:
  /// **'Classcount'**
  String get classcount;

  /// No description provided for @classesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Classes Completed'**
  String get classesCompleted;

  /// No description provided for @cleanup.
  ///
  /// In en, this message translates to:
  /// **'Cleanup'**
  String get cleanup;

  /// No description provided for @cleanupOld.
  ///
  /// In en, this message translates to:
  /// **'Cleanup Old'**
  String get cleanupOld;

  /// No description provided for @cleanupOldDrafts.
  ///
  /// In en, this message translates to:
  /// **'Cleanup Old Drafts'**
  String get cleanupOldDrafts;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clearAll2.
  ///
  /// In en, this message translates to:
  /// **'Clear All2'**
  String get clearAll2;

  /// No description provided for @clearDateRange.
  ///
  /// In en, this message translates to:
  /// **'Clear Date Range'**
  String get clearDateRange;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get clearFilter;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @clearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get clearLogs;

  /// No description provided for @clearPerformanceLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Performance Logs'**
  String get clearPerformanceLogs;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearSelection;

  /// No description provided for @clearTeacherFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Teacher Filter'**
  String get clearTeacherFilter;

  /// No description provided for @clickAddSubjectToCreateYour.
  ///
  /// In en, this message translates to:
  /// **'Click Add Subject To Create Your'**
  String get clickAddSubjectToCreateYour;

  /// No description provided for @clickToAddSignature.
  ///
  /// In en, this message translates to:
  /// **'Click To Add Signature'**
  String get clickToAddSignature;

  /// No description provided for @clickToUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Click To Upload Image'**
  String get clickToUploadImage;

  /// No description provided for @clockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get clockIn;

  /// No description provided for @clockInLocation.
  ///
  /// In en, this message translates to:
  /// **'Clock In Location'**
  String get clockInLocation;

  /// No description provided for @clockInNotYet.
  ///
  /// In en, this message translates to:
  /// **'Clock In Not Yet'**
  String get clockInNotYet;

  /// No description provided for @clockIns.
  ///
  /// In en, this message translates to:
  /// **'Clock Ins'**
  String get clockIns;

  /// No description provided for @clockOutLocation.
  ///
  /// In en, this message translates to:
  /// **'Clock Out Location'**
  String get clockOutLocation;

  /// No description provided for @clockOutTimeCannotBeEdited.
  ///
  /// In en, this message translates to:
  /// **'Clock Out Time Cannot Be Edited'**
  String get clockOutTimeCannotBeEdited;

  /// No description provided for @clockOutTimeMustBeAfter.
  ///
  /// In en, this message translates to:
  /// **'Clock Out Time Must Be After'**
  String get clockOutTimeMustBeAfter;

  /// No description provided for @clockedIn.
  ///
  /// In en, this message translates to:
  /// **'Clocked In'**
  String get clockedIn;

  /// No description provided for @codingIsTheLiteracyOfThe.
  ///
  /// In en, this message translates to:
  /// **'Coding Is The Literacy Of The'**
  String get codingIsTheLiteracyOfThe;

  /// No description provided for @codingTechnology.
  ///
  /// In en, this message translates to:
  /// **'Coding Technology'**
  String get codingTechnology;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse Sidebar'**
  String get collapseSidebar;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @commentDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Comment Deleted Successfully'**
  String get commentDeletedSuccessfully;

  /// No description provided for @commentcount.
  ///
  /// In en, this message translates to:
  /// **'Commentcount'**
  String get commentcount;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @completeNow.
  ///
  /// In en, this message translates to:
  /// **'Complete Now'**
  String get completeNow;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfile;

  /// No description provided for @completeYourProfileToAppearOn.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile To Appear On'**
  String get completeYourProfileToAppearOn;

  /// No description provided for @completedClassesWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Completed Classes Will Appear Here'**
  String get completedClassesWillAppearHere;

  /// No description provided for @completedcount.
  ///
  /// In en, this message translates to:
  /// **'Completedcount'**
  String get completedcount;

  /// No description provided for @completedcountCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completedcount Completed'**
  String get completedcountCompleted;

  /// No description provided for @composeNotification.
  ///
  /// In en, this message translates to:
  /// **'Compose Notification'**
  String get composeNotification;

  /// No description provided for @computeMetricsNow.
  ///
  /// In en, this message translates to:
  /// **'Compute Metrics Now'**
  String get computeMetricsNow;

  /// No description provided for @computingMetricsThisMayTakeA.
  ///
  /// In en, this message translates to:
  /// **'Computing Metrics This May Take A'**
  String get computingMetricsThisMayTakeA;

  /// No description provided for @configureAndManageYourEducationPlatform.
  ///
  /// In en, this message translates to:
  /// **'Configure And Manage Your Education Platform'**
  String get configureAndManageYourEducationPlatform;

  /// No description provided for @configureApplicationSettings.
  ///
  /// In en, this message translates to:
  /// **'Configure Application Settings'**
  String get configureApplicationSettings;

  /// No description provided for @configureIslamicEducationTeachingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Configure Islamic Education Teaching Schedule'**
  String get configureIslamicEducationTeachingSchedule;

  /// No description provided for @configuredRates.
  ///
  /// In en, this message translates to:
  /// **'Configured Rates'**
  String get configuredRates;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @confirmNewPassword2.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password2'**
  String get confirmNewPassword2;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @conflictsDetected.
  ///
  /// In en, this message translates to:
  /// **'Conflicts Detected'**
  String get conflictsDetected;

  /// No description provided for @connectWithTheWorldThroughLanguage.
  ///
  /// In en, this message translates to:
  /// **'Connect With The World Through Language'**
  String get connectWithTheWorldThroughLanguage;

  /// No description provided for @connecteam.
  ///
  /// In en, this message translates to:
  /// **'Connecteam'**
  String get connecteam;

  /// No description provided for @connectingToClass.
  ///
  /// In en, this message translates to:
  /// **'Connecting To Class'**
  String get connectingToClass;

  /// No description provided for @connectingToTaskDatabase.
  ///
  /// In en, this message translates to:
  /// **'Connecting To Task Database'**
  String get connectingToTaskDatabase;

  /// No description provided for @connectionTestErrorE.
  ///
  /// In en, this message translates to:
  /// **'Connection Test Error E'**
  String get connectionTestErrorE;

  /// No description provided for @contactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformation;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue With Google'**
  String get continueWithGoogle;

  /// No description provided for @convertedslotTeachertzabbr.
  ///
  /// In en, this message translates to:
  /// **'Convertedslot Teachertzabbr'**
  String get convertedslotTeachertzabbr;

  /// No description provided for @copyAllShiftsFromCurrentWeek.
  ///
  /// In en, this message translates to:
  /// **'Copy All Shifts From Current Week'**
  String get copyAllShiftsFromCurrentWeek;

  /// No description provided for @copyClassLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Class Link'**
  String get copyClassLink;

  /// No description provided for @copySummary.
  ///
  /// In en, this message translates to:
  /// **'Copy Summary'**
  String get copySummary;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy To Clipboard'**
  String get copyToClipboard;

  /// No description provided for @coreValues.
  ///
  /// In en, this message translates to:
  /// **'Core Values'**
  String get coreValues;

  /// No description provided for @couldNotOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Url'**
  String get couldNotOpenUrl;

  /// No description provided for @count.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get count;

  /// No description provided for @countTotal.
  ///
  /// In en, this message translates to:
  /// **'Count Total'**
  String get countTotal;

  /// No description provided for @courses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get courses;

  /// No description provided for @coursesEditor.
  ///
  /// In en, this message translates to:
  /// **'Courses Editor'**
  String get coursesEditor;

  /// No description provided for @creErPayer.
  ///
  /// In en, this message translates to:
  /// **'Cre Er Payer'**
  String get creErPayer;

  /// No description provided for @createAParentAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Create AParent Account First'**
  String get createAParentAccountFirst;

  /// No description provided for @createAndManageYourFormTemplates.
  ///
  /// In en, this message translates to:
  /// **'Create And Manage Your Form Templates'**
  String get createAndManageYourFormTemplates;

  /// No description provided for @createAssignment.
  ///
  /// In en, this message translates to:
  /// **'Create Assignment'**
  String get createAssignment;

  /// No description provided for @createDefaultTemplates.
  ///
  /// In en, this message translates to:
  /// **'Create Default Templates'**
  String get createDefaultTemplates;

  /// No description provided for @createForm.
  ///
  /// In en, this message translates to:
  /// **'Create Form'**
  String get createForm;

  /// No description provided for @createMultipleTasks.
  ///
  /// In en, this message translates to:
  /// **'Create Multiple Tasks'**
  String get createMultipleTasks;

  /// No description provided for @createShift.
  ///
  /// In en, this message translates to:
  /// **'Create Shift'**
  String get createShift;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get createTask;

  /// No description provided for @createUsers.
  ///
  /// In en, this message translates to:
  /// **'Create Users'**
  String get createUsers;

  /// No description provided for @createYourFirstAssignmentToGet.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Assignment To Get'**
  String get createYourFirstAssignmentToGet;

  /// No description provided for @createYourFirstFormToGet.
  ///
  /// In en, this message translates to:
  /// **'Create Your First Form To Get'**
  String get createYourFirstFormToGet;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created By'**
  String get createdBy;

  /// No description provided for @createdBy2.
  ///
  /// In en, this message translates to:
  /// **'Created By2'**
  String get createdBy2;

  /// No description provided for @createdByMe.
  ///
  /// In en, this message translates to:
  /// **'Created By Me'**
  String get createdByMe;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating'**
  String get creating;

  /// No description provided for @csv.
  ///
  /// In en, this message translates to:
  /// **'Csv'**
  String get csv;

  /// No description provided for @csvExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Csv Exported Successfully'**
  String get csvExportedSuccessfully;

  /// No description provided for @csvExportedSuccessfully2.
  ///
  /// In en, this message translates to:
  /// **'Csv Exported Successfully2'**
  String get csvExportedSuccessfully2;

  /// No description provided for @ctaEditor.
  ///
  /// In en, this message translates to:
  /// **'Cta Editor'**
  String get ctaEditor;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @currentPayment.
  ///
  /// In en, this message translates to:
  /// **'Current Payment'**
  String get currentPayment;

  /// No description provided for @currentSchedule.
  ///
  /// In en, this message translates to:
  /// **'Current Schedule'**
  String get currentSchedule;

  /// No description provided for @currentUserInfo.
  ///
  /// In en, this message translates to:
  /// **'Current User Info'**
  String get currentUserInfo;

  /// No description provided for @dailyRecurrenceSettings.
  ///
  /// In en, this message translates to:
  /// **'Daily Recurrence Settings'**
  String get dailyRecurrenceSettings;

  /// No description provided for @dailyReports.
  ///
  /// In en, this message translates to:
  /// **'Daily Reports'**
  String get dailyReports;

  /// No description provided for @dataComparison.
  ///
  /// In en, this message translates to:
  /// **'Data Comparison'**
  String get dataComparison;

  /// No description provided for @dataSecurity.
  ///
  /// In en, this message translates to:
  /// **'Data Security'**
  String get dataSecurity;

  /// No description provided for @databaseConnection.
  ///
  /// In en, this message translates to:
  /// **'Database Connection'**
  String get databaseConnection;

  /// No description provided for @dateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get dateAdded;

  /// No description provided for @dateFilterCleared.
  ///
  /// In en, this message translates to:
  /// **'Date Filter Cleared'**
  String get dateFilterCleared;

  /// No description provided for @datePicker.
  ///
  /// In en, this message translates to:
  /// **'Date Picker'**
  String get datePicker;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @dateRange2.
  ///
  /// In en, this message translates to:
  /// **'Date Range2'**
  String get dateRange2;

  /// No description provided for @dateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Date Submitted'**
  String get dateSubmitted;

  /// No description provided for @datestrType.
  ///
  /// In en, this message translates to:
  /// **'Datestr Type'**
  String get datestrType;

  /// No description provided for @daylightSavingTimeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Daylight Saving Time Adjustment'**
  String get daylightSavingTimeAdjustment;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @debugCheckMyAssignments.
  ///
  /// In en, this message translates to:
  /// **'Debug Check My Assignments'**
  String get debugCheckMyAssignments;

  /// No description provided for @debugErrorE.
  ///
  /// In en, this message translates to:
  /// **'Debug Error E'**
  String get debugErrorE;

  /// No description provided for @debugFirestoreDrafts.
  ///
  /// In en, this message translates to:
  /// **'Debug Firestore Drafts'**
  String get debugFirestoreDrafts;

  /// No description provided for @debugInfo.
  ///
  /// In en, this message translates to:
  /// **'Debug Info'**
  String get debugInfo;

  /// No description provided for @debugInfoN.
  ///
  /// In en, this message translates to:
  /// **'Debug info:'**
  String get debugInfoN;

  /// No description provided for @decision.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get decision;

  /// No description provided for @defaultTemplatesCreated.
  ///
  /// In en, this message translates to:
  /// **'Default Templates Created'**
  String get defaultTemplatesCreated;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @deleteAllTeacherShifts.
  ///
  /// In en, this message translates to:
  /// **'Delete All Teacher Shifts'**
  String get deleteAllTeacherShifts;

  /// No description provided for @deleteAllTeachershifts.
  ///
  /// In en, this message translates to:
  /// **'Delete All Teachershifts'**
  String get deleteAllTeachershifts;

  /// No description provided for @deleteAssignment.
  ///
  /// In en, this message translates to:
  /// **'Delete Assignment'**
  String get deleteAssignment;

  /// No description provided for @deleteAttachment.
  ///
  /// In en, this message translates to:
  /// **'Delete Attachment'**
  String get deleteAttachment;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get deleteComment;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft'**
  String get deleteDraft;

  /// No description provided for @deleteField.
  ///
  /// In en, this message translates to:
  /// **'Delete Field'**
  String get deleteField;

  /// No description provided for @deleteForm.
  ///
  /// In en, this message translates to:
  /// **'Delete Form'**
  String get deleteForm;

  /// No description provided for @deleteMultipleShifts.
  ///
  /// In en, this message translates to:
  /// **'Delete Multiple Shifts'**
  String get deleteMultipleShifts;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanently;

  /// No description provided for @deleteShift.
  ///
  /// In en, this message translates to:
  /// **'Delete Shift'**
  String get deleteShift;

  /// No description provided for @deleteShift2.
  ///
  /// In en, this message translates to:
  /// **'Delete Shift2'**
  String get deleteShift2;

  /// No description provided for @deleteSubject.
  ///
  /// In en, this message translates to:
  /// **'Delete Subject'**
  String get deleteSubject;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// No description provided for @deleteTasks.
  ///
  /// In en, this message translates to:
  /// **'Delete Tasks'**
  String get deleteTasks;

  /// No description provided for @deleteTeacherShifts.
  ///
  /// In en, this message translates to:
  /// **'Delete Teacher Shifts'**
  String get deleteTeacherShifts;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get deleteTemplate;

  /// No description provided for @deleteThisShift.
  ///
  /// In en, this message translates to:
  /// **'Delete This Shift'**
  String get deleteThisShift;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @description2.
  ///
  /// In en, this message translates to:
  /// **'Description2'**
  String get description2;

  /// No description provided for @designedForAdultsWhoWantTo.
  ///
  /// In en, this message translates to:
  /// **'Designed For Adults Who Want To'**
  String get designedForAdultsWhoWantTo;

  /// No description provided for @detailedPerformanceLogs.
  ///
  /// In en, this message translates to:
  /// **'Detailed Performance Logs'**
  String get detailedPerformanceLogs;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @directUpdate.
  ///
  /// In en, this message translates to:
  /// **'Direct Update'**
  String get directUpdate;

  /// No description provided for @discoverTheTransformativePowerOfOur.
  ///
  /// In en, this message translates to:
  /// **'Discover The Transformative Power Of Our'**
  String get discoverTheTransformativePowerOfOur;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @displayTimezone.
  ///
  /// In en, this message translates to:
  /// **'Display Timezone'**
  String get displayTimezone;

  /// No description provided for @dispute.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get dispute;

  /// No description provided for @disputeSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Dispute Submitted Successfully'**
  String get disputeSubmittedSuccessfully;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadFile.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get downloadFile;

  /// No description provided for @downloadImage.
  ///
  /// In en, this message translates to:
  /// **'Download Image'**
  String get downloadImage;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download Pdf'**
  String get downloadPdf;

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @draftDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Draft Deleted Successfully'**
  String get draftDeletedSuccessfully;

  /// No description provided for @draftForms.
  ///
  /// In en, this message translates to:
  /// **'Draft Forms'**
  String get draftForms;

  /// No description provided for @dragToMoveClickToClose.
  ///
  /// In en, this message translates to:
  /// **'Drag To Move Click To Close'**
  String get dragToMoveClickToClose;

  /// No description provided for @dstAdjustmentComplete.
  ///
  /// In en, this message translates to:
  /// **'Dst Adjustment Complete'**
  String get dstAdjustmentComplete;

  /// No description provided for @dstTimeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Dst Time Adjustment'**
  String get dstTimeAdjustment;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @dueDate2.
  ///
  /// In en, this message translates to:
  /// **'Due Date2'**
  String get dueDate2;

  /// No description provided for @dueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due Date Optional'**
  String get dueDateOptional;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @duplicateKioskCodeFoundKioskcodePlease.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Kiosk Code Found Kioskcode Please'**
  String get duplicateKioskCodeFoundKioskcodePlease;

  /// No description provided for @duplicateWeek.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Week'**
  String get duplicateWeek;

  /// No description provided for @dureEAPayerHeures.
  ///
  /// In en, this message translates to:
  /// **'Dure EAPayer Heures'**
  String get dureEAPayerHeures;

  /// No description provided for @duringClass.
  ///
  /// In en, this message translates to:
  /// **'During Class'**
  String get duringClass;

  /// No description provided for @dutyType.
  ///
  /// In en, this message translates to:
  /// **'Duty Type'**
  String get dutyType;

  /// No description provided for @eChoueS.
  ///
  /// In en, this message translates to:
  /// **'E Choue S'**
  String get eChoueS;

  /// No description provided for @eG.
  ///
  /// In en, this message translates to:
  /// **'E G'**
  String get eG;

  /// No description provided for @eG021Or5.
  ///
  /// In en, this message translates to:
  /// **'E G021Or5'**
  String get eG021Or5;

  /// No description provided for @eGEnterYourAnswerHere.
  ///
  /// In en, this message translates to:
  /// **'E GEnter Your Answer Here'**
  String get eGEnterYourAnswerHere;

  /// No description provided for @eGMathematics.
  ///
  /// In en, this message translates to:
  /// **'E GMathematics'**
  String get eGMathematics;

  /// No description provided for @eGOfficeRemote.
  ///
  /// In en, this message translates to:
  /// **'E GOffice Remote'**
  String get eGOfficeRemote;

  /// No description provided for @eGQuranStudies.
  ///
  /// In en, this message translates to:
  /// **'E GQuran Studies'**
  String get eGQuranStudies;

  /// No description provided for @eGQuranStudies2.
  ///
  /// In en, this message translates to:
  /// **'E GQuran Studies2'**
  String get eGQuranStudies2;

  /// No description provided for @eGStudentRequestedToMove.
  ///
  /// In en, this message translates to:
  /// **'E GStudent Requested To Move'**
  String get eGStudentRequestedToMove;

  /// No description provided for @eGWhatLessonDidYou.
  ///
  /// In en, this message translates to:
  /// **'E GWhat Lesson Did You'**
  String get eGWhatLessonDidYou;

  /// No description provided for @eachClassCardHasAColor.
  ///
  /// In en, this message translates to:
  /// **'Each Class Card Has AColor'**
  String get eachClassCardHasAColor;

  /// No description provided for @editAllInSeries.
  ///
  /// In en, this message translates to:
  /// **'Edit All In Series'**
  String get editAllInSeries;

  /// No description provided for @editAllShiftsForAStudent.
  ///
  /// In en, this message translates to:
  /// **'Edit All Shifts For AStudent'**
  String get editAllShiftsForAStudent;

  /// No description provided for @editByTimeRangeStudent.
  ///
  /// In en, this message translates to:
  /// **'Edit By Time Range Student'**
  String get editByTimeRangeStudent;

  /// No description provided for @editEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Edit Evaluation'**
  String get editEvaluation;

  /// No description provided for @editField.
  ///
  /// In en, this message translates to:
  /// **'Edit Field'**
  String get editField;

  /// No description provided for @editFunctionalityComingSoonUseWeb.
  ///
  /// In en, this message translates to:
  /// **'Edit Functionality Coming Soon Use Web'**
  String get editFunctionalityComingSoonUseWeb;

  /// No description provided for @editInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get editInformation;

  /// No description provided for @editOptions.
  ///
  /// In en, this message translates to:
  /// **'Edit Options'**
  String get editOptions;

  /// No description provided for @editShift.
  ///
  /// In en, this message translates to:
  /// **'Edit Shift'**
  String get editShift;

  /// No description provided for @editSubject.
  ///
  /// In en, this message translates to:
  /// **'Edit Subject'**
  String get editSubject;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @editTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get editTemplate;

  /// No description provided for @editTheMainLandingPageHero.
  ///
  /// In en, this message translates to:
  /// **'Edit The Main Landing Page Hero'**
  String get editTheMainLandingPageHero;

  /// No description provided for @editThisShiftOnly.
  ///
  /// In en, this message translates to:
  /// **'Edit This Shift Only'**
  String get editThisShiftOnly;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get edited;

  /// No description provided for @editedTimesheetsDetected.
  ///
  /// In en, this message translates to:
  /// **'Edited Timesheets Detected'**
  String get editedTimesheetsDetected;

  /// No description provided for @editingComment.
  ///
  /// In en, this message translates to:
  /// **'Editing Comment'**
  String get editingComment;

  /// No description provided for @educationHub.
  ///
  /// In en, this message translates to:
  /// **'Education Hub'**
  String get educationHub;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @emailSentToParent.
  ///
  /// In en, this message translates to:
  /// **'Email Sent To Parent'**
  String get emailSentToParent;

  /// No description provided for @emailSupportAlluwaleducationhubOrg.
  ///
  /// In en, this message translates to:
  /// **'Email Support Alluwaleducationhub Org'**
  String get emailSupportAlluwaleducationhubOrg;

  /// No description provided for @emailSystemWebCompatible.
  ///
  /// In en, this message translates to:
  /// **'Email System Web Compatible'**
  String get emailSystemWebCompatible;

  /// No description provided for @emailTest.
  ///
  /// In en, this message translates to:
  /// **'Email Test'**
  String get emailTest;

  /// No description provided for @employeeNotes.
  ///
  /// In en, this message translates to:
  /// **'Employee Notes'**
  String get employeeNotes;

  /// No description provided for @employmentStartDate.
  ///
  /// In en, this message translates to:
  /// **'Employment Start Date'**
  String get employmentStartDate;

  /// No description provided for @empowerYourselfWithTheSkillsOf.
  ///
  /// In en, this message translates to:
  /// **'Empower Yourself With The Skills Of'**
  String get empowerYourselfWithTheSkillsOf;

  /// No description provided for @enableDisplaynameMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Enable Displayname Microphone'**
  String get enableDisplaynameMicrophone;

  /// No description provided for @endDateOptional.
  ///
  /// In en, this message translates to:
  /// **'End Date Optional'**
  String get endDateOptional;

  /// No description provided for @endTimeMustBeAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End Time Must Be After Start'**
  String get endTimeMustBeAfterStart;

  /// No description provided for @englishIsTheGlobalLanguageOf.
  ///
  /// In en, this message translates to:
  /// **'English Is The Global Language Of'**
  String get englishIsTheGlobalLanguageOf;

  /// No description provided for @englishLanguageProgram.
  ///
  /// In en, this message translates to:
  /// **'English Language Program'**
  String get englishLanguageProgram;

  /// No description provided for @enrollInCoursename.
  ///
  /// In en, this message translates to:
  /// **'Enroll In Coursename'**
  String get enrollInCoursename;

  /// No description provided for @enrollInTutoring.
  ///
  /// In en, this message translates to:
  /// **'Enroll In Tutoring'**
  String get enrollInTutoring;

  /// No description provided for @enrollNow.
  ///
  /// In en, this message translates to:
  /// **'Enroll Now'**
  String get enrollNow;

  /// No description provided for @enrolledFilled.
  ///
  /// In en, this message translates to:
  /// **'Enrolled Filled'**
  String get enrolledFilled;

  /// No description provided for @enseignantTeachername.
  ///
  /// In en, this message translates to:
  /// **'Enseignant Teachername'**
  String get enseignantTeachername;

  /// No description provided for @enterADescriptiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter ADescriptive Title'**
  String get enterADescriptiveTitle;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter Current Password'**
  String get enterCurrentPassword;

  /// No description provided for @enterCustomShiftName.
  ///
  /// In en, this message translates to:
  /// **'Enter Custom Shift Name'**
  String get enterCustomShiftName;

  /// No description provided for @enterFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter Field Label'**
  String get enterFieldLabel;

  /// No description provided for @enterFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter Form Description'**
  String get enterFormDescription;

  /// No description provided for @enterFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Form Title'**
  String get enterFormTitle;

  /// No description provided for @enterLessonDetailsNotesOrObservations.
  ///
  /// In en, this message translates to:
  /// **'Enter Lesson Details Notes Or Observations'**
  String get enterLessonDetailsNotesOrObservations;

  /// No description provided for @enterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter New Password'**
  String get enterNewPassword;

  /// No description provided for @enterNotes.
  ///
  /// In en, this message translates to:
  /// **'Enter Notes'**
  String get enterNotes;

  /// No description provided for @enterNotificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter Notification Message'**
  String get enterNotificationMessage;

  /// No description provided for @enterNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Notification Title'**
  String get enterNotificationTitle;

  /// No description provided for @enterPlaceholderText.
  ///
  /// In en, this message translates to:
  /// **'Enter Placeholder Text'**
  String get enterPlaceholderText;

  /// No description provided for @enterReasonForRejection.
  ///
  /// In en, this message translates to:
  /// **'Enter Reason For Rejection'**
  String get enterReasonForRejection;

  /// No description provided for @enterTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter Template Description'**
  String get enterTemplateDescription;

  /// No description provided for @enterTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Enter Template Name'**
  String get enterTemplateName;

  /// No description provided for @enterYourEmailOrKiosqueCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Email Or Kiosque Code'**
  String get enterYourEmailOrKiosqueCode;

  /// No description provided for @entryUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Entry Updated Successfully'**
  String get entryUpdatedSuccessfully;

  /// No description provided for @entrycountEvents.
  ///
  /// In en, this message translates to:
  /// **'Entrycount Events'**
  String get entrycountEvents;

  /// No description provided for @erreurLorsDeLaCreAtion.
  ///
  /// In en, this message translates to:
  /// **'Erreur Lors De La Cre Ation'**
  String get erreurLorsDeLaCreAtion;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorAddingSubjectE.
  ///
  /// In en, this message translates to:
  /// **'Error Adding Subject E'**
  String get errorAddingSubjectE;

  /// No description provided for @errorAdjustingShiftsE.
  ///
  /// In en, this message translates to:
  /// **'Error Adjusting Shifts E'**
  String get errorAdjustingShiftsE;

  /// No description provided for @errorApplyingPenaltyE.
  ///
  /// In en, this message translates to:
  /// **'Error Applying Penalty E'**
  String get errorApplyingPenaltyE;

  /// No description provided for @errorApplyingWageChangesE.
  ///
  /// In en, this message translates to:
  /// **'Error Applying Wage Changes E'**
  String get errorApplyingWageChangesE;

  /// No description provided for @errorArchivingTaskE.
  ///
  /// In en, this message translates to:
  /// **'Error Archiving Task E'**
  String get errorArchivingTaskE;

  /// No description provided for @errorBanningShiftE.
  ///
  /// In en, this message translates to:
  /// **'Error Banning Shift E'**
  String get errorBanningShiftE;

  /// No description provided for @errorCouldNotLoadFormTemplate.
  ///
  /// In en, this message translates to:
  /// **'Error Could Not Load Form Template'**
  String get errorCouldNotLoadFormTemplate;

  /// No description provided for @errorCreatingStudentE.
  ///
  /// In en, this message translates to:
  /// **'Error Creating Student E'**
  String get errorCreatingStudentE;

  /// No description provided for @errorDeletingFormE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting Form E'**
  String get errorDeletingFormE;

  /// No description provided for @errorDeletingShiftE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting Shift E'**
  String get errorDeletingShiftE;

  /// No description provided for @errorDeletingShiftsE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting Shifts E'**
  String get errorDeletingShiftsE;

  /// No description provided for @errorDeletingTeacherShiftsE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting Teacher Shifts E'**
  String get errorDeletingTeacherShiftsE;

  /// No description provided for @errorDeletingTemplateE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting Template E'**
  String get errorDeletingTemplateE;

  /// No description provided for @errorDeletingUserE.
  ///
  /// In en, this message translates to:
  /// **'Error Deleting User E'**
  String get errorDeletingUserE;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error Details'**
  String get errorDetails;

  /// No description provided for @errorDuplicatingFormE.
  ///
  /// In en, this message translates to:
  /// **'Error Duplicating Form E'**
  String get errorDuplicatingFormE;

  /// No description provided for @errorDuplicatingTemplateE.
  ///
  /// In en, this message translates to:
  /// **'Error Duplicating Template E'**
  String get errorDuplicatingTemplateE;

  /// No description provided for @errorE.
  ///
  /// In en, this message translates to:
  /// **'Error E'**
  String get errorE;

  /// No description provided for @errorError.
  ///
  /// In en, this message translates to:
  /// **'Error Error'**
  String get errorError;

  /// No description provided for @errorExportingCsvE.
  ///
  /// In en, this message translates to:
  /// **'Error Exporting Csv E'**
  String get errorExportingCsvE;

  /// No description provided for @errorExportingE.
  ///
  /// In en, this message translates to:
  /// **'Error Exporting E'**
  String get errorExportingE;

  /// No description provided for @errorExportingExcelE.
  ///
  /// In en, this message translates to:
  /// **'Error Exporting Excel E'**
  String get errorExportingExcelE;

  /// No description provided for @errorFetchingTeachersE.
  ///
  /// In en, this message translates to:
  /// **'Error Fetching Teachers E'**
  String get errorFetchingTeachersE;

  /// No description provided for @errorLoadingCredentialsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Credentials E'**
  String get errorLoadingCredentialsE;

  /// No description provided for @errorLoadingDrafts.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Drafts'**
  String get errorLoadingDrafts;

  /// No description provided for @errorLoadingFormE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Form E'**
  String get errorLoadingFormE;

  /// No description provided for @errorLoadingLanguageSettingsPleaseRestart.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Language Settings Please Restart'**
  String get errorLoadingLanguageSettingsPleaseRestart;

  /// No description provided for @errorLoadingMetricsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Metrics E'**
  String get errorLoadingMetricsE;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Profile'**
  String get errorLoadingProfile;

  /// No description provided for @errorLoadingSettingsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Settings E'**
  String get errorLoadingSettingsE;

  /// No description provided for @errorLoadingShiftDetailsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Shift Details E'**
  String get errorLoadingShiftDetailsE;

  /// No description provided for @errorLoadingShiftE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Shift E'**
  String get errorLoadingShiftE;

  /// No description provided for @errorLoadingShiftsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Shifts E'**
  String get errorLoadingShiftsE;

  /// No description provided for @errorLoadingStudents.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Students'**
  String get errorLoadingStudents;

  /// No description provided for @errorLoadingSubjects.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Subjects'**
  String get errorLoadingSubjects;

  /// No description provided for @errorLoadingSubmissionE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Submission E'**
  String get errorLoadingSubmissionE;

  /// No description provided for @errorLoadingSubmissionsE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Submissions E'**
  String get errorLoadingSubmissionsE;

  /// No description provided for @errorLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Tasks'**
  String get errorLoadingTasks;

  /// No description provided for @errorLoadingTemplatesE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Templates E'**
  String get errorLoadingTemplatesE;

  /// No description provided for @errorLoadingTimesheetDataE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Timesheet Data E'**
  String get errorLoadingTimesheetDataE;

  /// No description provided for @errorLoadingTimesheetE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Timesheet E'**
  String get errorLoadingTimesheetE;

  /// No description provided for @errorLoadingUsers.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Users'**
  String get errorLoadingUsers;

  /// No description provided for @errorLoadingUsersE.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Users E'**
  String get errorLoadingUsersE;

  /// No description provided for @errorMissingShiftInformation.
  ///
  /// In en, this message translates to:
  /// **'Error Missing Shift Information'**
  String get errorMissingShiftInformation;

  /// No description provided for @errorOpeningFileE.
  ///
  /// In en, this message translates to:
  /// **'Error Opening File E'**
  String get errorOpeningFileE;

  /// No description provided for @errorOpeningLink.
  ///
  /// In en, this message translates to:
  /// **'Error Opening Link'**
  String get errorOpeningLink;

  /// No description provided for @errorPromotingUserE.
  ///
  /// In en, this message translates to:
  /// **'Error Promoting User E'**
  String get errorPromotingUserE;

  /// No description provided for @errorReorderingSubjectsE.
  ///
  /// In en, this message translates to:
  /// **'Error Reordering Subjects E'**
  String get errorReorderingSubjectsE;

  /// No description provided for @errorReschedulingShiftE.
  ///
  /// In en, this message translates to:
  /// **'Error Rescheduling Shift E'**
  String get errorReschedulingShiftE;

  /// No description provided for @errorResettingPasswordE.
  ///
  /// In en, this message translates to:
  /// **'Error Resetting Password E'**
  String get errorResettingPasswordE;

  /// No description provided for @errorSavingFormE.
  ///
  /// In en, this message translates to:
  /// **'Error Saving Form E'**
  String get errorSavingFormE;

  /// No description provided for @errorSavingSettingsE.
  ///
  /// In en, this message translates to:
  /// **'Error Saving Settings E'**
  String get errorSavingSettingsE;

  /// No description provided for @errorSavingShiftE.
  ///
  /// In en, this message translates to:
  /// **'Error Saving Shift E'**
  String get errorSavingShiftE;

  /// No description provided for @errorSavingTemplateE.
  ///
  /// In en, this message translates to:
  /// **'Error Saving Template E'**
  String get errorSavingTemplateE;

  /// No description provided for @errorSendingMessageE.
  ///
  /// In en, this message translates to:
  /// **'Error Sending Message E'**
  String get errorSendingMessageE;

  /// No description provided for @errorSendingNotificationE.
  ///
  /// In en, this message translates to:
  /// **'Error Sending Notification E'**
  String get errorSendingNotificationE;

  /// No description provided for @errorSubmittingE.
  ///
  /// In en, this message translates to:
  /// **'Error Submitting E'**
  String get errorSubmittingE;

  /// No description provided for @errorSubmittingTimesheetE.
  ///
  /// In en, this message translates to:
  /// **'Error Submitting Timesheet E'**
  String get errorSubmittingTimesheetE;

  /// No description provided for @errorUnarchivingTaskE.
  ///
  /// In en, this message translates to:
  /// **'Error Unarchiving Task E'**
  String get errorUnarchivingTaskE;

  /// No description provided for @errorUpdatingEntryE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Entry E'**
  String get errorUpdatingEntryE;

  /// No description provided for @errorUpdatingStatusE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Status E'**
  String get errorUpdatingStatusE;

  /// No description provided for @errorUpdatingSubjectE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Subject E'**
  String get errorUpdatingSubjectE;

  /// No description provided for @errorUpdatingSubjectStatusE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Subject Status E'**
  String get errorUpdatingSubjectStatusE;

  /// No description provided for @errorUpdatingTaskE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Task E'**
  String get errorUpdatingTaskE;

  /// No description provided for @errorUpdatingTasksE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Tasks E'**
  String get errorUpdatingTasksE;

  /// No description provided for @errorUpdatingTimesheetE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating Timesheet E'**
  String get errorUpdatingTimesheetE;

  /// No description provided for @errorUpdatingUserE.
  ///
  /// In en, this message translates to:
  /// **'Error Updating User E'**
  String get errorUpdatingUserE;

  /// No description provided for @errorYouMustBeLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Error You Must Be Logged In'**
  String get errorYouMustBeLoggedIn;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @estimatedEarnings.
  ///
  /// In en, this message translates to:
  /// **'Estimated Earnings'**
  String get estimatedEarnings;

  /// No description provided for @evaluate.
  ///
  /// In en, this message translates to:
  /// **'Evaluate'**
  String get evaluate;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @excelReportExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Excel Report Exported Successfully'**
  String get excelReportExportedSuccessfully;

  /// No description provided for @excelWithMonthlyPivotTables.
  ///
  /// In en, this message translates to:
  /// **'Excel With Monthly Pivot Tables'**
  String get excelWithMonthlyPivotTables;

  /// No description provided for @excludeDaysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Exclude Days Of Week'**
  String get excludeDaysOfWeek;

  /// No description provided for @excludeSpecificDates.
  ///
  /// In en, this message translates to:
  /// **'Exclude Specific Dates'**
  String get excludeSpecificDates;

  /// No description provided for @existingDispute.
  ///
  /// In en, this message translates to:
  /// **'Existing Dispute'**
  String get existingDispute;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get exitFullscreen;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @explainTheIssue.
  ///
  /// In en, this message translates to:
  /// **'Explain The Issue'**
  String get explainTheIssue;

  /// No description provided for @explainWhyYouAreEditingThis.
  ///
  /// In en, this message translates to:
  /// **'Explain Why You Are Editing This'**
  String get explainWhyYouAreEditingThis;

  /// No description provided for @exportAllMonthsPivotView.
  ///
  /// In en, this message translates to:
  /// **'Export All Months Pivot View'**
  String get exportAllMonthsPivotView;

  /// No description provided for @exportAuditReport.
  ///
  /// In en, this message translates to:
  /// **'Export Audit Report'**
  String get exportAuditReport;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export Csv'**
  String get exportCsv;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportFailedE.
  ///
  /// In en, this message translates to:
  /// **'Export Failed E'**
  String get exportFailedE;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf'**
  String get exportPdf;

  /// No description provided for @exportToCsv.
  ///
  /// In en, this message translates to:
  /// **'Export To Csv'**
  String get exportToCsv;

  /// No description provided for @failedLoginAttempt15MinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Failed Login Attempt15Minutes Ago'**
  String get failedLoginAttempt15MinutesAgo;

  /// No description provided for @failedToAddFileE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Add File E'**
  String get failedToAddFileE;

  /// No description provided for @failedToAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Failed To Add Members'**
  String get failedToAddMembers;

  /// No description provided for @failedToClaimShiftPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed To Claim Shift Please Try'**
  String get failedToClaimShiftPleaseTry;

  /// No description provided for @failedToCleanupDraftsE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Cleanup Drafts E'**
  String get failedToCleanupDraftsE;

  /// No description provided for @failedToDeleteAssignmentE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Delete Assignment E'**
  String get failedToDeleteAssignmentE;

  /// No description provided for @failedToDeleteDraftE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Delete Draft E'**
  String get failedToDeleteDraftE;

  /// No description provided for @failedToGeneratePdfE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Generate Pdf E'**
  String get failedToGeneratePdfE;

  /// No description provided for @failedToInitializeFirebase.
  ///
  /// In en, this message translates to:
  /// **'Failed To Initialize Firebase'**
  String get failedToInitializeFirebase;

  /// No description provided for @failedToLinkFormToShift.
  ///
  /// In en, this message translates to:
  /// **'Failed To Link Form To Shift'**
  String get failedToLinkFormToShift;

  /// No description provided for @failedToLoadAssignmentsE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Assignments E'**
  String get failedToLoadAssignmentsE;

  /// No description provided for @failedToLoadExistingProfileE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Existing Profile E'**
  String get failedToLoadExistingProfileE;

  /// No description provided for @failedToLoadInvoiceNMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Invoice NMessage'**
  String get failedToLoadInvoiceNMessage;

  /// No description provided for @failedToLoadInvoicesNMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Invoices NMessage'**
  String get failedToLoadInvoicesNMessage;

  /// No description provided for @failedToLoadProfileE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Profile E'**
  String get failedToLoadProfileE;

  /// No description provided for @failedToLoadSeriesE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Series E'**
  String get failedToLoadSeriesE;

  /// No description provided for @failedToLoadStudentShiftsE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Student Shifts E'**
  String get failedToLoadStudentShiftsE;

  /// No description provided for @failedToLoadTimeRangeShifts.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Time Range Shifts'**
  String get failedToLoadTimeRangeShifts;

  /// No description provided for @failedToOpenClassLinkE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Open Class Link E'**
  String get failedToOpenClassLinkE;

  /// No description provided for @failedToRemoveProfilePicturePlease.
  ///
  /// In en, this message translates to:
  /// **'Failed To Remove Profile Picture Please'**
  String get failedToRemoveProfilePicturePlease;

  /// No description provided for @failedToSaveContentE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Save Content E'**
  String get failedToSaveContentE;

  /// No description provided for @failedToSaveNoteE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Save Note E'**
  String get failedToSaveNoteE;

  /// No description provided for @failedToSavePreferencesPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed To Save Preferences Please Try'**
  String get failedToSavePreferencesPleaseTry;

  /// No description provided for @failedToSaveProfileE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Save Profile E'**
  String get failedToSaveProfileE;

  /// No description provided for @failedToSaveStatusE.
  ///
  /// In en, this message translates to:
  /// **'Failed To Save Status E'**
  String get failedToSaveStatusE;

  /// No description provided for @failedToSendReportPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed To Send Report Please Try'**
  String get failedToSendReportPleaseTry;

  /// No description provided for @failedToSwitchRolePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed To Switch Role Please Try'**
  String get failedToSwitchRolePleaseTry;

  /// No description provided for @failedToUpdatePayment.
  ///
  /// In en, this message translates to:
  /// **'Failed To Update Payment'**
  String get failedToUpdatePayment;

  /// No description provided for @failedToUpdateTaskPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed To Update Task Please Try'**
  String get failedToUpdateTaskPleaseTry;

  /// No description provided for @failedToUploadProfilePicturePlease.
  ///
  /// In en, this message translates to:
  /// **'Failed To Upload Profile Picture Please'**
  String get failedToUploadProfilePicturePlease;

  /// No description provided for @fallBack1Hour.
  ///
  /// In en, this message translates to:
  /// **'Fall Back1Hour'**
  String get fallBack1Hour;

  /// No description provided for @faqs.
  ///
  /// In en, this message translates to:
  /// **'Faqs'**
  String get faqs;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @featuresEditorComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Features Editor Coming Soon'**
  String get featuresEditorComingSoon;

  /// No description provided for @featuresSectionEditor.
  ///
  /// In en, this message translates to:
  /// **'Features Section Editor'**
  String get featuresSectionEditor;

  /// No description provided for @field.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get field;

  /// No description provided for @fieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field Label'**
  String get fieldLabel;

  /// No description provided for @fieldLabelCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Field Label Cannot Be Empty'**
  String get fieldLabelCannotBeEmpty;

  /// No description provided for @fieldToDispute.
  ///
  /// In en, this message translates to:
  /// **'Field To Dispute'**
  String get fieldToDispute;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Field Type'**
  String get fieldType;

  /// No description provided for @fieldType2.
  ///
  /// In en, this message translates to:
  /// **'Field Type2'**
  String get fieldType2;

  /// No description provided for @fileAttachmentIsOnlySupportedOn.
  ///
  /// In en, this message translates to:
  /// **'File Attachment Is Only Supported On'**
  String get fileAttachmentIsOnlySupportedOn;

  /// No description provided for @fileNotUploadedToStorage.
  ///
  /// In en, this message translates to:
  /// **'File Not Uploaded To Storage'**
  String get fileNotUploadedToStorage;

  /// No description provided for @fileSelectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'File Selection Cancelled'**
  String get fileSelectionCancelled;

  /// No description provided for @fileUpload.
  ///
  /// In en, this message translates to:
  /// **'File Upload'**
  String get fileUpload;

  /// No description provided for @fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get fill;

  /// No description provided for @fillClassReportNow.
  ///
  /// In en, this message translates to:
  /// **'Fill Class Report Now'**
  String get fillClassReportNow;

  /// No description provided for @fillInTheDetailsForEach.
  ///
  /// In en, this message translates to:
  /// **'Fill In The Details For Each'**
  String get fillInTheDetailsForEach;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filterByAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Filter By Assigned By'**
  String get filterByAssignedBy;

  /// No description provided for @filterByAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Filter By Assigned To'**
  String get filterByAssignedTo;

  /// No description provided for @filterByLabels.
  ///
  /// In en, this message translates to:
  /// **'Filter By Labels'**
  String get filterByLabels;

  /// No description provided for @filterByParent.
  ///
  /// In en, this message translates to:
  /// **'Filter By Parent'**
  String get filterByParent;

  /// No description provided for @filterByPriority.
  ///
  /// In en, this message translates to:
  /// **'Filter By Priority'**
  String get filterByPriority;

  /// No description provided for @filterByRole.
  ///
  /// In en, this message translates to:
  /// **'Filter By Role'**
  String get filterByRole;

  /// No description provided for @filterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter By Status'**
  String get filterByStatus;

  /// No description provided for @filterByStatus2.
  ///
  /// In en, this message translates to:
  /// **'Filter By Status2'**
  String get filterByStatus2;

  /// No description provided for @filterBySubject.
  ///
  /// In en, this message translates to:
  /// **'Filter By Subject'**
  String get filterBySubject;

  /// No description provided for @filterByTeacher.
  ///
  /// In en, this message translates to:
  /// **'Filter By Teacher'**
  String get filterByTeacher;

  /// No description provided for @filterByTeacher2.
  ///
  /// In en, this message translates to:
  /// **'Filter By Teacher2'**
  String get filterByTeacher2;

  /// No description provided for @filterFormResponsesByUser.
  ///
  /// In en, this message translates to:
  /// **'Filter Form Responses By User'**
  String get filterFormResponsesByUser;

  /// No description provided for @filterRecurringTasks.
  ///
  /// In en, this message translates to:
  /// **'Filter Recurring Tasks'**
  String get filterRecurringTasks;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @finalizeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Finalize Schedule'**
  String get finalizeSchedule;

  /// No description provided for @finalizeSchedulesForMatchedStudentsAnd.
  ///
  /// In en, this message translates to:
  /// **'Finalize Schedules For Matched Students And'**
  String get finalizeSchedulesForMatchedStudentsAnd;

  /// No description provided for @financialSummary.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialSummary;

  /// No description provided for @findPrograms.
  ///
  /// In en, this message translates to:
  /// **'Find Programs'**
  String get findPrograms;

  /// No description provided for @findShiftsForAStudentMatching.
  ///
  /// In en, this message translates to:
  /// **'Find Shifts For AStudent Matching'**
  String get findShiftsForAStudentMatching;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @firstName2.
  ///
  /// In en, this message translates to:
  /// **'First Name2'**
  String get firstName2;

  /// No description provided for @firstname.
  ///
  /// In en, this message translates to:
  /// **'Firstname'**
  String get firstname;

  /// No description provided for @fixMyTimezoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Fix My Timezone Only'**
  String get fixMyTimezoneOnly;

  /// No description provided for @fixTimezone.
  ///
  /// In en, this message translates to:
  /// **'Fix Timezone'**
  String get fixTimezone;

  /// No description provided for @fixTimezoneOrReportScheduleIssue.
  ///
  /// In en, this message translates to:
  /// **'Fix Timezone Or Report Schedule Issue'**
  String get fixTimezoneOrReportScheduleIssue;

  /// No description provided for @footer.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get footer;

  /// No description provided for @footerEditor.
  ///
  /// In en, this message translates to:
  /// **'Footer Editor'**
  String get footerEditor;

  /// No description provided for @forPrivacyQuestionsOrConcernsEmail.
  ///
  /// In en, this message translates to:
  /// **'For Privacy Questions Or Concerns Email'**
  String get forPrivacyQuestionsOrConcernsEmail;

  /// No description provided for @forTheMonthSOfMonth.
  ///
  /// In en, this message translates to:
  /// **'For The Month SOf Month'**
  String get forTheMonthSOfMonth;

  /// No description provided for @forTheMonthSOfMonthcovered.
  ///
  /// In en, this message translates to:
  /// **'For The Month SOf Monthcovered'**
  String get forTheMonthSOfMonthcovered;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @form.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get form;

  /// No description provided for @formAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Form Already Submitted'**
  String get formAlreadySubmitted;

  /// No description provided for @formBannedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Form Banned Successfully'**
  String get formBannedSuccessfully;

  /// No description provided for @formCompliance.
  ///
  /// In en, this message translates to:
  /// **'Form Compliance'**
  String get formCompliance;

  /// No description provided for @formDeleted.
  ///
  /// In en, this message translates to:
  /// **'Form Deleted'**
  String get formDeleted;

  /// No description provided for @formDescription.
  ///
  /// In en, this message translates to:
  /// **'Form Description'**
  String get formDescription;

  /// No description provided for @formDescription2.
  ///
  /// In en, this message translates to:
  /// **'Form Description2'**
  String get formDescription2;

  /// No description provided for @formDetails.
  ///
  /// In en, this message translates to:
  /// **'Form Details'**
  String get formDetails;

  /// No description provided for @formDuplicatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Form Duplicated Successfully'**
  String get formDuplicatedSuccessfully;

  /// No description provided for @formFields.
  ///
  /// In en, this message translates to:
  /// **'Form Fields'**
  String get formFields;

  /// No description provided for @formLinkedToShiftSuccessfullyPayment.
  ///
  /// In en, this message translates to:
  /// **'Form Linked To Shift Successfully Payment'**
  String get formLinkedToShiftSuccessfullyPayment;

  /// No description provided for @formListResponseCounts.
  ///
  /// In en, this message translates to:
  /// **'Form List Response Counts'**
  String get formListResponseCounts;

  /// Shown when a form cannot be found by ID.
  ///
  /// In en, this message translates to:
  /// **'Form not found (ID: {formId}). Please select another form.'**
  String formNotFoundIdFormidPlease(String formId);

  /// No description provided for @formNotFoundPleaseContactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Form Not Found Please Contact Admin'**
  String get formNotFoundPleaseContactAdmin;

  /// No description provided for @formResponses2.
  ///
  /// In en, this message translates to:
  /// **'Form Responses2'**
  String get formResponses2;

  /// No description provided for @formSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Form Saved Successfully'**
  String get formSavedSuccessfully;

  /// No description provided for @formSavedSuccessfullyPreviousVersionsDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Form Saved Successfully Previous Versions Deactivated'**
  String get formSavedSuccessfullyPreviousVersionsDeactivated;

  /// No description provided for @formSettings.
  ///
  /// In en, this message translates to:
  /// **'Form Settings'**
  String get formSettings;

  /// No description provided for @formSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Form Submitted'**
  String get formSubmitted;

  /// No description provided for @formsWithNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'Forms with no schedule'**
  String get formsWithNoSchedule;

  /// No description provided for @auditTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get auditTabOverview;

  /// No description provided for @auditTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get auditTabActivity;

  /// No description provided for @auditTabPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get auditTabPayment;

  /// No description provided for @auditTabForms.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get auditTabForms;

  /// No description provided for @auditKeyIndicators.
  ///
  /// In en, this message translates to:
  /// **'Key indicators'**
  String get auditKeyIndicators;

  /// No description provided for @auditPerformanceRates.
  ///
  /// In en, this message translates to:
  /// **'Performance rates'**
  String get auditPerformanceRates;

  /// No description provided for @auditIssuesAlerts.
  ///
  /// In en, this message translates to:
  /// **'Issues & alerts'**
  String get auditIssuesAlerts;

  /// No description provided for @auditClassesCompleted.
  ///
  /// In en, this message translates to:
  /// **'Classes completed'**
  String get auditClassesCompleted;

  /// No description provided for @auditHoursTaught.
  ///
  /// In en, this message translates to:
  /// **'Hours taught'**
  String get auditHoursTaught;

  /// No description provided for @auditCompletionRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Completion rate'**
  String get auditCompletionRateLabel;

  /// No description provided for @auditLateClockInsLabel.
  ///
  /// In en, this message translates to:
  /// **'Late clock-ins'**
  String get auditLateClockInsLabel;

  /// No description provided for @auditClassesMissedLabel.
  ///
  /// In en, this message translates to:
  /// **'Classes missed'**
  String get auditClassesMissedLabel;

  /// No description provided for @auditNoLateClockIns.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get auditNoLateClockIns;

  /// No description provided for @auditNoMissedClasses.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get auditNoMissedClasses;

  /// No description provided for @auditClassCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'Class completion'**
  String get auditClassCompletionRate;

  /// No description provided for @auditFormComplianceLabel.
  ///
  /// In en, this message translates to:
  /// **'Form compliance'**
  String get auditFormComplianceLabel;

  /// No description provided for @auditNoIssuesDetected.
  ///
  /// In en, this message translates to:
  /// **'No issues detected'**
  String get auditNoIssuesDetected;

  /// No description provided for @auditFormsAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get auditFormsAccepted;

  /// No description provided for @auditFormsRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get auditFormsRejected;

  /// No description provided for @auditFormsRejectedBreakdown.
  ///
  /// In en, this message translates to:
  /// **'({noShift} no shift, {duplicates} duplicate)'**
  String auditFormsRejectedBreakdown(int noShift, int duplicates);

  /// No description provided for @auditFormStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get auditFormStatusAccepted;

  /// No description provided for @auditFormStatusRejectedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Rejected (duplicate)'**
  String get auditFormStatusRejectedDuplicate;

  /// No description provided for @auditFormStatusRejectedNoShift.
  ///
  /// In en, this message translates to:
  /// **'Rejected (no shift)'**
  String get auditFormStatusRejectedNoShift;

  /// No description provided for @auditTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get auditTotalLabel;

  /// No description provided for @auditFormsSubmittedLabel.
  ///
  /// In en, this message translates to:
  /// **'Forms submitted'**
  String get auditFormsSubmittedLabel;

  /// No description provided for @auditGeneralOrUnlinked.
  ///
  /// In en, this message translates to:
  /// **'General / Unlinked'**
  String get auditGeneralOrUnlinked;

  /// No description provided for @auditNoFormsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'No forms submitted'**
  String get auditNoFormsSubmitted;

  /// No description provided for @auditTierExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get auditTierExcellent;

  /// No description provided for @auditTierGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get auditTierGood;

  /// No description provided for @auditTierNeedsImprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs Improvement'**
  String get auditTierNeedsImprovement;

  /// No description provided for @auditTierCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get auditTierCritical;

  /// No description provided for @auditStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get auditStatusCompleted;

  /// No description provided for @auditStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get auditStatusSubmitted;

  /// No description provided for @auditStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get auditStatusDisputed;

  /// No description provided for @auditStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get auditStatusPending;

  /// No description provided for @teacherAuditTabSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get teacherAuditTabSummary;

  /// No description provided for @teacherAuditTabMyClasses.
  ///
  /// In en, this message translates to:
  /// **'My classes'**
  String get teacherAuditTabMyClasses;

  /// No description provided for @teacherAuditTabDispute.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get teacherAuditTabDispute;

  /// No description provided for @teacherAuditPaymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get teacherAuditPaymentSection;

  /// No description provided for @teacherAuditPerformanceSection.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get teacherAuditPerformanceSection;

  /// No description provided for @teacherAuditNetToReceive.
  ///
  /// In en, this message translates to:
  /// **'NET TO RECEIVE'**
  String get teacherAuditNetToReceive;

  /// No description provided for @teacherAuditPointsOfAttention.
  ///
  /// In en, this message translates to:
  /// **'Points of attention'**
  String get teacherAuditPointsOfAttention;

  /// No description provided for @teacherAuditReportNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Report not available'**
  String get teacherAuditReportNotAvailable;

  /// No description provided for @teacherAuditReportNotFinalizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your report for {month} is not yet finalized or does not exist.'**
  String teacherAuditReportNotFinalizedMessage(String month);

  /// No description provided for @teacherAuditClassesLabel.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get teacherAuditClassesLabel;

  /// No description provided for @teacherAuditHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get teacherAuditHoursLabel;

  /// No description provided for @teacherAuditFormsLabel.
  ///
  /// In en, this message translates to:
  /// **'Forms'**
  String get teacherAuditFormsLabel;

  /// No description provided for @teacherAuditPunctualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get teacherAuditPunctualityLabel;

  /// No description provided for @teacherAuditContestationSent.
  ///
  /// In en, this message translates to:
  /// **'Dispute submitted successfully'**
  String get teacherAuditContestationSent;

  /// No description provided for @teacherAuditContestationError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String teacherAuditContestationError(String message);

  /// No description provided for @teacherAuditNewDispute.
  ///
  /// In en, this message translates to:
  /// **'New dispute'**
  String get teacherAuditNewDispute;

  /// No description provided for @teacherAuditExistingDispute.
  ///
  /// In en, this message translates to:
  /// **'Existing dispute'**
  String get teacherAuditExistingDispute;

  /// No description provided for @teacherAuditAdminResponse.
  ///
  /// In en, this message translates to:
  /// **'Admin response:'**
  String get teacherAuditAdminResponse;

  /// No description provided for @teacherAuditSelectField.
  ///
  /// In en, this message translates to:
  /// **'Select a field'**
  String get teacherAuditSelectField;

  /// No description provided for @teacherAuditReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get teacherAuditReasonLabel;

  /// No description provided for @teacherAuditSuggestedValue.
  ///
  /// In en, this message translates to:
  /// **'Correct value (optional)'**
  String get teacherAuditSuggestedValue;

  /// No description provided for @teacherAuditSendDispute.
  ///
  /// In en, this message translates to:
  /// **'Submit dispute'**
  String get teacherAuditSendDispute;

  /// No description provided for @teacherAuditSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get teacherAuditSending;

  /// No description provided for @teacherAuditDisputeInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'If you believe a value is incorrect, submit a dispute below. The team will review your request.'**
  String get teacherAuditDisputeInfoMessage;

  /// No description provided for @teacherAuditFieldToDispute.
  ///
  /// In en, this message translates to:
  /// **'Field to dispute'**
  String get teacherAuditFieldToDispute;

  /// No description provided for @teacherAuditDetailReason.
  ///
  /// In en, this message translates to:
  /// **'Explain why this value seems incorrect...'**
  String get teacherAuditDetailReason;

  /// No description provided for @teacherAuditExampleValue.
  ///
  /// In en, this message translates to:
  /// **'E.g.: 24h, 95%, 3 classes...'**
  String get teacherAuditExampleValue;

  /// No description provided for @teacherAuditGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get teacherAuditGross;

  /// No description provided for @teacherAuditPenalties.
  ///
  /// In en, this message translates to:
  /// **'Penalties'**
  String get teacherAuditPenalties;

  /// No description provided for @teacherAuditBonuses.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get teacherAuditBonuses;

  /// No description provided for @teacherAuditAdminAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Admin adjustment'**
  String get teacherAuditAdminAdjustment;

  /// No description provided for @teacherAuditDisputeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get teacherAuditDisputeFieldLabel;

  /// No description provided for @auditPaymentCalculation.
  ///
  /// In en, this message translates to:
  /// **'Calculation'**
  String get auditPaymentCalculation;

  /// No description provided for @auditHoursWorked.
  ///
  /// In en, this message translates to:
  /// **'Hours worked'**
  String get auditHoursWorked;

  /// No description provided for @auditTotalAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Total adjustments'**
  String get auditTotalAdjustments;

  /// No description provided for @auditNetToPay.
  ///
  /// In en, this message translates to:
  /// **'NET TO PAY'**
  String get auditNetToPay;

  /// No description provided for @auditNoPaymentDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No payment data available'**
  String get auditNoPaymentDataAvailable;

  /// No description provided for @auditPaymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment summary'**
  String get auditPaymentSummary;

  /// No description provided for @auditGrossSalary.
  ///
  /// In en, this message translates to:
  /// **'Gross salary'**
  String get auditGrossSalary;

  /// No description provided for @auditNetSalary.
  ///
  /// In en, this message translates to:
  /// **'Net salary'**
  String get auditNetSalary;

  /// No description provided for @auditAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get auditAdjustments;

  /// No description provided for @auditGlobalAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Global adjustment'**
  String get auditGlobalAdjustment;

  /// No description provided for @formTemplates.
  ///
  /// In en, this message translates to:
  /// **'Form Templates'**
  String get formTemplates;

  /// No description provided for @formTitle.
  ///
  /// In en, this message translates to:
  /// **'Form Title'**
  String get formTitle;

  /// No description provided for @formsCompliance.
  ///
  /// In en, this message translates to:
  /// **'Forms Compliance'**
  String get formsCompliance;

  /// No description provided for @formsReports.
  ///
  /// In en, this message translates to:
  /// **'Forms Reports'**
  String get formsReports;

  /// No description provided for @founder.
  ///
  /// In en, this message translates to:
  /// **'Founder'**
  String get founder;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @fromBasicArithmeticToAdvancedCalculus.
  ///
  /// In en, this message translates to:
  /// **'From Basic Arithmetic To Advanced Calculus'**
  String get fromBasicArithmeticToAdvancedCalculus;

  /// No description provided for @fromLogicalThinkingForKidsTo.
  ///
  /// In en, this message translates to:
  /// **'From Logical Thinking For Kids To'**
  String get fromLogicalThinkingForKidsTo;

  /// No description provided for @fromMasteringEnglishGrammarAndVocabulary.
  ///
  /// In en, this message translates to:
  /// **'From Mastering English Grammar And Vocabulary'**
  String get fromMasteringEnglishGrammarAndVocabulary;

  /// No description provided for @fromParentdisplayForStudentSStudentdisplay.
  ///
  /// In en, this message translates to:
  /// **'From Parentdisplay For Student SStudentdisplay'**
  String get fromParentdisplayForStudentSStudentdisplay;

  /// No description provided for @fromParentnameForStudentSStudentname.
  ///
  /// In en, this message translates to:
  /// **'From Parentname For Student SStudentname'**
  String get fromParentnameForStudentSStudentname;

  /// No description provided for @fromSupportAlluwaleducationhubOrg.
  ///
  /// In en, this message translates to:
  /// **'From Support Alluwaleducationhub Org'**
  String get fromSupportAlluwaleducationhubOrg;

  /// No description provided for @fullAdmin.
  ///
  /// In en, this message translates to:
  /// **'Full Admin'**
  String get fullAdmin;

  /// No description provided for @fullAdminPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Full Admin Privileges'**
  String get fullAdminPrivileges;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @generateAudits.
  ///
  /// In en, this message translates to:
  /// **'Generate Audits'**
  String get generateAudits;

  /// No description provided for @generateNow.
  ///
  /// In en, this message translates to:
  /// **'Generate Now'**
  String get generateNow;

  /// No description provided for @generatingCsv.
  ///
  /// In en, this message translates to:
  /// **'Generating Csv'**
  String get generatingCsv;

  /// No description provided for @generatingExcelReport.
  ///
  /// In en, this message translates to:
  /// **'Generating Excel Report'**
  String get generatingExcelReport;

  /// No description provided for @getHelpContactUs.
  ///
  /// In en, this message translates to:
  /// **'Get Help Contact Us'**
  String get getHelpContactUs;

  /// No description provided for @getHelpUsingTheApp.
  ///
  /// In en, this message translates to:
  /// **'Get Help Using The App'**
  String get getHelpUsingTheApp;

  /// No description provided for @getInTouch.
  ///
  /// In en, this message translates to:
  /// **'Get In Touch'**
  String get getInTouch;

  /// No description provided for @getNotifiedBeforeTaskDueDate.
  ///
  /// In en, this message translates to:
  /// **'Get Notified Before Task Due Date'**
  String get getNotifiedBeforeTaskDueDate;

  /// No description provided for @getNotifiedBeforeYourShiftStarts.
  ///
  /// In en, this message translates to:
  /// **'Get Notified Before Your Shift Starts'**
  String get getNotifiedBeforeYourShiftStarts;

  /// No description provided for @getNotifiedWhenYouReceiveMessages.
  ///
  /// In en, this message translates to:
  /// **'Get Notified When You Receive Messages'**
  String get getNotifiedWhenYouReceiveMessages;

  /// No description provided for @gettingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Getting Notifications'**
  String get gettingNotifications;

  /// No description provided for @globalLanguagesProgram.
  ///
  /// In en, this message translates to:
  /// **'Global Languages Program'**
  String get globalLanguagesProgram;

  /// No description provided for @globalTeacherHourlyRateUsd.
  ///
  /// In en, this message translates to:
  /// **'Global Teacher Hourly Rate Usd'**
  String get globalTeacherHourlyRateUsd;

  /// No description provided for @goToSite.
  ///
  /// In en, this message translates to:
  /// **'Go To Site'**
  String get goToSite;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got It'**
  String get gotIt;

  /// No description provided for @gradePerformance.
  ///
  /// In en, this message translates to:
  /// **'Grade Performance'**
  String get gradePerformance;

  /// No description provided for @greenWelcomeEmailForNewUsers.
  ///
  /// In en, this message translates to:
  /// **'Green Welcome Email For New Users'**
  String get greenWelcomeEmailForNewUsers;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get gridView;

  /// No description provided for @groupBy.
  ///
  /// In en, this message translates to:
  /// **'Group By'**
  String get groupBy;

  /// No description provided for @groupChat.
  ///
  /// In en, this message translates to:
  /// **'Group Chat'**
  String get groupChat;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group Info'**
  String get groupInfo;

  /// No description provided for @guestClassLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Guest Class Link Copied'**
  String get guestClassLinkCopied;

  /// No description provided for @hasAudit.
  ///
  /// In en, this message translates to:
  /// **'Has Audit'**
  String get hasAudit;

  /// No description provided for @hassimiouNiane.
  ///
  /// In en, this message translates to:
  /// **'Hassimiou Niane'**
  String get hassimiouNiane;

  /// No description provided for @healthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @heroSection.
  ///
  /// In en, this message translates to:
  /// **'Hero Section'**
  String get heroSection;

  /// No description provided for @heroSectionEditor.
  ///
  /// In en, this message translates to:
  /// **'Hero Section Editor'**
  String get heroSectionEditor;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @highSchoolStudent.
  ///
  /// In en, this message translates to:
  /// **'High School Student'**
  String get highSchoolStudent;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @hn.
  ///
  /// In en, this message translates to:
  /// **'Hn'**
  String get hn;

  /// No description provided for @hourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get hourlyRate;

  /// No description provided for @hourlyRateUsd.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate Usd'**
  String get hourlyRateUsd;

  /// No description provided for @hourlyWage.
  ///
  /// In en, this message translates to:
  /// **'Hourly Wage'**
  String get hourlyWage;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @hoursBySubject.
  ///
  /// In en, this message translates to:
  /// **'Hours By Subject'**
  String get hoursBySubject;

  /// No description provided for @hoursTaught.
  ///
  /// In en, this message translates to:
  /// **'Hours Taught'**
  String get hoursTaught;

  /// No description provided for @howToJoinAClass.
  ///
  /// In en, this message translates to:
  /// **'How To Join AClass'**
  String get howToJoinAClass;

  /// No description provided for @howWeUseYourInformation.
  ///
  /// In en, this message translates to:
  /// **'How We Use Your Information'**
  String get howWeUseYourInformation;

  /// No description provided for @iAmABeginner.
  ///
  /// In en, this message translates to:
  /// **'I Am ABeginner'**
  String get iAmABeginner;

  /// No description provided for @iAmExcellent.
  ///
  /// In en, this message translates to:
  /// **'I Am Excellent'**
  String get iAmExcellent;

  /// No description provided for @iAmIntermediate.
  ///
  /// In en, this message translates to:
  /// **'I Am Intermediate'**
  String get iAmIntermediate;

  /// No description provided for @iMemorizeLessThanJuzuAnma.
  ///
  /// In en, this message translates to:
  /// **'I Memorize Less Than Juzu Anma'**
  String get iMemorizeLessThanJuzuAnma;

  /// No description provided for @iconDescription.
  ///
  /// In en, this message translates to:
  /// **'Icon Description'**
  String get iconDescription;

  /// No description provided for @idCode.
  ///
  /// In en, this message translates to:
  /// **'Id Code'**
  String get idCode;

  /// No description provided for @idDisplaystudentcode.
  ///
  /// In en, this message translates to:
  /// **'ID: {studentCode}'**
  String idDisplaystudentcode(Object studentCode);

  /// No description provided for @ifLeftBlankASecurePassword.
  ///
  /// In en, this message translates to:
  /// **'If Left Blank ASecure Password'**
  String get ifLeftBlankASecurePassword;

  /// No description provided for @ifYouBelieveThereSAn.
  ///
  /// In en, this message translates to:
  /// **'If You Believe There SAn'**
  String get ifYouBelieveThereSAn;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image Upload Failed'**
  String get imageUploadFailed;

  /// No description provided for @immerseInTheProfoundNdepthsOf.
  ///
  /// In en, this message translates to:
  /// **'Immerse In The Profound Ndepths Of'**
  String get immerseInTheProfoundNdepthsOf;

  /// No description provided for @inAMonthFromNow.
  ///
  /// In en, this message translates to:
  /// **'In AMonth From Now'**
  String get inAMonthFromNow;

  /// No description provided for @inOneWeekFromNow.
  ///
  /// In en, this message translates to:
  /// **'In One Week From Now'**
  String get inOneWeekFromNow;

  /// No description provided for @inThreeWeeksFromNow.
  ///
  /// In en, this message translates to:
  /// **'In Three Weeks From Now'**
  String get inThreeWeeksFromNow;

  /// No description provided for @inTwoWeeksFromNow.
  ///
  /// In en, this message translates to:
  /// **'In Two Weeks From Now'**
  String get inTwoWeeksFromNow;

  /// No description provided for @individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get individual;

  /// No description provided for @individualUser.
  ///
  /// In en, this message translates to:
  /// **'Individual User'**
  String get individualUser;

  /// No description provided for @informationWeCollect.
  ///
  /// In en, this message translates to:
  /// **'Information We Collect'**
  String get informationWeCollect;

  /// No description provided for @initializingApplication.
  ///
  /// In en, this message translates to:
  /// **'Initializing Application'**
  String get initializingApplication;

  /// No description provided for @interactiveLearningExperience.
  ///
  /// In en, this message translates to:
  /// **'Interactive Learning Experience'**
  String get interactiveLearningExperience;

  /// No description provided for @internalName.
  ///
  /// In en, this message translates to:
  /// **'Internal Name'**
  String get internalName;

  /// No description provided for @invoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Invoice Details'**
  String get invoiceDetails;

  /// No description provided for @invoiceNotFoundForThisPayment.
  ///
  /// In en, this message translates to:
  /// **'Invoice Not Found For This Payment'**
  String get invoiceNotFoundForThisPayment;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @isAdminIsadmin.
  ///
  /// In en, this message translates to:
  /// **'Is Admin Isadmin'**
  String get isAdminIsadmin;

  /// No description provided for @isParentIsparent.
  ///
  /// In en, this message translates to:
  /// **'Is Parent Isparent'**
  String get isParentIsparent;

  /// No description provided for @isStudentIsstudent.
  ///
  /// In en, this message translates to:
  /// **'Is Student Isstudent'**
  String get isStudentIsstudent;

  /// No description provided for @isTeacherIsteacher.
  ///
  /// In en, this message translates to:
  /// **'Is Teacher Isteacher'**
  String get isTeacherIsteacher;

  /// No description provided for @islamicCalendar.
  ///
  /// In en, this message translates to:
  /// **'Islamic Calendar'**
  String get islamicCalendar;

  /// No description provided for @islamicPrograms.
  ///
  /// In en, this message translates to:
  /// **'Islamic Programs'**
  String get islamicPrograms;

  /// No description provided for @islamicStudiesTeacher.
  ///
  /// In en, this message translates to:
  /// **'Islamic Studies Teacher'**
  String get islamicStudiesTeacher;

  /// No description provided for @issuesFlags.
  ///
  /// In en, this message translates to:
  /// **'Issues Flags'**
  String get issuesFlags;

  /// No description provided for @issuesToAddress.
  ///
  /// In en, this message translates to:
  /// **'Issues To Address'**
  String get issuesToAddress;

  /// No description provided for @janeSmithEmailCom.
  ///
  /// In en, this message translates to:
  /// **'Jane Smith Email Com'**
  String get janeSmithEmailCom;

  /// No description provided for @johnDoeEmailCom.
  ///
  /// In en, this message translates to:
  /// **'John Doe Email Com'**
  String get johnDoeEmailCom;

  /// No description provided for @joinClass.
  ///
  /// In en, this message translates to:
  /// **'Join Class'**
  String get joinClass;

  /// No description provided for @joinLiveClass.
  ///
  /// In en, this message translates to:
  /// **'Join Live Class'**
  String get joinLiveClass;

  /// No description provided for @joinLiveClasses.
  ///
  /// In en, this message translates to:
  /// **'Join Live Classes'**
  String get joinLiveClasses;

  /// No description provided for @joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get joinNow;

  /// No description provided for @joinOurLeadershipTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Our Leadership Team'**
  String get joinOurLeadershipTeam;

  /// No description provided for @joinOurLeadershipTeam2.
  ///
  /// In en, this message translates to:
  /// **'Join Our Leadership Team2'**
  String get joinOurLeadershipTeam2;

  /// No description provided for @joinOurTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Our Team'**
  String get joinOurTeam;

  /// No description provided for @joinOurTeamOfDedicatedIslamic.
  ///
  /// In en, this message translates to:
  /// **'Join Our Team Of Dedicated Islamic'**
  String get joinOurTeamOfDedicatedIslamic;

  /// No description provided for @joinThousandsOfMuslimFamiliesWorldwide.
  ///
  /// In en, this message translates to:
  /// **'Join Thousands Of Muslim Families Worldwide'**
  String get joinThousandsOfMuslimFamiliesWorldwide;

  /// No description provided for @joinThousandsOfStudentsExcellingIn.
  ///
  /// In en, this message translates to:
  /// **'Join Thousands Of Students Excelling In'**
  String get joinThousandsOfStudentsExcellingIn;

  /// No description provided for @joinThousandsOfStudentsLearningFrom.
  ///
  /// In en, this message translates to:
  /// **'Join Thousands Of Students Learning From'**
  String get joinThousandsOfStudentsLearningFrom;

  /// No description provided for @joiningClass.
  ///
  /// In en, this message translates to:
  /// **'Joining Class'**
  String get joiningClass;

  /// No description provided for @jpgPngGifUpTo10mb.
  ///
  /// In en, this message translates to:
  /// **'Jpg Png Gif Up To10mb'**
  String get jpgPngGifUpTo10mb;

  /// No description provided for @jumpToDate.
  ///
  /// In en, this message translates to:
  /// **'Jump To Date'**
  String get jumpToDate;

  /// No description provided for @k12Support.
  ///
  /// In en, this message translates to:
  /// **'K12Support'**
  String get k12Support;

  /// No description provided for @keepTheirTeacherRoleIntact.
  ///
  /// In en, this message translates to:
  /// **'Keep Their Teacher Role Intact'**
  String get keepTheirTeacherRoleIntact;

  /// No description provided for @keyPerformanceIndicators.
  ///
  /// In en, this message translates to:
  /// **'Key Performance Indicators'**
  String get keyPerformanceIndicators;

  /// No description provided for @kioskCode.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Code'**
  String get kioskCode;

  /// No description provided for @kioskCodeKioskcodeAlreadyExistsPlease.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Code Kioskcode Already Exists Please'**
  String get kioskCodeKioskcodeAlreadyExistsPlease;

  /// No description provided for @laDureEDoitETre.
  ///
  /// In en, this message translates to:
  /// **'La Dure EDoit ETre'**
  String get laDureEDoitETre;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @label2.
  ///
  /// In en, this message translates to:
  /// **'Label2'**
  String get label2;

  /// No description provided for @labelCopied.
  ///
  /// In en, this message translates to:
  /// **'Label Copied'**
  String get labelCopied;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label Optional'**
  String get labelOptional;

  /// No description provided for @labelValue.
  ///
  /// In en, this message translates to:
  /// **'Label Value'**
  String get labelValue;

  /// No description provided for @labelsOptional.
  ///
  /// In en, this message translates to:
  /// **'Labels Optional'**
  String get labelsOptional;

  /// No description provided for @languageExcellence.
  ///
  /// In en, this message translates to:
  /// **'Language Excellence'**
  String get languageExcellence;

  /// No description provided for @languagesWeOffer.
  ///
  /// In en, this message translates to:
  /// **'Languages We Offer'**
  String get languagesWeOffer;

  /// No description provided for @last24Hours.
  ///
  /// In en, this message translates to:
  /// **'Last24Hours'**
  String get last24Hours;

  /// No description provided for @lastClassCompleted.
  ///
  /// In en, this message translates to:
  /// **'Last Class Completed'**
  String get lastClassCompleted;

  /// No description provided for @lastLogin.
  ///
  /// In en, this message translates to:
  /// **'Last Login'**
  String get lastLogin;

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Last Modified'**
  String get lastModified;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @lastName2.
  ///
  /// In en, this message translates to:
  /// **'Last Name2'**
  String get lastName2;

  /// No description provided for @lastSystemCheck.
  ///
  /// In en, this message translates to:
  /// **'Last System Check'**
  String get lastSystemCheck;

  /// No description provided for @lastTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Last Task Completed'**
  String get lastTaskCompleted;

  /// No description provided for @lastUpdatedJanuary2024.
  ///
  /// In en, this message translates to:
  /// **'Last Updated January2024'**
  String get lastUpdatedJanuary2024;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @lePaiementSeraCalculeDureE.
  ///
  /// In en, this message translates to:
  /// **'Le Paiement Sera Calcule Dure E'**
  String get lePaiementSeraCalculeDureE;

  /// No description provided for @leSujetEstRequis.
  ///
  /// In en, this message translates to:
  /// **'Le Sujet Est Requis'**
  String get leSujetEstRequis;

  /// No description provided for @leadInspireAndMakeALasting.
  ///
  /// In en, this message translates to:
  /// **'Lead Inspire And Make ALasting'**
  String get leadInspireAndMakeALasting;

  /// No description provided for @leaderDuty.
  ///
  /// In en, this message translates to:
  /// **'Leader Duty'**
  String get leaderDuty;

  /// No description provided for @leadersOnly.
  ///
  /// In en, this message translates to:
  /// **'Leaders Only'**
  String get leadersOnly;

  /// No description provided for @leadershipInterest.
  ///
  /// In en, this message translates to:
  /// **'Leadership Interest'**
  String get leadershipInterest;

  /// No description provided for @learnEnglishReadingWritingSpeakingFor.
  ///
  /// In en, this message translates to:
  /// **'Learn English Reading Writing Speaking For'**
  String get learnEnglishReadingWritingSpeakingFor;

  /// No description provided for @learnFromCertifiedNislamicScholars.
  ///
  /// In en, this message translates to:
  /// **'Learn From Certified Nislamic Scholars'**
  String get learnFromCertifiedNislamicScholars;

  /// No description provided for @learnLeadThrive.
  ///
  /// In en, this message translates to:
  /// **'Learn Lead Thrive'**
  String get learnLeadThrive;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get learnMore;

  /// No description provided for @learningTracks.
  ///
  /// In en, this message translates to:
  /// **'Learning Tracks'**
  String get learningTracks;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveClass.
  ///
  /// In en, this message translates to:
  /// **'Leave Class'**
  String get leaveClass;

  /// No description provided for @lessComfortable.
  ///
  /// In en, this message translates to:
  /// **'Less Comfortable'**
  String get lessComfortable;

  /// No description provided for @letSGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Let SGet Started'**
  String get letSGetStarted;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @linkForm.
  ///
  /// In en, this message translates to:
  /// **'Link Form'**
  String get linkForm;

  /// No description provided for @linkFormToShift.
  ///
  /// In en, this message translates to:
  /// **'Link Form To Shift'**
  String get linkFormToShift;

  /// No description provided for @linkToShift.
  ///
  /// In en, this message translates to:
  /// **'Link To Shift'**
  String get linkToShift;

  /// No description provided for @linkYourAccountToManageAll.
  ///
  /// In en, this message translates to:
  /// **'Link Your Account To Manage All'**
  String get linkYourAccountToManageAll;

  /// No description provided for @linkingFormAndRecalculatingPayment.
  ///
  /// In en, this message translates to:
  /// **'Linking Form And Recalculating Payment'**
  String get linkingFormAndRecalculatingPayment;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get listView;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @live2.
  ///
  /// In en, this message translates to:
  /// **'Live2'**
  String get live2;

  /// No description provided for @liveOnJobBoard.
  ///
  /// In en, this message translates to:
  /// **'Live On Job Board'**
  String get liveOnJobBoard;

  /// No description provided for @liveParticipants.
  ///
  /// In en, this message translates to:
  /// **'Live Participants'**
  String get liveParticipants;

  /// No description provided for @livePreview.
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get livePreview;

  /// No description provided for @liveWebinars.
  ///
  /// In en, this message translates to:
  /// **'Live Webinars'**
  String get liveWebinars;

  /// No description provided for @loadUserRole.
  ///
  /// In en, this message translates to:
  /// **'Load User Role'**
  String get loadUserRole;

  /// No description provided for @loadUserRoleFirst.
  ///
  /// In en, this message translates to:
  /// **'Load User Role First'**
  String get loadUserRoleFirst;

  /// No description provided for @loadingAuditsForSelectedyearmonth.
  ///
  /// In en, this message translates to:
  /// **'Loading audits…'**
  String get loadingAuditsForSelectedyearmonth;

  /// No description provided for @loadingDashboard.
  ///
  /// In en, this message translates to:
  /// **'Loading Dashboard'**
  String get loadingDashboard;

  /// No description provided for @loadingEvaluationFactors.
  ///
  /// In en, this message translates to:
  /// **'Loading Evaluation Factors'**
  String get loadingEvaluationFactors;

  /// No description provided for @loadingForms.
  ///
  /// In en, this message translates to:
  /// **'Loading Forms'**
  String get loadingForms;

  /// No description provided for @loadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading Messages'**
  String get loadingMessages;

  /// No description provided for @loadingPrayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Loading Prayer Times'**
  String get loadingPrayerTimes;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading Profile'**
  String get loadingProfile;

  /// No description provided for @loadingSeries.
  ///
  /// In en, this message translates to:
  /// **'Loading Series'**
  String get loadingSeries;

  /// No description provided for @loadingShiftInformation.
  ///
  /// In en, this message translates to:
  /// **'Loading Shift Information'**
  String get loadingShiftInformation;

  /// No description provided for @loadingStudents.
  ///
  /// In en, this message translates to:
  /// **'Loading Students'**
  String get loadingStudents;

  /// No description provided for @loadingTeachers.
  ///
  /// In en, this message translates to:
  /// **'Loading Teachers'**
  String get loadingTeachers;

  /// No description provided for @loadingUserProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading User Profile'**
  String get loadingUserProfile;

  /// No description provided for @loadingWebsiteContent.
  ///
  /// In en, this message translates to:
  /// **'Loading Website Content'**
  String get loadingWebsiteContent;

  /// No description provided for @loadingYourExistingProfileInformation.
  ///
  /// In en, this message translates to:
  /// **'Loading Your Existing Profile Information'**
  String get loadingYourExistingProfileInformation;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Location Error'**
  String get locationError;

  /// No description provided for @locationInformation.
  ///
  /// In en, this message translates to:
  /// **'Location Information'**
  String get locationInformation;

  /// No description provided for @locationInformationRequired.
  ///
  /// In en, this message translates to:
  /// **'Location Information Required'**
  String get locationInformationRequired;

  /// No description provided for @locationInformationWasNotCapturedFor.
  ///
  /// In en, this message translates to:
  /// **'Location Information Was Not Captured For'**
  String get locationInformationWasNotCapturedFor;

  /// No description provided for @locationIsMandatoryForAllTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Location Is Mandatory For All Timesheet'**
  String get locationIsMandatoryForAllTimesheet;

  /// No description provided for @locationIsMandatoryPleaseWaitFor.
  ///
  /// In en, this message translates to:
  /// **'Location Is Mandatory Please Wait For'**
  String get locationIsMandatoryPleaseWaitFor;

  /// No description provided for @locationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location Optional'**
  String get locationOptional;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @logInSignUp.
  ///
  /// In en, this message translates to:
  /// **'Log In Sign Up'**
  String get logInSignUp;

  /// No description provided for @logOutOfYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Log Out Of Your Account'**
  String get logOutOfYourAccount;

  /// No description provided for @loginLogs.
  ///
  /// In en, this message translates to:
  /// **'Login Logs'**
  String get loginLogs;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @longAnswerText.
  ///
  /// In en, this message translates to:
  /// **'Long Answer Text'**
  String get longAnswerText;

  /// No description provided for @mainHeadline.
  ///
  /// In en, this message translates to:
  /// **'Main Headline'**
  String get mainHeadline;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @manageIndividualWages.
  ///
  /// In en, this message translates to:
  /// **'Manage Individual Wages'**
  String get manageIndividualWages;

  /// No description provided for @manageRoleBasedWages.
  ///
  /// In en, this message translates to:
  /// **'Manage Role Based Wages'**
  String get manageRoleBasedWages;

  /// No description provided for @manageShift.
  ///
  /// In en, this message translates to:
  /// **'Manage Shift'**
  String get manageShift;

  /// No description provided for @manageStudentApplicationsAndEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Manage Student Applications And Enrollment'**
  String get manageStudentApplicationsAndEnrollment;

  /// No description provided for @manageSubjects.
  ///
  /// In en, this message translates to:
  /// **'Manage Subjects'**
  String get manageSubjects;

  /// No description provided for @manageSubjectsForShiftCreation.
  ///
  /// In en, this message translates to:
  /// **'Manage Subjects For Shift Creation'**
  String get manageSubjectsForShiftCreation;

  /// No description provided for @manageTeacherPerformanceAndPayments.
  ///
  /// In en, this message translates to:
  /// **'Manage Teacher Performance And Payments'**
  String get manageTeacherPerformanceAndPayments;

  /// No description provided for @managerNotes.
  ///
  /// In en, this message translates to:
  /// **'Manager Notes'**
  String get managerNotes;

  /// No description provided for @managerNotes2.
  ///
  /// In en, this message translates to:
  /// **'Manager Notes2'**
  String get managerNotes2;

  /// No description provided for @markAsPending.
  ///
  /// In en, this message translates to:
  /// **'Mark As Pending'**
  String get markAsPending;

  /// No description provided for @markAsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark As Reviewed'**
  String get markAsReviewed;

  /// No description provided for @markedAsContactedMovedToReady.
  ///
  /// In en, this message translates to:
  /// **'Marked As Contacted Moved To Ready'**
  String get markedAsContactedMovedToReady;

  /// No description provided for @masterEnglishAfricanNindigenousLanguages.
  ///
  /// In en, this message translates to:
  /// **'Master English African Nindigenous Languages'**
  String get masterEnglishAfricanNindigenousLanguages;

  /// No description provided for @masterEnglishWithNconfidenceFluency.
  ///
  /// In en, this message translates to:
  /// **'Master English With Nconfidence Fluency'**
  String get masterEnglishWithNconfidenceFluency;

  /// No description provided for @masterMathematicsWithNconfidenceClarity.
  ///
  /// In en, this message translates to:
  /// **'Master Mathematics With Nconfidence Clarity'**
  String get masterMathematicsWithNconfidenceClarity;

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get matched;

  /// No description provided for @mathematicsIsMoreThanJustNumbers.
  ///
  /// In en, this message translates to:
  /// **'Mathematics Is More Than Just Numbers'**
  String get mathematicsIsMoreThanJustNumbers;

  /// No description provided for @mathematicsProgram.
  ///
  /// In en, this message translates to:
  /// **'Mathematics Program'**
  String get mathematicsProgram;

  /// No description provided for @mayAllahBlessYourTeachingEfforts.
  ///
  /// In en, this message translates to:
  /// **'May Allah Bless Your Teaching Efforts'**
  String get mayAllahBlessYourTeachingEfforts;

  /// No description provided for @maybeButIWillTry.
  ///
  /// In en, this message translates to:
  /// **'Maybe But IWill Try'**
  String get maybeButIWillTry;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @meetingIsNotReadyYetContact.
  ///
  /// In en, this message translates to:
  /// **'Meeting Is Not Ready Yet Contact'**
  String get meetingIsNotReadyYetContact;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @messageDeletionNotYetImplemented.
  ///
  /// In en, this message translates to:
  /// **'Message Deletion Not Yet Implemented'**
  String get messageDeletionNotYetImplemented;

  /// No description provided for @messageForwardingNotYetImplemented.
  ///
  /// In en, this message translates to:
  /// **'Message Forwarding Not Yet Implemented'**
  String get messageForwardingNotYetImplemented;

  /// No description provided for @messageSentSuccessfullyWeWillContact.
  ///
  /// In en, this message translates to:
  /// **'Message Sent Successfully We Will Contact'**
  String get messageSentSuccessfullyWeWillContact;

  /// No description provided for @methodFirebaseCloudFunctionHostingerSmtp.
  ///
  /// In en, this message translates to:
  /// **'Method Firebase Cloud Function Hostinger Smtp'**
  String get methodFirebaseCloudFunctionHostingerSmtp;

  /// No description provided for @minutesMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes Minutes'**
  String get minutesMinutes;

  /// No description provided for @missedShiftClassReportRequired.
  ///
  /// In en, this message translates to:
  /// **'Missed Shift Class Report Required'**
  String get missedShiftClassReportRequired;

  /// No description provided for @mobilePhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile Phone'**
  String get mobilePhone;

  /// No description provided for @modificationHistory.
  ///
  /// In en, this message translates to:
  /// **'Modification History'**
  String get modificationHistory;

  /// No description provided for @modifiedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Modified Schedule'**
  String get modifiedSchedule;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @monthlyFeesPayment.
  ///
  /// In en, this message translates to:
  /// **'Monthly Fees Payment'**
  String get monthlyFeesPayment;

  /// No description provided for @monthlyRecurrenceSettings.
  ///
  /// In en, this message translates to:
  /// **'Monthly Recurrence Settings'**
  String get monthlyRecurrenceSettings;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @moveAllShifts1HourEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move All Shifts1Hour Earlier'**
  String get moveAllShifts1HourEarlier;

  /// No description provided for @moveAllShifts1HourLater.
  ///
  /// In en, this message translates to:
  /// **'Move All Shifts1Hour Later'**
  String get moveAllShifts1HourLater;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDown;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUp;

  /// No description provided for @muteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute All'**
  String get muteAll;

  /// No description provided for @muteEveryone.
  ///
  /// In en, this message translates to:
  /// **'Mute Everyone'**
  String get muteEveryone;

  /// No description provided for @myAssignments.
  ///
  /// In en, this message translates to:
  /// **'My Assignments'**
  String get myAssignments;

  /// No description provided for @myChildren.
  ///
  /// In en, this message translates to:
  /// **'My Children'**
  String get myChildren;

  /// No description provided for @myClasses.
  ///
  /// In en, this message translates to:
  /// **'My Classes'**
  String get myClasses;

  /// No description provided for @myIslamicClasses.
  ///
  /// In en, this message translates to:
  /// **'My Islamic Classes'**
  String get myIslamicClasses;

  /// No description provided for @myMonthlyReport.
  ///
  /// In en, this message translates to:
  /// **'My Monthly Report'**
  String get myMonthlyReport;

  /// No description provided for @myPerformanceAudit.
  ///
  /// In en, this message translates to:
  /// **'My Performance Audit'**
  String get myPerformanceAudit;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My Progress'**
  String get myProgress;

  /// No description provided for @myStudents.
  ///
  /// In en, this message translates to:
  /// **'My Students'**
  String get myStudents;

  /// No description provided for @myStudentsOverview.
  ///
  /// In en, this message translates to:
  /// **'My Students Overview'**
  String get myStudentsOverview;

  /// No description provided for @nA.
  ///
  /// In en, this message translates to:
  /// **'N A'**
  String get nA;

  /// No description provided for @nameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name AZ'**
  String get nameAZ;

  /// No description provided for @navigatingToAddNewUser.
  ///
  /// In en, this message translates to:
  /// **'Navigating To Add New User'**
  String get navigatingToAddNewUser;

  /// No description provided for @navigatingToFormBuilder.
  ///
  /// In en, this message translates to:
  /// **'Navigating To Form Builder'**
  String get navigatingToFormBuilder;

  /// No description provided for @navigatingToReports.
  ///
  /// In en, this message translates to:
  /// **'Navigating To Reports'**
  String get navigatingToReports;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @needHelpWeReHereFor.
  ///
  /// In en, this message translates to:
  /// **'Need Help We Re Here For'**
  String get needHelpWeReHereFor;

  /// No description provided for @needsRevision.
  ///
  /// In en, this message translates to:
  /// **'Needs Revision'**
  String get needsRevision;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @neverLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Never Logged In'**
  String get neverLoggedIn;

  /// No description provided for @neverMissAClass.
  ///
  /// In en, this message translates to:
  /// **'Never Miss AClass'**
  String get neverMissAClass;

  /// No description provided for @newEndTime.
  ///
  /// In en, this message translates to:
  /// **'New End Time'**
  String get newEndTime;

  /// No description provided for @newHourlyWage.
  ///
  /// In en, this message translates to:
  /// **'New Hourly Wage'**
  String get newHourlyWage;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @newStartTime.
  ///
  /// In en, this message translates to:
  /// **'New Start Time'**
  String get newStartTime;

  /// No description provided for @newStudentWillBeLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'New Student Will Be Linked To'**
  String get newStudentWillBeLinkedTo;

  /// No description provided for @newVersion.
  ///
  /// In en, this message translates to:
  /// **'New Version'**
  String get newVersion;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get newestFirst;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next Week'**
  String get nextWeek;

  /// No description provided for @noActiveFormsFound.
  ///
  /// In en, this message translates to:
  /// **'No Active Forms Found'**
  String get noActiveFormsFound;

  /// No description provided for @noActiveShift.
  ///
  /// In en, this message translates to:
  /// **'No Active Shift'**
  String get noActiveShift;

  /// No description provided for @noAdminUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No Admin Users Found'**
  String get noAdminUsersFound;

  /// No description provided for @noApplicationsFound.
  ///
  /// In en, this message translates to:
  /// **'No Applications Found'**
  String get noApplicationsFound;

  /// No description provided for @noAssignmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Assignments Yet'**
  String get noAssignmentsYet;

  /// No description provided for @noAttachments.
  ///
  /// In en, this message translates to:
  /// **'No Attachments'**
  String get noAttachments;

  /// No description provided for @noAttachmentsAdded.
  ///
  /// In en, this message translates to:
  /// **'No Attachments Added'**
  String get noAttachmentsAdded;

  /// No description provided for @noAttachmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Attachments Yet'**
  String get noAttachmentsYet;

  /// No description provided for @noAuditDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Audit Data Available'**
  String get noAuditDataAvailable;

  /// No description provided for @noAuditDataForSelectedmonth.
  ///
  /// In en, this message translates to:
  /// **'No Audit Data For Selectedmonth'**
  String get noAuditDataForSelectedmonth;

  /// No description provided for @noAuditsFound.
  ///
  /// In en, this message translates to:
  /// **'No Audits Found'**
  String get noAuditsFound;

  /// No description provided for @noAvailableShifts.
  ///
  /// In en, this message translates to:
  /// **'No Available Shifts'**
  String get noAvailableShifts;

  /// No description provided for @noChildrenLinkedToThisParent.
  ///
  /// In en, this message translates to:
  /// **'No Children Linked To This Parent'**
  String get noChildrenLinkedToThisParent;

  /// No description provided for @noClassHistory.
  ///
  /// In en, this message translates to:
  /// **'No Class History'**
  String get noClassHistory;

  /// No description provided for @noClassesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Classes Available'**
  String get noClassesAvailable;

  /// No description provided for @noClassesFound.
  ///
  /// In en, this message translates to:
  /// **'No Classes Found'**
  String get noClassesFound;

  /// No description provided for @noClassesRightNow.
  ///
  /// In en, this message translates to:
  /// **'No Classes Right Now'**
  String get noClassesRightNow;

  /// No description provided for @noClassesScheduledToday.
  ///
  /// In en, this message translates to:
  /// **'No Classes Scheduled Today'**
  String get noClassesScheduledToday;

  /// No description provided for @noClassesToday.
  ///
  /// In en, this message translates to:
  /// **'No Classes Today'**
  String get noClassesToday;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Comments Yet'**
  String get noCommentsYet;

  /// No description provided for @noCompleteRowsToSave.
  ///
  /// In en, this message translates to:
  /// **'No Complete Rows To Save'**
  String get noCompleteRowsToSave;

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Content Available'**
  String get noContentAvailable;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get noData;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Data Available'**
  String get noDataAvailable;

  /// No description provided for @noDataFoundToExport.
  ///
  /// In en, this message translates to:
  /// **'No Data Found To Export'**
  String get noDataFoundToExport;

  /// No description provided for @noDataToExport.
  ///
  /// In en, this message translates to:
  /// **'No Data To Export'**
  String get noDataToExport;

  /// No description provided for @noDataToExportWithCurrent.
  ///
  /// In en, this message translates to:
  /// **'No Data To Export With Current'**
  String get noDataToExportWithCurrent;

  /// No description provided for @noDataWillBePermanentlyLost.
  ///
  /// In en, this message translates to:
  /// **'No Data Will Be Permanently Lost'**
  String get noDataWillBePermanentlyLost;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No Data Yet'**
  String get noDataYet;

  /// No description provided for @noDevice.
  ///
  /// In en, this message translates to:
  /// **'No Device'**
  String get noDevice;

  /// No description provided for @noDocumentsFoundInThisCollection.
  ///
  /// In en, this message translates to:
  /// **'No Documents Found In This Collection'**
  String get noDocumentsFoundInThisCollection;

  /// No description provided for @noFieldsYetAddYourFirst.
  ///
  /// In en, this message translates to:
  /// **'No Fields Yet Add Your First'**
  String get noFieldsYetAddYourFirst;

  /// No description provided for @noFilesSelected.
  ///
  /// In en, this message translates to:
  /// **'No Files Selected'**
  String get noFilesSelected;

  /// No description provided for @noFilledOpportunitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No Filled Opportunities Yet'**
  String get noFilledOpportunitiesYet;

  /// No description provided for @noForm.
  ///
  /// In en, this message translates to:
  /// **'No Form'**
  String get noForm;

  /// No description provided for @noFormFieldsAreCurrentlyVisible.
  ///
  /// In en, this message translates to:
  /// **'No Form Fields Are Currently Visible'**
  String get noFormFieldsAreCurrentlyVisible;

  /// No description provided for @noFormResponsesFound.
  ///
  /// In en, this message translates to:
  /// **'No Form Responses Found'**
  String get noFormResponsesFound;

  /// No description provided for @noFormResponsesToExport.
  ///
  /// In en, this message translates to:
  /// **'No Form Responses To Export'**
  String get noFormResponsesToExport;

  /// No description provided for @noFormsFound.
  ///
  /// In en, this message translates to:
  /// **'No Forms Found'**
  String get noFormsFound;

  /// No description provided for @noFormsSubmittedForThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'No Forms Submitted For This Period'**
  String get noFormsSubmittedForThisPeriod;

  /// No description provided for @noFormsYet.
  ///
  /// In en, this message translates to:
  /// **'No Forms Yet'**
  String get noFormsYet;

  /// No description provided for @noICanT.
  ///
  /// In en, this message translates to:
  /// **'No ICan T'**
  String get noICanT;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get noInternet;

  /// No description provided for @noInvoicesFound.
  ///
  /// In en, this message translates to:
  /// **'No Invoices Found'**
  String get noInvoicesFound;

  /// No description provided for @noInvoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No Invoices Yet'**
  String get noInvoicesYet;

  /// No description provided for @noItemsOnThisInvoice.
  ///
  /// In en, this message translates to:
  /// **'No Items On This Invoice'**
  String get noItemsOnThisInvoice;

  /// No description provided for @noKnownStudentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Known Students Yet'**
  String get noKnownStudentsYet;

  /// No description provided for @noLabelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Labels Available'**
  String get noLabelsAvailable;

  /// No description provided for @noMatchingLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No Matching Logs Yet'**
  String get noMatchingLogsYet;

  /// No description provided for @noOneHasJoinedYet.
  ///
  /// In en, this message translates to:
  /// **'No One Has Joined Yet'**
  String get noOneHasJoinedYet;

  /// No description provided for @noOneIsInTheRoom.
  ///
  /// In en, this message translates to:
  /// **'No One Is In The Room'**
  String get noOneIsInTheRoom;

  /// No description provided for @noOptionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Options Available'**
  String get noOptionsAvailable;

  /// No description provided for @noOrphanShiftsFoundNearby.
  ///
  /// In en, this message translates to:
  /// **'No Orphan Shifts Found Nearby'**
  String get noOrphanShiftsFoundNearby;

  /// No description provided for @noParentsFound.
  ///
  /// In en, this message translates to:
  /// **'No Parents Found'**
  String get noParentsFound;

  /// No description provided for @noParticipants.
  ///
  /// In en, this message translates to:
  /// **'No Participants'**
  String get noParticipants;

  /// No description provided for @noParticipantsYet.
  ///
  /// In en, this message translates to:
  /// **'No Participants Yet'**
  String get noParticipantsYet;

  /// No description provided for @noPaymentDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Payment Data Available'**
  String get noPaymentDataAvailable;

  /// No description provided for @noPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Payments Yet'**
  String get noPaymentsYet;

  /// No description provided for @noRatesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No Rates Configured'**
  String get noRatesConfigured;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No Recent Activity'**
  String get noRecentActivity;

  /// No description provided for @noRecentLessons.
  ///
  /// In en, this message translates to:
  /// **'No Recent Lessons'**
  String get noRecentLessons;

  /// No description provided for @noRecentShiftsFoundToReport.
  ///
  /// In en, this message translates to:
  /// **'No Recent Shifts Found To Report'**
  String get noRecentShiftsFoundToReport;

  /// No description provided for @noResponse.
  ///
  /// In en, this message translates to:
  /// **'No Response'**
  String get noResponse;

  /// No description provided for @noResponseDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Response Data Available'**
  String get noResponseDataAvailable;

  /// No description provided for @noResponses.
  ///
  /// In en, this message translates to:
  /// **'No Responses'**
  String get noResponses;

  /// No description provided for @noResponsesFound.
  ///
  /// In en, this message translates to:
  /// **'No Responses Found'**
  String get noResponsesFound;

  /// No description provided for @noResponsesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No Responses Recorded'**
  String get noResponsesRecorded;

  /// No description provided for @noSavedDrafts.
  ///
  /// In en, this message translates to:
  /// **'No Saved Drafts'**
  String get noSavedDrafts;

  /// No description provided for @noScheduledShiftsFoundToDelete.
  ///
  /// In en, this message translates to:
  /// **'No Scheduled Shifts Found To Delete'**
  String get noScheduledShiftsFoundToDelete;

  /// No description provided for @noScheduledShiftsFoundToEdit.
  ///
  /// In en, this message translates to:
  /// **'No Scheduled Shifts Found To Edit'**
  String get noScheduledShiftsFoundToEdit;

  /// No description provided for @noShiftAssociated.
  ///
  /// In en, this message translates to:
  /// **'No Shift Associated'**
  String get noShiftAssociated;

  /// No description provided for @noShiftsOrFormsFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No Shifts Or Forms Found For'**
  String get noShiftsOrFormsFoundFor;

  /// No description provided for @noShiftsSelected.
  ///
  /// In en, this message translates to:
  /// **'No Shifts Selected'**
  String get noShiftsSelected;

  /// No description provided for @noShiftsWithFormsFoundLink.
  ///
  /// In en, this message translates to:
  /// **'No Shifts With Forms Found Link'**
  String get noShiftsWithFormsFoundLink;

  /// No description provided for @missedClassFormSubmittedRecovery.
  ///
  /// In en, this message translates to:
  /// **'Missed class • Form submitted (recovery)'**
  String get missedClassFormSubmittedRecovery;

  /// No description provided for @noStudentsAvailableInTheSystem.
  ///
  /// In en, this message translates to:
  /// **'No Students Available In The System'**
  String get noStudentsAvailableInTheSystem;

  /// No description provided for @noStudentsFound.
  ///
  /// In en, this message translates to:
  /// **'No Students Found'**
  String get noStudentsFound;

  /// No description provided for @noStudentsHaveJoinedTheClass.
  ///
  /// In en, this message translates to:
  /// **'No Students Have Joined The Class'**
  String get noStudentsHaveJoinedTheClass;

  /// No description provided for @noStudentsYet.
  ///
  /// In en, this message translates to:
  /// **'No Students Yet'**
  String get noStudentsYet;

  /// No description provided for @noSubTasksClickAddTo.
  ///
  /// In en, this message translates to:
  /// **'No Sub Tasks Click Add To'**
  String get noSubTasksClickAddTo;

  /// No description provided for @noSubjectData.
  ///
  /// In en, this message translates to:
  /// **'No Subject Data'**
  String get noSubjectData;

  /// No description provided for @noSubmissionsToExport.
  ///
  /// In en, this message translates to:
  /// **'No Submissions To Export'**
  String get noSubmissionsToExport;

  /// No description provided for @noTasksFound.
  ///
  /// In en, this message translates to:
  /// **'No Tasks Found'**
  String get noTasksFound;

  /// No description provided for @noTeachersFound.
  ///
  /// In en, this message translates to:
  /// **'No Teachers Found'**
  String get noTeachersFound;

  /// No description provided for @noTeachersFoundMakeSureTeachers.
  ///
  /// In en, this message translates to:
  /// **'No teachers found. Make sure teachers have audits for the selected period.'**
  String get noTeachersFoundMakeSureTeachers;

  /// No description provided for @noTemplatesForThisFrequency.
  ///
  /// In en, this message translates to:
  /// **'No Templates For This Frequency'**
  String get noTemplatesForThisFrequency;

  /// No description provided for @noTimesheetFoundForThisShift.
  ///
  /// In en, this message translates to:
  /// **'No Timesheet Found For This Shift'**
  String get noTimesheetFoundForThisShift;

  /// No description provided for @noTimesheetRecordFoundForThis.
  ///
  /// In en, this message translates to:
  /// **'No Timesheet Record Found For This'**
  String get noTimesheetRecordFoundForThis;

  /// No description provided for @noTimesheetsFound.
  ///
  /// In en, this message translates to:
  /// **'No Timesheets Found'**
  String get noTimesheetsFound;

  /// No description provided for @noUnlinkedFormsFoundNearby.
  ///
  /// In en, this message translates to:
  /// **'No Unlinked Forms Found Nearby'**
  String get noUnlinkedFormsFoundNearby;

  /// No description provided for @noUpcomingClasses.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Classes'**
  String get noUpcomingClasses;

  /// No description provided for @noUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Events'**
  String get noUpcomingEvents;

  /// No description provided for @noUsersAvailableToAdd.
  ///
  /// In en, this message translates to:
  /// **'No Users Available To Add'**
  String get noUsersAvailableToAdd;

  /// No description provided for @noUsersSelected.
  ///
  /// In en, this message translates to:
  /// **'No Users Selected'**
  String get noUsersSelected;

  /// No description provided for @noValidShiftFoundForClock.
  ///
  /// In en, this message translates to:
  /// **'No Valid Shift Found For Clock'**
  String get noValidShiftFoundForClock;

  /// No description provided for @noVideoCallIsConfiguredFor.
  ///
  /// In en, this message translates to:
  /// **'No Video Call Is Configured For'**
  String get noVideoCallIsConfiguredFor;

  /// No description provided for @notAtAll.
  ///
  /// In en, this message translates to:
  /// **'Not At All'**
  String get notAtAll;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @noteSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Note Saved Successfully'**
  String get noteSavedSuccessfully;

  /// No description provided for @noteStudentsNeedingEnglishHelpShould.
  ///
  /// In en, this message translates to:
  /// **'Note Students Needing English Help Should'**
  String get noteStudentsNeedingEnglishHelpShould;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @notificationContent.
  ///
  /// In en, this message translates to:
  /// **'Notification Content'**
  String get notificationContent;

  /// No description provided for @notificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Notification Message'**
  String get notificationMessage;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// No description provided for @notificationPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences Saved'**
  String get notificationPreferencesSaved;

  /// No description provided for @notificationResults.
  ///
  /// In en, this message translates to:
  /// **'Notification Results'**
  String get notificationResults;

  /// No description provided for @notificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification Sent'**
  String get notificationSent;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Title'**
  String get notificationTitle;

  /// No description provided for @notificationsHelpYouStayOnTop.
  ///
  /// In en, this message translates to:
  /// **'Notifications Help You Stay On Top'**
  String get notificationsHelpYouStayOnTop;

  /// No description provided for @notificationsPrivacyTheme.
  ///
  /// In en, this message translates to:
  /// **'Notifications Privacy Theme'**
  String get notificationsPrivacyTheme;

  /// No description provided for @notificationsWillBeSentInstantlyTo.
  ///
  /// In en, this message translates to:
  /// **'Notifications Will Be Sent Instantly To'**
  String get notificationsWillBeSentInstantlyTo;

  /// No description provided for @notifyMeBeforeDueDate.
  ///
  /// In en, this message translates to:
  /// **'Notify Me Before Due Date'**
  String get notifyMeBeforeDueDate;

  /// No description provided for @notifyMeBeforeShift.
  ///
  /// In en, this message translates to:
  /// **'Notify Me Before Shift'**
  String get notifyMeBeforeShift;

  /// No description provided for @number.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get number;

  /// No description provided for @oftenFewDaysAWeek.
  ///
  /// In en, this message translates to:
  /// **'Often Few Days AWeek'**
  String get oftenFewDaysAWeek;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @oldDraftsCleanedUpSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Old Drafts Cleaned Up Successfully'**
  String get oldDraftsCleanedUpSuccessfully;

  /// No description provided for @oldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get oldestFirst;

  /// No description provided for @onceSubmittedYouCannotEditThis.
  ///
  /// In en, this message translates to:
  /// **'Once Submitted You Cannot Edit This'**
  String get onceSubmittedYouCannotEditThis;

  /// No description provided for @oneTimeOnly.
  ///
  /// In en, this message translates to:
  /// **'One Time Only'**
  String get oneTimeOnly;

  /// No description provided for @onlyIfYouNeedTheRaw.
  ///
  /// In en, this message translates to:
  /// **'Only If You Need The Raw'**
  String get onlyIfYouNeedTheRaw;

  /// No description provided for @onlyScheduledShiftsThatHavenT.
  ///
  /// In en, this message translates to:
  /// **'Only Scheduled Shifts That Haven T'**
  String get onlyScheduledShiftsThatHavenT;

  /// No description provided for @onlyTeachersCanShareTheirScreen.
  ///
  /// In en, this message translates to:
  /// **'Only Teachers Can Share Their Screen'**
  String get onlyTeachersCanShareTheirScreen;

  /// No description provided for @onlyTheTaskCreatorCanDelete.
  ///
  /// In en, this message translates to:
  /// **'Only The Task Creator Can Delete'**
  String get onlyTheTaskCreatorCanDelete;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Open Activity Log'**
  String get openActivityLog;

  /// No description provided for @openCheckoutLinkAgain.
  ///
  /// In en, this message translates to:
  /// **'Open Checkout Link Again'**
  String get openCheckoutLinkAgain;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @openingFilename.
  ///
  /// In en, this message translates to:
  /// **'Opening Filename'**
  String get openingFilename;

  /// No description provided for @operational.
  ///
  /// In en, this message translates to:
  /// **'Operational'**
  String get operational;

  /// No description provided for @option1Option2Option3.
  ///
  /// In en, this message translates to:
  /// **'Option1Option2Option3'**
  String get option1Option2Option3;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get or;

  /// No description provided for @orangeTaskAssignmentNotification.
  ///
  /// In en, this message translates to:
  /// **'Orange Task Assignment Notification'**
  String get orangeTaskAssignmentNotification;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @originalDataNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Original Data Not Available'**
  String get originalDataNotAvailable;

  /// No description provided for @originalSchedule.
  ///
  /// In en, this message translates to:
  /// **'Original Schedule'**
  String get originalSchedule;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @ourIslamicCourses.
  ///
  /// In en, this message translates to:
  /// **'Our Islamic Courses'**
  String get ourIslamicCourses;

  /// No description provided for @ourIslamicProgramIsMeticulouslyDesigned.
  ///
  /// In en, this message translates to:
  /// **'Our Islamic Program Is Meticulously Designed'**
  String get ourIslamicProgramIsMeticulouslyDesigned;

  /// No description provided for @ourJourney.
  ///
  /// In en, this message translates to:
  /// **'Our Journey'**
  String get ourJourney;

  /// No description provided for @ourLanguageProgramsAreDesignedTo.
  ///
  /// In en, this message translates to:
  /// **'Our Language Programs Are Designed To'**
  String get ourLanguageProgramsAreDesignedTo;

  /// No description provided for @ourLeadership.
  ///
  /// In en, this message translates to:
  /// **'Our Leadership'**
  String get ourLeadership;

  /// No description provided for @ourMission.
  ///
  /// In en, this message translates to:
  /// **'Our Mission'**
  String get ourMission;

  /// No description provided for @ourTeachers.
  ///
  /// In en, this message translates to:
  /// **'Our Teachers'**
  String get ourTeachers;

  /// No description provided for @ourTeachersAreCertifiedIslamicScholars.
  ///
  /// In en, this message translates to:
  /// **'Our Teachers Are Certified Islamic Scholars'**
  String get ourTeachersAreCertifiedIslamicScholars;

  /// No description provided for @ourVision.
  ///
  /// In en, this message translates to:
  /// **'Our Vision'**
  String get ourVision;

  /// No description provided for @overallAttendance.
  ///
  /// In en, this message translates to:
  /// **'Overall Attendance'**
  String get overallAttendance;

  /// No description provided for @overallScore.
  ///
  /// In en, this message translates to:
  /// **'Overall Score'**
  String get overallScore;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @overdue2.
  ///
  /// In en, this message translates to:
  /// **'Overdue2'**
  String get overdue2;

  /// No description provided for @overduetasksOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overduetasks Overdue'**
  String get overduetasksOverdue;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @parentResources.
  ///
  /// In en, this message translates to:
  /// **'Parent Resources'**
  String get parentResources;

  /// No description provided for @parentSettings.
  ///
  /// In en, this message translates to:
  /// **'Parent Settings'**
  String get parentSettings;

  /// No description provided for @parents.
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get parents;

  /// No description provided for @participantcount.
  ///
  /// In en, this message translates to:
  /// **'Participantcount'**
  String get participantcount;

  /// No description provided for @participantcountInClass.
  ///
  /// In en, this message translates to:
  /// **'Participantcount In Class'**
  String get participantcountInClass;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password Changed Successfully'**
  String get passwordChangedSuccessfully;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @pleaseEnterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get pleaseEnterCurrentPassword;

  /// No description provided for @pleaseEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get pleaseEnterNewPassword;

  /// No description provided for @pleaseConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get pleaseConfirmNewPassword;

  /// No description provided for @passwordMustBeAtLeast6Characters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast6Characters;

  /// No description provided for @failedToChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get failedToChangePassword;

  /// No description provided for @incorrectCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password'**
  String get incorrectCurrentPassword;

  /// No description provided for @passwordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get passwordTooWeak;

  /// No description provided for @updateYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get updateYourPassword;

  /// No description provided for @studentId.
  ///
  /// In en, this message translates to:
  /// **'Student ID'**
  String get studentId;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password Requirements'**
  String get passwordRequirements;

  /// No description provided for @passwordResetInitiatedForAllUsers.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Initiated For All Users'**
  String get passwordResetInitiatedForAllUsers;

  /// No description provided for @passwordResetSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password Reset Successfully'**
  String get passwordResetSuccessfully;

  /// No description provided for @payInvoice.
  ///
  /// In en, this message translates to:
  /// **'Pay Invoice'**
  String get payInvoice;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @paySettings.
  ///
  /// In en, this message translates to:
  /// **'Pay Settings'**
  String get paySettings;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentAdjustedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Payment Adjusted Successfully'**
  String get paymentAdjustedSuccessfully;

  /// No description provided for @paymentBySubject.
  ///
  /// In en, this message translates to:
  /// **'Payment By Subject'**
  String get paymentBySubject;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @paymentHistoryWillAppearOnceYou.
  ///
  /// In en, this message translates to:
  /// **'Payment History Will Appear Once You'**
  String get paymentHistoryWillAppearOnceYou;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @penaltyPerMissedClass.
  ///
  /// In en, this message translates to:
  /// **'Penalty Per Missed Class'**
  String get penaltyPerMissedClass;

  /// No description provided for @penaltyPerMissing.
  ///
  /// In en, this message translates to:
  /// **'Penalty Per Missing'**
  String get penaltyPerMissing;

  /// No description provided for @penaltyPerShift.
  ///
  /// In en, this message translates to:
  /// **'Penalty Per Shift'**
  String get penaltyPerShift;

  /// No description provided for @pendingapprovals.
  ///
  /// In en, this message translates to:
  /// **'Pendingapprovals'**
  String get pendingapprovals;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @performanceEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Performance Evaluation'**
  String get performanceEvaluation;

  /// No description provided for @performanceSummaryCopied.
  ///
  /// In en, this message translates to:
  /// **'Performance Summary Copied'**
  String get performanceSummaryCopied;

  /// No description provided for @performanceSummaryCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Performance Summary Copied To Clipboard'**
  String get performanceSummaryCopiedToClipboard;

  /// No description provided for @performanceTier.
  ///
  /// In en, this message translates to:
  /// **'Performance Tier'**
  String get performanceTier;

  /// No description provided for @permanentlyDeleteUser.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete User'**
  String get permanentlyDeleteUser;

  /// No description provided for @permissionsDenied.
  ///
  /// In en, this message translates to:
  /// **'Permissions Denied'**
  String get permissionsDenied;

  /// No description provided for @permissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get permissionsRequired;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @phoneNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number Optional'**
  String get phoneNumberOptional;

  /// No description provided for @pictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture In Picture'**
  String get pictureInPicture;

  /// No description provided for @pilot.
  ///
  /// In en, this message translates to:
  /// **'Pilot'**
  String get pilot;

  /// No description provided for @pilotOnly.
  ///
  /// In en, this message translates to:
  /// **'Pilot Only'**
  String get pilotOnly;

  /// No description provided for @placeholder.
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get placeholder;

  /// No description provided for @placeholderOptional.
  ///
  /// In en, this message translates to:
  /// **'Placeholder Optional'**
  String get placeholderOptional;

  /// No description provided for @platformUptime.
  ///
  /// In en, this message translates to:
  /// **'Platform Uptime'**
  String get platformUptime;

  /// No description provided for @pleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'Please Check'**
  String get pleaseCheck;

  /// No description provided for @pleaseCheckYourInternetConnectionAnd.
  ///
  /// In en, this message translates to:
  /// **'Please Check Your Internet Connection And'**
  String get pleaseCheckYourInternetConnectionAnd;

  /// No description provided for @pleaseContactYourSupervisorIfYou.
  ///
  /// In en, this message translates to:
  /// **'Please Contact Your Supervisor If You'**
  String get pleaseContactYourSupervisorIfYou;

  /// No description provided for @pleaseEnablePermissionsInSettingsTo.
  ///
  /// In en, this message translates to:
  /// **'Please Enable Permissions In Settings To'**
  String get pleaseEnablePermissionsInSettingsTo;

  /// No description provided for @pleaseEnterAFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Please Enter AForm Title'**
  String get pleaseEnterAFormTitle;

  /// No description provided for @pleaseEnterAValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please Enter AValid Number'**
  String get pleaseEnterAValidNumber;

  /// No description provided for @pleaseEnterAValidWageAmount.
  ///
  /// In en, this message translates to:
  /// **'Please Enter AValid Wage Amount'**
  String get pleaseEnterAValidWageAmount;

  /// No description provided for @pleaseEnterYourCurrentPasswordAnd.
  ///
  /// In en, this message translates to:
  /// **'Please Enter Your Current Password And'**
  String get pleaseEnterYourCurrentPasswordAnd;

  /// No description provided for @pleaseExplainWhyYouBelieveThis.
  ///
  /// In en, this message translates to:
  /// **'Please Explain Why You Believe This'**
  String get pleaseExplainWhyYouBelieveThis;

  /// No description provided for @pleaseFillInAllRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please Fill In All Required Fields'**
  String get pleaseFillInAllRequiredFields;

  /// No description provided for @pleaseProvideAReason.
  ///
  /// In en, this message translates to:
  /// **'Please Provide AReason'**
  String get pleaseProvideAReason;

  /// No description provided for @pleaseProvideAReasonForRejection.
  ///
  /// In en, this message translates to:
  /// **'Please Provide AReason For Rejection'**
  String get pleaseProvideAReasonForRejection;

  /// No description provided for @pleaseProvideAtLeastOneOption.
  ///
  /// In en, this message translates to:
  /// **'Please Provide At Least One Option'**
  String get pleaseProvideAtLeastOneOption;

  /// No description provided for @pleaseRefreshThePage.
  ///
  /// In en, this message translates to:
  /// **'Please Refresh The Page'**
  String get pleaseRefreshThePage;

  /// No description provided for @pleaseSelectADutyTypeFor.
  ///
  /// In en, this message translates to:
  /// **'Please Select ADuty Type For'**
  String get pleaseSelectADutyTypeFor;

  /// No description provided for @pleaseSelectARole.
  ///
  /// In en, this message translates to:
  /// **'Please Select ARole'**
  String get pleaseSelectARole;

  /// No description provided for @pleaseSelectAStudent.
  ///
  /// In en, this message translates to:
  /// **'Please Select AStudent'**
  String get pleaseSelectAStudent;

  /// No description provided for @pleaseSelectATeacher.
  ///
  /// In en, this message translates to:
  /// **'Please Select ATeacher'**
  String get pleaseSelectATeacher;

  /// No description provided for @pleaseSelectAUserRole.
  ///
  /// In en, this message translates to:
  /// **'Please Select AUser Role'**
  String get pleaseSelectAUserRole;

  /// No description provided for @pleaseSelectAnIssueType.
  ///
  /// In en, this message translates to:
  /// **'Please Select An Issue Type'**
  String get pleaseSelectAnIssueType;

  /// No description provided for @pleaseSelectAtLeastOneLanguage.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Language'**
  String get pleaseSelectAtLeastOneLanguage;

  /// No description provided for @pleaseSelectAtLeastOneOption.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Option'**
  String get pleaseSelectAtLeastOneOption;

  /// No description provided for @pleaseSelectAtLeastOneRecipient.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Recipient'**
  String get pleaseSelectAtLeastOneRecipient;

  /// No description provided for @pleaseSelectAtLeastOneStudent.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Student'**
  String get pleaseSelectAtLeastOneStudent;

  /// No description provided for @pleaseSelectAtLeastOneStudent2.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Student2'**
  String get pleaseSelectAtLeastOneStudent2;

  /// No description provided for @pleaseSelectAtLeastOneTeaching.
  ///
  /// In en, this message translates to:
  /// **'Please Select At Least One Teaching'**
  String get pleaseSelectAtLeastOneTeaching;

  /// No description provided for @pleaseSelectBothStartAndEnd.
  ///
  /// In en, this message translates to:
  /// **'Please Select Both Start And End'**
  String get pleaseSelectBothStartAndEnd;

  /// No description provided for @pleaseSelectWhichClassThisReport.
  ///
  /// In en, this message translates to:
  /// **'Please Select Which Class This Report'**
  String get pleaseSelectWhichClassThisReport;

  /// No description provided for @pleaseSignInAgainToJoin.
  ///
  /// In en, this message translates to:
  /// **'Please Sign In Again To Join'**
  String get pleaseSignInAgainToJoin;

  /// No description provided for @pleaseSignInToAccessForms.
  ///
  /// In en, this message translates to:
  /// **'Please Sign In To Access Forms'**
  String get pleaseSignInToAccessForms;

  /// No description provided for @pleaseSignInToViewForms.
  ///
  /// In en, this message translates to:
  /// **'Please Sign In To View Forms'**
  String get pleaseSignInToViewForms;

  /// No description provided for @pleaseSignInToViewYour.
  ///
  /// In en, this message translates to:
  /// **'Please Sign In To View Your'**
  String get pleaseSignInToViewYour;

  /// No description provided for @pleaseSignInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Please Sign In To Your Account'**
  String get pleaseSignInToYourAccount;

  /// No description provided for @pleaseTrySigningOutAndSigning.
  ///
  /// In en, this message translates to:
  /// **'Please Try Signing Out And Signing'**
  String get pleaseTrySigningOutAndSigning;

  /// No description provided for @pleaseUpdateToContinueUsingThe.
  ///
  /// In en, this message translates to:
  /// **'Please Update To Continue Using The'**
  String get pleaseUpdateToContinueUsingThe;

  /// No description provided for @pleaseWaitWhileWeConnectYou.
  ///
  /// In en, this message translates to:
  /// **'Please Wait While We Connect You'**
  String get pleaseWaitWhileWeConnectYou;

  /// No description provided for @pleaseWaitWhileWeLoadYour.
  ///
  /// In en, this message translates to:
  /// **'Please Wait While We Load Your'**
  String get pleaseWaitWhileWeLoadYour;

  /// No description provided for @possibleCausesN.
  ///
  /// In en, this message translates to:
  /// **'Possible causes:'**
  String get possibleCausesN;

  /// No description provided for @preFilled.
  ///
  /// In en, this message translates to:
  /// **'Pre Filled'**
  String get preFilled;

  /// No description provided for @preserveAllTheirDataSafely.
  ///
  /// In en, this message translates to:
  /// **'Preserve All Their Data Safely'**
  String get preserveAllTheirDataSafely;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @previewChanges.
  ///
  /// In en, this message translates to:
  /// **'Preview Changes'**
  String get previewChanges;

  /// No description provided for @previewInTeacherTimezone.
  ///
  /// In en, this message translates to:
  /// **'Preview In Teacher Timezone'**
  String get previewInTeacherTimezone;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous Week'**
  String get previousWeek;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @primaryButton.
  ///
  /// In en, this message translates to:
  /// **'Primary Button'**
  String get primaryButton;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priority2.
  ///
  /// In en, this message translates to:
  /// **'Priority2'**
  String get priority2;

  /// No description provided for @proceedAnyway.
  ///
  /// In en, this message translates to:
  /// **'Proceed Anyway'**
  String get proceedAnyway;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileCompletionpercentageComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile Completionpercentage Complete'**
  String get profileCompletionpercentageComplete;

  /// No description provided for @profilePercentageComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile Percentage Complete'**
  String get profilePercentageComplete;

  /// No description provided for @profilePictureRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture Removed Successfully'**
  String get profilePictureRemovedSuccessfully;

  /// No description provided for @profilePictureUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture Updated Successfully'**
  String get profilePictureUpdatedSuccessfully;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile Updated Successfully'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @programDetails.
  ///
  /// In en, this message translates to:
  /// **'Program Details'**
  String get programDetails;

  /// No description provided for @programDetailsForEachStudent.
  ///
  /// In en, this message translates to:
  /// **'Program Details For Each Student'**
  String get programDetailsForEachStudent;

  /// No description provided for @programOverview.
  ///
  /// In en, this message translates to:
  /// **'Program Overview'**
  String get programOverview;

  /// No description provided for @programs.
  ///
  /// In en, this message translates to:
  /// **'Programs'**
  String get programs;

  /// No description provided for @programs2.
  ///
  /// In en, this message translates to:
  /// **'Programs2'**
  String get programs2;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @progress2.
  ///
  /// In en, this message translates to:
  /// **'Progress2'**
  String get progress2;

  /// No description provided for @progressNotes.
  ///
  /// In en, this message translates to:
  /// **'Progress Notes'**
  String get progressNotes;

  /// No description provided for @progressionProgressTotal.
  ///
  /// In en, this message translates to:
  /// **'Progression Progress Total'**
  String get progressionProgressTotal;

  /// No description provided for @promoteTeachersFromTheUsersTab.
  ///
  /// In en, this message translates to:
  /// **'Promote Teachers From The Users Tab'**
  String get promoteTeachersFromTheUsersTab;

  /// No description provided for @promoteTeachersToAdminTeacherDual.
  ///
  /// In en, this message translates to:
  /// **'Promote Teachers To Admin Teacher Dual'**
  String get promoteTeachersToAdminTeacherDual;

  /// No description provided for @promoteToAdminTeacher.
  ///
  /// In en, this message translates to:
  /// **'Promote To Admin Teacher'**
  String get promoteToAdminTeacher;

  /// No description provided for @prophetMuhammadPbuh.
  ///
  /// In en, this message translates to:
  /// **'Prophet Muhammad Pbuh'**
  String get prophetMuhammadPbuh;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @punctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get punctuality;

  /// No description provided for @purpleBasicEmailTest.
  ///
  /// In en, this message translates to:
  /// **'Purple Basic Email Test'**
  String get purpleBasicEmailTest;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// No description provided for @qualifiedIslamicEducators.
  ///
  /// In en, this message translates to:
  /// **'Qualified Islamic Educators'**
  String get qualifiedIslamicEducators;

  /// No description provided for @qualityIslamicEducationFromAnywhereIn.
  ///
  /// In en, this message translates to:
  /// **'Quality Islamic Education From Anywhere In'**
  String get qualityIslamicEducationFromAnywhereIn;

  /// No description provided for @questionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question Label'**
  String get questionLabel;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @quickEdit.
  ///
  /// In en, this message translates to:
  /// **'Quick Edit'**
  String get quickEdit;

  /// No description provided for @quickEditOrFullEditorFor.
  ///
  /// In en, this message translates to:
  /// **'Quick Edit Or Full Editor For'**
  String get quickEditOrFullEditorFor;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// No description provided for @quickTasks.
  ///
  /// In en, this message translates to:
  /// **'Quick Tasks'**
  String get quickTasks;

  /// No description provided for @quran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get quran;

  /// No description provided for @rarely.
  ///
  /// In en, this message translates to:
  /// **'Rarely'**
  String get rarely;

  /// No description provided for @rarelyFewHoursAWeek.
  ///
  /// In en, this message translates to:
  /// **'Rarely Few Hours AWeek'**
  String get rarelyFewHoursAWeek;

  /// No description provided for @rateUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Rate Updated Successfully'**
  String get rateUpdatedSuccessfully;

  /// No description provided for @reEnableAccessToTheSystem.
  ///
  /// In en, this message translates to:
  /// **'Re Enable Access To The System'**
  String get reEnableAccessToTheSystem;

  /// No description provided for @reGularisationAdministrative.
  ///
  /// In en, this message translates to:
  /// **'Re Gularisation Administrative'**
  String get reGularisationAdministrative;

  /// No description provided for @reUssis.
  ///
  /// In en, this message translates to:
  /// **'Re Ussis'**
  String get reUssis;

  /// No description provided for @reactionAddedReaction.
  ///
  /// In en, this message translates to:
  /// **'Reaction Added Reaction'**
  String get reactionAddedReaction;

  /// No description provided for @readOurPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read Our Privacy Policy'**
  String get readOurPrivacyPolicy;

  /// No description provided for @readinessFormRequired2.
  ///
  /// In en, this message translates to:
  /// **'Readiness Form Required2'**
  String get readinessFormRequired2;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @reasonForDispute.
  ///
  /// In en, this message translates to:
  /// **'Reason For Dispute'**
  String get reasonForDispute;

  /// No description provided for @reasonForEdit.
  ///
  /// In en, this message translates to:
  /// **'Reason For Edit'**
  String get reasonForEdit;

  /// No description provided for @reasonForReschedulingRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason For Rescheduling Required'**
  String get reasonForReschedulingRequired;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason Required'**
  String get reasonRequired;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @recentInvoices.
  ///
  /// In en, this message translates to:
  /// **'Recent Invoices'**
  String get recentInvoices;

  /// No description provided for @recentLessons.
  ///
  /// In en, this message translates to:
  /// **'Recent Lessons'**
  String get recentLessons;

  /// No description provided for @recentPayments.
  ///
  /// In en, this message translates to:
  /// **'Recent Payments'**
  String get recentPayments;

  /// No description provided for @recipientsWillReceiveBothPushNotification.
  ///
  /// In en, this message translates to:
  /// **'Recipients Will Receive Both Push Notification'**
  String get recipientsWillReceiveBothPushNotification;

  /// No description provided for @recurrence.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get recurrence;

  /// No description provided for @recurrenceSettings.
  ///
  /// In en, this message translates to:
  /// **'Recurrence Settings'**
  String get recurrenceSettings;

  /// No description provided for @recurrenceType.
  ///
  /// In en, this message translates to:
  /// **'Recurrence Type'**
  String get recurrenceType;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @recurringOnly.
  ///
  /// In en, this message translates to:
  /// **'Recurring Only'**
  String get recurringOnly;

  /// No description provided for @refreshData.
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshData;

  /// No description provided for @regenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Code'**
  String get regenerateCode;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @reject2.
  ///
  /// In en, this message translates to:
  /// **'Reject2'**
  String get reject2;

  /// No description provided for @rejectAll.
  ///
  /// In en, this message translates to:
  /// **'Reject All'**
  String get rejectAll;

  /// No description provided for @rejectEditedTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Reject Edited Timesheet'**
  String get rejectEditedTimesheet;

  /// No description provided for @rejectTheEntireTimesheetRequiresReason.
  ///
  /// In en, this message translates to:
  /// **'Reject The Entire Timesheet Requires Reason'**
  String get rejectTheEntireTimesheetRequiresReason;

  /// No description provided for @rejectTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Reject Timesheet'**
  String get rejectTimesheet;

  /// No description provided for @remainingcount.
  ///
  /// In en, this message translates to:
  /// **'Remainingcount'**
  String get remainingcount;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeAccessToAdminFunctions.
  ///
  /// In en, this message translates to:
  /// **'Remove Access To Admin Functions'**
  String get removeAccessToAdminFunctions;

  /// No description provided for @removeAccessToTheSystem.
  ///
  /// In en, this message translates to:
  /// **'Remove Access To The System'**
  String get removeAccessToTheSystem;

  /// No description provided for @removeAdminPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin Privileges'**
  String get removeAdminPrivileges;

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove Attachment'**
  String get removeAttachment;

  /// No description provided for @removeDisplaynameFromTheMeeting.
  ///
  /// In en, this message translates to:
  /// **'Remove Displayname From The Meeting'**
  String get removeDisplaynameFromTheMeeting;

  /// No description provided for @removeOverride.
  ///
  /// In en, this message translates to:
  /// **'Remove Override'**
  String get removeOverride;

  /// No description provided for @removeParticipant.
  ///
  /// In en, this message translates to:
  /// **'Remove Participant'**
  String get removeParticipant;

  /// No description provided for @removePicture.
  ///
  /// In en, this message translates to:
  /// **'Remove Picture'**
  String get removePicture;

  /// No description provided for @removeStudent.
  ///
  /// In en, this message translates to:
  /// **'Remove Student'**
  String get removeStudent;

  /// No description provided for @removeTask.
  ///
  /// In en, this message translates to:
  /// **'Remove Task'**
  String get removeTask;

  /// No description provided for @replaceTheStudentListForAll.
  ///
  /// In en, this message translates to:
  /// **'Replace The Student List For All'**
  String get replaceTheStudentListForAll;

  /// No description provided for @reportNow.
  ///
  /// In en, this message translates to:
  /// **'Report Now'**
  String get reportNow;

  /// No description provided for @reportOpenedInNewTabUse.
  ///
  /// In en, this message translates to:
  /// **'Report Opened In New Tab Use'**
  String get reportOpenedInNewTabUse;

  /// No description provided for @reportScheduleIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Schedule Issue'**
  String get reportScheduleIssue;

  /// No description provided for @reportedIssues.
  ///
  /// In en, this message translates to:
  /// **'Reported Issues'**
  String get reportedIssues;

  /// No description provided for @requestReceived.
  ///
  /// In en, this message translates to:
  /// **'Request Received'**
  String get requestReceived;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required Field'**
  String get requiredField;

  /// No description provided for @requiredFieldDefaultReviewed.
  ///
  /// In en, this message translates to:
  /// **'Required Field Default Reviewed'**
  String get requiredFieldDefaultReviewed;

  /// No description provided for @requiredRatingBelow9.
  ///
  /// In en, this message translates to:
  /// **'Required Rating Below9'**
  String get requiredRatingBelow9;

  /// No description provided for @rescheduleShift.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Shift'**
  String get rescheduleShift;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get resetAll;

  /// No description provided for @resetAllPasswords.
  ///
  /// In en, this message translates to:
  /// **'Reset All Passwords'**
  String get resetAllPasswords;

  /// No description provided for @resetLayout.
  ///
  /// In en, this message translates to:
  /// **'Reset Layout'**
  String get resetLayout;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset To Defaults'**
  String get resetToDefaults;

  /// No description provided for @resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get resetZoom;

  /// No description provided for @responseDetails.
  ///
  /// In en, this message translates to:
  /// **'Response Details'**
  String get responseDetails;

  /// No description provided for @responses.
  ///
  /// In en, this message translates to:
  /// **'Responses'**
  String get responses;

  /// No description provided for @restoreAllTheirPreviousData.
  ///
  /// In en, this message translates to:
  /// **'Restore All Their Previous Data'**
  String get restoreAllTheirPreviousData;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get restoreBackup;

  /// No description provided for @restoreOriginalTimesAndKeepTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Restore Original Times And Keep Timesheet'**
  String get restoreOriginalTimesAndKeepTimesheet;

  /// No description provided for @restoreTheirAccountFromArchive.
  ///
  /// In en, this message translates to:
  /// **'Restore Their Account From Archive'**
  String get restoreTheirAccountFromArchive;

  /// No description provided for @restoreUser.
  ///
  /// In en, this message translates to:
  /// **'Restore User'**
  String get restoreUser;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @resumeWorkingOnYourUnfinishedForms.
  ///
  /// In en, this message translates to:
  /// **'Resume Working On Your Unfinished Forms'**
  String get resumeWorkingOnYourUnfinishedForms;

  /// No description provided for @retryNow.
  ///
  /// In en, this message translates to:
  /// **'Retry Now'**
  String get retryNow;

  /// No description provided for @returnHome.
  ///
  /// In en, this message translates to:
  /// **'Return Home'**
  String get returnHome;

  /// No description provided for @revertToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Revert To Original'**
  String get revertToOriginal;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewAndApproveEmployeeTimesheets.
  ///
  /// In en, this message translates to:
  /// **'Review And Approve Employee Timesheets'**
  String get reviewAndApproveEmployeeTimesheets;

  /// No description provided for @reviewAs.
  ///
  /// In en, this message translates to:
  /// **'Review As'**
  String get reviewAs;

  /// No description provided for @reviewComment.
  ///
  /// In en, this message translates to:
  /// **'Review Comment'**
  String get reviewComment;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review Submitted'**
  String get reviewSubmitted;

  /// No description provided for @reviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get reviewed;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeAdminPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Revoke Admin Privileges'**
  String get revokeAdminPrivileges;

  /// No description provided for @roleBasedPermissionsAreConfiguredAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Role Based Permissions Are Configured Automatically'**
  String get roleBasedPermissionsAreConfiguredAutomatically;

  /// No description provided for @roleCheckResults.
  ///
  /// In en, this message translates to:
  /// **'Role Check Results'**
  String get roleCheckResults;

  /// No description provided for @rolePermissions.
  ///
  /// In en, this message translates to:
  /// **'Role Permissions'**
  String get rolePermissions;

  /// No description provided for @roleSystemTest.
  ///
  /// In en, this message translates to:
  /// **'Role System Test'**
  String get roleSystemTest;

  /// No description provided for @roleType.
  ///
  /// In en, this message translates to:
  /// **'Role Type'**
  String get roleType;

  /// No description provided for @roundingAdjustmentPenaltyBonusEtc.
  ///
  /// In en, this message translates to:
  /// **'Rounding Adjustment Penalty Bonus Etc'**
  String get roundingAdjustmentPenaltyBonusEtc;

  /// No description provided for @rowsPerPage.
  ///
  /// In en, this message translates to:
  /// **'Rows Per Page'**
  String get rowsPerPage;

  /// No description provided for @runBasicTests.
  ///
  /// In en, this message translates to:
  /// **'Run Basic Tests'**
  String get runBasicTests;

  /// No description provided for @runTheComputeScriptToGenerate.
  ///
  /// In en, this message translates to:
  /// **'Run The Compute Script To Generate'**
  String get runTheComputeScriptToGenerate;

  /// No description provided for @sampleAssignments.
  ///
  /// In en, this message translates to:
  /// **'Sample Assignments'**
  String get sampleAssignments;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get saveDraft;

  /// No description provided for @saveField.
  ///
  /// In en, this message translates to:
  /// **'Save Field'**
  String get saveField;

  /// No description provided for @saveForm.
  ///
  /// In en, this message translates to:
  /// **'Save Form'**
  String get saveForm;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @savedDrafts.
  ///
  /// In en, this message translates to:
  /// **'Saved Drafts'**
  String get savedDrafts;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @schedule2.
  ///
  /// In en, this message translates to:
  /// **'Schedule2'**
  String get schedule2;

  /// No description provided for @scheduleInformation.
  ///
  /// In en, this message translates to:
  /// **'Schedule Information'**
  String get scheduleInformation;

  /// No description provided for @schedulePreferences.
  ///
  /// In en, this message translates to:
  /// **'Schedule Preferences'**
  String get schedulePreferences;

  /// No description provided for @scheduleType.
  ///
  /// In en, this message translates to:
  /// **'Schedule Type'**
  String get scheduleType;

  /// No description provided for @schoolAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'School Announcements'**
  String get schoolAnnouncements;

  /// No description provided for @schoolUpdates.
  ///
  /// In en, this message translates to:
  /// **'School Updates'**
  String get schoolUpdates;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @score2.
  ///
  /// In en, this message translates to:
  /// **'Score2'**
  String get score2;

  /// No description provided for @score3.
  ///
  /// In en, this message translates to:
  /// **'Score3'**
  String get score3;

  /// No description provided for @scoreBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Score Breakdown'**
  String get scoreBreakdown;

  /// No description provided for @screenNotFound.
  ///
  /// In en, this message translates to:
  /// **'Screen Not Found'**
  String get screenNotFound;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchActiveForms.
  ///
  /// In en, this message translates to:
  /// **'Search Active Forms'**
  String get searchActiveForms;

  /// No description provided for @searchAnything.
  ///
  /// In en, this message translates to:
  /// **'Search Anything'**
  String get searchAnything;

  /// No description provided for @searchByCityTimezoneIdOr.
  ///
  /// In en, this message translates to:
  /// **'Search By City Timezone Id Or'**
  String get searchByCityTimezoneIdOr;

  /// No description provided for @searchByFormOrCreator.
  ///
  /// In en, this message translates to:
  /// **'Search By Form Or Creator'**
  String get searchByFormOrCreator;

  /// No description provided for @searchByNameEmailOrRole.
  ///
  /// In en, this message translates to:
  /// **'Search By Name Email Or Role'**
  String get searchByNameEmailOrRole;

  /// No description provided for @searchByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search By Name Or Email'**
  String get searchByNameOrEmail;

  /// No description provided for @searchByNameOrNumber.
  ///
  /// In en, this message translates to:
  /// **'Search By Name Or Number'**
  String get searchByNameOrNumber;

  /// No description provided for @searchByNameOrRole.
  ///
  /// In en, this message translates to:
  /// **'Search By Name Or Role'**
  String get searchByNameOrRole;

  /// No description provided for @searchByOperationIdMetadata.
  ///
  /// In en, this message translates to:
  /// **'Search By Operation Id Metadata'**
  String get searchByOperationIdMetadata;

  /// No description provided for @searchClassesTeacherStudentSubject.
  ///
  /// In en, this message translates to:
  /// **'Search Classes Teacher Student Subject'**
  String get searchClassesTeacherStudentSubject;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search Country'**
  String get searchCountry;

  /// No description provided for @searchForms.
  ///
  /// In en, this message translates to:
  /// **'Search Forms'**
  String get searchForms;

  /// No description provided for @searchInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Search Invoice Number'**
  String get searchInvoiceNumber;

  /// No description provided for @searchParentsByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search Parents By Name Or Email'**
  String get searchParentsByNameOrEmail;

  /// No description provided for @searchStudents.
  ///
  /// In en, this message translates to:
  /// **'Search Students'**
  String get searchStudents;

  /// No description provided for @searchSubjects.
  ///
  /// In en, this message translates to:
  /// **'Search Subjects'**
  String get searchSubjects;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search Tasks'**
  String get searchTasks;

  /// No description provided for @searchTeacher.
  ///
  /// In en, this message translates to:
  /// **'Search by name or email'**
  String get searchTeacher;

  /// No description provided for @periodOneMonth.
  ///
  /// In en, this message translates to:
  /// **'One month'**
  String get periodOneMonth;

  /// No description provided for @periodTwoMonths.
  ///
  /// In en, this message translates to:
  /// **'Two months'**
  String get periodTwoMonths;

  /// No description provided for @periodCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get periodCustomRange;

  /// No description provided for @periodAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get periodAllTime;

  /// No description provided for @startMonth.
  ///
  /// In en, this message translates to:
  /// **'Start month'**
  String get startMonth;

  /// No description provided for @endMonth.
  ///
  /// In en, this message translates to:
  /// **'End month'**
  String get endMonth;

  /// No description provided for @auditPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get auditPeriodLabel;

  /// No description provided for @searchTeachers.
  ///
  /// In en, this message translates to:
  /// **'Search Teachers'**
  String get searchTeachers;

  /// No description provided for @searchTeachers2.
  ///
  /// In en, this message translates to:
  /// **'Search Teachers2'**
  String get searchTeachers2;

  /// No description provided for @searchUserOrName.
  ///
  /// In en, this message translates to:
  /// **'Search User Or Name'**
  String get searchUserOrName;

  /// No description provided for @searchUsersByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search Users By Name Or Email'**
  String get searchUsersByNameOrEmail;

  /// No description provided for @searchUsersOrShifts.
  ///
  /// In en, this message translates to:
  /// **'Search Users Or Shifts'**
  String get searchUsersOrShifts;

  /// No description provided for @secondaryButton.
  ///
  /// In en, this message translates to:
  /// **'Secondary Button'**
  String get secondaryButton;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectABackupToRestoreFrom.
  ///
  /// In en, this message translates to:
  /// **'Select ABackup To Restore From'**
  String get selectABackupToRestoreFrom;

  /// No description provided for @selectAFormToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Select AForm To Get Started'**
  String get selectAFormToGetStarted;

  /// No description provided for @selectAProgramForEachStudent.
  ///
  /// In en, this message translates to:
  /// **'Select AProgram For Each Student'**
  String get selectAProgramForEachStudent;

  /// No description provided for @selectARoleAndSetThe.
  ///
  /// In en, this message translates to:
  /// **'Select ARole And Set The'**
  String get selectARoleAndSetThe;

  /// No description provided for @selectAShift.
  ///
  /// In en, this message translates to:
  /// **'Select AShift'**
  String get selectAShift;

  /// No description provided for @selectAShiftToReportAn.
  ///
  /// In en, this message translates to:
  /// **'Select AShift To Report An'**
  String get selectAShiftToReportAn;

  /// No description provided for @selectAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Select Adjustment'**
  String get selectAdjustment;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @selectAll2.
  ///
  /// In en, this message translates to:
  /// **'Select All2'**
  String get selectAll2;

  /// No description provided for @selectAssignedBy.
  ///
  /// In en, this message translates to:
  /// **'Select Assigned By'**
  String get selectAssignedBy;

  /// No description provided for @selectAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Select Assigned To'**
  String get selectAssignedTo;

  /// No description provided for @selectAtLeastOneChangeTo.
  ///
  /// In en, this message translates to:
  /// **'Select At Least One Change To'**
  String get selectAtLeastOneChangeTo;

  /// No description provided for @selectByUserGroupEG.
  ///
  /// In en, this message translates to:
  /// **'Select By User Group EG'**
  String get selectByUserGroupEG;

  /// No description provided for @selectClass.
  ///
  /// In en, this message translates to:
  /// **'Select Class'**
  String get selectClass;

  /// No description provided for @selectDaysOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Select Days Of Month'**
  String get selectDaysOfMonth;

  /// No description provided for @selectDaysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Select Days Of Week'**
  String get selectDaysOfWeek;

  /// No description provided for @selectDueDate.
  ///
  /// In en, this message translates to:
  /// **'Select Due Date'**
  String get selectDueDate;

  /// No description provided for @selectDurationAndTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Select Duration And Time Of Day'**
  String get selectDurationAndTimeOfDay;

  /// No description provided for @selectDutyType.
  ///
  /// In en, this message translates to:
  /// **'Select Duty Type'**
  String get selectDutyType;

  /// No description provided for @selectIndividualUsers.
  ///
  /// In en, this message translates to:
  /// **'Select Individual Users'**
  String get selectIndividualUsers;

  /// No description provided for @selectItems.
  ///
  /// In en, this message translates to:
  /// **'Select Items'**
  String get selectItems;

  /// No description provided for @selectLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Label'**
  String get selectLabel;

  /// No description provided for @selectMonths.
  ///
  /// In en, this message translates to:
  /// **'Select Months'**
  String get selectMonths;

  /// No description provided for @selectNewOnly.
  ///
  /// In en, this message translates to:
  /// **'Select New Only'**
  String get selectNewOnly;

  /// No description provided for @selectParent.
  ///
  /// In en, this message translates to:
  /// **'Select Parent'**
  String get selectParent;

  /// No description provided for @selectPeriod.
  ///
  /// In en, this message translates to:
  /// **'Select Period'**
  String get selectPeriod;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @selectStudent.
  ///
  /// In en, this message translates to:
  /// **'Select Student'**
  String get selectStudent;

  /// No description provided for @selectStudent2.
  ///
  /// In en, this message translates to:
  /// **'Select Student2'**
  String get selectStudent2;

  /// No description provided for @selectStudents.
  ///
  /// In en, this message translates to:
  /// **'Select Students'**
  String get selectStudents;

  /// No description provided for @selectSubject.
  ///
  /// In en, this message translates to:
  /// **'Select Subject'**
  String get selectSubject;

  /// No description provided for @selectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Select Teacher'**
  String get selectTeacher;

  /// No description provided for @selectTeachersToGenerateRegenerateAudit.
  ///
  /// In en, this message translates to:
  /// **'Select Teachers To Generate Regenerate Audit'**
  String get selectTeachersToGenerateRegenerateAudit;

  /// No description provided for @selectTeamMembers.
  ///
  /// In en, this message translates to:
  /// **'Select Team Members'**
  String get selectTeamMembers;

  /// No description provided for @selectTheAppropriateRoleForThis.
  ///
  /// In en, this message translates to:
  /// **'Select The Appropriate Role For This'**
  String get selectTheAppropriateRoleForThis;

  /// No description provided for @selectTheProgramSYouAre.
  ///
  /// In en, this message translates to:
  /// **'Select The Program SYou Are'**
  String get selectTheProgramSYouAre;

  /// No description provided for @selectUserWhoCreatedTheTasks.
  ///
  /// In en, this message translates to:
  /// **'Select User Who Created The Tasks'**
  String get selectUserWhoCreatedTheTasks;

  /// No description provided for @selectUsers.
  ///
  /// In en, this message translates to:
  /// **'Select Users'**
  String get selectUsers;

  /// No description provided for @selectUsers2.
  ///
  /// In en, this message translates to:
  /// **'Select Users2'**
  String get selectUsers2;

  /// No description provided for @selectUsersToFilterTasks.
  ///
  /// In en, this message translates to:
  /// **'Select Users To Filter Tasks'**
  String get selectUsersToFilterTasks;

  /// No description provided for @selectYourCorrectTimezone.
  ///
  /// In en, this message translates to:
  /// **'Select Your Correct Timezone'**
  String get selectYourCorrectTimezone;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @selectedSelectedteachername.
  ///
  /// In en, this message translates to:
  /// **'Selected Selectedteachername'**
  String get selectedSelectedteachername;

  /// No description provided for @selectedShifts.
  ///
  /// In en, this message translates to:
  /// **'Selected Shifts'**
  String get selectedShifts;

  /// No description provided for @selectedShiftsUseMultipleTimezonesApplying.
  ///
  /// In en, this message translates to:
  /// **'Selected Shifts Use Multiple Timezones Applying'**
  String get selectedShiftsUseMultipleTimezonesApplying;

  /// No description provided for @selectedUsers.
  ///
  /// In en, this message translates to:
  /// **'Selected Users'**
  String get selectedUsers;

  /// No description provided for @selectionMethod.
  ///
  /// In en, this message translates to:
  /// **'Selection Method'**
  String get selectionMethod;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessage;

  /// No description provided for @sendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Notification'**
  String get sendNotification;

  /// No description provided for @sendTestEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Test Email'**
  String get sendTestEmail;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send To'**
  String get sendTo;

  /// No description provided for @sendTo2.
  ///
  /// In en, this message translates to:
  /// **'Send To2'**
  String get sendTo2;

  /// No description provided for @sendUsAnEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Us An Email'**
  String get sendUsAnEmail;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @sessionAlreadyClosedBySystemTimer.
  ///
  /// In en, this message translates to:
  /// **'Session Already Closed By System Timer'**
  String get sessionAlreadyClosedBySystemTimer;

  /// No description provided for @setANewStartEndTime.
  ///
  /// In en, this message translates to:
  /// **'Set ANew Start End Time'**
  String get setANewStartEndTime;

  /// No description provided for @setAsActive.
  ///
  /// In en, this message translates to:
  /// **'Set As Active'**
  String get setAsActive;

  /// No description provided for @setDefaultRates.
  ///
  /// In en, this message translates to:
  /// **'Set Default Rates'**
  String get setDefaultRates;

  /// No description provided for @setDefaults.
  ///
  /// In en, this message translates to:
  /// **'Set Defaults'**
  String get setDefaults;

  /// No description provided for @setDifferentHourlyRatesForEach.
  ///
  /// In en, this message translates to:
  /// **'Set Different Hourly Rates For Each'**
  String get setDifferentHourlyRatesForEach;

  /// No description provided for @setHourlyRatesForEachSubject.
  ///
  /// In en, this message translates to:
  /// **'Set Hourly Rates For Each Subject'**
  String get setHourlyRatesForEachSubject;

  /// No description provided for @setNotesForAllSelectedShifts.
  ///
  /// In en, this message translates to:
  /// **'Set Notes For All Selected Shifts'**
  String get setNotesForAllSelectedShifts;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings Saved Successfully'**
  String get settingsSavedSuccessfully;

  /// No description provided for @settingsSavedSuccessfully2.
  ///
  /// In en, this message translates to:
  /// **'Settings Saved Successfully2'**
  String get settingsSavedSuccessfully2;

  /// No description provided for @sharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get sharing;

  /// No description provided for @sheetsIncludedInExport.
  ///
  /// In en, this message translates to:
  /// **'Sheets Included In Export'**
  String get sheetsIncludedInExport;

  /// No description provided for @shiftBannedSuccessfullyRecalculatingAudit.
  ///
  /// In en, this message translates to:
  /// **'Shift Banned Successfully Recalculating Audit'**
  String get shiftBannedSuccessfullyRecalculatingAudit;

  /// No description provided for @shiftClaimedSuccessfullyCheckMyShifts.
  ///
  /// In en, this message translates to:
  /// **'Shift Claimed Successfully Check My Shifts'**
  String get shiftClaimedSuccessfullyCheckMyShifts;

  /// No description provided for @shiftCompleted2.
  ///
  /// In en, this message translates to:
  /// **'Shift Completed2'**
  String get shiftCompleted2;

  /// No description provided for @shiftCreEEtPaiementSynchronise.
  ///
  /// In en, this message translates to:
  /// **'Shift Cre EEt Paiement Synchronise'**
  String get shiftCreEEtPaiementSynchronise;

  /// No description provided for @shiftCreatedSyncedToTeacherTimezone.
  ///
  /// In en, this message translates to:
  /// **'Shift Created Synced To Teacher Timezone'**
  String get shiftCreatedSyncedToTeacherTimezone;

  /// No description provided for @shiftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Shift Deleted'**
  String get shiftDeleted;

  /// No description provided for @shiftDetailsConsolidated.
  ///
  /// In en, this message translates to:
  /// **'Shift Details Consolidated'**
  String get shiftDetailsConsolidated;

  /// No description provided for @shiftEndTimeMustBeDifferent.
  ///
  /// In en, this message translates to:
  /// **'Shift End Time Must Be Different'**
  String get shiftEndTimeMustBeDifferent;

  /// No description provided for @shiftEndedClockOutRecorded.
  ///
  /// In en, this message translates to:
  /// **'Shift Ended Clock Out Recorded'**
  String get shiftEndedClockOutRecorded;

  /// No description provided for @shiftInformationAutofilled.
  ///
  /// In en, this message translates to:
  /// **'Shift Information Autofilled'**
  String get shiftInformationAutofilled;

  /// No description provided for @shiftName.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get shiftName;

  /// No description provided for @shiftNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shift Not Found'**
  String get shiftNotFound;

  /// No description provided for @shiftReminders.
  ///
  /// In en, this message translates to:
  /// **'Shift Reminders'**
  String get shiftReminders;

  /// No description provided for @shiftUpdated.
  ///
  /// In en, this message translates to:
  /// **'Shift Updated'**
  String get shiftUpdated;

  /// No description provided for @shiftsWithoutForms.
  ///
  /// In en, this message translates to:
  /// **'Shifts Without Forms'**
  String get shiftsWithoutForms;

  /// No description provided for @shortAnswerText.
  ///
  /// In en, this message translates to:
  /// **'Short Answer Text'**
  String get shortAnswerText;

  /// No description provided for @showInactive.
  ///
  /// In en, this message translates to:
  /// **'Show Inactive'**
  String get showInactive;

  /// No description provided for @showingStartEndOfTotalResults.
  ///
  /// In en, this message translates to:
  /// **'Showing Start End Of Total Results'**
  String get showingStartEndOfTotalResults;

  /// No description provided for @showsPerformanceloggerStartCheckpointEndEvents.
  ///
  /// In en, this message translates to:
  /// **'Shows Performancelogger Start Checkpoint End Events'**
  String get showsPerformanceloggerStartCheckpointEndEvents;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signUpForNewClass.
  ///
  /// In en, this message translates to:
  /// **'Sign Up For New Class'**
  String get signUpForNewClass;

  /// No description provided for @signature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signature;

  /// No description provided for @signatureCaptured.
  ///
  /// In en, this message translates to:
  /// **'Signature Captured'**
  String get signatureCaptured;

  /// No description provided for @simpleClock.
  ///
  /// In en, this message translates to:
  /// **'Simple Clock'**
  String get simpleClock;

  /// No description provided for @slotStudenttzabbr.
  ///
  /// In en, this message translates to:
  /// **'Slot Studenttzabbr'**
  String get slotStudenttzabbr;

  /// No description provided for @slowestEnd.
  ///
  /// In en, this message translates to:
  /// **'Slowest End'**
  String get slowestEnd;

  /// No description provided for @slowestInCurrentLogBuffer.
  ///
  /// In en, this message translates to:
  /// **'Slowest In Current Log Buffer'**
  String get slowestInCurrentLogBuffer;

  /// No description provided for @someStudentsOnThisShiftCould.
  ///
  /// In en, this message translates to:
  /// **'Some Students On This Shift Could'**
  String get someStudentsOnThisShiftCould;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something Went Wrong'**
  String get somethingWentWrong;

  /// No description provided for @sometimes.
  ///
  /// In en, this message translates to:
  /// **'Sometimes'**
  String get sometimes;

  /// No description provided for @sorryNotAtAllIAm.
  ///
  /// In en, this message translates to:
  /// **'Sorry Not At All IAm'**
  String get sorryNotAtAllIAm;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @sourceWeek.
  ///
  /// In en, this message translates to:
  /// **'Source Week'**
  String get sourceWeek;

  /// No description provided for @specificRole.
  ///
  /// In en, this message translates to:
  /// **'Specific Role'**
  String get specificRole;

  /// No description provided for @specificUsers.
  ///
  /// In en, this message translates to:
  /// **'Specific Users'**
  String get specificUsers;

  /// No description provided for @springForward1Hour.
  ///
  /// In en, this message translates to:
  /// **'Spring Forward1Hour'**
  String get springForward1Hour;

  /// No description provided for @startCodingToday.
  ///
  /// In en, this message translates to:
  /// **'Start Coding Today'**
  String get startCodingToday;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @startTheConversation.
  ///
  /// In en, this message translates to:
  /// **'Start The Conversation'**
  String get startTheConversation;

  /// No description provided for @startYourChildSIslamicJourney.
  ///
  /// In en, this message translates to:
  /// **'Start Your Child SIslamic Journey'**
  String get startYourChildSIslamicJourney;

  /// No description provided for @startYourLearningJourneyToday.
  ///
  /// In en, this message translates to:
  /// **'Start Your Learning Journey Today'**
  String get startYourLearningJourneyToday;

  /// No description provided for @startdatetextStarttimetextEndtimetext.
  ///
  /// In en, this message translates to:
  /// **'Startdatetext Starttimetext Endtimetext'**
  String get startdatetextStarttimetextEndtimetext;

  /// No description provided for @startingScreenShare.
  ///
  /// In en, this message translates to:
  /// **'Starting Screen Share'**
  String get startingScreenShare;

  /// No description provided for @starttimeEndtime.
  ///
  /// In en, this message translates to:
  /// **'Starttime Endtime'**
  String get starttimeEndtime;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @statsEditor.
  ///
  /// In en, this message translates to:
  /// **'Stats Editor'**
  String get statsEditor;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusStatus.
  ///
  /// In en, this message translates to:
  /// **'Status Status'**
  String get statusStatus;

  /// Snackbar message after updating a status value.
  ///
  /// In en, this message translates to:
  /// **'Status updated to {newStatus}'**
  String statusUpdatedToNewstatus(String newStatus);

  /// Snackbar message after updating a status value.
  ///
  /// In en, this message translates to:
  /// **'Status updated to {status}'**
  String statusUpdatedToStatus(String status);

  /// No description provided for @stayOnTrackWithReminders.
  ///
  /// In en, this message translates to:
  /// **'Stay On Track With Reminders'**
  String get stayOnTrackWithReminders;

  /// No description provided for @stepnumberOfTotalsteps.
  ///
  /// In en, this message translates to:
  /// **'Stepnumber Of Totalsteps'**
  String get stepnumberOfTotalsteps;

  /// No description provided for @stillNoInternetConnectionPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Still No Internet Connection Please Try'**
  String get stillNoInternetConnectionPleaseTry;

  /// No description provided for @storageService.
  ///
  /// In en, this message translates to:
  /// **'Storage Service'**
  String get storageService;

  /// No description provided for @structuredLearningPaths.
  ///
  /// In en, this message translates to:
  /// **'Structured Learning Paths'**
  String get structuredLearningPaths;

  /// No description provided for @student1.
  ///
  /// In en, this message translates to:
  /// **'Student1'**
  String get student1;

  /// Snackbar message after creating a student account.
  ///
  /// In en, this message translates to:
  /// **'Student account created. ID: {studentCode}'**
  String studentAccountCreatedIdStudentcode(String studentCode);

  /// No description provided for @studentApplicants.
  ///
  /// In en, this message translates to:
  /// **'Student Applicants'**
  String get studentApplicants;

  /// No description provided for @studentIdStudentcode.
  ///
  /// In en, this message translates to:
  /// **'Student ID: {studentCode}'**
  String studentIdStudentcode(Object studentCode);

  /// No description provided for @studentJoined.
  ///
  /// In en, this message translates to:
  /// **'Student Joined'**
  String get studentJoined;

  /// No description provided for @studentLoginCredentials.
  ///
  /// In en, this message translates to:
  /// **'Student Login Credentials'**
  String get studentLoginCredentials;

  /// No description provided for @studentProgressOverview.
  ///
  /// In en, this message translates to:
  /// **'Student Progress Overview'**
  String get studentProgressOverview;

  /// No description provided for @studentSInformation.
  ///
  /// In en, this message translates to:
  /// **'Student SInformation'**
  String get studentSInformation;

  /// No description provided for @studentStudent.
  ///
  /// In en, this message translates to:
  /// **'Student Student'**
  String get studentStudent;

  /// No description provided for @studentType.
  ///
  /// In en, this message translates to:
  /// **'Student Type'**
  String get studentType;

  /// No description provided for @studentWillUseStudentIdAnd.
  ///
  /// In en, this message translates to:
  /// **'Student Will Use Student Id And'**
  String get studentWillUseStudentIdAnd;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @studentsWillAppearHereAfterYou.
  ///
  /// In en, this message translates to:
  /// **'Students Will Appear Here After You'**
  String get studentsWillAppearHereAfterYou;

  /// No description provided for @subTasksOptional.
  ///
  /// In en, this message translates to:
  /// **'Sub Tasks Optional'**
  String get subTasksOptional;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// Snackbar message after adding a subject.
  ///
  /// In en, this message translates to:
  /// **'Subject \"{displayName}\" added successfully'**
  String subjectDisplaynameAddedSuccessfully(String displayName);

  /// Snackbar message after updating a subject.
  ///
  /// In en, this message translates to:
  /// **'Subject \"{displayName}\" updated successfully'**
  String subjectDisplaynameUpdatedSuccessfully(String displayName);

  /// No description provided for @subjectHourlyRates.
  ///
  /// In en, this message translates to:
  /// **'Subject Hourly Rates'**
  String get subjectHourlyRates;

  /// No description provided for @subjectManagement.
  ///
  /// In en, this message translates to:
  /// **'Subject Management'**
  String get subjectManagement;

  /// No description provided for @subjectName.
  ///
  /// In en, this message translates to:
  /// **'Subject Name'**
  String get subjectName;

  /// No description provided for @subjectPerformanceWillAppearHereAs.
  ///
  /// In en, this message translates to:
  /// **'Subject Performance Will Appear Here As'**
  String get subjectPerformanceWillAppearHereAs;

  /// No description provided for @submissionFailedE.
  ///
  /// In en, this message translates to:
  /// **'Submission Failed E'**
  String get submissionFailedE;

  /// No description provided for @submissionInfo.
  ///
  /// In en, this message translates to:
  /// **'Submission Info'**
  String get submissionInfo;

  /// No description provided for @submissions.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get submissions;

  /// No description provided for @submitAgain.
  ///
  /// In en, this message translates to:
  /// **'Submit Again'**
  String get submitAgain;

  /// No description provided for @submitAllDrafts.
  ///
  /// In en, this message translates to:
  /// **'Submit All Drafts'**
  String get submitAllDrafts;

  /// No description provided for @submitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get submitApplication;

  /// No description provided for @submitEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Submit Evaluation'**
  String get submitEvaluation;

  /// No description provided for @submitForm.
  ///
  /// In en, this message translates to:
  /// **'Submit Form'**
  String get submitForm;

  /// No description provided for @submitNewDispute.
  ///
  /// In en, this message translates to:
  /// **'Submit New Dispute'**
  String get submitNewDispute;

  /// No description provided for @submitReportsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Reports Feedback'**
  String get submitReportsFeedback;

  /// No description provided for @submitTimesheet.
  ///
  /// In en, this message translates to:
  /// **'Submit Timesheet'**
  String get submitTimesheet;

  /// No description provided for @submitWithoutImage.
  ///
  /// In en, this message translates to:
  /// **'Submit Without Image'**
  String get submitWithoutImage;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @submittedDatestr.
  ///
  /// In en, this message translates to:
  /// **'Submitted Datestr'**
  String get submittedDatestr;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting'**
  String get submitting;

  /// No description provided for @subtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get subtitle;

  /// No description provided for @successcountSuccessfulN.
  ///
  /// In en, this message translates to:
  /// **'Successcount Successful N'**
  String get successcountSuccessfulN;

  /// No description provided for @successfulLogin1HourAgo.
  ///
  /// In en, this message translates to:
  /// **'Successful Login1Hour Ago'**
  String get successfulLogin1HourAgo;

  /// No description provided for @successfulLogin2MinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Successful Login2Minutes Ago'**
  String get successfulLogin2MinutesAgo;

  /// No description provided for @successfuluploadsFileSUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Successfuluploads File SUploaded Successfully'**
  String get successfuluploadsFileSUploadedSuccessfully;

  /// No description provided for @suggestedCorrectValueOptional.
  ///
  /// In en, this message translates to:
  /// **'Suggested Correct Value Optional'**
  String get suggestedCorrectValueOptional;

  /// No description provided for @sujetDuCours.
  ///
  /// In en, this message translates to:
  /// **'Sujet Du Cours'**
  String get sujetDuCours;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @summary2.
  ///
  /// In en, this message translates to:
  /// **'Summary2'**
  String get summary2;

  /// No description provided for @supportAlluwaleducationhubOrg.
  ///
  /// In en, this message translates to:
  /// **'Support Alluwaleducationhub Org'**
  String get supportAlluwaleducationhubOrg;

  /// No description provided for @surah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surah;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncWithSubjects.
  ///
  /// In en, this message translates to:
  /// **'Sync With Subjects'**
  String get syncWithSubjects;

  /// No description provided for @syncedSyncedSubjectsWithRates.
  ///
  /// In en, this message translates to:
  /// **'Synced Synced Subjects With Rates'**
  String get syncedSyncedSubjectsWithRates;

  /// No description provided for @systemDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'System Diagnostics'**
  String get systemDiagnostics;

  /// No description provided for @systemHealth.
  ///
  /// In en, this message translates to:
  /// **'System Health'**
  String get systemHealth;

  /// No description provided for @systemInformation.
  ///
  /// In en, this message translates to:
  /// **'System Information'**
  String get systemInformation;

  /// No description provided for @systemLoad.
  ///
  /// In en, this message translates to:
  /// **'System Load'**
  String get systemLoad;

  /// No description provided for @systemOverview.
  ///
  /// In en, this message translates to:
  /// **'System Overview'**
  String get systemOverview;

  /// No description provided for @systemPerformance.
  ///
  /// In en, this message translates to:
  /// **'System Performance'**
  String get systemPerformance;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// No description provided for @systemSettings2.
  ///
  /// In en, this message translates to:
  /// **'System Settings2'**
  String get systemSettings2;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take APhoto'**
  String get takeAPhoto;

  /// No description provided for @tapAndHoldForMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap And Hold For More Details'**
  String get tapAndHoldForMoreDetails;

  /// No description provided for @tapOnUsersBelowToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap On Users Below To Select'**
  String get tapOnUsersBelowToSelect;

  /// No description provided for @tapToSelectUsers.
  ///
  /// In en, this message translates to:
  /// **'Tap To Select Users'**
  String get tapToSelectUsers;

  /// No description provided for @targetAudienceAllowedRoles.
  ///
  /// In en, this message translates to:
  /// **'Target Audience Allowed Roles'**
  String get targetAudienceAllowedRoles;

  /// No description provided for @targetWeek.
  ///
  /// In en, this message translates to:
  /// **'Target Week'**
  String get targetWeek;

  /// No description provided for @taskArchived.
  ///
  /// In en, this message translates to:
  /// **'Task Archived'**
  String get taskArchived;

  /// No description provided for @taskDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Task Deleted Successfully'**
  String get taskDeletedSuccessfully;

  /// No description provided for @taskName.
  ///
  /// In en, this message translates to:
  /// **'Task Name'**
  String get taskName;

  /// No description provided for @taskName2.
  ///
  /// In en, this message translates to:
  /// **'Task Name2'**
  String get taskName2;

  /// No description provided for @taskReminders.
  ///
  /// In en, this message translates to:
  /// **'Task Reminders'**
  String get taskReminders;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitle;

  /// No description provided for @taskSubtasksCount.
  ///
  /// In en, this message translates to:
  /// **'Subtasks: {count}'**
  String taskSubtasksCount(Object count);

  /// No description provided for @taskUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Task Unarchived'**
  String get taskUnarchived;

  /// No description provided for @teachForUs.
  ///
  /// In en, this message translates to:
  /// **'Teach For Us'**
  String get teachForUs;

  /// No description provided for @teacherApplicants.
  ///
  /// In en, this message translates to:
  /// **'Teacher Applicants'**
  String get teacherApplicants;

  /// No description provided for @teacherApplication.
  ///
  /// In en, this message translates to:
  /// **'Teacher Application'**
  String get teacherApplication;

  /// No description provided for @teacherArrived.
  ///
  /// In en, this message translates to:
  /// **'Teacher Arrived'**
  String get teacherArrived;

  /// No description provided for @teacherAuditDashboard.
  ///
  /// In en, this message translates to:
  /// **'Teacher Audit Dashboard'**
  String get teacherAuditDashboard;

  /// No description provided for @teacherClass.
  ///
  /// In en, this message translates to:
  /// **'Teacher Class'**
  String get teacherClass;

  /// No description provided for @teacherDidNotSubmitReadinessForm.
  ///
  /// In en, this message translates to:
  /// **'Teacher Did Not Submit Readiness Form'**
  String get teacherDidNotSubmitReadinessForm;

  /// No description provided for @teacherIdNotFound.
  ///
  /// In en, this message translates to:
  /// **'Teacher Id Not Found'**
  String get teacherIdNotFound;

  /// No description provided for @teacherInformationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Teacher Information Not Available'**
  String get teacherInformationNotAvailable;

  /// No description provided for @teacherNotHere.
  ///
  /// In en, this message translates to:
  /// **'Teacher Not Here'**
  String get teacherNotHere;

  /// No description provided for @teacherProfile.
  ///
  /// In en, this message translates to:
  /// **'Teacher Profile'**
  String get teacherProfile;

  /// No description provided for @teacherSelectedSelectedteachername.
  ///
  /// In en, this message translates to:
  /// **'Teacher Selected Selectedteachername'**
  String get teacherSelectedSelectedteachername;

  /// No description provided for @teacherUstaz.
  ///
  /// In en, this message translates to:
  /// **'Teacher Ustaz'**
  String get teacherUstaz;

  /// No description provided for @teacherUstaza.
  ///
  /// In en, this message translates to:
  /// **'Teacher Ustaza'**
  String get teacherUstaza;

  /// No description provided for @teachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teachers;

  /// No description provided for @teachers2.
  ///
  /// In en, this message translates to:
  /// **'Teachers2'**
  String get teachers2;

  /// No description provided for @teachersOnly.
  ///
  /// In en, this message translates to:
  /// **'Teachers Only'**
  String get teachersOnly;

  /// No description provided for @teachershiftsShiftsWillBePermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Teachershifts Shifts Will Be Permanently Deleted'**
  String get teachershiftsShiftsWillBePermanentlyDeleted;

  /// No description provided for @teachingSelectedstudentname.
  ///
  /// In en, this message translates to:
  /// **'Teaching Selectedstudentname'**
  String get teachingSelectedstudentname;

  /// No description provided for @tealTestLastLoginUpdateTracking.
  ///
  /// In en, this message translates to:
  /// **'Teal Test Last Login Update Tracking'**
  String get tealTestLastLoginUpdateTracking;

  /// No description provided for @templateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template Deleted'**
  String get templateDeleted;

  /// No description provided for @templateDuplicatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Template Duplicated Successfully'**
  String get templateDuplicatedSuccessfully;

  /// No description provided for @templateMustHaveAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Template Must Have At Least One'**
  String get templateMustHaveAtLeastOne;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// No description provided for @templateNameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Template Name Cannot Be Empty'**
  String get templateNameCannotBeEmpty;

  /// No description provided for @templateUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Template Updated Successfully'**
  String get templateUpdatedSuccessfully;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @testDraftCreation.
  ///
  /// In en, this message translates to:
  /// **'Test Draft Creation'**
  String get testDraftCreation;

  /// No description provided for @testGeNeRationAuditDe.
  ///
  /// In en, this message translates to:
  /// **'Test Ge Ne Ration Audit De'**
  String get testGeNeRationAuditDe;

  /// No description provided for @testLoginTracking.
  ///
  /// In en, this message translates to:
  /// **'Test Login Tracking'**
  String get testLoginTracking;

  /// No description provided for @testNotificationSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Test Notification Sent Successfully'**
  String get testNotificationSentSuccessfully;

  /// No description provided for @testRoleChecks.
  ///
  /// In en, this message translates to:
  /// **'Test Role Checks'**
  String get testRoleChecks;

  /// No description provided for @testStatusUpdate.
  ///
  /// In en, this message translates to:
  /// **'Test Status Update'**
  String get testStatusUpdate;

  /// No description provided for @testTaskAssignment.
  ///
  /// In en, this message translates to:
  /// **'Test Task Assignment'**
  String get testTaskAssignment;

  /// No description provided for @testWelcomeEmail.
  ///
  /// In en, this message translates to:
  /// **'Test Welcome Email'**
  String get testWelcomeEmail;

  /// No description provided for @testimonials.
  ///
  /// In en, this message translates to:
  /// **'Testimonials'**
  String get testimonials;

  /// No description provided for @testimonialsEditor.
  ///
  /// In en, this message translates to:
  /// **'Testimonials Editor'**
  String get testimonialsEditor;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing Connection'**
  String get testingConnection;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @text10.
  ///
  /// In en, this message translates to:
  /// **'*'**
  String get text10;

  /// No description provided for @text2.
  ///
  /// In en, this message translates to:
  /// **'Text2'**
  String get text2;

  /// No description provided for @text3.
  ///
  /// In en, this message translates to:
  /// **'Text3'**
  String get text3;

  /// No description provided for @text4.
  ///
  /// In en, this message translates to:
  /// **'#'**
  String get text4;

  /// No description provided for @text5.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get text5;

  /// No description provided for @text6.
  ///
  /// In en, this message translates to:
  /// **' • '**
  String get text6;

  /// No description provided for @text7.
  ///
  /// In en, this message translates to:
  /// **'Text7'**
  String get text7;

  /// No description provided for @text8.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get text8;

  /// No description provided for @text9.
  ///
  /// In en, this message translates to:
  /// **' • '**
  String get text9;

  /// No description provided for @thankYouForYourInterestIn.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest In'**
  String get thankYouForYourInterestIn;

  /// No description provided for @thankYouForYourInterestIn2.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest In2'**
  String get thankYouForYourInterestIn2;

  /// No description provided for @thankYouForYourInterestIn3.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest In3'**
  String get thankYouForYourInterestIn3;

  /// No description provided for @thankYouForYourInterestPlease.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest Please'**
  String get thankYouForYourInterestPlease;

  /// No description provided for @thankYouForYourInterestPlease2.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest Please2'**
  String get thankYouForYourInterestPlease2;

  /// No description provided for @thankYouForYourInterestWe.
  ///
  /// In en, this message translates to:
  /// **'Thank You For Your Interest We'**
  String get thankYouForYourInterestWe;

  /// No description provided for @theBestOfPeopleAreThose.
  ///
  /// In en, this message translates to:
  /// **'The Best Of People Are Those'**
  String get theBestOfPeopleAreThose;

  /// No description provided for @theDailySchedulerWillGenerateNew.
  ///
  /// In en, this message translates to:
  /// **'The Daily Scheduler Will Generate New'**
  String get theDailySchedulerWillGenerateNew;

  /// No description provided for @theFormCreatorHasNotAdded.
  ///
  /// In en, this message translates to:
  /// **'The Form Creator Has Not Added'**
  String get theFormCreatorHasNotAdded;

  /// No description provided for @theSmallBusinessPlan.
  ///
  /// In en, this message translates to:
  /// **'The Small Business Plan'**
  String get theSmallBusinessPlan;

  /// No description provided for @theTimezoneForTheTimesBelow.
  ///
  /// In en, this message translates to:
  /// **'The Timezone For The Times Below'**
  String get theTimezoneForTheTimesBelow;

  /// No description provided for @theTimezoneForTheTimesYou.
  ///
  /// In en, this message translates to:
  /// **'The Timezone For The Times You'**
  String get theTimezoneForTheTimesYou;

  /// No description provided for @theTimezoneUsedForTheStart.
  ///
  /// In en, this message translates to:
  /// **'The Timezone Used For The Start'**
  String get theTimezoneUsedForTheStart;

  /// No description provided for @theViewContains.
  ///
  /// In en, this message translates to:
  /// **'The View Contains'**
  String get theViewContains;

  /// No description provided for @thereAreCurrentlyNoPublishedShifts.
  ///
  /// In en, this message translates to:
  /// **'There Are Currently No Published Shifts'**
  String get thereAreCurrentlyNoPublishedShifts;

  /// No description provided for @theseShiftsWereCompletedButNo.
  ///
  /// In en, this message translates to:
  /// **'These Shifts Were Completed But No'**
  String get theseShiftsWereCompletedButNo;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This Action Cannot Be Undone'**
  String get thisActionCannotBeUndone;

  /// No description provided for @thisAppRequiresAnActiveInternet.
  ///
  /// In en, this message translates to:
  /// **'This App Requires An Active Internet'**
  String get thisAppRequiresAnActiveInternet;

  /// No description provided for @thisClassDoesNotHaveA.
  ///
  /// In en, this message translates to:
  /// **'This Class Does Not Have A'**
  String get thisClassDoesNotHaveA;

  /// No description provided for @thisClassLinkIsNoLonger.
  ///
  /// In en, this message translates to:
  /// **'This Class Link Is No Longer'**
  String get thisClassLinkIsNoLonger;

  /// No description provided for @thisEmailWillReceiveNotificationsFor.
  ///
  /// In en, this message translates to:
  /// **'This Email Will Receive Notifications For'**
  String get thisEmailWillReceiveNotificationsFor;

  /// No description provided for @thisFileWasNotUploadedTo.
  ///
  /// In en, this message translates to:
  /// **'This File Was Not Uploaded To'**
  String get thisFileWasNotUploadedTo;

  /// No description provided for @thisFormIndicatesTheTeacherConducted.
  ///
  /// In en, this message translates to:
  /// **'This Form Indicates The Teacher Conducted'**
  String get thisFormIndicatesTheTeacherConducted;

  /// No description provided for @thisIsTheTaskscreenScreen.
  ///
  /// In en, this message translates to:
  /// **'This Is The Taskscreen Screen'**
  String get thisIsTheTaskscreenScreen;

  /// No description provided for @thisIsTheTimeoffscreenScreen.
  ///
  /// In en, this message translates to:
  /// **'This Is The Timeoffscreen Screen'**
  String get thisIsTheTimeoffscreenScreen;

  /// No description provided for @thisShiftSpansTwoDaysIn.
  ///
  /// In en, this message translates to:
  /// **'This Shift Spans Two Days In'**
  String get thisShiftSpansTwoDaysIn;

  /// No description provided for @thisShiftSpansTwoDaysIn2.
  ///
  /// In en, this message translates to:
  /// **'This Shift Spans Two Days In2'**
  String get thisShiftSpansTwoDaysIn2;

  /// No description provided for @thisShiftWasMissedPleaseFill.
  ///
  /// In en, this message translates to:
  /// **'This Shift Was Missed Please Fill'**
  String get thisShiftWasMissedPleaseFill;

  /// No description provided for @thisTimesheetHasBeenApprovedAnd.
  ///
  /// In en, this message translates to:
  /// **'This Timesheet Has Been Approved And'**
  String get thisTimesheetHasBeenApprovedAnd;

  /// No description provided for @thisTimesheetWasEditedAndRequires.
  ///
  /// In en, this message translates to:
  /// **'This Timesheet Was Edited And Requires'**
  String get thisTimesheetWasEditedAndRequires;

  /// No description provided for @thisTimesheetWasEditedButThe.
  ///
  /// In en, this message translates to:
  /// **'This Timesheet Was Edited But The'**
  String get thisTimesheetWasEditedButThe;

  /// No description provided for @thisTimesheetWasEditedChooseAn.
  ///
  /// In en, this message translates to:
  /// **'This Timesheet Was Edited Choose An'**
  String get thisTimesheetWasEditedChooseAn;

  /// No description provided for @thisWill.
  ///
  /// In en, this message translates to:
  /// **'This Will'**
  String get thisWill;

  /// No description provided for @thisWillAdjustAllFutureScheduled.
  ///
  /// In en, this message translates to:
  /// **'This Will Adjust All Future Scheduled'**
  String get thisWillAdjustAllFutureScheduled;

  /// No description provided for @thisWillDeleteAllDraftsOlder.
  ///
  /// In en, this message translates to:
  /// **'This Will Delete All Drafts Older'**
  String get thisWillDeleteAllDraftsOlder;

  /// No description provided for @thisWillGiveThem.
  ///
  /// In en, this message translates to:
  /// **'This Will Give Them'**
  String get thisWillGiveThem;

  /// No description provided for @thisWillMakeTheOpportunityVisible.
  ///
  /// In en, this message translates to:
  /// **'This Will Make The Opportunity Visible'**
  String get thisWillMakeTheOpportunityVisible;

  /// No description provided for @thisWillMuteAllParticipantsExcept.
  ///
  /// In en, this message translates to:
  /// **'This Will Mute All Participants Except'**
  String get thisWillMuteAllParticipantsExcept;

  /// No description provided for @thisWillPermanentlyDeleteThisShift.
  ///
  /// In en, this message translates to:
  /// **'This Will Permanently Delete This Shift'**
  String get thisWillPermanentlyDeleteThisShift;

  /// No description provided for @thisWillSetDefaultRatesFor.
  ///
  /// In en, this message translates to:
  /// **'This Will Set Default Rates For'**
  String get thisWillSetDefaultRatesFor;

  /// No description provided for @thisWillUpdateAllExistingShifts.
  ///
  /// In en, this message translates to:
  /// **'This Will Update All Existing Shifts'**
  String get thisWillUpdateAllExistingShifts;

  /// No description provided for @thisWillUpdateTheDefaultwageField.
  ///
  /// In en, this message translates to:
  /// **'This Will Update The Defaultwage Field'**
  String get thisWillUpdateTheDefaultwageField;

  /// No description provided for @thisWillUpdateTheRecurringTemplate.
  ///
  /// In en, this message translates to:
  /// **'This Will Update The Recurring Template'**
  String get thisWillUpdateTheRecurringTemplate;

  /// No description provided for @timeConversionPreview.
  ///
  /// In en, this message translates to:
  /// **'Time Conversion Preview'**
  String get timeConversionPreview;

  /// No description provided for @timePicker.
  ///
  /// In en, this message translates to:
  /// **'Time Picker'**
  String get timePicker;

  /// No description provided for @timeUntilShiftsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Time Until Shifts Display'**
  String get timeUntilShiftsDisplay;

  /// No description provided for @timeUntilTimesheetsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Time Until Timesheets Display'**
  String get timeUntilTimesheetsDisplay;

  /// No description provided for @timesWillBeAppliedInThis.
  ///
  /// In en, this message translates to:
  /// **'Times Will Be Applied In This'**
  String get timesWillBeAppliedInThis;

  /// No description provided for @timesheetDetails2.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Details2'**
  String get timesheetDetails2;

  /// No description provided for @timesheetReview.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Review'**
  String get timesheetReview;

  /// No description provided for @timesheetSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Submitted For Review'**
  String get timesheetSubmittedForReview;

  /// No description provided for @timesheetWasEdited.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Was Edited'**
  String get timesheetWasEdited;

  /// No description provided for @timesheets.
  ///
  /// In en, this message translates to:
  /// **'Timesheets'**
  String get timesheets;

  /// Snackbar message after updating a user's timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone updated to {timezone}'**
  String timezoneUpdatedToSelectedtimezone(String timezone);

  /// No description provided for @tipIfYouJustCompletedPayment.
  ///
  /// In en, this message translates to:
  /// **'Tip If You Just Completed Payment'**
  String get tipIfYouJustCompletedPayment;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @toCreateAnInclusiveInspiringEnvironment.
  ///
  /// In en, this message translates to:
  /// **'To Create An Inclusive Inspiring Environment'**
  String get toCreateAnInclusiveInspiringEnvironment;

  /// No description provided for @toHassimiouNianeMaineEdu.
  ///
  /// In en, this message translates to:
  /// **'To Hassimiou Niane Maine Edu'**
  String get toHassimiouNianeMaineEdu;

  /// No description provided for @toIntegrateIslamicAfricanAndWestern.
  ///
  /// In en, this message translates to:
  /// **'To Integrate Islamic African And Western'**
  String get toIntegrateIslamicAfricanAndWestern;

  /// No description provided for @tooEarlyToClockInPlease.
  ///
  /// In en, this message translates to:
  /// **'Too Early To Clock In Please'**
  String get tooEarlyToClockInPlease;

  /// No description provided for @topicsWeCover.
  ///
  /// In en, this message translates to:
  /// **'Topics We Cover'**
  String get topicsWeCover;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @totalClasses.
  ///
  /// In en, this message translates to:
  /// **'Total Classes'**
  String get totalClasses;

  /// No description provided for @totalPayment.
  ///
  /// In en, this message translates to:
  /// **'Total Payment'**
  String get totalPayment;

  /// No description provided for @totalPenalty.
  ///
  /// In en, this message translates to:
  /// **'Total Penalty'**
  String get totalPenalty;

  /// No description provided for @totalTeachingHours.
  ///
  /// In en, this message translates to:
  /// **'Total Teaching Hours'**
  String get totalTeachingHours;

  /// No description provided for @totalTotalusersUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Totalusers Users'**
  String get totalTotalusersUsers;

  /// No description provided for @totalscoreMaxscore.
  ///
  /// In en, this message translates to:
  /// **'Totalscore Maxscore'**
  String get totalscoreMaxscore;

  /// No description provided for @training.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get training;

  /// No description provided for @transformativeEducationNbeyondTraditionalBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Transformative Education Nbeyond Traditional Boundaries'**
  String get transformativeEducationNbeyondTraditionalBoundaries;

  /// No description provided for @trustIndicator.
  ///
  /// In en, this message translates to:
  /// **'Trust Indicator'**
  String get trustIndicator;

  /// No description provided for @tryAdjustingYourFiltersOrSearch.
  ///
  /// In en, this message translates to:
  /// **'Try Adjusting Your Filters Or Search'**
  String get tryAdjustingYourFiltersOrSearch;

  /// No description provided for @tryAdjustingYourFiltersOrSearch2.
  ///
  /// In en, this message translates to:
  /// **'Try Adjusting Your Filters Or Search2'**
  String get tryAdjustingYourFiltersOrSearch2;

  /// No description provided for @tryAdjustingYourSearchOrFilters.
  ///
  /// In en, this message translates to:
  /// **'Try Adjusting Your Search Or Filters'**
  String get tryAdjustingYourSearchOrFilters;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @tryChangingTheFilterOrCheck.
  ///
  /// In en, this message translates to:
  /// **'Try Changing The Filter Or Check'**
  String get tryChangingTheFilterOrCheck;

  /// No description provided for @tryChangingTheMonthOrGenerating.
  ///
  /// In en, this message translates to:
  /// **'Try Changing The Month Or Generating'**
  String get tryChangingTheMonthOrGenerating;

  /// No description provided for @turnOffToKeepParticipantsMuted.
  ///
  /// In en, this message translates to:
  /// **'Turn Off To Keep Participants Muted'**
  String get turnOffToKeepParticipantsMuted;

  /// No description provided for @unBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Un Broadcast'**
  String get unBroadcast;

  /// No description provided for @unableToFindAuditContext.
  ///
  /// In en, this message translates to:
  /// **'Unable To Find Audit Context'**
  String get unableToFindAuditContext;

  /// No description provided for @unableToGetYourLocationE.
  ///
  /// In en, this message translates to:
  /// **'Unable To Get Your Location E'**
  String get unableToGetYourLocationE;

  /// No description provided for @unableToJoin.
  ///
  /// In en, this message translates to:
  /// **'Unable To Join'**
  String get unableToJoin;

  /// No description provided for @unableToLoadClassesNMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable To Load Classes NMessage'**
  String get unableToLoadClassesNMessage;

  /// No description provided for @unableToLoadParentAccountPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable To Load Parent Account Please'**
  String get unableToLoadParentAccountPlease;

  /// No description provided for @unableToLoadQuran.
  ///
  /// In en, this message translates to:
  /// **'Unable To Load Quran'**
  String get unableToLoadQuran;

  /// No description provided for @unableToLoadSeriesShifts.
  ///
  /// In en, this message translates to:
  /// **'Unable To Load Series Shifts'**
  String get unableToLoadSeriesShifts;

  /// No description provided for @unableToLoadSurah.
  ///
  /// In en, this message translates to:
  /// **'Unable To Load Surah'**
  String get unableToLoadSurah;

  /// No description provided for @uncomfortable.
  ///
  /// In en, this message translates to:
  /// **'Uncomfortable'**
  String get uncomfortable;

  /// No description provided for @understandingClassColors.
  ///
  /// In en, this message translates to:
  /// **'Understanding Class Colors'**
  String get understandingClassColors;

  /// No description provided for @universityGraduate.
  ///
  /// In en, this message translates to:
  /// **'University Graduate'**
  String get universityGraduate;

  /// No description provided for @universityStudent.
  ///
  /// In en, this message translates to:
  /// **'University Student'**
  String get universityStudent;

  /// No description provided for @unknownUserRole.
  ///
  /// In en, this message translates to:
  /// **'Unknown User Role'**
  String get unknownUserRole;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @unlockYourFullPotentialWithExpert.
  ///
  /// In en, this message translates to:
  /// **'Unlock Your Full Potential With Expert'**
  String get unlockYourFullPotentialWithExpert;

  /// No description provided for @unlockYourMathPotentialToday.
  ///
  /// In en, this message translates to:
  /// **'Unlock Your Math Potential Today'**
  String get unlockYourMathPotentialToday;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @unmuteParticipant.
  ///
  /// In en, this message translates to:
  /// **'Unmute Participant'**
  String get unmuteParticipant;

  /// No description provided for @unsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsaved;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChanges;

  /// No description provided for @untitledForm.
  ///
  /// In en, this message translates to:
  /// **'Untitled Form'**
  String get untitledForm;

  /// No description provided for @untitledForm2.
  ///
  /// In en, this message translates to:
  /// **'Untitled Form2'**
  String get untitledForm2;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get upcomingEvents;

  /// No description provided for @upcomingOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Occurrences'**
  String get upcomingOccurrences;

  /// No description provided for @upcomingTasks.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Tasks'**
  String get upcomingTasks;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @updateRecurringTemplate.
  ///
  /// In en, this message translates to:
  /// **'Update Recurring Template'**
  String get updateRecurringTemplate;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get updateRequired;

  /// No description provided for @updateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Status'**
  String get updateStatus;

  /// No description provided for @updateSubject.
  ///
  /// In en, this message translates to:
  /// **'Update Subject'**
  String get updateSubject;

  /// No description provided for @updateTimezoneWithoutReportingAShift.
  ///
  /// In en, this message translates to:
  /// **'Update Timezone Without Reporting AShift'**
  String get updateTimezoneWithoutReportingAShift;

  /// No description provided for @updateUserInformationAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Update User Information And Settings'**
  String get updateUserInformationAndSettings;

  /// No description provided for @updatedDefaultRatesForUpdatedSubjects.
  ///
  /// In en, this message translates to:
  /// **'Updated Default Rates For Updated Subjects'**
  String get updatedDefaultRatesForUpdatedSubjects;

  /// No description provided for @updatedSelectedcountTaskS.
  ///
  /// In en, this message translates to:
  /// **'Updated Selectedcount Task S'**
  String get updatedSelectedcountTaskS;

  /// No description provided for @uploadImageOrUseSignaturePad.
  ///
  /// In en, this message translates to:
  /// **'Upload Image Or Use Signature Pad'**
  String get uploadImageOrUseSignaturePad;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// No description provided for @useCustomShiftName.
  ///
  /// In en, this message translates to:
  /// **'Use Custom Shift Name'**
  String get useCustomShiftName;

  /// No description provided for @useLowercaseWithUnderscores.
  ///
  /// In en, this message translates to:
  /// **'Use Lowercase With Underscores'**
  String get useLowercaseWithUnderscores;

  /// No description provided for @useStudentId.
  ///
  /// In en, this message translates to:
  /// **'Use Student Id'**
  String get useStudentId;

  /// No description provided for @userAnalytics.
  ///
  /// In en, this message translates to:
  /// **'User Analytics'**
  String get userAnalytics;

  /// No description provided for @userData.
  ///
  /// In en, this message translates to:
  /// **'User Data'**
  String get userData;

  /// No description provided for @userDataNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'User Data Not Loaded'**
  String get userDataNotLoaded;

  /// No description provided for @userDetails.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get userDetails;

  /// No description provided for @userDistribution.
  ///
  /// In en, this message translates to:
  /// **'User Distribution'**
  String get userDistribution;

  /// No description provided for @userDocumentNotFound.
  ///
  /// In en, this message translates to:
  /// **'User document not found'**
  String get userDocumentNotFound;

  /// No description provided for @userListScreenComingSoon.
  ///
  /// In en, this message translates to:
  /// **'User List Screen Coming Soon'**
  String get userListScreenComingSoon;

  /// No description provided for @userRole2.
  ///
  /// In en, this message translates to:
  /// **'User Role2'**
  String get userRole2;

  /// No description provided for @userType2.
  ///
  /// In en, this message translates to:
  /// **'User Type2'**
  String get userType2;

  /// No description provided for @userUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User Updated Successfully'**
  String get userUpdatedSuccessfully;

  /// No description provided for @userUpdatedSuccessfully2.
  ///
  /// In en, this message translates to:
  /// **'User Updated Successfully2'**
  String get userUpdatedSuccessfully2;

  /// No description provided for @usersDidnTLogInYet.
  ///
  /// In en, this message translates to:
  /// **'Users Didn TLog In Yet'**
  String get usersDidnTLogInYet;

  /// No description provided for @usersWillReceiveLoginCredentialsVia.
  ///
  /// In en, this message translates to:
  /// **'Users Will Receive Login Credentials Via'**
  String get usersWillReceiveLoginCredentialsVia;

  /// No description provided for @v.
  ///
  /// In en, this message translates to:
  /// **'V'**
  String get v;

  /// No description provided for @version100.
  ///
  /// In en, this message translates to:
  /// **'Version100'**
  String get version100;

  /// No description provided for @versionAndAppInformation.
  ///
  /// In en, this message translates to:
  /// **'Version And App Information'**
  String get versionAndAppInformation;

  /// No description provided for @veryComfortable.
  ///
  /// In en, this message translates to:
  /// **'Very Comfortable'**
  String get veryComfortable;

  /// No description provided for @videoProvider.
  ///
  /// In en, this message translates to:
  /// **'Video Provider'**
  String get videoProvider;

  /// No description provided for @viewAllActivity.
  ///
  /// In en, this message translates to:
  /// **'View All Activity'**
  String get viewAllActivity;

  /// No description provided for @viewAndPay.
  ///
  /// In en, this message translates to:
  /// **'View And Pay'**
  String get viewAndPay;

  /// No description provided for @viewAttachment.
  ///
  /// In en, this message translates to:
  /// **'View Attachment'**
  String get viewAttachment;

  /// No description provided for @viewAuditDetails.
  ///
  /// In en, this message translates to:
  /// **'View Audit Details'**
  String get viewAuditDetails;

  /// No description provided for @viewFile.
  ///
  /// In en, this message translates to:
  /// **'View File'**
  String get viewFile;

  /// No description provided for @viewForm.
  ///
  /// In en, this message translates to:
  /// **'View Form'**
  String get viewForm;

  /// No description provided for @viewFormDetails.
  ///
  /// In en, this message translates to:
  /// **'View Form Details'**
  String get viewFormDetails;

  /// No description provided for @viewOptions.
  ///
  /// In en, this message translates to:
  /// **'View Options'**
  String get viewOptions;

  /// No description provided for @viewResponse.
  ///
  /// In en, this message translates to:
  /// **'View Response'**
  String get viewResponse;

  /// No description provided for @viewShift.
  ///
  /// In en, this message translates to:
  /// **'View Shift'**
  String get viewShift;

  /// No description provided for @wageChangesApplied.
  ///
  /// In en, this message translates to:
  /// **'Wage Changes Applied'**
  String get wageChangesApplied;

  /// No description provided for @wageManagement.
  ///
  /// In en, this message translates to:
  /// **'Wage Management'**
  String get wageManagement;

  /// No description provided for @waitingForOthersToJoin.
  ///
  /// In en, this message translates to:
  /// **'Waiting For Others To Join'**
  String get waitingForOthersToJoin;

  /// No description provided for @wantToBecomeATeacher.
  ///
  /// In en, this message translates to:
  /// **'Want To Become ATeacher'**
  String get wantToBecomeATeacher;

  /// No description provided for @weAreCommittedToProtectingChildren.
  ///
  /// In en, this message translates to:
  /// **'We Are Committed To Protecting Children'**
  String get weAreCommittedToProtectingChildren;

  /// No description provided for @weAreFosteringAWorldWhere.
  ///
  /// In en, this message translates to:
  /// **'We Are Fostering AWorld Where'**
  String get weAreFosteringAWorldWhere;

  /// No description provided for @weCollectInformationYouProvideDirectly.
  ///
  /// In en, this message translates to:
  /// **'We Collect Information You Provide Directly'**
  String get weCollectInformationYouProvideDirectly;

  /// No description provided for @weDLoveToHearFrom.
  ///
  /// In en, this message translates to:
  /// **'We DLove To Hear From'**
  String get weDLoveToHearFrom;

  /// No description provided for @weImplementIndustryStandardSecurityMeasures.
  ///
  /// In en, this message translates to:
  /// **'We Implement Industry Standard Security Measures'**
  String get weImplementIndustryStandardSecurityMeasures;

  /// No description provided for @websiteContentSavedSuccessfullyChangesWill.
  ///
  /// In en, this message translates to:
  /// **'Website Content Saved Successfully Changes Will'**
  String get websiteContentSavedSuccessfullyChangesWill;

  /// No description provided for @websiteManagement.
  ///
  /// In en, this message translates to:
  /// **'Website Management'**
  String get websiteManagement;

  /// No description provided for @weekCalendar.
  ///
  /// In en, this message translates to:
  /// **'Week Calendar'**
  String get weekCalendar;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @weeklyCalendar.
  ///
  /// In en, this message translates to:
  /// **'Weekly Calendar'**
  String get weeklyCalendar;

  /// No description provided for @weeklyRecurrenceSettings.
  ///
  /// In en, this message translates to:
  /// **'Weekly Recurrence Settings'**
  String get weeklyRecurrenceSettings;

  /// No description provided for @welcomeBackFirstname.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back Firstname'**
  String get welcomeBackFirstname;

  /// No description provided for @welcomeToAlluvialAcademy.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Alluvial Academy'**
  String get welcomeToAlluvialAcademy;

  /// No description provided for @whatNeedsToBeDone.
  ///
  /// In en, this message translates to:
  /// **'What Needs To Be Done'**
  String get whatNeedsToBeDone;

  /// No description provided for @whatSTheIssue.
  ///
  /// In en, this message translates to:
  /// **'What SThe Issue'**
  String get whatSTheIssue;

  /// No description provided for @whatShouldTheCorrectTimesBe.
  ///
  /// In en, this message translates to:
  /// **'What Should The Correct Times Be'**
  String get whatShouldTheCorrectTimesBe;

  /// No description provided for @whatShouldTheCorrectValueBe.
  ///
  /// In en, this message translates to:
  /// **'What Should The Correct Value Be'**
  String get whatShouldTheCorrectValueBe;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp'**
  String get whatsapp;

  /// No description provided for @whatsappNumber.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp Number'**
  String get whatsappNumber;

  /// No description provided for @whatsappNumber2.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp Number2'**
  String get whatsappNumber2;

  /// No description provided for @whenInvoicesAreCreatedTheyWill.
  ///
  /// In en, this message translates to:
  /// **'When Invoices Are Created They Will'**
  String get whenInvoicesAreCreatedTheyWill;

  /// No description provided for @whereEducationTranscendsBoundaries.
  ///
  /// In en, this message translates to:
  /// **'Where Education Transcends Boundaries'**
  String get whereEducationTranscendsBoundaries;

  /// No description provided for @whyChooseOurEnglishProgram.
  ///
  /// In en, this message translates to:
  /// **'Why Choose Our English Program'**
  String get whyChooseOurEnglishProgram;

  /// No description provided for @whyChooseOurMathProgram.
  ///
  /// In en, this message translates to:
  /// **'Why Choose Our Math Program'**
  String get whyChooseOurMathProgram;

  /// No description provided for @whyChooseOurTeachers.
  ///
  /// In en, this message translates to:
  /// **'Why Choose Our Teachers'**
  String get whyChooseOurTeachers;

  /// No description provided for @whyLearnToCode.
  ///
  /// In en, this message translates to:
  /// **'Why Learn To Code'**
  String get whyLearnToCode;

  /// No description provided for @worldClassEducation.
  ///
  /// In en, this message translates to:
  /// **'World Class Education'**
  String get worldClassEducation;

  /// No description provided for @wouldYouLikeToClockOut.
  ///
  /// In en, this message translates to:
  /// **'Would You Like To Clock Out'**
  String get wouldYouLikeToClockOut;

  /// No description provided for @wouldYouLikeToCompleteThe.
  ///
  /// In en, this message translates to:
  /// **'Would You Like To Complete The'**
  String get wouldYouLikeToCompleteThe;

  /// No description provided for @yearlyRecurrenceSettings.
  ///
  /// In en, this message translates to:
  /// **'Yearly Recurrence Settings'**
  String get yearlyRecurrenceSettings;

  /// No description provided for @yesAndAlways.
  ///
  /// In en, this message translates to:
  /// **'Yes And Always'**
  String get yesAndAlways;

  /// No description provided for @yesUpdateTemplate.
  ///
  /// In en, this message translates to:
  /// **'Yes Update Template'**
  String get yesUpdateTemplate;

  /// Confirmation dialog text before bulk rejecting timesheets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are about to reject 1 timesheet.} other{You are about to reject {count} timesheets.}}'**
  String youAreAboutToRejectCount(int count);

  /// No description provided for @youAreNotAssignedToThis.
  ///
  /// In en, this message translates to:
  /// **'You Are Not Assigned To This'**
  String get youAreNotAssignedToThis;

  /// No description provided for @youCanAddMultipleStudentsIn.
  ///
  /// In en, this message translates to:
  /// **'You Can Add Multiple Students In'**
  String get youCanAddMultipleStudentsIn;

  /// No description provided for @youCanOnlyDeleteTasksYou.
  ///
  /// In en, this message translates to:
  /// **'You Can Only Delete Tasks You'**
  String get youCanOnlyDeleteTasksYou;

  /// No description provided for @youDonTHavePermissionTo.
  ///
  /// In en, this message translates to:
  /// **'You Don THave Permission To'**
  String get youDonTHavePermissionTo;

  /// No description provided for @youHaveAlreadySubmittedThisForm.
  ///
  /// In en, this message translates to:
  /// **'You Have Already Submitted This Form'**
  String get youHaveAlreadySubmittedThisForm;

  /// No description provided for @youHaveAlreadySubmittedThisForm2.
  ///
  /// In en, this message translates to:
  /// **'You Have Already Submitted This Form2'**
  String get youHaveAlreadySubmittedThisForm2;

  /// No description provided for @youHaveNoCompletedOrMissed.
  ///
  /// In en, this message translates to:
  /// **'You have no completed or missed classes. If you are trying to submit a report for an older class, please contact your admin.'**
  String get youHaveNoCompletedOrMissed;

  /// No description provided for @youHaveTheRightToAccess.
  ///
  /// In en, this message translates to:
  /// **'You Have The Right To Access'**
  String get youHaveTheRightToAccess;

  /// No description provided for @youHaveUnsavedChangesAreYou.
  ///
  /// In en, this message translates to:
  /// **'You Have Unsaved Changes Are You'**
  String get youHaveUnsavedChangesAreYou;

  /// No description provided for @youMustBeLoggedInTo.
  ///
  /// In en, this message translates to:
  /// **'You Must Be Logged In To'**
  String get youMustBeLoggedInTo;

  /// No description provided for @youReAllSet.
  ///
  /// In en, this message translates to:
  /// **'You Re All Set'**
  String get youReAllSet;

  /// No description provided for @youReManagingRoledisplay.
  ///
  /// In en, this message translates to:
  /// **'You Re Managing Roledisplay'**
  String get youReManagingRoledisplay;

  /// No description provided for @youReSignedInAsRoledisplay.
  ///
  /// In en, this message translates to:
  /// **'You Re Signed In As Roledisplay'**
  String get youReSignedInAsRoledisplay;

  /// No description provided for @yourAccountHasNotBeenSet.
  ///
  /// In en, this message translates to:
  /// **'Your Account Has Not Been Set'**
  String get yourAccountHasNotBeenSet;

  /// No description provided for @yourAuditReportWillBeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Your Audit Report Will Be Available'**
  String get yourAuditReportWillBeAvailable;

  /// No description provided for @yourChildHasNoScheduledClasses.
  ///
  /// In en, this message translates to:
  /// **'Your Child Has No Scheduled Classes'**
  String get yourChildHasNoScheduledClasses;

  /// No description provided for @yourChildHasNoUpcomingClasses.
  ///
  /// In en, this message translates to:
  /// **'Your Child Has No Upcoming Classes'**
  String get yourChildHasNoUpcomingClasses;

  /// No description provided for @yourClasses.
  ///
  /// In en, this message translates to:
  /// **'Your Classes'**
  String get yourClasses;

  /// No description provided for @yourInformation.
  ///
  /// In en, this message translates to:
  /// **'Your Information'**
  String get yourInformation;

  /// No description provided for @yourInformationIsUsedToProvide.
  ///
  /// In en, this message translates to:
  /// **'Your Information Is Used To Provide'**
  String get yourInformationIsUsedToProvide;

  /// No description provided for @yourIslamicEducationJourneyStartsHere.
  ///
  /// In en, this message translates to:
  /// **'Your Islamic Education Journey Starts Here'**
  String get yourIslamicEducationJourneyStartsHere;

  /// No description provided for @yourPerformanceDataWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your Performance Data Will Appear Here'**
  String get yourPerformanceDataWillAppearHere;

  /// No description provided for @yourPrivacyIsImportantToUs.
  ///
  /// In en, this message translates to:
  /// **'Your Privacy Is Important To Us'**
  String get yourPrivacyIsImportantToUs;

  /// No description provided for @yourProfileSettings.
  ///
  /// In en, this message translates to:
  /// **'Your Profile Settings'**
  String get yourProfileSettings;

  /// No description provided for @yourProgressWillBeAutomaticallySaved.
  ///
  /// In en, this message translates to:
  /// **'Your Progress Will Be Automatically Saved'**
  String get yourProgressWillBeAutomaticallySaved;

  /// No description provided for @yourRights.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get yourRights;

  /// No description provided for @yourScheduledClassesWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Your Scheduled Classes Will Appear Here'**
  String get yourScheduledClassesWillAppearHere;

  /// No description provided for @yourTeacherHasnTJoinedThe.
  ///
  /// In en, this message translates to:
  /// **'Your Teacher Hasn TJoined The'**
  String get yourTeacherHasnTJoinedThe;

  /// No description provided for @yourTimezone.
  ///
  /// In en, this message translates to:
  /// **'Your Timezone'**
  String get yourTimezone;

  /// No description provided for @commonNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get commonNotSignedIn;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get commonNotAvailable;

  /// No description provided for @commonNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Not loaded'**
  String get commonNotLoaded;

  /// No description provided for @commonErrorWithDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {details}'**
  String commonErrorWithDetails(Object details);

  /// No description provided for @commonActivated.
  ///
  /// In en, this message translates to:
  /// **'activated'**
  String get commonActivated;

  /// No description provided for @commonDeactivated.
  ///
  /// In en, this message translates to:
  /// **'deactivated'**
  String get commonDeactivated;

  /// No description provided for @testRoleAuthUser.
  ///
  /// In en, this message translates to:
  /// **'Auth User: {email}'**
  String testRoleAuthUser(Object email);

  /// No description provided for @testRoleUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID: {userId}'**
  String testRoleUserId(Object userId);

  /// No description provided for @testRoleRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String testRoleRole(Object role);

  /// No description provided for @testRoleKeyValue.
  ///
  /// In en, this message translates to:
  /// **'{key}: {value}'**
  String testRoleKeyValue(Object key, Object value);

  /// No description provided for @debugDocumentId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String debugDocumentId(Object id);

  /// No description provided for @debugEmail.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String debugEmail(Object email);

  /// No description provided for @debugName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String debugName(Object name);

  /// No description provided for @debugType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String debugType(Object type);

  /// No description provided for @debugMoreDocuments.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more documents'**
  String debugMoreDocuments(Object count);

  /// No description provided for @applicationSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit application: {details}'**
  String applicationSubmitFailed(Object details);

  /// No description provided for @notificationSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Notifications sent successfully'**
  String get notificationSentSuccess;

  /// No description provided for @notificationRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients: {count}'**
  String notificationRecipients(Object count);

  /// No description provided for @notificationSuccessCount.
  ///
  /// In en, this message translates to:
  /// **'✓ Success: {count}'**
  String notificationSuccessCount(Object count);

  /// No description provided for @notificationFailedCount.
  ///
  /// In en, this message translates to:
  /// **'✗ Failed: {count}'**
  String notificationFailedCount(Object count);

  /// No description provided for @notificationTotalRecipients.
  ///
  /// In en, this message translates to:
  /// **'Total Recipients: {count}'**
  String notificationTotalRecipients(Object count);

  /// No description provided for @notificationEmailsSentCount.
  ///
  /// In en, this message translates to:
  /// **'✓ Sent: {count}'**
  String notificationEmailsSentCount(Object count);

  /// No description provided for @notificationEmailsFailedCount.
  ///
  /// In en, this message translates to:
  /// **'✗ Failed: {count}'**
  String notificationEmailsFailedCount(Object count);

  /// No description provided for @classJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join class: {details}'**
  String classJoinFailed(Object details);

  /// No description provided for @formsListFormStatus.
  ///
  /// In en, this message translates to:
  /// **'Form {status}'**
  String formsListFormStatus(Object status, Object statut);

  /// No description provided for @formsListTemplateStatus.
  ///
  /// In en, this message translates to:
  /// **'Template {status}'**
  String formsListTemplateStatus(Object status, Object statut);

  /// No description provided for @formsListDeleteFieldConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{field}\"?'**
  String formsListDeleteFieldConfirm(Object field);

  /// No description provided for @formsListOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String formsListOptionHint(Object index);

  /// No description provided for @userDetailName.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String userDetailName(Object name);

  /// No description provided for @userDetailEmail.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String userDetailEmail(Object email);

  /// No description provided for @userDetailRole.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String userDetailRole(Object role);

  /// No description provided for @userPromoteError.
  ///
  /// In en, this message translates to:
  /// **'Error promoting user: {details}'**
  String userPromoteError(Object details);

  /// No description provided for @userRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke admin privileges.'**
  String get userRevokeFailed;

  /// No description provided for @userRevokeError.
  ///
  /// In en, this message translates to:
  /// **'Error revoking privileges: {details}'**
  String userRevokeError(Object details);

  /// No description provided for @userArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive user.'**
  String get userArchiveFailed;

  /// No description provided for @userDeactivateError.
  ///
  /// In en, this message translates to:
  /// **'Error deactivating user: {details}'**
  String userDeactivateError(Object details);

  /// No description provided for @userRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore user.'**
  String get userRestoreFailed;

  /// No description provided for @userActivateError.
  ///
  /// In en, this message translates to:
  /// **'Error activating user: {details}'**
  String userActivateError(Object details);

  /// No description provided for @userCredentialsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading credentials: {details}'**
  String userCredentialsLoadError(Object details);

  /// No description provided for @userResetPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Error resetting password: {details}'**
  String userResetPasswordError(Object details);

  /// No description provided for @userDeleteSelfNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You cannot delete your own account.'**
  String get userDeleteSelfNotAllowed;

  /// No description provided for @userArchiveBeforeDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to archive user before deletion.'**
  String get userArchiveBeforeDeleteFailed;

  /// No description provided for @userDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting user: {details}'**
  String userDeleteError(Object details);

  /// No description provided for @userArchiveAndDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive & Permanently Delete'**
  String get userArchiveAndDeleteTitle;

  /// No description provided for @userDeletePermanentTitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete User'**
  String get userDeletePermanentTitle;

  /// No description provided for @userDeleteActiveInfo.
  ///
  /// In en, this message translates to:
  /// **'This user is currently active. They will be archived first, then permanently deleted.'**
  String get userDeleteActiveInfo;

  /// No description provided for @userDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User deleted successfully'**
  String get userDeletedSuccessfully;

  /// No description provided for @userEmailRole.
  ///
  /// In en, this message translates to:
  /// **'{email} • {role}'**
  String userEmailRole(Object email, Object role);

  /// No description provided for @auditMetricsComputed.
  ///
  /// In en, this message translates to:
  /// **'Metrics computed! Score: {score}%'**
  String auditMetricsComputed(Object score);

  /// No description provided for @wageUpdatedUsers.
  ///
  /// In en, this message translates to:
  /// **'Updated wages for {count} users'**
  String wageUpdatedUsers(Object count);

  /// No description provided for @wageUpdatedShifts.
  ///
  /// In en, this message translates to:
  /// **'✅ Updated {count} shifts'**
  String wageUpdatedShifts(Object count);

  /// No description provided for @wageUpdatedTimesheets.
  ///
  /// In en, this message translates to:
  /// **'✅ Updated {count} timesheet entries'**
  String wageUpdatedTimesheets(Object count);

  /// No description provided for @timesheetSubmitDrafts.
  ///
  /// In en, this message translates to:
  /// **'Submit Drafts ({count})'**
  String timesheetSubmitDrafts(Object count);

  /// No description provided for @formsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading forms: {details}'**
  String formsErrorLoading(Object details);

  /// No description provided for @formsNoDataReceived.
  ///
  /// In en, this message translates to:
  /// **'No forms data received. Please check your connection.'**
  String get formsNoDataReceived;

  /// No description provided for @formsErrorLoadingForm.
  ///
  /// In en, this message translates to:
  /// **'Error loading form: {details}'**
  String formsErrorLoadingForm(Object details);

  /// No description provided for @livekitParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'Participants ({count})'**
  String livekitParticipantsCount(Object count);

  /// No description provided for @auditGenerateCount.
  ///
  /// In en, this message translates to:
  /// **'Generate ({count})'**
  String auditGenerateCount(Object count);

  /// No description provided for @auditScoreWithTier.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}% • {tier}'**
  String auditScoreWithTier(Object score, Object tier);

  /// No description provided for @auditPaymentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Payment updated to \${amount}. Total payment recalculated.'**
  String auditPaymentUpdated(Object amount);

  /// No description provided for @auditPenaltyApplied.
  ///
  /// In en, this message translates to:
  /// **'Penalty of \${amount} applied'**
  String auditPenaltyApplied(Object amount);

  /// No description provided for @auditMaxPayment.
  ///
  /// In en, this message translates to:
  /// **'Maximum payment for {subject} is \${amount} (max \${hourly}/hour)'**
  String auditMaxPayment(
      Object subject, Object amount, Object hourly, Object sujet, Object time);

  /// No description provided for @auditDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day: {day}'**
  String auditDayLabel(Object day, Object jour);

  /// No description provided for @auditShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'{student} - {subject}'**
  String auditShiftTitle(Object student, Object subject);

  /// No description provided for @auditDisputeField.
  ///
  /// In en, this message translates to:
  /// **'Field: {field}'**
  String auditDisputeField(Object field);

  /// No description provided for @auditDisputeReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String auditDisputeReason(Object reason);

  /// No description provided for @payHourlyRateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Hourly rate updated to \${amount}'**
  String payHourlyRateUpdated(Object amount);

  /// No description provided for @paySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {details}'**
  String paySaveFailed(Object details);

  /// No description provided for @timeClockClockOutExceed.
  ///
  /// In en, this message translates to:
  /// **'Clock-out time cannot exceed scheduled shift end time ({time})'**
  String timeClockClockOutExceed(Object time);

  /// No description provided for @timeClockClockOutExceedShort.
  ///
  /// In en, this message translates to:
  /// **'Clock-out time cannot exceed shift end: {time}'**
  String timeClockClockOutExceedShort(Object time);

  /// No description provided for @assignmentErrorOpeningFile.
  ///
  /// In en, this message translates to:
  /// **'Error opening file: {details}'**
  String assignmentErrorOpeningFile(Object details);

  /// No description provided for @assignmentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This action cannot be undone.'**
  String assignmentDeleteConfirm(Object title);

  /// No description provided for @assignmentLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'Assignments loaded (limit 10): {count}'**
  String assignmentLoadedCount(Object count);

  /// No description provided for @assignmentUserId.
  ///
  /// In en, this message translates to:
  /// **'Your user ID: {id}'**
  String assignmentUserId(Object id);

  /// No description provided for @assignmentDocId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String assignmentDocId(Object id);

  /// No description provided for @assignmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Title: {title}'**
  String assignmentTitle(Object title);

  /// No description provided for @assignmentTeacherId.
  ///
  /// In en, this message translates to:
  /// **'Teacher ID: {id}'**
  String assignmentTeacherId(Object id);

  /// No description provided for @assignmentStudentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{# student} other{# students}}'**
  String assignmentStudentsCount(num count);

  /// No description provided for @assignmentUploadingFile.
  ///
  /// In en, this message translates to:
  /// **'Uploading \"{fileName}\"...'**
  String assignmentUploadingFile(Object fileName);

  /// No description provided for @assignmentUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'File \"{fileName}\" uploaded successfully!'**
  String assignmentUploadSuccess(Object fileName);

  /// No description provided for @assignmentUploadError.
  ///
  /// In en, this message translates to:
  /// **'Error uploading file: {details}'**
  String assignmentUploadError(Object details);

  /// No description provided for @taskDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download file: {details}'**
  String taskDownloadFailed(Object details);

  /// No description provided for @taskRemoveAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove attachment: {details}'**
  String taskRemoveAttachmentFailed(Object details);

  /// No description provided for @taskDeleteAttachmentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {fileName}?'**
  String taskDeleteAttachmentConfirm(Object fileName);

  /// No description provided for @taskDeleteCommentError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting comment: {details}'**
  String taskDeleteCommentError(Object details);

  /// No description provided for @taskSubtaskHint.
  ///
  /// In en, this message translates to:
  /// **'Sub-task {index}'**
  String taskSubtaskHint(Object index);

  /// No description provided for @timesheetPendingReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{# new timesheet pending review} other{# new timesheets pending review}}'**
  String timesheetPendingReview(num count);

  /// No description provided for @timesheetTotalEntries.
  ///
  /// In en, this message translates to:
  /// **'Total Entries: {count}'**
  String timesheetTotalEntries(Object count);

  /// No description provided for @timesheetTotalPayment.
  ///
  /// In en, this message translates to:
  /// **'Total Payment: \${amount}'**
  String timesheetTotalPayment(Object amount);

  /// No description provided for @timesheetTimeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} - {end}'**
  String timesheetTimeRange(Object start, Object end);

  /// No description provided for @timesheetEntrySummary.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours • \${amount}'**
  String timesheetEntrySummary(Object hours, Object amount);

  /// No description provided for @formSubmissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Submissions • {title}'**
  String formSubmissionsTitle(Object title);

  /// No description provided for @formSubmissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{# submission} other{# submissions}}'**
  String formSubmissionsCount(num count);

  /// No description provided for @timeClockAutoClockOut.
  ///
  /// In en, this message translates to:
  /// **'Shift ended - automatically clocked out from {shift}'**
  String timeClockAutoClockOut(Object shift);

  /// No description provided for @timeClockClockOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Clock-out failed: {details}'**
  String timeClockClockOutFailed(Object details);

  /// No description provided for @timeClockClockInFailed.
  ///
  /// In en, this message translates to:
  /// **'Clock-in failed: {details}'**
  String timeClockClockInFailed(Object details);

  /// No description provided for @shiftSelectedTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Selected ({abbr}): {startDate}, {startTime} - {endDatePart}{endTime}'**
  String shiftSelectedTimeRange(Object abbr, Object startDate, Object startTime,
      Object endDatePart, Object endTime);

  /// No description provided for @shiftSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected ({count})'**
  String shiftSelectedCount(Object count);

  /// No description provided for @shiftConfirmCount.
  ///
  /// In en, this message translates to:
  /// **'Confirm ({count})'**
  String shiftConfirmCount(Object count);

  /// No description provided for @taskBulkChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status for {count} Tasks'**
  String taskBulkChangeStatus(Object count);

  /// No description provided for @taskBulkChangePriority.
  ///
  /// In en, this message translates to:
  /// **'Change Priority for {count} Tasks'**
  String taskBulkChangePriority(Object count);

  /// No description provided for @taskBulkDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} task(s)? This action cannot be undone.'**
  String taskBulkDeleteConfirm(Object count);

  /// No description provided for @taskDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String taskDeleteConfirm(Object title);

  /// No description provided for @shiftDeletingCount.
  ///
  /// In en, this message translates to:
  /// **'Deleting {count} shifts...'**
  String shiftDeletingCount(Object count);

  /// No description provided for @dashboardErrorLoadingFormDetails.
  ///
  /// In en, this message translates to:
  /// **'Error loading form details: {details}'**
  String dashboardErrorLoadingFormDetails(Object details);

  /// No description provided for @dashboardErrorOpeningLink.
  ///
  /// In en, this message translates to:
  /// **'Error opening link: {details}'**
  String dashboardErrorOpeningLink(Object details);

  /// No description provided for @dashboardClockInProgrammed.
  ///
  /// In en, this message translates to:
  /// **'Clock-in programmed for {time}'**
  String dashboardClockInProgrammed(Object time);

  /// No description provided for @dashboardAssignmentCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create assignment: {details}'**
  String dashboardAssignmentCreateFailed(Object details);

  /// No description provided for @dashboardFileAdded.
  ///
  /// In en, this message translates to:
  /// **'File \"{fileName}\" added successfully!'**
  String dashboardFileAdded(Object fileName);

  /// No description provided for @performanceLogViewerOnlyendevents.
  ///
  /// In en, this message translates to:
  /// **'Only END events'**
  String get performanceLogViewerOnlyendevents;

  /// No description provided for @performanceLogViewerPerfenabled.
  ///
  /// In en, this message translates to:
  /// **'Perf enabled'**
  String get performanceLogViewerPerfenabled;

  /// No description provided for @performanceLogViewerCaptureenabled.
  ///
  /// In en, this message translates to:
  /// **'Capture enabled'**
  String get performanceLogViewerCaptureenabled;

  /// No description provided for @performanceLogViewerEndops.
  ///
  /// In en, this message translates to:
  /// **'END ops'**
  String get performanceLogViewerEndops;

  /// No description provided for @performanceLogViewerSlow.
  ///
  /// In en, this message translates to:
  /// **'SLOW'**
  String get performanceLogViewerSlow;

  /// No description provided for @performanceLogViewerModerate.
  ///
  /// In en, this message translates to:
  /// **'MODERATE'**
  String get performanceLogViewerModerate;

  /// No description provided for @performanceLogViewerFast.
  ///
  /// In en, this message translates to:
  /// **'FAST'**
  String get performanceLogViewerFast;

  /// No description provided for @performanceLogViewerAvg.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get performanceLogViewerAvg;

  /// No description provided for @adminSettingsNotificationemail.
  ///
  /// In en, this message translates to:
  /// **'Notification Email'**
  String get adminSettingsNotificationemail;

  /// Label for notification lead time options (e.g. '15 min').
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String notificationPreferencesMinutesmin(int minutes);

  /// No description provided for @quickTasksAssignedby.
  ///
  /// In en, this message translates to:
  /// **'Assigned By'**
  String get quickTasksAssignedby;

  /// No description provided for @quickTasksLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get quickTasksLabels;

  /// No description provided for @quickTasksAssignedbyme.
  ///
  /// In en, this message translates to:
  /// **'Assigned by Me'**
  String get quickTasksAssignedbyme;

  /// No description provided for @quickTasksAssignedtome.
  ///
  /// In en, this message translates to:
  /// **'Assigned to Me'**
  String get quickTasksAssignedtome;

  /// No description provided for @quranReaderTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get quranReaderTranslation;

  /// No description provided for @quranReaderReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get quranReaderReload;

  /// No description provided for @adminDashboardActivetoday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get adminDashboardActivetoday;

  /// No description provided for @adminDashboardOnlinenow.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get adminDashboardOnlinenow;

  /// No description provided for @adminDashboardLiveforms.
  ///
  /// In en, this message translates to:
  /// **'Live forms'**
  String get adminDashboardLiveforms;

  /// No description provided for @timelineShiftClockinnotyet.
  ///
  /// In en, this message translates to:
  /// **'Clock In (Not Yet)'**
  String get timelineShiftClockinnotyet;

  /// No description provided for @timelineShiftProgrammed.
  ///
  /// In en, this message translates to:
  /// **'PROGRAMMED'**
  String get timelineShiftProgrammed;

  /// No description provided for @timelineShiftActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get timelineShiftActive;

  /// No description provided for @timelineShiftCompleted.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get timelineShiftCompleted;

  /// No description provided for @timelineShiftPartial.
  ///
  /// In en, this message translates to:
  /// **'PARTIAL'**
  String get timelineShiftPartial;

  /// No description provided for @timelineShiftMissed.
  ///
  /// In en, this message translates to:
  /// **'MISSED'**
  String get timelineShiftMissed;

  /// No description provided for @timelineShiftCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get timelineShiftCancelled;

  /// No description provided for @timelineShiftReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get timelineShiftReady;

  /// No description provided for @timelineShiftUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get timelineShiftUpcoming;

  /// No description provided for @shiftManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Management'**
  String get shiftManagementTitle;

  /// No description provided for @shiftThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get shiftThisWeek;

  /// No description provided for @shiftSelectDays.
  ///
  /// In en, this message translates to:
  /// **'Select days'**
  String get shiftSelectDays;

  /// No description provided for @shiftNoTemplatesFound.
  ///
  /// In en, this message translates to:
  /// **'No schedule templates found'**
  String get shiftNoTemplatesFound;

  /// No description provided for @shiftTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get shiftTimeLabel;

  /// No description provided for @shiftTimePerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Time per day'**
  String get shiftTimePerDayLabel;

  /// No description provided for @shiftScheduleUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Schedule updated successfully'**
  String get shiftScheduleUpdatedSuccess;

  /// No description provided for @shiftScheduleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update schedule'**
  String get shiftScheduleUpdateFailed;

  /// No description provided for @hideFilters.
  ///
  /// In en, this message translates to:
  /// **'Hide filters'**
  String get hideFilters;

  /// No description provided for @showFilters.
  ///
  /// In en, this message translates to:
  /// **'Show filters'**
  String get showFilters;

  /// No description provided for @shiftManagementGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get shiftManagementGrid;

  /// No description provided for @shiftManagementList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get shiftManagementList;

  /// No description provided for @shiftTabAllCount.
  ///
  /// In en, this message translates to:
  /// **'All Shifts ({count})'**
  String shiftTabAllCount(int count);

  /// No description provided for @shiftTabTodayCount.
  ///
  /// In en, this message translates to:
  /// **'Today ({count})'**
  String shiftTabTodayCount(int count);

  /// No description provided for @shiftTabUpcomingCount.
  ///
  /// In en, this message translates to:
  /// **'Upcoming ({count})'**
  String shiftTabUpcomingCount(int count);

  /// No description provided for @shiftTabActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String shiftTabActiveCount(int count);

  /// No description provided for @shiftTemplateManagement.
  ///
  /// In en, this message translates to:
  /// **'Schedule Templates'**
  String get shiftTemplateManagement;

  /// No description provided for @shiftTemplateDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Schedule'**
  String get shiftTemplateDeactivate;

  /// No description provided for @shiftTemplateReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate Schedule'**
  String get shiftTemplateReactivate;

  /// No description provided for @shiftTemplateReassign.
  ///
  /// In en, this message translates to:
  /// **'Reassign Schedule'**
  String get shiftTemplateReassign;

  /// No description provided for @shiftTemplateModifyDays.
  ///
  /// In en, this message translates to:
  /// **'Modify Days'**
  String get shiftTemplateModifyDays;

  /// No description provided for @shiftTemplateDeactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will stop generating future shifts for this schedule. Existing shifts won\'t be deleted.'**
  String get shiftTemplateDeactivateConfirm;

  /// No description provided for @shiftTemplateReactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will resume generating future shifts for this schedule.'**
  String get shiftTemplateReactivateConfirm;

  /// No description provided for @shiftTemplateDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Schedule deactivated'**
  String get shiftTemplateDeactivated;

  /// No description provided for @shiftTemplateReactivated.
  ///
  /// In en, this message translates to:
  /// **'Schedule reactivated'**
  String get shiftTemplateReactivated;

  /// No description provided for @shiftTemplateFilterTeacher.
  ///
  /// In en, this message translates to:
  /// **'Filter by teacher'**
  String get shiftTemplateFilterTeacher;

  /// No description provided for @shiftTemplateCompleteSchedule.
  ///
  /// In en, this message translates to:
  /// **'Complete schedule'**
  String get shiftTemplateCompleteSchedule;

  /// No description provided for @shiftTemplateSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search teacher, student...'**
  String get shiftTemplateSearchPlaceholder;

  /// No description provided for @shiftTemplateViewTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get shiftTemplateViewTemplates;

  /// No description provided for @shiftTemplateViewSchedule.
  ///
  /// In en, this message translates to:
  /// **'Complete schedule'**
  String get shiftTemplateViewSchedule;

  /// No description provided for @shiftTemplateAllTeachers.
  ///
  /// In en, this message translates to:
  /// **'All teachers'**
  String get shiftTemplateAllTeachers;

  /// No description provided for @shiftTemplateSelectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Select teacher'**
  String get shiftTemplateSelectTeacher;

  /// No description provided for @shiftTemplateStudentSchedule.
  ///
  /// In en, this message translates to:
  /// **'Student schedule'**
  String get shiftTemplateStudentSchedule;

  /// No description provided for @shiftWeeklyScheduleSetup.
  ///
  /// In en, this message translates to:
  /// **'Weekly Schedule Setup'**
  String get shiftWeeklyScheduleSetup;

  /// No description provided for @shiftPerDayTime.
  ///
  /// In en, this message translates to:
  /// **'Set time per day'**
  String get shiftPerDayTime;

  /// No description provided for @shiftSameTimeAllDays.
  ///
  /// In en, this message translates to:
  /// **'Same time for all days'**
  String get shiftSameTimeAllDays;

  /// No description provided for @shiftDifferentTimePerDay.
  ///
  /// In en, this message translates to:
  /// **'Different time per day'**
  String get shiftDifferentTimePerDay;

  /// No description provided for @subjectManagementDisplayname.
  ///
  /// In en, this message translates to:
  /// **'Display Name *'**
  String get subjectManagementDisplayname;

  /// No description provided for @subjectManagementArabicnameoptional.
  ///
  /// In en, this message translates to:
  /// **'Arabic Name (Optional)'**
  String get subjectManagementArabicnameoptional;

  /// No description provided for @subjectManagementDefaulthourlywageoptional.
  ///
  /// In en, this message translates to:
  /// **'Default Hourly Wage (Optional)'**
  String get subjectManagementDefaulthourlywageoptional;

  /// No description provided for @shiftDetailsTimeworked.
  ///
  /// In en, this message translates to:
  /// **'Time Worked'**
  String get shiftDetailsTimeworked;

  /// No description provided for @shiftDetailsRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get shiftDetailsRate;

  /// No description provided for @parentInvoicesPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get parentInvoicesPaid;

  /// No description provided for @studentQuickStatsAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get studentQuickStatsAttendance;

  /// No description provided for @studentQuickStatsTasksdone.
  ///
  /// In en, this message translates to:
  /// **'Tasks Done'**
  String get studentQuickStatsTasksdone;

  /// No description provided for @studentProgressTabTotalhours.
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get studentProgressTabTotalhours;

  /// No description provided for @studentProgressTabSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get studentProgressTabSubjects;

  /// No description provided for @financialSummaryOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get financialSummaryOutstanding;

  /// No description provided for @zoomCheckingwhosintheroom.
  ///
  /// In en, this message translates to:
  /// **'Checking who’s in the room…'**
  String get zoomCheckingwhosintheroom;

  /// No description provided for @zoomUnabletoloadparticipants.
  ///
  /// In en, this message translates to:
  /// **'Unable to load participants'**
  String get zoomUnabletoloadparticipants;

  /// Shows how many participants are currently in the class.
  ///
  /// In en, this message translates to:
  /// **'In class now: {count}'**
  String zoomInclassnowcount(int count);

  /// No description provided for @studentFeatureTourLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get studentFeatureTourLive;

  /// No description provided for @studentFeatureTourJoinnow.
  ///
  /// In en, this message translates to:
  /// **'JOIN NOW'**
  String get studentFeatureTourJoinnow;

  /// No description provided for @studentFeatureTourStartingsoon.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get studentFeatureTourStartingsoon;

  /// No description provided for @studentFeatureTourStartingin15min.
  ///
  /// In en, this message translates to:
  /// **'Starting in 15 min'**
  String get studentFeatureTourStartingin15min;

  /// No description provided for @formsListNewquestion.
  ///
  /// In en, this message translates to:
  /// **'New Question'**
  String get formsListNewquestion;

  /// No description provided for @adminAuditAvgscore.
  ///
  /// In en, this message translates to:
  /// **'Avg Score'**
  String get adminAuditAvgscore;

  /// No description provided for @adminAuditTotalteachersaudited.
  ///
  /// In en, this message translates to:
  /// **'Total Teachers Audited'**
  String get adminAuditTotalteachersaudited;

  /// No description provided for @adminAuditAveragescore.
  ///
  /// In en, this message translates to:
  /// **'Average Score'**
  String get adminAuditAveragescore;

  /// No description provided for @adminAuditTotalpayoutdue.
  ///
  /// In en, this message translates to:
  /// **'Total Payout Due'**
  String get adminAuditTotalpayoutdue;

  /// No description provided for @adminAuditPendingreviews.
  ///
  /// In en, this message translates to:
  /// **'Pending Reviews'**
  String get adminAuditPendingreviews;

  /// No description provided for @adminAuditPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get adminAuditPayout;

  /// No description provided for @adminAuditAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adminAuditAdjust;

  /// No description provided for @adminAuditPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get adminAuditPlanned;

  /// No description provided for @adminAuditMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get adminAuditMissing;

  /// No description provided for @formTemplate1unacceptable.
  ///
  /// In en, this message translates to:
  /// **'1 - Unacceptable'**
  String get formTemplate1unacceptable;

  /// No description provided for @formTemplate1verypoor.
  ///
  /// In en, this message translates to:
  /// **'1 - Very Poor'**
  String get formTemplate1verypoor;

  /// No description provided for @formTemplate12days.
  ///
  /// In en, this message translates to:
  /// **'1-2 days'**
  String get formTemplate12days;

  /// No description provided for @formTemplate10outstanding.
  ///
  /// In en, this message translates to:
  /// **'10 - Outstanding'**
  String get formTemplate10outstanding;

  /// No description provided for @formTemplate2poor.
  ///
  /// In en, this message translates to:
  /// **'2 - Poor'**
  String get formTemplate2poor;

  /// No description provided for @formTemplate2verypoor.
  ///
  /// In en, this message translates to:
  /// **'2 - Very Poor'**
  String get formTemplate2verypoor;

  /// No description provided for @formTemplate2448hours.
  ///
  /// In en, this message translates to:
  /// **'24-48 hours'**
  String get formTemplate2448hours;

  /// No description provided for @formTemplate3average.
  ///
  /// In en, this message translates to:
  /// **'3 - Average'**
  String get formTemplate3average;

  /// No description provided for @formTemplate3poor.
  ///
  /// In en, this message translates to:
  /// **'3 - Poor'**
  String get formTemplate3poor;

  /// No description provided for @formTemplate37days.
  ///
  /// In en, this message translates to:
  /// **'3-7 days'**
  String get formTemplate37days;

  /// No description provided for @formTemplate4belowaverage.
  ///
  /// In en, this message translates to:
  /// **'4 - Below Average'**
  String get formTemplate4belowaverage;

  /// No description provided for @formTemplate4good.
  ///
  /// In en, this message translates to:
  /// **'4 - Good'**
  String get formTemplate4good;

  /// No description provided for @formTemplate5average.
  ///
  /// In en, this message translates to:
  /// **'5 - Average'**
  String get formTemplate5average;

  /// No description provided for @formTemplate5excellent.
  ///
  /// In en, this message translates to:
  /// **'5 - Excellent'**
  String get formTemplate5excellent;

  /// No description provided for @formTemplate6satisfactory.
  ///
  /// In en, this message translates to:
  /// **'6 - Satisfactory'**
  String get formTemplate6satisfactory;

  /// No description provided for @formTemplate7good.
  ///
  /// In en, this message translates to:
  /// **'7 - Good'**
  String get formTemplate7good;

  /// No description provided for @formTemplate8verygood.
  ///
  /// In en, this message translates to:
  /// **'8 - Very Good'**
  String get formTemplate8verygood;

  /// No description provided for @formTemplate9excellent.
  ///
  /// In en, this message translates to:
  /// **'9 - Excellent'**
  String get formTemplate9excellent;

  /// No description provided for @formTemplateActionplanfornextmonth.
  ///
  /// In en, this message translates to:
  /// **'Action Plan for Next Month'**
  String get formTemplateActionplanfornextmonth;

  /// No description provided for @formTemplateAdditionalcomments.
  ///
  /// In en, this message translates to:
  /// **'Additional Comments'**
  String get formTemplateAdditionalcomments;

  /// No description provided for @formTemplateAdditionalnotes.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get formTemplateAdditionalnotes;

  /// No description provided for @formTemplateAdditionalcommentsforadmin.
  ///
  /// In en, this message translates to:
  /// **'Additional comments for admin'**
  String get formTemplateAdditionalcommentsforadmin;

  /// No description provided for @formTemplateAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get formTemplateAdvanced;

  /// No description provided for @formTemplateAllontime.
  ///
  /// In en, this message translates to:
  /// **'All on time'**
  String get formTemplateAllontime;

  /// No description provided for @formTemplateAllretained.
  ///
  /// In en, this message translates to:
  /// **'All retained'**
  String get formTemplateAllretained;

  /// No description provided for @formTemplateAlwaysontime.
  ///
  /// In en, this message translates to:
  /// **'Always on time'**
  String get formTemplateAlwaysontime;

  /// No description provided for @formTemplateAnyadditionalobservationsaboutthestudent.
  ///
  /// In en, this message translates to:
  /// **'Any additional observations about the student...'**
  String get formTemplateAnyadditionalobservationsaboutthestudent;

  /// No description provided for @formTemplateAnychallengesorsupportneeded.
  ///
  /// In en, this message translates to:
  /// **'Any challenges or support needed?'**
  String get formTemplateAnychallengesorsupportneeded;

  /// No description provided for @formTemplateAnyfeedbackrequestsorconcerns.
  ///
  /// In en, this message translates to:
  /// **'Any feedback, requests, or concerns'**
  String get formTemplateAnyfeedbackrequestsorconcerns;

  /// No description provided for @formTemplateAnyissuesorconcerns.
  ///
  /// In en, this message translates to:
  /// **'Any issues or concerns?'**
  String get formTemplateAnyissuesorconcerns;

  /// No description provided for @formTemplateAnyotherfeedbackorsuggestions.
  ///
  /// In en, this message translates to:
  /// **'Any other feedback or suggestions...'**
  String get formTemplateAnyotherfeedbackorsuggestions;

  /// No description provided for @formTemplateAnysuggestionsforimprovement.
  ///
  /// In en, this message translates to:
  /// **'Any suggestions for improvement?'**
  String get formTemplateAnysuggestionsforimprovement;

  /// No description provided for @formTemplateArabicreadinglevel.
  ///
  /// In en, this message translates to:
  /// **'Arabic Reading Level'**
  String get formTemplateArabicreadinglevel;

  /// No description provided for @formTemplateArabicwritinglevel.
  ///
  /// In en, this message translates to:
  /// **'Arabic Writing Level'**
  String get formTemplateArabicwritinglevel;

  /// No description provided for @formTemplateAreasforimprovement.
  ///
  /// In en, this message translates to:
  /// **'Areas for Improvement'**
  String get formTemplateAreasforimprovement;

  /// No description provided for @formTemplateAssessmenttype.
  ///
  /// In en, this message translates to:
  /// **'Assessment Type'**
  String get formTemplateAssessmenttype;

  /// No description provided for @formTemplateAudittimeliness.
  ///
  /// In en, this message translates to:
  /// **'Audit Timeliness'**
  String get formTemplateAudittimeliness;

  /// No description provided for @formTemplateAuditscompletedthismonth.
  ///
  /// In en, this message translates to:
  /// **'Audits Completed This Month'**
  String get formTemplateAuditscompletedthismonth;

  /// No description provided for @formTemplateAverageresponsetimetoissues.
  ///
  /// In en, this message translates to:
  /// **'Average Response Time to Issues'**
  String get formTemplateAverageresponsetimetoissues;

  /// No description provided for @formTemplateBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get formTemplateBeginner;

  /// No description provided for @formTemplateBelowexpectations.
  ///
  /// In en, this message translates to:
  /// **'Below expectations'**
  String get formTemplateBelowexpectations;

  /// No description provided for @formTemplateBiggestachievementthismonth.
  ///
  /// In en, this message translates to:
  /// **'Biggest Achievement This Month'**
  String get formTemplateBiggestachievementthismonth;

  /// No description provided for @formTemplateBiggestchallengefaced.
  ///
  /// In en, this message translates to:
  /// **'Biggest Challenge Faced'**
  String get formTemplateBiggestchallengefaced;

  /// No description provided for @formTemplateBrieftopicofyourfeedback.
  ///
  /// In en, this message translates to:
  /// **'Brief topic of your feedback'**
  String get formTemplateBrieftopicofyourfeedback;

  /// No description provided for @formTemplateChallenging.
  ///
  /// In en, this message translates to:
  /// **'Challenging'**
  String get formTemplateChallenging;

  /// No description provided for @formTemplateChild.
  ///
  /// In en, this message translates to:
  /// **'Child\\'**
  String get formTemplateChild;

  /// No description provided for @formTemplateClassesshouldbecancelled.
  ///
  /// In en, this message translates to:
  /// **'Classes should be cancelled'**
  String get formTemplateClassesshouldbecancelled;

  /// No description provided for @formTemplateCoachname.
  ///
  /// In en, this message translates to:
  /// **'Coach Name'**
  String get formTemplateCoachname;

  /// No description provided for @formTemplateComplaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get formTemplateComplaint;

  /// No description provided for @formTemplateCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get formTemplateCritical;

  /// No description provided for @formTemplateDateofincident.
  ///
  /// In en, this message translates to:
  /// **'Date of Incident'**
  String get formTemplateDateofincident;

  /// No description provided for @formTemplateDefinitelyno.
  ///
  /// In en, this message translates to:
  /// **'Definitely no'**
  String get formTemplateDefinitelyno;

  /// No description provided for @formTemplateDefinitelyyes.
  ///
  /// In en, this message translates to:
  /// **'Definitely yes'**
  String get formTemplateDefinitelyyes;

  /// No description provided for @formTemplateDescribeanyimmediateactiontaken.
  ///
  /// In en, this message translates to:
  /// **'Describe any immediate action taken...'**
  String get formTemplateDescribeanyimmediateactiontaken;

  /// No description provided for @formTemplateDescribewhathappened.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened'**
  String get formTemplateDescribewhathappened;

  /// No description provided for @formTemplateDescribeyourmainaccomplishment.
  ///
  /// In en, this message translates to:
  /// **'Describe your main accomplishment...'**
  String get formTemplateDescribeyourmainaccomplishment;

  /// No description provided for @formTemplateDetaileddescription.
  ///
  /// In en, this message translates to:
  /// **'Detailed Description'**
  String get formTemplateDetaileddescription;

  /// No description provided for @formTemplateDissatisfied.
  ///
  /// In en, this message translates to:
  /// **'Dissatisfied'**
  String get formTemplateDissatisfied;

  /// No description provided for @formTemplateEnddate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get formTemplateEnddate;

  /// No description provided for @formTemplateEndofsemester.
  ///
  /// In en, this message translates to:
  /// **'End of Semester'**
  String get formTemplateEndofsemester;

  /// No description provided for @formTemplateEnterstudentfullname.
  ///
  /// In en, this message translates to:
  /// **'Enter student full name'**
  String get formTemplateEnterstudentfullname;

  /// No description provided for @formTemplateExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get formTemplateExcellent;

  /// No description provided for @formTemplateFamilyemergency.
  ///
  /// In en, this message translates to:
  /// **'Family Emergency'**
  String get formTemplateFamilyemergency;

  /// No description provided for @formTemplateFewgoals.
  ///
  /// In en, this message translates to:
  /// **'Few goals'**
  String get formTemplateFewgoals;

  /// No description provided for @formTemplateFluent.
  ///
  /// In en, this message translates to:
  /// **'Fluent'**
  String get formTemplateFluent;

  /// No description provided for @formTemplateGoalsfornextmonth.
  ///
  /// In en, this message translates to:
  /// **'Goals for Next Month'**
  String get formTemplateGoalsfornextmonth;

  /// No description provided for @formTemplateGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get formTemplateGood;

  /// No description provided for @formTemplateHaveyouarrangedforcoverage.
  ///
  /// In en, this message translates to:
  /// **'Have you arranged for coverage?'**
  String get formTemplateHaveyouarrangedforcoverage;

  /// No description provided for @formTemplateHighturnover.
  ///
  /// In en, this message translates to:
  /// **'High turnover'**
  String get formTemplateHighturnover;

  /// No description provided for @formTemplateHowdidthesessiongo.
  ///
  /// In en, this message translates to:
  /// **'How did the session go?'**
  String get formTemplateHowdidthesessiongo;

  /// No description provided for @formTemplateHoweffectiveistheircommunication.
  ///
  /// In en, this message translates to:
  /// **'How effective is their communication?'**
  String get formTemplateHoweffectiveistheircommunication;

  /// No description provided for @formTemplateHowhelpfulisthesupportyoureceive.
  ///
  /// In en, this message translates to:
  /// **'How helpful is the support you receive?'**
  String get formTemplateHowhelpfulisthesupportyoureceive;

  /// No description provided for @formTemplateHowmanyhadithsdoesthisstudentknow.
  ///
  /// In en, this message translates to:
  /// **'How many Hadiths does this student know?'**
  String get formTemplateHowmanyhadithsdoesthisstudentknow;

  /// No description provided for @formTemplateHowmanysurahsdoesthisstudentknow.
  ///
  /// In en, this message translates to:
  /// **'How many Surahs does this student know?'**
  String get formTemplateHowmanysurahsdoesthisstudentknow;

  /// No description provided for @formTemplateHowmanyclasseswillbemissed.
  ///
  /// In en, this message translates to:
  /// **'How many classes will be missed?'**
  String get formTemplateHowmanyclasseswillbemissed;

  /// No description provided for @formTemplateHowmanystudentsattended.
  ///
  /// In en, this message translates to:
  /// **'How many students attended?'**
  String get formTemplateHowmanystudentsattended;

  /// No description provided for @formTemplateHowmuchadvancenoticeareyouproviding.
  ///
  /// In en, this message translates to:
  /// **'How much advance notice are you providing?'**
  String get formTemplateHowmuchadvancenoticeareyouproviding;

  /// No description provided for @formTemplateHowurgentisthis.
  ///
  /// In en, this message translates to:
  /// **'How urgent is this?'**
  String get formTemplateHowurgentisthis;

  /// No description provided for @formTemplateHowwouldyouratethismonth.
  ///
  /// In en, this message translates to:
  /// **'How would you rate this month?'**
  String get formTemplateHowwouldyouratethismonth;

  /// No description provided for @formTemplateHowwouldyouratethisweekoverall.
  ///
  /// In en, this message translates to:
  /// **'How would you rate this week overall?'**
  String get formTemplateHowwouldyouratethisweekoverall;

  /// No description provided for @formTemplateHowwouldyourateyourcoachleaderoverall.
  ///
  /// In en, this message translates to:
  /// **'How would you rate your coach/leader overall?'**
  String get formTemplateHowwouldyourateyourcoachleaderoverall;

  /// No description provided for @formTemplateInitialnewstudent.
  ///
  /// In en, this message translates to:
  /// **'Initial (New Student)'**
  String get formTemplateInitialnewstudent;

  /// No description provided for @formTemplateIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get formTemplateIntermediate;

  /// No description provided for @formTemplateIsfollowupneeded.
  ///
  /// In en, this message translates to:
  /// **'Is follow-up needed?'**
  String get formTemplateIsfollowupneeded;

  /// No description provided for @formTemplateIsyourchildmakingprogress.
  ///
  /// In en, this message translates to:
  /// **'Is your child making progress?'**
  String get formTemplateIsyourchildmakingprogress;

  /// No description provided for @formTemplateIssuesproblemsresolved.
  ///
  /// In en, this message translates to:
  /// **'Issues/Problems Resolved'**
  String get formTemplateIssuesproblemsresolved;

  /// No description provided for @formTemplateKeystrengths.
  ///
  /// In en, this message translates to:
  /// **'Key Strengths'**
  String get formTemplateKeystrengths;

  /// No description provided for @formTemplateLeaveemptyifnone.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if none'**
  String get formTemplateLeaveemptyifnone;

  /// No description provided for @formTemplateLittleprogress.
  ///
  /// In en, this message translates to:
  /// **'Little progress'**
  String get formTemplateLittleprogress;

  /// No description provided for @formTemplateLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get formTemplateLow;

  /// No description provided for @formTemplateMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get formTemplateMedium;

  /// No description provided for @formTemplateMidsemester.
  ///
  /// In en, this message translates to:
  /// **'Mid-Semester'**
  String get formTemplateMidsemester;

  /// No description provided for @formTemplateMinorturnover12.
  ///
  /// In en, this message translates to:
  /// **'Minor turnover (1-2)'**
  String get formTemplateMinorturnover12;

  /// No description provided for @formTemplateModerateturnover3.
  ///
  /// In en, this message translates to:
  /// **'Moderate turnover (3+)'**
  String get formTemplateModerateturnover3;

  /// No description provided for @formTemplateMorethan1week.
  ///
  /// In en, this message translates to:
  /// **'More than 1 week'**
  String get formTemplateMorethan1week;

  /// No description provided for @formTemplateMorethan48hours.
  ///
  /// In en, this message translates to:
  /// **'More than 48 hours'**
  String get formTemplateMorethan48hours;

  /// No description provided for @formTemplateMostgoals.
  ///
  /// In en, this message translates to:
  /// **'Most goals'**
  String get formTemplateMostgoals;

  /// No description provided for @formTemplateMostontime80.
  ///
  /// In en, this message translates to:
  /// **'Most on time (>80%)'**
  String get formTemplateMostontime80;

  /// No description provided for @formTemplateNameofcoachbeingreviewed.
  ///
  /// In en, this message translates to:
  /// **'Name of coach being reviewed'**
  String get formTemplateNameofcoachbeingreviewed;

  /// No description provided for @formTemplateNamesofpeopleinvolved.
  ///
  /// In en, this message translates to:
  /// **'Names of people involved'**
  String get formTemplateNamesofpeopleinvolved;

  /// No description provided for @formTemplateNeedsimprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs Improvement'**
  String get formTemplateNeedsimprovement;

  /// No description provided for @formTemplateNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get formTemplateNeutral;

  /// No description provided for @formTemplateNoneedadminhelp.
  ///
  /// In en, this message translates to:
  /// **'No - need admin help'**
  String get formTemplateNoneedadminhelp;

  /// No description provided for @formTemplateNoprogress.
  ///
  /// In en, this message translates to:
  /// **'No progress'**
  String get formTemplateNoprogress;

  /// No description provided for @formTemplateNoincludemyname.
  ///
  /// In en, this message translates to:
  /// **'No, include my name'**
  String get formTemplateNoincludemyname;

  /// No description provided for @formTemplateNothelpful.
  ///
  /// In en, this message translates to:
  /// **'Not Helpful'**
  String get formTemplateNothelpful;

  /// No description provided for @formTemplateNotstarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get formTemplateNotstarted;

  /// No description provided for @formTemplateNotsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get formTemplateNotsure;

  /// No description provided for @formTemplateNumberofhadiths.
  ///
  /// In en, this message translates to:
  /// **'Number of Hadiths'**
  String get formTemplateNumberofhadiths;

  /// No description provided for @formTemplateNumberofsurahs.
  ///
  /// In en, this message translates to:
  /// **'Number of Surahs'**
  String get formTemplateNumberofsurahs;

  /// No description provided for @formTemplateNumberofteachersmanaged.
  ///
  /// In en, this message translates to:
  /// **'Number of Teachers Managed'**
  String get formTemplateNumberofteachersmanaged;

  /// No description provided for @formTemplateNumberofteachersyousupported.
  ///
  /// In en, this message translates to:
  /// **'Number of Teachers You Supported'**
  String get formTemplateNumberofteachersyousupported;

  /// No description provided for @formTemplateNumberofshiftsaffected.
  ///
  /// In en, this message translates to:
  /// **'Number of shifts affected'**
  String get formTemplateNumberofshiftsaffected;

  /// No description provided for @formTemplateNumberofstudentspresent.
  ///
  /// In en, this message translates to:
  /// **'Number of students present'**
  String get formTemplateNumberofstudentspresent;

  /// No description provided for @formTemplateOftenlate.
  ///
  /// In en, this message translates to:
  /// **'Often late'**
  String get formTemplateOftenlate;

  /// No description provided for @formTemplateOverallcoachrating110.
  ///
  /// In en, this message translates to:
  /// **'Overall Coach Rating (1-10)'**
  String get formTemplateOverallcoachrating110;

  /// No description provided for @formTemplateOverallsatisfactionwithteacher.
  ///
  /// In en, this message translates to:
  /// **'Overall Satisfaction with Teacher'**
  String get formTemplateOverallsatisfactionwithteacher;

  /// No description provided for @formTemplateOverallstudentlevel.
  ///
  /// In en, this message translates to:
  /// **'Overall Student Level'**
  String get formTemplateOverallstudentlevel;

  /// No description provided for @formTemplateParentconcern.
  ///
  /// In en, this message translates to:
  /// **'Parent Concern'**
  String get formTemplateParentconcern;

  /// No description provided for @formTemplatePersonalemergency.
  ///
  /// In en, this message translates to:
  /// **'Personal Emergency'**
  String get formTemplatePersonalemergency;

  /// No description provided for @formTemplatePlanfornextsession.
  ///
  /// In en, this message translates to:
  /// **'Plan for next session'**
  String get formTemplatePlanfornextsession;

  /// No description provided for @formTemplatePleaseexplainthereasonforyourrequest.
  ///
  /// In en, this message translates to:
  /// **'Please explain the reason for your request...'**
  String get formTemplatePleaseexplainthereasonforyourrequest;

  /// No description provided for @formTemplatePleaseprovideadetaileddescription.
  ///
  /// In en, this message translates to:
  /// **'Please provide a detailed description...'**
  String get formTemplatePleaseprovideadetaileddescription;

  /// No description provided for @formTemplatePleaseprovidedetailsaboutyourfeedback.
  ///
  /// In en, this message translates to:
  /// **'Please provide details about your feedback...'**
  String get formTemplatePleaseprovidedetailsaboutyourfeedback;

  /// No description provided for @formTemplatePoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get formTemplatePoor;

  /// No description provided for @formTemplatePraise.
  ///
  /// In en, this message translates to:
  /// **'Praise'**
  String get formTemplatePraise;

  /// No description provided for @formTemplatePreplannedabsence.
  ///
  /// In en, this message translates to:
  /// **'Pre-planned Absence'**
  String get formTemplatePreplannedabsence;

  /// No description provided for @formTemplateProbablyno.
  ///
  /// In en, this message translates to:
  /// **'Probably no'**
  String get formTemplateProbablyno;

  /// No description provided for @formTemplateProbablyyes.
  ///
  /// In en, this message translates to:
  /// **'Probably yes'**
  String get formTemplateProbablyyes;

  /// No description provided for @formTemplateQualityofcommunication.
  ///
  /// In en, this message translates to:
  /// **'Quality of Communication'**
  String get formTemplateQualityofcommunication;

  /// No description provided for @formTemplateQualityofteachersupport.
  ///
  /// In en, this message translates to:
  /// **'Quality of Teacher Support'**
  String get formTemplateQualityofteachersupport;

  /// No description provided for @formTemplateRateyourperformancethismonth.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Performance This Month'**
  String get formTemplateRateyourperformancethismonth;

  /// No description provided for @formTemplateRatereadingskills15.
  ///
  /// In en, this message translates to:
  /// **'Rate reading skills (1-5)'**
  String get formTemplateRatereadingskills15;

  /// No description provided for @formTemplateRatewritingskills15.
  ///
  /// In en, this message translates to:
  /// **'Rate writing skills (1-5)'**
  String get formTemplateRatewritingskills15;

  /// No description provided for @formTemplateReasonforleave.
  ///
  /// In en, this message translates to:
  /// **'Reason for Leave'**
  String get formTemplateReasonforleave;

  /// No description provided for @formTemplateReligiousholiday.
  ///
  /// In en, this message translates to:
  /// **'Religious Holiday'**
  String get formTemplateReligiousholiday;

  /// No description provided for @formTemplateSameday.
  ///
  /// In en, this message translates to:
  /// **'Same day'**
  String get formTemplateSameday;

  /// No description provided for @formTemplateSatisfied.
  ///
  /// In en, this message translates to:
  /// **'Satisfied'**
  String get formTemplateSatisfied;

  /// No description provided for @formTemplateSchedulingconflict.
  ///
  /// In en, this message translates to:
  /// **'Scheduling Conflict'**
  String get formTemplateSchedulingconflict;

  /// No description provided for @formTemplateSickleave.
  ///
  /// In en, this message translates to:
  /// **'Sick Leave'**
  String get formTemplateSickleave;

  /// No description provided for @formTemplateSignificantdelays.
  ///
  /// In en, this message translates to:
  /// **'Significant delays'**
  String get formTemplateSignificantdelays;

  /// No description provided for @formTemplateSignificantprogress.
  ///
  /// In en, this message translates to:
  /// **'Significant progress'**
  String get formTemplateSignificantprogress;

  /// No description provided for @formTemplateSomedelays80.
  ///
  /// In en, this message translates to:
  /// **'Some delays (<80%)'**
  String get formTemplateSomedelays80;

  /// No description provided for @formTemplateSomegoals.
  ///
  /// In en, this message translates to:
  /// **'Some goals'**
  String get formTemplateSomegoals;

  /// No description provided for @formTemplateSomeprogress.
  ///
  /// In en, this message translates to:
  /// **'Some progress'**
  String get formTemplateSomeprogress;

  /// No description provided for @formTemplateSometimeslate.
  ///
  /// In en, this message translates to:
  /// **'Sometimes late'**
  String get formTemplateSometimeslate;

  /// No description provided for @formTemplateSomewhathelpful.
  ///
  /// In en, this message translates to:
  /// **'Somewhat Helpful'**
  String get formTemplateSomewhathelpful;

  /// No description provided for @formTemplateSpecificgoalsoractions.
  ///
  /// In en, this message translates to:
  /// **'Specific goals or actions...'**
  String get formTemplateSpecificgoalsoractions;

  /// No description provided for @formTemplateStudentbehavior.
  ///
  /// In en, this message translates to:
  /// **'Student Behavior'**
  String get formTemplateStudentbehavior;

  /// No description provided for @formTemplateStudentname.
  ///
  /// In en, this message translates to:
  /// **'Student Name'**
  String get formTemplateStudentname;

  /// No description provided for @formTemplateSubjecttopic.
  ///
  /// In en, this message translates to:
  /// **'Subject/Topic'**
  String get formTemplateSubjecttopic;

  /// No description provided for @formTemplateSubmitanonymously.
  ///
  /// In en, this message translates to:
  /// **'Submit anonymously?'**
  String get formTemplateSubmitanonymously;

  /// No description provided for @formTemplateSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get formTemplateSuggestion;

  /// No description provided for @formTemplateSummarizestudentprogressmilestonesreachedetc.
  ///
  /// In en, this message translates to:
  /// **'Summarize student progress, milestones reached, etc.'**
  String get formTemplateSummarizestudentprogressmilestonesreachedetc;

  /// No description provided for @formTemplateSupportneededfromleadership.
  ///
  /// In en, this message translates to:
  /// **'Support Needed from Leadership'**
  String get formTemplateSupportneededfromleadership;

  /// No description provided for @formTemplateTaskscompletedthismonth.
  ///
  /// In en, this message translates to:
  /// **'Tasks Completed This Month'**
  String get formTemplateTaskscompletedthismonth;

  /// No description provided for @formTemplateTaskscurrentlyoverdue.
  ///
  /// In en, this message translates to:
  /// **'Tasks Currently Overdue'**
  String get formTemplateTaskscurrentlyoverdue;

  /// No description provided for @formTemplateTeachername.
  ///
  /// In en, this message translates to:
  /// **'Teacher Name'**
  String get formTemplateTeachername;

  /// No description provided for @formTemplateTeacherpunctuality.
  ///
  /// In en, this message translates to:
  /// **'Teacher Punctuality'**
  String get formTemplateTeacherpunctuality;

  /// No description provided for @formTemplateTeacherretentioninteam.
  ///
  /// In en, this message translates to:
  /// **'Teacher Retention in Team'**
  String get formTemplateTeacherretentioninteam;

  /// No description provided for @formTemplateTechnicalissue.
  ///
  /// In en, this message translates to:
  /// **'Technical Issue'**
  String get formTemplateTechnicalissue;

  /// No description provided for @formTemplateTypeoffeedback.
  ///
  /// In en, this message translates to:
  /// **'Type of Feedback'**
  String get formTemplateTypeoffeedback;

  /// No description provided for @formTemplateTypeofincident.
  ///
  /// In en, this message translates to:
  /// **'Type of Incident'**
  String get formTemplateTypeofincident;

  /// No description provided for @formTemplateTypeofleave.
  ///
  /// In en, this message translates to:
  /// **'Type of Leave'**
  String get formTemplateTypeofleave;

  /// No description provided for @formTemplateUsuallyontime.
  ///
  /// In en, this message translates to:
  /// **'Usually on time'**
  String get formTemplateUsuallyontime;

  /// No description provided for @formTemplateVerydissatisfied.
  ///
  /// In en, this message translates to:
  /// **'Very Dissatisfied'**
  String get formTemplateVerydissatisfied;

  /// No description provided for @formTemplateVeryhelpful.
  ///
  /// In en, this message translates to:
  /// **'Very Helpful'**
  String get formTemplateVeryhelpful;

  /// No description provided for @formTemplateVerysatisfied.
  ///
  /// In en, this message translates to:
  /// **'Very Satisfied'**
  String get formTemplateVerysatisfied;

  /// No description provided for @formTemplateWereyourteachinggoalsmet.
  ///
  /// In en, this message translates to:
  /// **'Were your teaching goals met?'**
  String get formTemplateWereyourteachinggoalsmet;

  /// No description provided for @formTemplateWhatactiondidyoutake.
  ///
  /// In en, this message translates to:
  /// **'What action did you take?'**
  String get formTemplateWhatactiondidyoutake;

  /// No description provided for @formTemplateWhatadditionalsupportwouldhelpyou.
  ///
  /// In en, this message translates to:
  /// **'What additional support would help you?'**
  String get formTemplateWhatadditionalsupportwouldhelpyou;

  /// No description provided for @formTemplateWhatcouldbedonebetter.
  ///
  /// In en, this message translates to:
  /// **'What could be done better?'**
  String get formTemplateWhatcouldbedonebetter;

  /// No description provided for @formTemplateWhatdoyouplantoaccomplish.
  ///
  /// In en, this message translates to:
  /// **'What do you plan to accomplish?'**
  String get formTemplateWhatdoyouplantoaccomplish;

  /// No description provided for @formTemplateWhatdoesthiscoachdowell.
  ///
  /// In en, this message translates to:
  /// **'What does this coach do well?'**
  String get formTemplateWhatdoesthiscoachdowell;

  /// No description provided for @formTemplateWhatlessontopicdidyoucovertoday.
  ///
  /// In en, this message translates to:
  /// **'What lesson/topic did you cover today?'**
  String get formTemplateWhatlessontopicdidyoucovertoday;

  /// No description provided for @formTemplateWhatshouldthiscoachworkon.
  ///
  /// In en, this message translates to:
  /// **'What should this coach work on?'**
  String get formTemplateWhatshouldthiscoachworkon;

  /// No description provided for @formTemplateWhatwasyourmainchallenge.
  ///
  /// In en, this message translates to:
  /// **'What was your main challenge?'**
  String get formTemplateWhatwasyourmainchallenge;

  /// No description provided for @formTemplateWhatwerethekeyachievementsthisweek.
  ///
  /// In en, this message translates to:
  /// **'What were the key achievements this week?'**
  String get formTemplateWhatwerethekeyachievementsthisweek;

  /// No description provided for @formTemplateWhatwillyoucovernext.
  ///
  /// In en, this message translates to:
  /// **'What will you cover next?'**
  String get formTemplateWhatwillyoucovernext;

  /// No description provided for @formTemplateWhowasinvolved.
  ///
  /// In en, this message translates to:
  /// **'Who was involved?'**
  String get formTemplateWhowasinvolved;

  /// No description provided for @formTemplateWithin24hours.
  ///
  /// In en, this message translates to:
  /// **'Within 24 hours'**
  String get formTemplateWithin24hours;

  /// No description provided for @formTemplateWouldyourecommendthisteacher.
  ///
  /// In en, this message translates to:
  /// **'Would you recommend this teacher?'**
  String get formTemplateWouldyourecommendthisteacher;

  /// No description provided for @formTemplateYesnonurgent.
  ///
  /// In en, this message translates to:
  /// **'Yes - Non-urgent'**
  String get formTemplateYesnonurgent;

  /// No description provided for @formTemplateYesurgent.
  ///
  /// In en, this message translates to:
  /// **'Yes - Urgent'**
  String get formTemplateYesurgent;

  /// No description provided for @formTemplateYesanotherteacherwillcover.
  ///
  /// In en, this message translates to:
  /// **'Yes - another teacher will cover'**
  String get formTemplateYesanotherteacherwillcover;

  /// No description provided for @formTemplateYesallgoals.
  ///
  /// In en, this message translates to:
  /// **'Yes, all goals'**
  String get formTemplateYesallgoals;

  /// No description provided for @formTemplateYeskeepanonymous.
  ///
  /// In en, this message translates to:
  /// **'Yes, keep anonymous'**
  String get formTemplateYeskeepanonymous;

  /// No description provided for @formTemplateEgsurahalfatihaverses13.
  ///
  /// In en, this message translates to:
  /// **'e.g., Surah Al-Fatiha verses 1-3'**
  String get formTemplateEgsurahalfatihaverses13;

  /// No description provided for @formTemplateAdminselfassessment.
  ///
  /// In en, this message translates to:
  /// **'Admin Self-Assessment'**
  String get formTemplateAdminselfassessment;

  /// No description provided for @formTemplateCoachperformancereview.
  ///
  /// In en, this message translates to:
  /// **'Coach Performance Review'**
  String get formTemplateCoachperformancereview;

  /// No description provided for @formTemplateCollectfeedbackfromparentsabouttheirchild.
  ///
  /// In en, this message translates to:
  /// **'Collect feedback from parents about their child\\'**
  String get formTemplateCollectfeedbackfromparentsabouttheirchild;

  /// No description provided for @formTemplateDailyclassreport.
  ///
  /// In en, this message translates to:
  /// **'Daily Class Report'**
  String get formTemplateDailyclassreport;

  /// No description provided for @formTemplateEndofmonthteachingreview.
  ///
  /// In en, this message translates to:
  /// **'End of month teaching review'**
  String get formTemplateEndofmonthteachingreview;

  /// No description provided for @formTemplateEndofweekteachingsummary.
  ///
  /// In en, this message translates to:
  /// **'End of week teaching summary'**
  String get formTemplateEndofweekteachingsummary;

  /// No description provided for @formTemplateEvaluatestudentprogressandskillsatenrollmentorsemesterend.
  ///
  /// In en, this message translates to:
  /// **'Evaluate student progress and skills at enrollment or semester end'**
  String
      get formTemplateEvaluatestudentprogressandskillsatenrollmentorsemesterend;

  /// No description provided for @formTemplateFeedbackforleaders.
  ///
  /// In en, this message translates to:
  /// **'Feedback for Leaders'**
  String get formTemplateFeedbackforleaders;

  /// No description provided for @formTemplateIncidentreport.
  ///
  /// In en, this message translates to:
  /// **'Incident Report'**
  String get formTemplateIncidentreport;

  /// No description provided for @formTemplateLeaverequest.
  ///
  /// In en, this message translates to:
  /// **'Leave Request'**
  String get formTemplateLeaverequest;

  /// No description provided for @formTemplateMonthlyreview.
  ///
  /// In en, this message translates to:
  /// **'Monthly Review'**
  String get formTemplateMonthlyreview;

  /// No description provided for @formTemplateMonthlyevaluationofcoachsupervisorperformanceadminonly.
  ///
  /// In en, this message translates to:
  /// **'Monthly evaluation of coach/supervisor performance (Admin only)'**
  String get formTemplateMonthlyevaluationofcoachsupervisorperformanceadminonly;

  /// No description provided for @formTemplateMonthlyselfevaluationforadministratorsandcoaches.
  ///
  /// In en, this message translates to:
  /// **'Monthly self-evaluation for administrators and coaches'**
  String get formTemplateMonthlyselfevaluationforadministratorsandcoaches;

  /// No description provided for @formTemplateParentguardianfeedback.
  ///
  /// In en, this message translates to:
  /// **'Parent/Guardian Feedback'**
  String get formTemplateParentguardianfeedback;

  /// No description provided for @formTemplateQuickreportaftereachteachingsession.
  ///
  /// In en, this message translates to:
  /// **'Quick report after each teaching session'**
  String get formTemplateQuickreportaftereachteachingsession;

  /// No description provided for @formTemplateRateandprovidefeedbackaboutyourcoachsupervisor.
  ///
  /// In en, this message translates to:
  /// **'Rate and provide feedback about your coach/supervisor'**
  String get formTemplateRateandprovidefeedbackaboutyourcoachsupervisor;

  /// No description provided for @formTemplateReportanincidentorissuethatoccurred.
  ///
  /// In en, this message translates to:
  /// **'Report an incident or issue that occurred'**
  String get formTemplateReportanincidentorissuethatoccurred;

  /// No description provided for @formTemplateRequesttimeofforabsencefromscheduledshifts.
  ///
  /// In en, this message translates to:
  /// **'Request time off or absence from scheduled shifts'**
  String get formTemplateRequesttimeofforabsencefromscheduledshifts;

  /// No description provided for @formTemplateStudentassessment.
  ///
  /// In en, this message translates to:
  /// **'Student Assessment'**
  String get formTemplateStudentassessment;

  /// No description provided for @formTemplateSubmitfeedbacksuggestionsorcomplaintstoleadership.
  ///
  /// In en, this message translates to:
  /// **'Submit feedback, suggestions, or complaints to leadership'**
  String get formTemplateSubmitfeedbacksuggestionsorcomplaintstoleadership;

  /// No description provided for @formTemplateTeacherfeedbackcomplaints.
  ///
  /// In en, this message translates to:
  /// **'Teacher Feedback & Complaints'**
  String get formTemplateTeacherfeedbackcomplaints;

  /// No description provided for @formTemplateWeeklysummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly Summary'**
  String get formTemplateWeeklysummary;

  /// No description provided for @sidebarAudits.
  ///
  /// In en, this message translates to:
  /// **'Audits'**
  String get sidebarAudits;

  /// No description provided for @sidebarCms.
  ///
  /// In en, this message translates to:
  /// **'CMS'**
  String get sidebarCms;

  /// No description provided for @sidebarCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get sidebarCommunication;

  /// No description provided for @sidebarFormbuilder.
  ///
  /// In en, this message translates to:
  /// **'Form Builder'**
  String get sidebarFormbuilder;

  /// No description provided for @sidebarLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sidebarLearning;

  /// No description provided for @sidebarMyreport.
  ///
  /// In en, this message translates to:
  /// **'My Report'**
  String get sidebarMyreport;

  /// No description provided for @sidebarMyshifts.
  ///
  /// In en, this message translates to:
  /// **'My Shifts'**
  String get sidebarMyshifts;

  /// No description provided for @sidebarOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get sidebarOperations;

  /// No description provided for @sidebarPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get sidebarPeople;

  /// No description provided for @sidebarReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get sidebarReports;

  /// No description provided for @sidebarRolestest.
  ///
  /// In en, this message translates to:
  /// **'Roles (Test)'**
  String get sidebarRolestest;

  /// No description provided for @sidebarSubjectrates.
  ///
  /// In en, this message translates to:
  /// **'Subject Rates'**
  String get sidebarSubjectrates;

  /// No description provided for @sidebarTestauditgeneration.
  ///
  /// In en, this message translates to:
  /// **'Test Audit Génération'**
  String get sidebarTestauditgeneration;

  /// No description provided for @sidebarWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get sidebarWebsite;

  /// No description provided for @sidebarWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get sidebarWork;

  /// No description provided for @recurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'No recurrence'**
  String get recurrenceNone;

  /// No description provided for @recurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurrenceDaily;

  /// No description provided for @recurrenceDailyExcludingDays.
  ///
  /// In en, this message translates to:
  /// **'Daily (excluding {days})'**
  String recurrenceDailyExcludingDays(Object days);

  /// No description provided for @recurrenceExcludedDates.
  ///
  /// In en, this message translates to:
  /// **'({count} specific dates excluded)'**
  String recurrenceExcludedDates(Object count);

  /// No description provided for @recurrenceWeeklyOn.
  ///
  /// In en, this message translates to:
  /// **'Weekly on {days}'**
  String recurrenceWeeklyOn(Object days);

  /// No description provided for @recurrenceMonthlyOn.
  ///
  /// In en, this message translates to:
  /// **'Monthly on {days}'**
  String recurrenceMonthlyOn(Object days);

  /// No description provided for @recurrenceMonthlyOnCount.
  ///
  /// In en, this message translates to:
  /// **'Monthly on {count} selected days'**
  String recurrenceMonthlyOnCount(Object count);

  /// No description provided for @recurrenceYearlyIn.
  ///
  /// In en, this message translates to:
  /// **'Yearly in {months}'**
  String recurrenceYearlyIn(Object months);

  /// No description provided for @settingsTourJoinClassDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap on any upcoming class card and click \"Join Class\" when it\'s time.'**
  String get settingsTourJoinClassDescription;

  /// No description provided for @settingsTourEnableNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications in Settings to get reminders before your classes.'**
  String get settingsTourEnableNotificationsDescription;

  /// No description provided for @settingsTourMediaControlsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the mic and camera buttons to control your audio and video.'**
  String get settingsTourMediaControlsDescription;

  /// No description provided for @settingsTourChatDescription.
  ///
  /// In en, this message translates to:
  /// **'Send messages to your teacher using the Chat tab.'**
  String get settingsTourChatDescription;

  /// No description provided for @taskSubtaskOf.
  ///
  /// In en, this message translates to:
  /// **'Sub-task of: {title}'**
  String taskSubtaskOf(Object title);

  /// No description provided for @taskUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get taskUnassigned;

  /// No description provided for @taskSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select Multiple'**
  String get taskSelectMultiple;

  /// No description provided for @taskExitSelection.
  ///
  /// In en, this message translates to:
  /// **'Exit Selection'**
  String get taskExitSelection;

  /// No description provided for @editAllInSeriesCount.
  ///
  /// In en, this message translates to:
  /// **'Edit all in series ({count})'**
  String editAllInSeriesCount(Object count);

  /// No description provided for @shiftUpdatesTemplate.
  ///
  /// In en, this message translates to:
  /// **'Updates Template'**
  String get shiftUpdatesTemplate;

  /// No description provided for @selectStartTime.
  ///
  /// In en, this message translates to:
  /// **'Select start time'**
  String get selectStartTime;

  /// No description provided for @selectEndTime.
  ///
  /// In en, this message translates to:
  /// **'Select end time'**
  String get selectEndTime;

  /// No description provided for @shiftTimesheetRecords.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Records ({count})'**
  String shiftTimesheetRecords(Object count);

  /// No description provided for @shiftDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String shiftDurationHours(Object hours);

  /// No description provided for @shiftHourlyRateValue.
  ///
  /// In en, this message translates to:
  /// **'\${rate}/hr'**
  String shiftHourlyRateValue(Object rate);

  /// No description provided for @shiftActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active Now'**
  String get shiftActiveNow;

  /// No description provided for @shiftDetailDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get shiftDetailDate;

  /// No description provided for @shiftDetailTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get shiftDetailTime;

  /// No description provided for @shiftDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get shiftDetailDuration;

  /// No description provided for @shiftDetailSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get shiftDetailSubject;

  /// No description provided for @shiftDetailHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get shiftDetailHourlyRate;

  /// No description provided for @shiftDetailNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get shiftDetailNotes;

  /// No description provided for @shiftDetailTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get shiftDetailTeacher;

  /// No description provided for @shiftDetailTotalWorked.
  ///
  /// In en, this message translates to:
  /// **'Total Worked'**
  String get shiftDetailTotalWorked;

  /// No description provided for @shiftDetailClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get shiftDetailClockIn;

  /// No description provided for @shiftDetailClockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get shiftDetailClockOut;

  /// No description provided for @shiftStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get shiftStatusInProgress;

  /// No description provided for @shiftElapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed Time: {time}'**
  String shiftElapsedTime(Object time);

  /// No description provided for @shiftStatusFullyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Fully Completed'**
  String get shiftStatusFullyCompleted;

  /// No description provided for @shiftStatusAllScheduledTimeWorked.
  ///
  /// In en, this message translates to:
  /// **'All scheduled time was worked'**
  String get shiftStatusAllScheduledTimeWorked;

  /// No description provided for @shiftStatusPartiallyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Partially Completed'**
  String get shiftStatusPartiallyCompleted;

  /// No description provided for @shiftStatusSomeTimeWorked.
  ///
  /// In en, this message translates to:
  /// **'Some time was worked'**
  String get shiftStatusSomeTimeWorked;

  /// No description provided for @shiftStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get shiftStatusMissed;

  /// No description provided for @shiftStatusNotAttended.
  ///
  /// In en, this message translates to:
  /// **'This shift was not attended'**
  String get shiftStatusNotAttended;

  /// No description provided for @shiftStatusReadyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready to Start'**
  String get shiftStatusReadyToStart;

  /// No description provided for @shiftStatusCanClockInNow.
  ///
  /// In en, this message translates to:
  /// **'You can clock in now!'**
  String get shiftStatusCanClockInNow;

  /// No description provided for @shiftStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get shiftStatusUpcoming;

  /// No description provided for @shiftStartsInDays.
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} days'**
  String shiftStartsInDays(Object count);

  /// No description provided for @shiftStartsInHours.
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} hours'**
  String shiftStartsInHours(Object count);

  /// No description provided for @shiftStartsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} minutes'**
  String shiftStartsInMinutes(Object count);

  /// No description provided for @shiftStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get shiftStatusScheduled;

  /// No description provided for @shiftStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shiftStatusActive;

  /// No description provided for @shiftStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get shiftStatusCompleted;

  /// No description provided for @shiftStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get shiftStatusCancelled;

  /// No description provided for @shiftStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get shiftStatusApproved;

  /// No description provided for @shiftStatusApprovedOn.
  ///
  /// In en, this message translates to:
  /// **'Approved on {date}'**
  String shiftStatusApprovedOn(Object date);

  /// No description provided for @shiftStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get shiftStatusPaid;

  /// No description provided for @shiftStatusPaymentProcessed.
  ///
  /// In en, this message translates to:
  /// **'Payment processed'**
  String get shiftStatusPaymentProcessed;

  /// No description provided for @shiftStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get shiftStatusRejected;

  /// No description provided for @shiftStatusReviewResubmit.
  ///
  /// In en, this message translates to:
  /// **'Please review and resubmit'**
  String get shiftStatusReviewResubmit;

  /// No description provided for @shiftStatusPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get shiftStatusPendingApproval;

  /// No description provided for @shiftStatusAwaitingAdminReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting admin review'**
  String get shiftStatusAwaitingAdminReview;

  /// No description provided for @shiftStatusEditPending.
  ///
  /// In en, this message translates to:
  /// **'Edit Pending'**
  String get shiftStatusEditPending;

  /// No description provided for @shiftStatusEditAwaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Your edit is awaiting approval'**
  String get shiftStatusEditAwaitingApproval;

  /// No description provided for @localTime.
  ///
  /// In en, this message translates to:
  /// **'Local Time'**
  String get localTime;

  /// No description provided for @shiftStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'✓ Confirmed'**
  String get shiftStatusConfirmed;

  /// No description provided for @shiftStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get shiftStatusPending;

  /// No description provided for @weeklyScheduleTeachersCount.
  ///
  /// In en, this message translates to:
  /// **'TEACHERS ({count})'**
  String weeklyScheduleTeachersCount(Object count);

  /// No description provided for @weeklyScheduleLeadersCount.
  ///
  /// In en, this message translates to:
  /// **'LEADERS ({count})'**
  String weeklyScheduleLeadersCount(Object count);

  /// No description provided for @weeklyScheduleDateRange.
  ///
  /// In en, this message translates to:
  /// **'{start} → {end}'**
  String weeklyScheduleDateRange(Object start, Object end);

  /// No description provided for @weeklyScheduleShiftsScheduled.
  ///
  /// In en, this message translates to:
  /// **'{count} shifts scheduled'**
  String weeklyScheduleShiftsScheduled(Object count);

  /// No description provided for @weeklyScheduleShiftNumber.
  ///
  /// In en, this message translates to:
  /// **'Shift #{number}'**
  String weeklyScheduleShiftNumber(Object number);

  /// No description provided for @auditScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get auditScheduled;

  /// No description provided for @auditCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get auditCompleted;

  /// No description provided for @auditMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get auditMissed;

  /// No description provided for @auditCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get auditCompletionRate;

  /// No description provided for @auditTotalClockIns.
  ///
  /// In en, this message translates to:
  /// **'Total Clock-Ins'**
  String get auditTotalClockIns;

  /// No description provided for @auditOnTime.
  ///
  /// In en, this message translates to:
  /// **'On-Time'**
  String get auditOnTime;

  /// No description provided for @auditLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get auditLate;

  /// No description provided for @auditPunctualityRate.
  ///
  /// In en, this message translates to:
  /// **'Punctuality Rate'**
  String get auditPunctualityRate;

  /// No description provided for @auditRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get auditRequired;

  /// No description provided for @auditSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get auditSubmitted;

  /// No description provided for @auditComplianceRate.
  ///
  /// In en, this message translates to:
  /// **'Compliance Rate'**
  String get auditComplianceRate;

  /// No description provided for @auditCompletionPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% completion'**
  String auditCompletionPercent(Object percent);

  /// No description provided for @auditSubjectsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subjects'**
  String auditSubjectsCount(Object count);

  /// No description provided for @auditOnTimeClockIns.
  ///
  /// In en, this message translates to:
  /// **'{onTime}/{total} on-time'**
  String auditOnTimeClockIns(Object onTime, Object total);

  /// No description provided for @auditCompliancePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% compliance'**
  String auditCompliancePercent(Object percent);

  /// No description provided for @notificationSelectAtLeastOneUser.
  ///
  /// In en, this message translates to:
  /// **'Select at least one user'**
  String get notificationSelectAtLeastOneUser;

  /// No description provided for @notificationConfirmSelected.
  ///
  /// In en, this message translates to:
  /// **'Confirm ({count} selected)'**
  String notificationConfirmSelected(Object count);

  /// No description provided for @notificationEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get notificationEnterTitle;

  /// No description provided for @notificationEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Please enter a message'**
  String get notificationEnterMessage;

  /// No description provided for @notificationUsersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} users selected'**
  String notificationUsersSelected(Object count);

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @noUsersMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No users match your search'**
  String get noUsersMatchSearch;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @commonUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get commonUnknownUser;

  /// No description provided for @commonUnknownParent.
  ///
  /// In en, this message translates to:
  /// **'Unknown Parent'**
  String get commonUnknownParent;

  /// No description provided for @commonUnknownSubject.
  ///
  /// In en, this message translates to:
  /// **'Unknown Subject'**
  String get commonUnknownSubject;

  /// No description provided for @commonUnknownTeacher.
  ///
  /// In en, this message translates to:
  /// **'Unknown Teacher'**
  String get commonUnknownTeacher;

  /// No description provided for @commonUnknownStudent.
  ///
  /// In en, this message translates to:
  /// **'Unknown Student'**
  String get commonUnknownStudent;

  /// No description provided for @commonUnknownShift.
  ///
  /// In en, this message translates to:
  /// **'Unknown Shift'**
  String get commonUnknownShift;

  /// No description provided for @commonUnknownClass.
  ///
  /// In en, this message translates to:
  /// **'Unknown Class'**
  String get commonUnknownClass;

  /// No description provided for @commonUnknownForm.
  ///
  /// In en, this message translates to:
  /// **'Unknown Form'**
  String get commonUnknownForm;

  /// No description provided for @commonUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get commonUnknownDate;

  /// No description provided for @commonUnknownFile.
  ///
  /// In en, this message translates to:
  /// **'Unknown file'**
  String get commonUnknownFile;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get commonUnknownError;

  /// No description provided for @commonUnknownInitial.
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get commonUnknownInitial;

  /// No description provided for @timeClockTeachingSessionWith.
  ///
  /// In en, this message translates to:
  /// **'Teaching session with {name}'**
  String timeClockTeachingSessionWith(Object name);

  /// No description provided for @formQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String formQuestionNumber(Object number);

  /// No description provided for @formSelectMultipleOptions.
  ///
  /// In en, this message translates to:
  /// **'Select multiple options...'**
  String get formSelectMultipleOptions;

  /// No description provided for @selectUser.
  ///
  /// In en, this message translates to:
  /// **'Select User'**
  String get selectUser;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get selectDateRange;

  /// No description provided for @selectDateRangeForFormResponses.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range for Form Responses'**
  String get selectDateRangeForFormResponses;

  /// No description provided for @selectDateRangeForFormSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range for Form Submissions'**
  String get selectDateRangeForFormSubmissions;

  /// No description provided for @selectDateRangeForTimesheetReview.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range for Timesheet Review'**
  String get selectDateRangeForTimesheetReview;

  /// No description provided for @selectDateRangeForTasks.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range for Tasks'**
  String get selectDateRangeForTasks;

  /// No description provided for @selectDueDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select Due Date Range'**
  String get selectDueDateRange;

  /// No description provided for @selectDates.
  ///
  /// In en, this message translates to:
  /// **'Select dates'**
  String get selectDates;

  /// No description provided for @selectStudentsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Select students ({count} selected)'**
  String selectStudentsWithCount(Object count);

  /// No description provided for @selectTimezone.
  ///
  /// In en, this message translates to:
  /// **'Select Timezone'**
  String get selectTimezone;

  /// No description provided for @selectTimezonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select timezone…'**
  String get selectTimezonePlaceholder;

  /// No description provided for @selectEndDate.
  ///
  /// In en, this message translates to:
  /// **'Select end date'**
  String get selectEndDate;

  /// No description provided for @formsNoActiveMatching.
  ///
  /// In en, this message translates to:
  /// **'No active forms match your search.'**
  String get formsNoActiveMatching;

  /// No description provided for @formsNoActiveForRole.
  ///
  /// In en, this message translates to:
  /// **'No active forms for {role}.'**
  String formsNoActiveForRole(Object role);

  /// No description provided for @formsFieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String formsFieldCount(Object count);

  /// No description provided for @livekitMuteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get livekitMuteAll;

  /// No description provided for @livekitPip.
  ///
  /// In en, this message translates to:
  /// **'Picture in picture'**
  String get livekitPip;

  /// No description provided for @livekitQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get livekitQuran;

  /// No description provided for @livekitLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get livekitLeave;

  /// No description provided for @whiteboard.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard'**
  String get whiteboard;

  /// No description provided for @whiteboardClose.
  ///
  /// In en, this message translates to:
  /// **'Close Board'**
  String get whiteboardClose;

  /// No description provided for @whiteboardTeacherView.
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s Whiteboard'**
  String get whiteboardTeacherView;

  /// No description provided for @whiteboardViewOnly.
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get whiteboardViewOnly;

  /// No description provided for @whiteboardStudentsCanDraw.
  ///
  /// In en, this message translates to:
  /// **'Students can draw'**
  String get whiteboardStudentsCanDraw;

  /// No description provided for @parentInvoiceDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String parentInvoiceDueDate(Object date);

  /// No description provided for @studentFeatureTourLiveDesc.
  ///
  /// In en, this message translates to:
  /// **'This class is live right now.'**
  String get studentFeatureTourLiveDesc;

  /// No description provided for @studentFeatureTourJoinNowDesc.
  ///
  /// In en, this message translates to:
  /// **'Join your class when the button appears.'**
  String get studentFeatureTourJoinNowDesc;

  /// No description provided for @studentFeatureTourStartingSoonDesc.
  ///
  /// In en, this message translates to:
  /// **'This class starts soon.'**
  String get studentFeatureTourStartingSoonDesc;

  /// No description provided for @studentFeatureTourStartingSoon15Desc.
  ///
  /// In en, this message translates to:
  /// **'This class starts in about 15 minutes.'**
  String get studentFeatureTourStartingSoon15Desc;

  /// No description provided for @studentFeatureTourScheduledDesc.
  ///
  /// In en, this message translates to:
  /// **'This class is scheduled for later.'**
  String get studentFeatureTourScheduledDesc;

  /// No description provided for @formsUntitledForm.
  ///
  /// In en, this message translates to:
  /// **'Untitled form'**
  String get formsUntitledForm;

  /// No description provided for @formsUntitledField.
  ///
  /// In en, this message translates to:
  /// **'Untitled field'**
  String get formsUntitledField;

  /// No description provided for @formsEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a value'**
  String get formsEnterValue;

  /// No description provided for @roleUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}\nPlease contact an administrator.'**
  String roleUnknownMessage(Object role);

  /// No description provided for @navTutor.
  ///
  /// In en, this message translates to:
  /// **'Tutor'**
  String get navTutor;

  /// No description provided for @tutorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor'**
  String get tutorTitle;

  /// No description provided for @tutorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal learning assistant'**
  String get tutorSubtitle;

  /// No description provided for @tutorConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to your tutor...'**
  String get tutorConnecting;

  /// No description provided for @tutorConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get tutorConnectionError;

  /// No description provided for @tutorConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to the AI tutor. Please try again.'**
  String get tutorConnectionFailed;

  /// No description provided for @tutorMicPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to talk to the AI tutor.'**
  String get tutorMicPermissionRequired;

  /// No description provided for @tutorNotAvailableForRole.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor is only available for students.'**
  String get tutorNotAvailableForRole;

  /// No description provided for @tutorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor service is currently unavailable. Please try again later.'**
  String get tutorServiceUnavailable;

  /// No description provided for @tutorListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get tutorListening;

  /// No description provided for @tutorWaitingForAgent.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Alluwal'**
  String get tutorWaitingForAgent;

  /// No description provided for @tutorSpeakNow.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything about your studies!'**
  String get tutorSpeakNow;

  /// No description provided for @tutorAgentConnecting.
  ///
  /// In en, this message translates to:
  /// **'Alluwal is joining...'**
  String get tutorAgentConnecting;

  /// No description provided for @tutorMicOn.
  ///
  /// In en, this message translates to:
  /// **'Mic On'**
  String get tutorMicOn;

  /// No description provided for @tutorMicOff.
  ///
  /// In en, this message translates to:
  /// **'Mic Off'**
  String get tutorMicOff;

  /// No description provided for @tutorEndSession.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get tutorEndSession;

  /// No description provided for @tutorShowAI.
  ///
  /// In en, this message translates to:
  /// **'Show AI'**
  String get tutorShowAI;

  /// No description provided for @tutorWhiteboardSent.
  ///
  /// In en, this message translates to:
  /// **'Whiteboard sent to AI'**
  String get tutorWhiteboardSent;

  /// No description provided for @tutorWhiteboardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send whiteboard'**
  String get tutorWhiteboardFailed;

  /// No description provided for @tutorStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get tutorStartSession;

  /// No description provided for @tutorDescription.
  ///
  /// In en, this message translates to:
  /// **'Talk to Alluwal, your AI learning buddy. Ask questions about school subjects or explore stories from Islamic history.'**
  String get tutorDescription;

  /// No description provided for @classJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get classJoin;

  /// No description provided for @classMeetingNotReady.
  ///
  /// In en, this message translates to:
  /// **'Meeting not ready'**
  String get classMeetingNotReady;

  /// No description provided for @classJoinIn.
  ///
  /// In en, this message translates to:
  /// **'Join ({time})'**
  String classJoinIn(String time);

  /// No description provided for @classEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get classEnded;

  /// No description provided for @classFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get classFilterAll;

  /// No description provided for @classFilterJoinable.
  ///
  /// In en, this message translates to:
  /// **'Joinable'**
  String get classFilterJoinable;

  /// No description provided for @classFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get classFilterActive;

  /// No description provided for @classFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get classFilterUpcoming;

  /// No description provided for @classFilterPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get classFilterPast;

  /// No description provided for @livekitErrorNotDeployed.
  ///
  /// In en, this message translates to:
  /// **'Presence function not deployed yet'**
  String get livekitErrorNotDeployed;

  /// No description provided for @livekitErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get livekitErrorPermissionDenied;

  /// No description provided for @livekitErrorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get livekitErrorUnauthenticated;

  /// No description provided for @livekitErrorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get livekitErrorServiceUnavailable;

  /// No description provided for @classAvailableWhenJoinable.
  ///
  /// In en, this message translates to:
  /// **'Available when the class is joinable'**
  String get classAvailableWhenJoinable;

  /// No description provided for @classNoOneJoinedYet.
  ///
  /// In en, this message translates to:
  /// **'No one has joined yet'**
  String get classNoOneJoinedYet;

  /// No description provided for @classesMyClasses.
  ///
  /// In en, this message translates to:
  /// **'My Classes'**
  String get classesMyClasses;

  /// No description provided for @classesYourClasses.
  ///
  /// In en, this message translates to:
  /// **'Your classes'**
  String get classesYourClasses;

  /// No description provided for @classesJoinDescription.
  ///
  /// In en, this message translates to:
  /// **'Join your classes directly in the app. The Join button becomes active 10 minutes before the class starts.'**
  String get classesJoinDescription;

  /// No description provided for @filtersCount.
  ///
  /// In en, this message translates to:
  /// **'Filters ({count})'**
  String filtersCount(int count);

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @classesNoActiveClassesNow.
  ///
  /// In en, this message translates to:
  /// **'No active classes right now'**
  String get classesNoActiveClassesNow;

  /// No description provided for @classesSwitchTimeFilter.
  ///
  /// In en, this message translates to:
  /// **'Switch the Time filter to Upcoming or All to browse other classes.'**
  String get classesSwitchTimeFilter;

  /// No description provided for @classesResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String classesResultsCount(int count);

  /// No description provided for @classesParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'Participants ({count})'**
  String classesParticipantsCount(int count);

  /// No description provided for @classesNoMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No classes match your filters'**
  String get classesNoMatchFilters;

  /// No description provided for @classesNoClassesFound.
  ///
  /// In en, this message translates to:
  /// **'No classes found'**
  String get classesNoClassesFound;

  /// No description provided for @classesTryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or clearing them.'**
  String get classesTryAdjustingFilters;

  /// No description provided for @classesTryClearingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try clearing filters or coming back later.'**
  String get classesTryClearingFilters;

  /// No description provided for @teamOurGlobalTeam.
  ///
  /// In en, this message translates to:
  /// **'OUR GLOBAL TEAM'**
  String get teamOurGlobalTeam;

  /// No description provided for @teamMeetThePeopleBehindAlluwal.
  ///
  /// In en, this message translates to:
  /// **'Meet the People Behind Alluwal'**
  String get teamMeetThePeopleBehindAlluwal;

  /// No description provided for @teamHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Educators, leaders, and innovators united by a shared mission — to make quality Islamic and academic education accessible to every learner, everywhere.'**
  String get teamHeroSubtitle;

  /// No description provided for @teamAllTeam.
  ///
  /// In en, this message translates to:
  /// **'All Team'**
  String get teamAllTeam;

  /// No description provided for @teamAllTeamTagline.
  ///
  /// In en, this message translates to:
  /// **'The full Alluwal family'**
  String get teamAllTeamTagline;

  /// No description provided for @teamAllTeamDescription.
  ///
  /// In en, this message translates to:
  /// **'Visionaries and educators united by one mission.'**
  String get teamAllTeamDescription;

  /// No description provided for @teamLeadership.
  ///
  /// In en, this message translates to:
  /// **'Leadership'**
  String get teamLeadership;

  /// No description provided for @teamLeadershipTagline.
  ///
  /// In en, this message translates to:
  /// **'Vision & Direction'**
  String get teamLeadershipTagline;

  /// No description provided for @teamLeadershipDescription.
  ///
  /// In en, this message translates to:
  /// **'The architects and coordinators of Alluwal — shaping policy, strategy, operations and culture.'**
  String get teamLeadershipDescription;

  /// No description provided for @teamTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teamTeachers;

  /// No description provided for @teamTeachersTagline.
  ///
  /// In en, this message translates to:
  /// **'Global Knowledge Carriers'**
  String get teamTeachersTagline;

  /// No description provided for @teamTeachersDescription.
  ///
  /// In en, this message translates to:
  /// **'Scholars and educators spanning 10+ countries — bringing Islamic and academic excellence to every learner, everywhere.'**
  String get teamTeachersDescription;

  /// No description provided for @teamFounderBadge.
  ///
  /// In en, this message translates to:
  /// **'✦  FOUNDER'**
  String get teamFounderBadge;

  /// No description provided for @teamViewFullProfile.
  ///
  /// In en, this message translates to:
  /// **'View Full Profile'**
  String get teamViewFullProfile;

  /// No description provided for @teamWantToJoinOurTeam.
  ///
  /// In en, this message translates to:
  /// **'Want to Join Our Team?'**
  String get teamWantToJoinOurTeam;

  /// No description provided for @teamJoinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We are always looking for passionate educators and professionals who share our vision. Join us in making a difference.'**
  String get teamJoinSubtitle;

  /// No description provided for @teamViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get teamViewProfile;

  /// No description provided for @teamAboutName.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String teamAboutName(String name);

  /// No description provided for @teamWhyAlluwal.
  ///
  /// In en, this message translates to:
  /// **'Why Alluwal'**
  String get teamWhyAlluwal;

  /// No description provided for @teamLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get teamLanguages;

  /// No description provided for @teamContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact {name}'**
  String teamContactName(String name);

  /// No description provided for @teamMessageForName.
  ///
  /// In en, this message translates to:
  /// **'Message for {name}'**
  String teamMessageForName(String name);

  /// No description provided for @teamStaffFallbackSnippet.
  ///
  /// In en, this message translates to:
  /// **'Spreading knowledge and light through Alluwal Education Hub.'**
  String get teamStaffFallbackSnippet;

  /// No description provided for @teamStaffFallbackBio.
  ///
  /// In en, this message translates to:
  /// **'A dedicated member of the Alluwal team, committed to delivering quality Islamic and academic education to learners across the globe.'**
  String get teamStaffFallbackBio;

  /// No description provided for @teamStaffFallbackWhyAlluwal.
  ///
  /// In en, this message translates to:
  /// **'I believe in Alluwal\'s mission to make education accessible, empowering every student to grow spiritually and academically — wherever they are.'**
  String get teamStaffFallbackWhyAlluwal;

  /// No description provided for @teamPartOfTeamBuildsPlatform.
  ///
  /// In en, this message translates to:
  /// **'Part of the team that builds our platform · Math & science'**
  String get teamPartOfTeamBuildsPlatform;

  /// No description provided for @always24Hours7Days.
  ///
  /// In en, this message translates to:
  /// **'Always (24/7)'**
  String get always24Hours7Days;

  /// No description provided for @chatMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat Messages'**
  String get chatMessagesLabel;

  /// No description provided for @adjustmentAmountExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., +0.2 or -5'**
  String get adjustmentAmountExampleHint;

  /// No description provided for @formResponsesTitle.
  ///
  /// In en, this message translates to:
  /// **'Form Responses'**
  String get formResponsesTitle;

  /// No description provided for @optionsCommaSeparatedExample.
  ///
  /// In en, this message translates to:
  /// **'e.g., Option 1, Option 2, Option 3'**
  String get optionsCommaSeparatedExample;

  /// No description provided for @readinessFormRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Readiness Form Required'**
  String get readinessFormRequiredTitle;

  /// No description provided for @requiredForRatingsBelow9.
  ///
  /// In en, this message translates to:
  /// **'Required for ratings below 9'**
  String get requiredForRatingsBelow9;

  /// No description provided for @shiftCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift Completed'**
  String get shiftCompletedLabel;

  /// No description provided for @studentDefaultName1.
  ///
  /// In en, this message translates to:
  /// **'Student 1'**
  String get studentDefaultName1;

  /// No description provided for @requiredAsterisk.
  ///
  /// In en, this message translates to:
  /// **'*'**
  String get requiredAsterisk;

  /// No description provided for @notProvidedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvidedLabel;

  /// No description provided for @bulletSeparator.
  ///
  /// In en, this message translates to:
  /// **' • '**
  String get bulletSeparator;

  /// No description provided for @timesheetDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Timesheet Details'**
  String get timesheetDetailsTitle;

  /// No description provided for @userRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'User Role'**
  String get userRoleLabel;

  /// No description provided for @userTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'User Type'**
  String get userTypeLabel;

  /// No description provided for @confirmDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get confirmDeleteAccountMessage;

  /// No description provided for @confirmResetAllPasswordsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all passwords?'**
  String get confirmResetAllPasswordsMessage;

  /// No description provided for @confirmLeaveClassMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this class?'**
  String get confirmLeaveClassMessage;

  /// No description provided for @confirmDeleteCommentMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment?'**
  String get confirmDeleteCommentMessage;

  /// No description provided for @confirmDeleteAllTeacherShiftsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all shifts for this teacher?'**
  String get confirmDeleteAllTeacherShiftsMessage;

  /// No description provided for @confirmClaimShiftMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to claim this shift?'**
  String get confirmClaimShiftMessage;

  /// No description provided for @confirmDeleteTemplateMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this template?'**
  String get confirmDeleteTemplateMessage;

  /// No description provided for @confirmDeleteFormMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this form?'**
  String get confirmDeleteFormMessage;

  /// No description provided for @confirmDeleteDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this draft?'**
  String get confirmDeleteDraftMessage;

  /// No description provided for @confirmBanShiftMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to ban this shift?'**
  String get confirmBanShiftMessage;

  /// No description provided for @confirmBanFormMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to ban this form?'**
  String get confirmBanFormMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
