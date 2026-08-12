import 'dart:async';
import 'dart:io';

import 'core/services/auth_service.dart';
import 'core/services/error_reporting_service.dart';
import 'core/services/web_app_stability_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';

import 'features/dashboard/screens/role_based_dashboard.dart';
import 'firebase_options.dart' as prod_firebase;
import 'firebase_options_dev.dart' as dev_firebase;
import 'core/constants/app_constants.dart';
import 'core/services/public_site_cms_service.dart';
import 'features/website/screens/landing_page.dart';
import 'core/utils/timezone_utils.dart';
import 'core/utils/auth_debug_logger.dart';
import 'features/auth/screens/mobile_login_screen.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/language_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/prayer_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/version_service.dart';
import 'core/widgets/version_check_wrapper.dart';
import 'core/widgets/language_switcher.dart';
import 'core/utils/app_logger.dart';
import 'core/widgets/web_app_stability_banner.dart';
import 'package:alluwalacademyadmin/core/services/join_link_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_service.dart';
import 'package:alluwalacademyadmin/core/services/class_video_service.dart';
import 'features/livekit/screens/guest_join_screen.dart';

// NOTE: The legacy shift wage migration has been permanently disabled.
// If you ever need to run it manually, trigger ShiftWageMigration.runMigration()
// from a separate maintenance script instead of during app startup.

const String _firebaseEnv =
    String.fromEnvironment('FIREBASE_ENV', defaultValue: 'prod');

bool get _useProdFirebase {
  final env = _firebaseEnv.trim().toLowerCase();
  if (env == 'prod') return true;
  if (env == 'dev') return false;
  return kReleaseMode;
}

FirebaseOptions get _firebaseOptions => _useProdFirebase
    ? prod_firebase.DefaultFirebaseOptions.currentPlatform
    : dev_firebase.DevFirebaseOptions.currentPlatform;

bool get _isNativeMobilePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

bool get _isMobileWebPlatform {
  if (!kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get _isMobileLikePlatform =>
    _isNativeMobilePlatform || _isMobileWebPlatform;

bool _isMobileLayout(BuildContext context) {
  if (_isMobileLikePlatform) return true;
  if (!kIsWeb) return false;
  final shortestSide = MediaQuery.of(context).size.shortestSide;
  return shortestSide < 600;
}

/// Save FCM token if user is already logged in (non-blocking)
void _saveFCMTokenIfLoggedIn() {
  // Run in background to avoid blocking app startup
  // iOS needs more time for APNs token -> FCM token conversion
  final delay = (!kIsWeb && Platform.isIOS)
      ? const Duration(seconds: 5)
      : const Duration(seconds: 2);

  Future.delayed(delay, () async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      AppLogger.debug('🔍 Checking if user is logged in...');
      AppLogger.debug('🔍 Current user: ${currentUser?.uid}');
      AppLogger.debug('🔍 Current user email: ${currentUser?.email}');

      if (currentUser != null) {
        AppLogger.info('✅ User is logged in, attempting to save FCM token...');
        await NotificationService().saveTokenToFirestore(
          userId: currentUser.uid,
        );
        AppLogger.info(
          '✅ FCM token save completed for user: ${currentUser.uid}',
        );
      } else {
        AppLogger.warning('❌ No user logged in - FCM token will not be saved');
      }
    } catch (e) {
      AppLogger.error('❌ ERROR saving FCM token on launch: $e');
      AppLogger.error('❌ Stack trace: ${StackTrace.current}');
    }
  });
}

Widget _wrapWithDebugDevicePreview(Widget app) {
  if (!kDebugMode) return app;
  return DevicePreview(enabled: true, builder: (_) => app);
}

Future<void> main() async {
  // Disable zone error assertions for web in debug mode
  if (kIsWeb && kDebugMode) {
    BindingBase.debugZoneErrorsAreFatal = false;
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Allow Google Fonts to fetch at runtime (fonts are downloaded on first use)
  GoogleFonts.config.allowRuntimeFetching = true;

  if (kIsWeb) {
    JoinLinkService.initFromUri(Uri.base);
  }

  AppLogger.info('Firebase env: ${_useProdFirebase ? 'prod' : 'dev'}');

  // Lock orientation to portrait only (mobile apps only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Firebase before running the app (required for web and all platforms)
  final selectedFirebaseOptions = _firebaseOptions;
  late final FirebaseApp firebaseApp;
  try {
    firebaseApp = await Firebase.initializeApp(
      options: selectedFirebaseOptions,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      firebaseApp = Firebase.app();
    } else {
      rethrow;
    }
  }
  final actualProjectId = firebaseApp.options.projectId;
  final expectedProjectId = selectedFirebaseOptions.projectId;
  if (kDebugMode) {
    AppLogger.info('Firebase projectId: $actualProjectId');
  }
  if (actualProjectId != expectedProjectId) {
    AppLogger.error(
      'Firebase project mismatch. expected=$expectedProjectId actual=$actualProjectId',
    );
  }

  // App Check: in debug on device/emulator use the debug provider so you can
  // whitelist this device in Firebase Console (App Check > Manage debug tokens).
  // When App Check validation fails, the callable layer does not pass the request
  // body to the function (hence jobId/idToken were undefined). A valid debug
  // token fixes that. Only active in debug + native mobile.
  if (kDebugMode && _isNativeMobilePlatform) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    AppLogger.info(
      'App Check debug provider active. In Flutter console look for the debug '
      'token (UUID) and add it in Firebase Console > App Check > your app > '
      'Manage debug tokens.',
    );
  }

  // Web auth persistence:
  // Ensure auth survives reloads/navigation (e.g. cache-busting or SW updates).
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      AppLogger.debug('FirebaseAuth: web persistence set to LOCAL');
    } catch (e) {
      AppLogger.error('FirebaseAuth: failed to set web persistence: $e');
    }
  }

  // Debug visibility into unexpected sign-outs / token changes (especially on web).
  if (kDebugMode) {
    AuthDebugLogger.start();
  }

  // Firestore web SDK stability:
  // Disable IndexedDB persistence on web to avoid rare internal assertion crashes
  // that can occur due to corrupted browser cache/state or multi-tab contention.
  // Also allow the SDK to fall back to long-polling on restrictive networks
  // where WebChannel streaming can become unstable.
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      // Work around intermittent Firestore WebChannel crashes on some networks
      // (`INTERNAL ASSERTION FAILED: Unexpected state`).
      webExperimentalForceLongPolling: true,
      webExperimentalAutoDetectLongPolling: false,
    );

    // Global recovery for the "page spins forever, must clear browsing data
    // to fix" symptom: unregisters stale service workers, evicts Cache Storage
    // entries from prior deploys, and runs a Firestore WebChannel watchdog.
    // Awaited so the SW/cache cleanup completes before runApp; the watchdog
    // itself runs in the background.
    try {
      await WebAppStabilityService.instance.initialize();
    } catch (e) {
      AppLogger.error('WebAppStabilityService init failed: $e');
    }
  }

  // Initialize Firebase Cloud Messaging background handler.
  // The current push-notification flow is configured for native mobile only.
  if (_isNativeMobilePlatform) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize Stripe for in-app payments (mobile only)
  if (_isNativeMobilePlatform) {
    final stripePublishableKey = const String.fromEnvironment(
      'STRIPE_PUBLISHABLE_KEY',
    );
    if (stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = stripePublishableKey;
      await Stripe.instance.applySettings();
    }
  }

  // Initialize timezone database
  TimezoneUtils.initializeTimezones();

  // Initialize Notification Service (only for native mobile platforms)
  if (_isNativeMobilePlatform) {
    await NotificationService().initialize();

    // Create the Adhan notification channel (Android only, safe no-op on iOS).
    await PrayerNotificationService.createAndroidChannel();

    // Schedule location-based prayer time notifications with Adhan sound.
    // Runs in background so it doesn't delay app startup.
    PrayerNotificationService.scheduleAllPrayerNotifications();

    // Save FCM token if user is already logged in
    _saveFCMTokenIfLoggedIn();
  }

  // Initialize Version Service and Remote Config (for force update)
  if (!kIsWeb && kReleaseMode) {
    await VersionService.initialize();
  }

  // Shift wage migration intentionally disabled.
  if (kDebugMode) {
    AppLogger.debug('Shift wage migration is disabled on startup.');
  }

  try {
    await PublicSiteCmsService.warmStartupDocsFromDiskCache();
  } catch (e, st) {
    AppLogger.debug('warmStartupDocsFromDiskCache: $e\n$st');
  }

  // Handle Flutter framework errors gracefully (like trackpad gesture assertions)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filter out known framework issues
    if (details.exception.toString().contains('PointerDeviceKind.trackpad') ||
        details.exception.toString().contains(
              '!identical(kind, PointerDeviceKind.trackpad)',
            )) {
      if (kDebugMode) {
        AppLogger.debug(
          'Ignoring trackpad gesture assertion: ${details.exception}',
        );
      }
      return;
    }

    // For other errors, be conservative on web to avoid inspector crashes
    if (kIsWeb) {
      final msg = details.exception.toString();
      if (msg.contains('LegacyJavaScriptObject') ||
          msg.contains('DiagnosticsNode') ||
          msg.contains('Assertion failed') ||
          msg.contains('org-dartlang-sdk')) {
        if (kDebugMode) {
          AppLogger.debug('Ignoring web inspector/engine error: $msg');
        }
        return;
      }
      // Report to Firestore for remote tracing
      ErrorReportingService.reportError(
        details.exception,
        details.stack,
        context: 'flutter_error',
        fatal: false,
      );
      FlutterError.dumpErrorToConsole(details);
      return;
    }

    // Native: report to Crashlytics + Firestore
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
    ErrorReportingService.reportError(
      details.exception,
      details.stack,
      context: 'flutter_error',
      fatal: false,
    );
    FlutterError.presentError(details);
  };

  // Catch async errors not handled by Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReportingService.reportError(
      error,
      stack,
      context: 'platform_async',
      fatal: true,
    );
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  // Initialize Crashlytics on native platforms
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
  }

  // Use runWidget for web multiview compatibility
  if (kIsWeb) {
    try {
      // Check if we have views available
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        runWidget(
          View(
            view: views.first,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => ThemeService()),
                ChangeNotifierProvider(create: (_) => LanguageService()),
              ],
              child: _wrapWithDebugDevicePreview(const MyApp()),
            ),
          ),
        );
      } else {
        // Fallback to runApp if no views available
        runApp(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeService()),
              ChangeNotifierProvider(create: (_) => LanguageService()),
            ],
            child: _wrapWithDebugDevicePreview(const MyApp()),
          ),
        );
      }
    } catch (e) {
      // If runWidget fails, fallback to runApp
      AppLogger.error('runWidget failed, falling back to runApp: $e');
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => LanguageService()),
          ],
          child: _wrapWithDebugDevicePreview(const MyApp()),
        ),
      );
    }
  } else {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => LanguageService()),
        ],
        child: kReleaseMode
            ? VersionCheckWrapper(
                child: _wrapWithDebugDevicePreview(const MyApp()),
              )
            : _wrapWithDebugDevicePreview(const MyApp()),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Determine initial screen based on platform
  Widget _initialScreen(BuildContext context) {
    AppLogger.debug('=== MyApp._initialScreen: kIsWeb = $kIsWeb ===');

    // NATIVE MOBILE (iOS/Android) - Always go to AuthenticationWrapper
    if (!kIsWeb) {
      AppLogger.debug(
        '=== Native platform detected (${Platform.operatingSystem}) - going to AuthenticationWrapper ===',
      );
      return const AuthenticationWrapper();
    }

    // WEB: Check for special join links
    if (JoinLinkService.hasPendingGuestJoin) {
      AppLogger.debug('=== Guest join link detected ===');
      return const GuestJoinScreen();
    }

    if (JoinLinkService.hasPendingJoin) {
      AppLogger.debug(
        '=== Join link detected: routing to AuthenticationWrapper ===',
      );
      return const AuthenticationWrapper();
    }

    // WEB: the public site is the Next.js app at the domain root; this Flutter
    // build is mounted under /app/. Its own LandingPage is a leftover duplicate
    // of that homepage, so nothing on the web should land here — signing in and
    // pressing the browser Back button used to show it.
    // Auth pages remain available via explicit routes like /login.
    final platformLabel = defaultTargetPlatform.toString();
    final isMobileLayout = _isMobileLayout(context);
    AppLogger.debug(
      '=== Web platform check: $platformLabel, isMobile=$isMobileLayout ===',
    );
    AppLogger.debug('=== Returning WebRootScreen for web (mobile/desktop) ===');
    return const WebRootScreen();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, LanguageService>(
      builder: (context, themeService, languageService, child) {
        final previewLocale = DevicePreview.locale(context);
        // Ensure we always have a valid supported locale
        final appLocale = languageService.locale ??
            (previewLocale != null &&
                    LanguageService.supportedLocales.any(
                      (l) => l.languageCode == previewLocale.languageCode,
                    )
                ? previewLocale
                : const Locale('en'));
        return MaterialApp(
          // Navigator key for notification navigation
          navigatorKey: NotificationService.navigatorKey,
          // DevicePreview configuration
          locale: appLocale,
          supportedLocales: LanguageService.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale.languageCode) {
                return supported;
              }
            }
            return supportedLocales.first;
          },
          builder: (context, child) {
            final built = DevicePreview.appBuilder(context, child);

            // [WebAppStabilityBanner] is no-op on non-web; on web it surfaces a
            // floating "page is stuck" banner with Recover / Reload actions
            // when a screen reports being stuck.
            final appContent = WebAppStabilityBanner(child: built);

            if (kReleaseMode) return appContent;

            // Avoid Material [Banner] here: on Flutter Web + DevicePreview it can trigger
            // "A _RenderLayoutBuilder was mutated in performLayout" when overlays
            // activate during a parent LayoutBuilder layout pass.
            final label = _useProdFirebase ? 'PROD' : 'DEV';
            final color = _useProdFirebase
                ? const Color(0xFFDC2626)
                : const Color(0xFF16A34A);

            return Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                appContent,
                Positioned(
                  top: 0,
                  left: 0,
                  child: IgnorePointer(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          debugShowCheckedModeBanner: false,
          scrollBehavior: AppScrollBehavior(),

          // Theme configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,

          // Route handling for direct URL navigation
          onGenerateRoute: (settings) {
            // Handle routes that may come from browser URL
            switch (settings.name) {
              case '/login':
              case '/signup':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => const AuthenticationWrapper(),
                );
              default:
                return MaterialPageRoute(
                  settings: const RouteSettings(name: '/'),
                  builder: (context) => _initialScreen(context),
                );
            }
          },
          initialRoute: '/',
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        // Keep touch-based drag scrolling available across web and mobile.
        PointerDeviceKind.touch,
        // Keep mouse drags for SelectionArea. Flutter documents that making
        // scrollables accept mouse drags prevents text selection.
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class FirebaseInitializer extends StatefulWidget {
  const FirebaseInitializer({super.key});

  @override
  State<FirebaseInitializer> createState() => _FirebaseInitializerState();
}

class _FirebaseInitializerState extends State<FirebaseInitializer> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      // Add delay for web to ensure proper initialization order
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Firebase.initializeApp(options: _firebaseOptions);

      // Additional delay for web Firebase services to fully initialize
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));

        // Touch Firestore to ensure it's initialized on web.
        // Avoid toggling network state here; it can destabilize active listeners in the web SDK.
        // (Firestore connectivity errors will be surfaced naturally by queries/listeners.)
        FirebaseFirestore.instance;
      }

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      AppLogger.error('Firebase initialization error: $e');
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.failedToInitializeFirebase,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!
                    .pleaseCheckYourInternetConnectionAnd,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = false;
                    _initialized = false;
                  });
                  _initializeFirebase();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/Alluwal_Education_Hub_Logo.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.of(context)!.alluwalEducationHub,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.initializingApplication,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
              ),
            ],
          ),
        ),
      );
    }

    return const AuthenticationWrapper();
  }
}

/// Pauses the web Firestore stability probe while auth is unknown or signed out.
class _WebWatchdogAuthBinding extends StatefulWidget {
  const _WebWatchdogAuthBinding({
    super.key,
    required this.snapshot,
    required this.child,
  });

  final AsyncSnapshot<User?> snapshot;
  final Widget child;

  @override
  State<_WebWatchdogAuthBinding> createState() =>
      _WebWatchdogAuthBindingState();
}

class _WebWatchdogAuthBindingState extends State<_WebWatchdogAuthBinding> {
  @override
  void initState() {
    super.initState();
    _sync(widget.snapshot);
  }

  @override
  void didUpdateWidget(covariant _WebWatchdogAuthBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = oldWidget.snapshot;
    final b = widget.snapshot;
    if (a.connectionState != b.connectionState ||
        a.hasData != b.hasData ||
        a.data?.uid != b.data?.uid) {
      _sync(b);
    }
  }

  void _sync(AsyncSnapshot<User?> s) {
    if (!kIsWeb) return;
    final paused = s.connectionState == ConnectionState.waiting ||
        !s.hasData ||
        s.data == null;
    WebAppStabilityService.instance.setWatchdogPaused(paused);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


/// What the web app shows at `/`.
///
/// The public site is the Next.js app at the domain root; this Flutter build is
/// mounted under `/app/`, and its own [LandingPage] is a leftover duplicate of
/// that homepage. Signing in and pressing the browser Back button landed there,
/// so `/` now resolves by auth state — signed in goes to the dashboard, signed
/// out gets the sign-in screen.
///
/// It deliberately does NOT navigate anywhere itself. Flutter builds the `/`
/// route during startup even when the URL asks for `/login`, so redirecting
/// from here fires before the requested route resolves and throws people off
/// the sign-in page. Deferring entirely to [AuthenticationWrapper] keeps `/`
/// and `/login` behaving identically and leaves the browser history alone.
class WebRootScreen extends StatelessWidget {
  const WebRootScreen({super.key});

  @override
  Widget build(BuildContext context) => const AuthenticationWrapper();
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool _isCheckingConnection = true;
  bool _handledJoinLink = false;
  bool _joiningFromLink = false;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    // Start monitoring connectivity
    ConnectivityService.startMonitoring(context);
  }

  Future<void> _checkInternetConnection() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    setState(() {
      _isCheckingConnection = false;
    });

    if (!hasInternet && mounted) {
      ConnectivityService.showNoInternetDialog(context);
    }
  }

  void _triggerJoinLinkHandling() {
    if (_handledJoinLink) return;
    _handledJoinLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeJoinFromLink());
  }

  Future<void> _maybeJoinFromLink() async {
    if (!mounted || _joiningFromLink) return;
    final shiftId = JoinLinkService.consumePendingShiftId();
    if (shiftId == null) return;

    _joiningFromLink = true;
    try {
      final shift = await ShiftService.getShiftById(shiftId);
      if (!mounted) return;
      if (shift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.thisClassLinkIsNoLonger,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await VideoCallService.joinClass(context, shift);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToOpenClassLinkE),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _joiningFromLink = false;
    }
  }

  // Helper to check if we should use the mobile UI
  bool _isMobile(BuildContext context) {
    return _isMobileLayout(context);
  }

  Widget _authSnapshotBody(
    BuildContext context,
    AsyncSnapshot<User?> snapshot,
  ) {
    if (snapshot.hasError) {
      AppLogger.error('Auth state error: ${snapshot.error}');
      return _isMobile(context)
          ? const MobileLoginScreen()
          : const EmployeeHubApp();
    }
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/Alluwal_Education_Hub_Logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.commonLoading,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (snapshot.hasData && snapshot.data != null) {
      final user = snapshot.data!;
      ErrorReportingService.setUser(user.uid, email: user.email);
      ErrorReportingService.addBreadcrumb('user_authenticated');
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      }

      _triggerJoinLinkHandling();
      return const RoleBasedDashboard();
    }

    ErrorReportingService.clearUser();
    return _isMobile(context)
        ? const MobileLoginScreen()
        : const EmployeeHubApp();
  }

  @override
  void dispose() {
    ConnectivityService.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show checking connection screen
    if (_isCheckingConnection) {
      return Scaffold(
        backgroundColor: const Color(0xffF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/Alluwal_Education_Hub_Logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.checkingConnection,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) => _WebWatchdogAuthBinding(
        snapshot: snapshot,
        child: _authSnapshotBody(context, snapshot),
      ),
    );
  }
}

class EmployeeHubApp extends StatefulWidget {
  const EmployeeHubApp({super.key});

  @override
  State<EmployeeHubApp> createState() => _EmployeeHubAppState();
}

class _EmployeeHubAppState extends State<EmployeeHubApp> {
  TextEditingController emailAddressController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool _useStudentIdLogin = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Removed pre-filled credentials to ensure proper Firebase authentication
  }

  void _showErrorDialog(String message) {
    if (!mounted) return; // Check if widget is still mounted
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.commonError,
          style: openSansHebrewTextStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(message, style: openSansHebrewTextStyle),
        actions: <Widget>[
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.okay,
              style: openSansHebrewTextStyle.copyWith(
                color: const Color(0xff04ABC1),
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    if (!mounted) return; // Check if widget is still mounted
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: openSansHebrewTextStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xff059669),
          ),
        ),
        content: Text(message, style: openSansHebrewTextStyle),
        actions: <Widget>[
          TextButton(
            child: Text(
              AppLocalizations.of(context)!.okay,
              style: openSansHebrewTextStyle.copyWith(
                color: const Color(0xff0386FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // Handle forgot password
  Future<void> _handleForgotPassword() async {
    final l = AppLocalizations.of(context)!;
    String email = emailAddressController.text.trim();

    // Check if email is provided
    if (email.isEmpty) {
      if (mounted) {
        _showErrorDialog(l.publicEnterEmailFirst);
      }
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      if (mounted) {
        _showErrorDialog(l.loginInvalidEmailFormat);
      }
      return;
    }

    try {
      AuthService authService = AuthService();
      await authService.sendPasswordResetEmail(email);

      // Show success message
      if (mounted) {
        _showSuccessDialog(
          l.publicResetTitle,
          l.publicResetBody(email),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = l.loginNoAccountEmail;
          break;
        case 'invalid-email':
          errorMessage = l.loginInvalidEmailFormat;
          break;
        case 'too-many-requests':
          errorMessage = l.publicResetTooMany;
          break;
        case 'network-request-failed':
          errorMessage = l.publicNetworkError;
          break;
        default:
          errorMessage = l.publicResetFailed;
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          l.loginUnexpectedError,
        );
      }
    }
  }

  // Handle sign-in process
  Future<void> _handleSignIn() async {
    final l = AppLocalizations.of(context)!;
    AuthService authService = AuthService();
    try {
      String emailOrId = emailAddressController.text.trim();
      String password = passwordController.text;

      // If using Student ID mode, convert ID to alias email
      if (_useStudentIdLogin) {
        // Avoid adding import at top by using fully-qualified name via a helper
        // We'll map student ID to alias email on the fly
        final aliasEmail = _aliasFromStudentId(emailOrId);
        emailOrId = aliasEmail;
      }

      User? user = await authService.signInWithEmailAndPassword(
        emailOrId,
        password,
      );

      if (user != null) {
        AppLogger.info('AuthService login succeeded for uid=${user.uid}');
        ErrorReportingService.addBreadcrumb('login_email');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-deactivated':
          errorMessage = l.loginAccountArchived;
          break;
        case 'user-not-found':
          errorMessage = l.loginNoAccountEmail;
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = l.loginIncorrectPassword;
          break;
        case 'keychain-error':
          errorMessage = l.loginFailed;
          break;
        case 'invalid-email':
          errorMessage = l.loginInvalidEmailFormat;
          break;
        case 'user-disabled':
          errorMessage = l.loginAccountDisabled;
          break;
        case 'too-many-requests':
          errorMessage = l.loginTooManyAttempts;
          break;
        case 'network-request-failed':
          errorMessage = l.publicNetworkError;
          break;
        case 'unknown-error':
          errorMessage = l.loginUnexpectedError;
          break;
        default:
          errorMessage = l.loginFailed;
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          l.loginUnexpectedError,
        );
      }
    }
  }

  // Local helper to build alias email without importing service at top-level
  String _aliasFromStudentId(String studentId) {
    final normalized = studentId.trim().toLowerCase();
    const domain = 'alluwaleducationhub.org';
    return '$normalized@$domain';
  }

  // Handle Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    final l = AppLocalizations.of(context)!;
    AuthService authService = AuthService();
    try {
      User? user = await authService.signInWithGoogle();

      if (user != null) {
        AppLogger.info('Google sign-in succeeded for uid=${user.uid}');
        ErrorReportingService.addBreadcrumb('login_google');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-registered':
          errorMessage = l.publicGoogleNoAccount;
          break;
        case 'user-deactivated':
          errorMessage = l.loginAccountArchived;
          break;
        case 'account-exists-with-different-credential':
          errorMessage = l.publicGoogleDifferentMethod;
          break;
        case 'google-signin-failed':
          errorMessage = l.publicGoogleFailed;
          break;
        default:
          errorMessage = l.loginFailed;
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(l.loginUnexpectedError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Color(0xffF8FAFC)),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguageSwitcher(),
                  ),
                  // Logo and Title
                  Column(
                    children: [
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            color: const Color(0xffF8FAFC),
                            child: Image.asset(
                              'assets/Alluwal_Education_Hub_Logo.png',
                              width: 170,
                              height: 170,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context)!.loginWelcomeBack,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(context)!.pleaseSignInToYourAccount,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xff6B7280),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Login Mode Toggle
                  Row(
                    children: [
                      Switch(
                        value: _useStudentIdLogin,
                        onChanged: (val) {
                          setState(() {
                            _useStudentIdLogin = val;
                            emailAddressController.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.useStudentId,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xff374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Email or Student ID Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _useStudentIdLogin
                            ? AppLocalizations.of(context)!.loginStudentId
                            : AppLocalizations.of(context)!.loginEmail,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailAddressController,
                        keyboardType: TextInputType.text,
                        onFieldSubmitted: (_) => _handleSignIn(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xff111827),
                        ),
                        decoration: InputDecoration(
                          hintText: _useStudentIdLogin
                              ? AppLocalizations.of(context)!
                                  .loginEnterStudentId
                              : AppLocalizations.of(context)!.loginEnterEmail,
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xff9CA3AF),
                            fontSize: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffD1D5DB),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffD1D5DB),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xff0386FF),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.loginPassword,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff374151),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        onFieldSubmitted: (_) => _handleSignIn(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xff111827),
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!
                              .loginEnterPassword,
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xff9CA3AF),
                            fontSize: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xff6B7280),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            tooltip: _obscurePassword
                                ? AppLocalizations.of(context)!
                                    .publicShowPassword
                                : AppLocalizations.of(context)!
                                    .publicHidePassword,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffD1D5DB),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xffD1D5DB),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xff0386FF),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xffF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.forgotPassword,
                        style: GoogleFonts.inter(
                          color: const Color(0xff0386FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign In Button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _handleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0386FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.loginSignIn,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xffE5E7EB),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          AppLocalizations.of(context)!.or,
                          style: GoogleFonts.inter(
                            color: const Color(0xff6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xffE5E7EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign In Button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xffD1D5DB),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google "G" logo using custom colors
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CustomPaint(painter: _GoogleLogoPainter()),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.continueWithGoogle,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xff374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the Google "G" logo
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Blue arc (right side)
    final bluePaint = Paint()
      ..color = const Color(0xff4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.butt;

    // Green arc (bottom right)
    final greenPaint = Paint()
      ..color = const Color(0xff34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.butt;

    // Yellow arc (bottom left)
    final yellowPaint = Paint()
      ..color = const Color(0xffFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.butt;

    // Red arc (top)
    final redPaint = Paint()
      ..color = const Color(0xffEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromLTWH(
      width * 0.09,
      height * 0.09,
      width * 0.82,
      height * 0.82,
    );

    // Draw arcs (clockwise from right)
    canvas.drawArc(rect, -0.4, 1.2, false, bluePaint); // Right
    canvas.drawArc(rect, 0.8, 0.9, false, greenPaint); // Bottom right
    canvas.drawArc(rect, 1.7, 0.9, false, yellowPaint); // Bottom left / left
    canvas.drawArc(rect, 2.6, 1.0, false, redPaint); // Top

    // Draw the horizontal bar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xff4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(width * 0.5, height * 0.42, width * 0.41, height * 0.16),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
