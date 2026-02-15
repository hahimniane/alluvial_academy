import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'location_service.dart';
import 'location_preference_service.dart';
import 'prayer_time_service.dart';
import 'user_role_service.dart';
import 'timezone_service.dart';
import 'notification_service.dart';
import 'route_persistence_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Web: make sure the freshly-signed-in user's token is ready before any Firestore calls.
        // This avoids rare timing issues where early Firestore reads can run unauthenticated.
        if (kIsWeb) {
          try {
            await user.getIdToken(true);
            AppLogger.debug('AuthService: refreshed ID token after login (web)');
          } catch (e) {
            AppLogger.error('AuthService: failed to refresh ID token after login: $e');
          }
        }

        // Check if the user exists in our system (Firestore users collection)
        final userData = await UserRoleService.getCurrentUserData();
        if (userData == null) {
          AppLogger.debug('AuthService: User authenticated but no Firestore document found for ${user.email}');
          // Sign out and throw error
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-registered',
            message:
                'No account found with this email. Please contact an administrator to create your account.',
          );
        }

        // Check if the user is active before proceeding
        final isActive = await UserRoleService.isUserActive(user.email!);
        if (!isActive) {
          // If the user is not active, sign them out immediately
          await _auth.signOut();
          // Throw a specific exception to be caught in the UI
          throw FirebaseAuthException(
            code: 'user-deactivated',
            message:
                'Your account has been archived. Please contact an administrator for assistance.',
          );
        }

        // Update last login time in Firestore
        await _updateLastLoginTime(user);

        // Update timezone on login (non-blocking)
        TimezoneService.updateUserTimezoneOnLogin().catchError((e) {
          AppLogger.error('AuthService: Failed to update timezone: $e');
        });

        // Initialize location and prayer times for teachers (non-blocking)
        _initializeTeacherServices(user).catchError((e) {
          AppLogger.error('AuthService: Background teacher initialization failed: $e');
        });
      }

      return user;
    } on FirebaseAuthException {
      // Re-throw FirebaseAuthException to preserve error codes
      rethrow;
    } catch (e) {
      AppLogger.error('AuthService error: $e');
      // Throw a generic FirebaseAuthException for other errors
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'An unexpected error occurred. Please try again later.',
      );
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        AppLogger.debug('AuthService: Google sign-in cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential result =
          await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        // Web: refresh ID token
        if (kIsWeb) {
          try {
            await user.getIdToken(true);
            AppLogger.debug(
                'AuthService: refreshed ID token after Google login (web)');
          } catch (e) {
            AppLogger.error(
                'AuthService: failed to refresh ID token after Google login: $e');
          }
        }

        // Check if the user exists in our system
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Also check by email
          final emailQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: user.email?.toLowerCase())
              .limit(1)
              .get();

          if (emailQuery.docs.isEmpty) {
            // User doesn't exist in our system - sign them out
            await _auth.signOut();
            await googleSignIn.signOut();
            throw FirebaseAuthException(
              code: 'user-not-registered',
              message:
                  'No account found with this email. Please contact an administrator to create your account.',
            );
          }
        }

        // Check if the user is active
        final isActive = await UserRoleService.isUserActive(user.email!);
        if (!isActive) {
          await _auth.signOut();
          await googleSignIn.signOut();
          throw FirebaseAuthException(
            code: 'user-deactivated',
            message:
                'Your account has been archived. Please contact an administrator for assistance.',
          );
        }

        // Update last login time
        await _updateLastLoginTime(user);

        // Update timezone (non-blocking)
        TimezoneService.updateUserTimezoneOnLogin().catchError((e) {
          AppLogger.error('AuthService: Failed to update timezone: $e');
        });

        // Initialize teacher services (non-blocking)
        _initializeTeacherServices(user).catchError((e) {
          AppLogger.error(
              'AuthService: Background teacher initialization failed: $e');
        });

        AppLogger.info(
            'AuthService: Google sign-in succeeded for ${user.email}');
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      AppLogger.error('AuthService: Google sign-in error: $e');
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  // Initialize services for teachers after login
  Future<void> _initializeTeacherServices(User user) async {
    try {
      // Get user role
      final role = await UserRoleService.getCurrentUserRole();

      if (role?.toLowerCase() == 'teacher') {
        AppLogger.error('AuthService: Initializing services for teacher ${user.uid}');

        // Fetch location in background - completely fire and forget
        _fetchLocationInBackground(user).catchError((e) {
          AppLogger.error('AuthService: Background location fetch failed: $e');
        });

        // Pre-load prayer times - fire and forget
        _preloadPrayerTimesInBackground().catchError((e) {
          AppLogger.error('AuthService: Background prayer time pre-load failed: $e');
        });
      }
    } catch (e) {
      AppLogger.error('AuthService: Error initializing teacher services: $e');
      // Don't block login if these fail
    }
  }

  // Fetch location in background without blocking login
  Future<void> _fetchLocationInBackground(User user) async {
    try {
      AppLogger.debug('AuthService: Fetching location for teacher...');

      // Add a delay to ensure the UI has settled and user has navigated
      await Future.delayed(const Duration(seconds: 2));

      // Only proceed if we haven't asked for location recently
      final shouldSkip =
          await LocationPreferenceService.shouldSkipLocationRequest();
      if (shouldSkip) {
        AppLogger.debug(
            'AuthService: Skipping location request based on user preferences');
        return;
      }

      // Request location permission and get current location with timeout
      final location = await LocationService.getCurrentLocation(interactive: false)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        AppLogger.debug('AuthService: Location request timed out');
        return null;
      });

      if (location != null) {
        AppLogger.debug('AuthService: Location obtained: ${location.address}');

        // Optionally store location in user profile for future use
        await _updateUserLocation(user, location);
      } else {
        AppLogger.error('AuthService: Could not get location');
      }
    } catch (e) {
      AppLogger.error('AuthService: Error fetching location: $e');
      // Silent fail - this is background initialization
    }
  }

  // Pre-load prayer times in background
  Future<void> _preloadPrayerTimesInBackground() async {
    try {
      AppLogger.error('AuthService: Pre-loading prayer times...');
      await PrayerTimeService.initializeInBackground();
      AppLogger.error('AuthService: Prayer times pre-loaded successfully');
    } catch (e) {
      AppLogger.error('AuthService: Error pre-loading prayer times: $e');
    }
  }

  // Update user location in Firestore
  Future<void> _updateUserLocation(User user, LocationData location) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'last_known_location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': location.address,
          'neighborhood': location.neighborhood,
          'updated_at': FieldValue.serverTimestamp(),
        },
      });

      AppLogger.error('AuthService: User location updated in Firestore');
    } catch (e) {
      AppLogger.error('AuthService: Error updating user location: $e');
    }
  }

  // Update last login time in Firestore
  Future<void> _updateLastLoginTime(User user) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');

      // Prefer updating the UID document if it exists (most reliable + avoids email-case issues).
      try {
        final uidDoc = await users.doc(user.uid).get();
        if (uidDoc.exists) {
          await uidDoc.reference.update({
            'last_login': FieldValue.serverTimestamp(),
          });
          AppLogger.debug('AuthService: Last login time updated for ${user.email}');
          return;
        }
      } catch (_) {
        // Ignore and fallback to legacy email lookup below.
      }

      // Legacy: lookup by email (some projects store user docs by email key).
      final email = user.email?.toLowerCase();
      if (email == null) return;

      // Prefer updating the email-id document if it exists (legacy schema).
      try {
        final emailDoc = await users.doc(email).get();
        if (emailDoc.exists) {
          await emailDoc.reference.update({
            'last_login': FieldValue.serverTimestamp(),
          });
          AppLogger.debug('AuthService: Last login time updated for ${user.email}');
          return;
        }
      } catch (_) {
        // Ignore and fallback to query-by-field below.
      }

      final QuerySnapshot userQuery =
          await users.where('e-mail', isEqualTo: email).limit(1).get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        await userDoc.reference.update({
          'last_login': FieldValue.serverTimestamp(),
        });
        AppLogger.debug('AuthService: Last login time updated for ${user.email}');
      } else {
        AppLogger.debug('AuthService: User document not found for ${user.email}');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Not critical for normal app usage; avoid spamming error logs for roles that can't update metadata.
        AppLogger.debug('AuthService: Skipping last login update (permission denied)');
        return;
      }
      AppLogger.error('AuthService: Error updating last login time: $e');
    } catch (e) {
      AppLogger.error('AuthService: Error updating last login time: $e');
    }
  }

  // Register with email and password
  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      return user;
    } catch (e) {
      AppLogger.error(e.toString());
      return null;
    }
  }

  // Send password reset email using custom branded template
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Use custom Cloud Function for branded email with better deliverability
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendCustomPasswordResetEmail');

      // Get user's display name from Firestore if available
      String displayName = '';
      try {
        final QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('e-mail', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data() as Map<String, dynamic>;
          final firstName = userData['first-name'] ?? '';
          final lastName = userData['last-name'] ?? '';
          displayName = '$firstName $lastName'.trim();
        }
      } catch (e) {
        AppLogger.error('AuthService: Could not fetch user display name: $e');
        // Continue without display name
      }

      await callable.call({
        'email': email,
        'displayName': displayName,
      });

      AppLogger.error('AuthService: Custom password reset email sent to $email');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'AuthService: Password reset function error: ${e.code} - ${e.message}');

      // Convert function errors to auth errors for consistent handling
      String errorCode;
      switch (e.code) {
        case 'not-found':
          errorCode = 'user-not-found';
          break;
        case 'invalid-argument':
          errorCode = 'invalid-email';
          break;
        default:
          errorCode = 'unknown-error';
      }

      throw FirebaseAuthException(
        code: errorCode,
        message: e.message ??
            'Unable to send password reset email. Please try again later.',
      );
    } catch (e) {
      AppLogger.error('AuthService: Unexpected error in password reset: $e');
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'An unexpected error occurred. Please try again later.',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Remove FCM token before signing out (mobile only)
      if (!kIsWeb) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await NotificationService().removeTokenFromFirestore(userId: currentUser.uid);
        }
      }
      
      // Clear persisted route on sign out
      await RoutePersistenceService.clearRoute();

      return await _auth.signOut();
    } catch (e) {
      AppLogger.error(e.toString());
      return;
    }
  }
}
