import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/location_service.dart';
import 'package:alluwalacademyadmin/features/settings/services/location_preference_service.dart';
import 'prayer_time_service.dart';
import 'user_role_service.dart';
import 'timezone_service.dart';
import 'notification_service.dart';
import 'package:alluwalacademyadmin/features/dashboard/services/route_persistence_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Shared post-login logic
  Future<void> handleSuccessfulLogin(User user) async {
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
    var userData = await UserRoleService.getCurrentUserData();
    if (userData == null) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        try {
          AppLogger.info('AuthService: New phone user ${user.uid} — auto-provisioning as circle_member');
          await _provisionCircleMemberUser(user);
          UserRoleService.clearCache();
          userData = await UserRoleService.getCurrentUserData();
        } catch (e) {
          AppLogger.error('AuthService: Failed to provision circle_member for ${user.uid}: $e');
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-registered',
            message:
                'Failed to create your account. Please try again or contact support.',
          );
        }
      }

      if (userData == null) {
        AppLogger.debug('AuthService: User authenticated but no Firestore document found for ${user.uid}');
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-not-registered',
          message:
              'No account found with your credentials. Please contact an administrator to create your account.',
        );
      }
    }

    // Check if the user is active before proceeding
    final isActive = await UserRoleService.isUserActive(user.email);
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

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await handleSuccessfulLogin(user);
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

        try {
          await handleSuccessfulLogin(user);
          AppLogger.info(
              'AuthService: Google sign-in succeeded for ${user.email}');
        } catch (e) {
          await googleSignIn.signOut();
          rethrow;
        }
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
          AppLogger.debug('AuthService: Last login time updated for uid ${user.uid}');
          return;
        }
      } catch (_) {
        // Ignore and fallback
      }

      // Legacy: lookup by email
      final email = user.email?.toLowerCase();
      if (email != null && email.isNotEmpty) {
        try {
          final emailDoc = await users.doc(email).get();
          if (emailDoc.exists) {
            await emailDoc.reference.update({
              'last_login': FieldValue.serverTimestamp(),
            });
            AppLogger.debug('AuthService: Last login time updated for ${user.email}');
            return;
          }
        } catch (_) {}

        QuerySnapshot userQuery = await users.where('e-mail', isEqualTo: email).limit(1).get();
        if (userQuery.docs.isEmpty) {
          userQuery = await users.where('email', isEqualTo: email).limit(1).get();
        }

        // Check aliases if using a generated student/kiosk auth email
        if (userQuery.docs.isEmpty && email.endsWith('@alluwaleducationhub.org')) {
          final alias = email.split('@')[0];
          userQuery = await users.where('student_code', isEqualTo: alias).limit(1).get();
          if (userQuery.docs.isEmpty) {
            userQuery = await users.where('studentCode', isEqualTo: alias).limit(1).get();
          }
          if (userQuery.docs.isEmpty) {
            userQuery = await users.where('kiosk_code', isEqualTo: alias).limit(1).get();
          }
        }

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          await userDoc.reference.update({
            'last_login': FieldValue.serverTimestamp(),
          });
          AppLogger.debug('AuthService: Last login time updated for ${user.email}');
          return;
        }
      }

      // Fallback: lookup by phone number
      final phoneNumber = user.phoneNumber;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final phoneQuery = await users.where('phone_number', isEqualTo: phoneNumber).limit(1).get();
        if (phoneQuery.docs.isNotEmpty) {
          await phoneQuery.docs.first.reference.update({
            'last_login': FieldValue.serverTimestamp(),
          });
          AppLogger.debug('AuthService: Last login time updated for phone $phoneNumber');
          return;
        }
      }

      AppLogger.debug('AuthService: User document not found for last login update (uid: ${user.uid})');
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

  Future<void> _provisionCircleMemberUser(User user) async {
    final phone = user.phoneNumber!;
    final firestore = FirebaseFirestore.instance;

    // Step 1: Create the user document first (critical — must succeed)
    final userRef = firestore.collection('users').doc(user.uid);
    await userRef.set({
      'user_type': 'circle_member',
      'phone_number': phone,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'first_name': '',
      'last_name': '',
      'name': phone,
    });
    AppLogger.info('AuthService: Created circle_member doc for $phone (uid=${user.uid})');

    // Step 2: Link pending invites and members (non-blocking — failures here
    // should not prevent login since the user doc already exists)
    try {
      final inviteQuery = await firestore
          .collection('circle_invites')
          .where('contact_info', isEqualTo: phone)
          .where('status', isEqualTo: 'pending')
          .get();

      final memberQuery = await firestore
          .collection('circle_members')
          .where('contact_info', isEqualTo: phone)
          .where('status', isEqualTo: 'invited')
          .get();

      if (inviteQuery.docs.isNotEmpty || memberQuery.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in inviteQuery.docs) {
          batch.update(doc.reference, {'existing_user_id': user.uid});
        }
        for (final doc in memberQuery.docs) {
          batch.update(doc.reference, {'user_id': user.uid});
        }
        await batch.commit();
        AppLogger.info('AuthService: Linked ${inviteQuery.docs.length} invite(s) and ${memberQuery.docs.length} member record(s) for $phone');
      }
    } catch (e) {
      AppLogger.error('AuthService: Failed to link invites/members for $phone (non-fatal): $e');
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
