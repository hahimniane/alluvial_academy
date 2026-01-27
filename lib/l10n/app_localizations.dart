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
  /// **'Total Hours'**
  String get timesheetTotalHours;

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
  /// **'New password for {name}'**
  String userNewPasswordFor(String name);

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
  String userPromoteConfirm(String name);

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
  /// **'Are you sure you want to permanently delete {name}?'**
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
  /// **'User deleted successfully'**
  String get userDeletedSuccess;

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
