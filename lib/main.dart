import 'dart:io';

import 'core/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';

import 'role_based_dashboard.dart';
import 'firebase_options.dart' as prod_firebase;
import 'firebase_options_dev.dart' as dev_firebase;
import 'core/constants/app_constants.dart';
import 'screens/landing_page.dart';
import 'core/utils/timezone_utils.dart';
import 'core/utils/auth_debug_logger.dart';
import 'features/auth/screens/mobile_login_screen.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/version_service.dart';
import 'core/widgets/version_check_wrapper.dart';
import 'core/utils/app_logger.dart';
import 'core/services/join_link_service.dart';
import 'core/services/shift_service.dart';
import 'core/services/video_call_service.dart';
import 'features/livekit/screens/guest_join_screen.dart';

// NOTE: The legacy shift wage migration has been permanently disabled.
// If you ever need to run it manually, trigger ShiftWageMigration.runMigration()
// from a separate maintenance script instead of during app startup.

// const String _firebaseEnv =
//     String.fromEnvironment('FIREBASE_ENV', defaultValue: '');

    const String _firebaseEnv = 'prod'; // change to 'dev' to switch projects and prod to run the production project


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

bool get _isMobileLikePlatform => _isNativeMobilePlatform || _isMobileWebPlatform;

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
        await NotificationService()
            .saveTokenToFirestore(userId: currentUser.uid);
        AppLogger.info(
            '✅ FCM token save completed for user: ${currentUser.uid}');
      } else {
        AppLogger.warning('❌ No user logged in - FCM token will not be saved');
      }
    } catch (e) {
      AppLogger.error('❌ ERROR saving FCM token on launch: $e');
      AppLogger.error('❌ Stack trace: ${StackTrace.current}');
    }
  });
}

Future<void> main() async {
  // Disable zone error assertions for web in debug mode
  if (kIsWeb && kDebugMode) {
    BindingBase.debugZoneErrorsAreFatal = false;
  }

  WidgetsFlutterBinding.ensureInitialized();

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
  final firebaseApp = await Firebase.initializeApp(
    options: selectedFirebaseOptions,
  );
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
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  // Initialize Firebase Cloud Messaging background handler
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize timezone database
  TimezoneUtils.initializeTimezones();

  // Initialize Notification Service (only for mobile platforms)
  if (!kIsWeb) {
    await NotificationService().initialize();

    // Save FCM token if user is already logged in
    _saveFCMTokenIfLoggedIn();
  }

  // Initialize Version Service and Remote Config (for force update)
  if (!kIsWeb) {
    await VersionService.initialize();
  }

  // Shift wage migration intentionally disabled.
  if (kDebugMode) {
    AppLogger.debug('Shift wage migration is disabled on startup.');
  }

  // Handle Flutter framework errors gracefully (like trackpad gesture assertions)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filter out known framework issues
    if (details.exception.toString().contains('PointerDeviceKind.trackpad') ||
        details.exception
            .toString()
            .contains('!identical(kind, PointerDeviceKind.trackpad)')) {
      // Silently ignore trackpad gesture assertion errors
      if (kDebugMode) {
        AppLogger.debug(
            'Ignoring trackpad gesture assertion: ${details.exception}');
      }
      return;
    }

    // For other errors, be conservative on web to avoid inspector crashes
    if (kIsWeb) {
      // Work around a web debug inspector type error with LegacyJavaScriptObject
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
      // Dump to console without structured inspector overlay
      FlutterError.dumpErrorToConsole(details);
      return;
    }

    // Non-web: use default handler
    FlutterError.presentError(details);
  };

  // Use runWidget for web multiview compatibility
  if (kIsWeb) {
    try {
      // Check if we have views available
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) {
        runWidget(
          View(
            view: views.first,
            child: ChangeNotifierProvider(
              create: (_) => ThemeService(),
              child: DevicePreview(
                enabled: kDebugMode, // Only enabled in debug mode
                builder: (context) => const MyApp(),
              ),
            ),
          ),
        );
      } else {
        // Fallback to runApp if no views available
        runApp(
          ChangeNotifierProvider(
            create: (_) => ThemeService(),
            child: DevicePreview(
              enabled: kDebugMode,
              builder: (context) => const MyApp(),
            ),
          ),
        );
      }
    } catch (e) {
      // If runWidget fails, fallback to runApp
      AppLogger.error('runWidget failed, falling back to runApp: $e');
      runApp(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: DevicePreview(
            enabled: kDebugMode,
            builder: (context) => const MyApp(),
          ),
        ),
      );
    }
  } else {
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: VersionCheckWrapper(
          child: DevicePreview(
            enabled: kDebugMode, // Only enabled in debug mode
            builder: (context) => const MyApp(),
          ),
        ),
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
      AppLogger.debug('=== Native platform detected (${Platform.operatingSystem}) - going to AuthenticationWrapper ===');
      return const AuthenticationWrapper();
    }

    // WEB: Check for special join links
    if (JoinLinkService.hasPendingGuestJoin) {
      AppLogger.debug('=== Guest join link detected ===');
      return const GuestJoinScreen();
    }

    if (JoinLinkService.hasPendingJoin) {
      AppLogger.debug('=== Join link detected: routing to AuthenticationWrapper ===');
      return const AuthenticationWrapper();
    }

    // WEB: Check if mobile-sized screen (responsive)
    final platformLabel = defaultTargetPlatform.toString();
    AppLogger.debug(
        '=== Web platform check: $platformLabel, isMobile=${_isMobileLayout(context)} ===');

    if (_isMobileLayout(context)) {
      AppLogger.debug('=== Mobile web layout - going to AuthenticationWrapper ===');
      return const AuthenticationWrapper();
    }

    // WEB desktop: Show landing page
    AppLogger.debug('=== Returning LandingPage for web desktop ===');
    return const LandingPage();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          // Navigator key for notification navigation
          navigatorKey: NotificationService.navigatorKey,
          // DevicePreview configuration
          locale: DevicePreview.locale(context),
          builder: (context, child) {
            final built = DevicePreview.appBuilder(context, child);
            if (kReleaseMode) return built;

            final label = _useProdFirebase ? 'PROD' : 'DEV';
            final color =
                _useProdFirebase ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

            return Banner(
              message: label,
              location: BannerLocation.topStart,
              color: color,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              child: built,
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
        // Enable drag scrolling for all common input devices on web/mobile
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
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

      await Firebase.initializeApp(
        options: _firebaseOptions,
      );

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
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to initialize Firebase',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your internet connection and try again',
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
                child: const Text('Retry'),
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
                'Alluwal Education Hub',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Initializing application...',
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
          const SnackBar(
            content: Text('This class link is no longer valid.'),
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
          content: Text('Failed to open class link: $e'),
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
                'Checking connection...',
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
      builder: (context, snapshot) {
        // Handle errors gracefully during auth state changes
        if (snapshot.hasError) {
          AppLogger.error('Auth state error: ${snapshot.error}');
          return _isMobile(context) ? const MobileLoginScreen() : const EmployeeHubApp();
        }
        // Handle connection states properly
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xff0386FF)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
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

        // Handle errors
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xffF8FAFC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Error',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please refresh the page',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData && snapshot.data != null) {
          _triggerJoinLinkHandling();
          // Use the unified role-based dashboard across platforms.
          // DashboardPage adapts layout responsively (drawer on small screens).
          return const RoleBasedDashboard();
        }

        // Otherwise, they're not signed in
        // On mobile (native or mobile web), show mobile login; on desktop web, show web login
        return _isMobile(context) ? const MobileLoginScreen() : const EmployeeHubApp();
      },
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
          'Error',
          style: openSansHebrewTextStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: openSansHebrewTextStyle,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'Okay',
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
        content: Text(
          message,
          style: openSansHebrewTextStyle,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'Okay',
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
    String email = emailAddressController.text.trim();

    // Check if email is provided
    if (email.isEmpty) {
      if (mounted) {
        _showErrorDialog('Please enter your email address first.');
      }
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      if (mounted) {
        _showErrorDialog('Please enter a valid email address.');
      }
      return;
    }

    try {
      AuthService authService = AuthService();
      await authService.sendPasswordResetEmail(email);

      // Show success message
      if (mounted) {
        _showSuccessDialog(
          'Password Reset Email Sent',
          'A password reset link has been sent to $email. Please check your inbox and follow the instructions to reset your password.',
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage =
              'No account found with this email address. Please check your email or contact an administrator.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many password reset requests. Please wait a few minutes before trying again.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network connection failed. Please check your internet connection and try again.';
          break;
        default:
          errorMessage = e.message ??
              'Unable to send password reset email. Please try again later.';
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
            'An unexpected error occurred. Please try again later.');
      }
    }
  }

  // Handle sign-in process
  Future<void> _handleSignIn() async {
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
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-deactivated':
          errorMessage =
              'Your account has been archived. Please contact an administrator for assistance.';
          break;
        case 'user-not-found':
          errorMessage =
              'No account found with this email address. Please check your email or contact an administrator.';
          break;
        case 'wrong-password':
          errorMessage =
              'Incorrect password. Please try again or use "Forgot Password" if needed.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage =
              'This account has been disabled. Please contact an administrator for assistance.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many failed login attempts. Please wait a few minutes before trying again.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network connection failed. Please check your internet connection and try again.';
          break;
        case 'unknown-error':
          errorMessage = e.message ??
              'An unexpected error occurred. Please try again later.';
          break;
        default:
          errorMessage =
              'Login failed. Please check your credentials and try again.';
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
            'An unexpected error occurred. Please try again later.');
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
    AuthService authService = AuthService();
    try {
      User? user = await authService.signInWithGoogle();

      if (user != null) {
        AppLogger.info('Google sign-in succeeded for uid=${user.uid}');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-registered':
          errorMessage =
              'No account found with this Google email. Please contact an administrator to create your account first.';
          break;
        case 'user-deactivated':
          errorMessage =
              'Your account has been archived. Please contact an administrator for assistance.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with this email but uses a different sign-in method. Please use your email and password to sign in.';
          break;
        case 'google-signin-failed':
          errorMessage = 'Google sign-in failed. Please try again.';
          break;
        default:
          errorMessage =
              'Sign-in failed. Please check your account and try again.';
      }
      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xffF8FAFC),
        ),
        child: Center(
            child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(48),
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
                // Logo and Title
                Column(
                  children: [
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAFC),
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
                        child: Container(
                          color: const Color(0xffF8FAFC),
                          child: Image.asset(
                            'assets/Alluwal_Education_Hub_Logo.png',
                            width: 280,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome Back',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please sign in to your account',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

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
                      'Use Student ID',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xff374151),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email or Student ID Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _useStudentIdLogin ? 'Student ID' : 'Email',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff374151),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                            ? 'Enter your Student ID (e.g., A7Q4-MZ2N)'
                            : 'Enter your email address',
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
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Password Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _handleSignIn(),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xff111827),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
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
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleForgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.inter(
                        color: const Color(0xff0386FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign In Button
                SizedBox(
                  height: 48,
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
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                        'or',
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
                const SizedBox(height: 32),

                // Google Sign In Button
                SizedBox(
                  height: 48,
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
                          child: CustomPaint(
                            painter: _GoogleLogoPainter(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
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
        )),
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
      Rect.fromLTWH(
        width * 0.5,
        height * 0.42,
        width * 0.41,
        height * 0.16,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
