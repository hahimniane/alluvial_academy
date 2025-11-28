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
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'screens/landing_page.dart';
import 'core/utils/timezone_utils.dart';
import 'features/auth/screens/mobile_login_screen.dart';
import 'features/dashboard/screens/mobile_dashboard_screen.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/services/version_service.dart';
import 'core/widgets/version_check_wrapper.dart';
import 'core/utils/app_logger.dart';

// NOTE: The legacy shift wage migration has been permanently disabled.
// If you ever need to run it manually, trigger ShiftWageMigration.runMigration()
// from a separate maintenance script instead of during app startup.

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

  // Lock orientation to portrait only (mobile apps only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Firebase before running the app (required for web and all platforms)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  Widget get _initialScreen {
    AppLogger.debug('=== MyApp._initialScreen: kIsWeb = $kIsWeb ===');

    if (!kIsWeb) {
      final platform = defaultTargetPlatform;
      final isMobilePlatform =
          platform == TargetPlatform.android || platform == TargetPlatform.iOS;

      AppLogger.debug(
          '=== Platform check: $platform, isMobile=$isMobilePlatform ===');
      if (isMobilePlatform) {
        AppLogger.debug('=== Returning AuthenticationWrapper for mobile ===');
        return const AuthenticationWrapper();
      }
    }

    // On web or other platforms, show the website landing page
    AppLogger.debug('=== Returning LandingPage ===');
    return const LandingPage();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          // DevicePreview configuration
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          debugShowCheckedModeBanner: false,
          scrollBehavior: AppScrollBehavior(),

          // Theme configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,

          home: _initialScreen,
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
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Additional delay for web Firebase services to fully initialize
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));

        // Initialize Firestore with error handling
        try {
          final firestore = FirebaseFirestore.instance;
          // Test connection
          await firestore.disableNetwork();
          await firestore.enableNetwork();
        } catch (firestoreError) {
          AppLogger.error('Firestore initialization error: $firestoreError');
          // Continue anyway - might be a temporary issue
        }
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

  // Helper to check if running on mobile
  bool get _isMobile {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
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
          return _isMobile ? const MobileLoginScreen() : const EmployeeHubApp();
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
          // On mobile, use mobile dashboard; on web, use role-based dashboard
          return _isMobile
              ? const MobileDashboardScreen()
              : const RoleBasedDashboard();
        }

        // Otherwise, they're not signed in
        // On mobile, show mobile login; on web, show web login
        return _isMobile ? const MobileLoginScreen() : const EmployeeHubApp();
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

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RoleBasedDashboard(),
          ),
        );
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
                      obscureText: true,
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
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 20,
                      color: Color(0xff374151),
                    ),
                    label: Text(
                      'Continue with Google',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff374151),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xffD1D5DB),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
