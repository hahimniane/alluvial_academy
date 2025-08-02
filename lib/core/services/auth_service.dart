import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';
import 'location_preference_service.dart';
import 'prayer_time_service.dart';
import 'user_role_service.dart';

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

        // Initialize location and prayer times for teachers (non-blocking)
        _initializeTeacherServices(user).catchError((e) {
          print('AuthService: Background teacher initialization failed: $e');
        });
      }

      return user;
    } on FirebaseAuthException {
      // Re-throw FirebaseAuthException to preserve error codes
      rethrow;
    } catch (e) {
      print('AuthService error: $e');
      // Throw a generic FirebaseAuthException for other errors
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'An unexpected error occurred. Please try again later.',
      );
    }
  }

  // Initialize services for teachers after login
  Future<void> _initializeTeacherServices(User user) async {
    try {
      // Get user role
      final role = await UserRoleService.getCurrentUserRole();

      if (role?.toLowerCase() == 'teacher') {
        print('AuthService: Initializing services for teacher ${user.uid}');

        // Fetch location in background - completely fire and forget
        _fetchLocationInBackground(user).catchError((e) {
          print('AuthService: Background location fetch failed: $e');
        });

        // Pre-load prayer times - fire and forget
        _preloadPrayerTimesInBackground().catchError((e) {
          print('AuthService: Background prayer time pre-load failed: $e');
        });
      }
    } catch (e) {
      print('AuthService: Error initializing teacher services: $e');
      // Don't block login if these fail
    }
  }

  // Fetch location in background without blocking login
  Future<void> _fetchLocationInBackground(User user) async {
    try {
      print('AuthService: Fetching location for teacher...');

      // Add a delay to ensure the UI has settled and user has navigated
      await Future.delayed(const Duration(seconds: 2));

      // Only proceed if we haven't asked for location recently
      final shouldSkip =
          await LocationPreferenceService.shouldSkipLocationRequest();
      if (shouldSkip) {
        print(
            'AuthService: Skipping location request based on user preferences');
        return;
      }

      // Request location permission and get current location with timeout
      final location = await LocationService.getCurrentLocation()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('AuthService: Location request timed out');
        return null;
      });

      if (location != null) {
        print('AuthService: Location obtained: ${location.address}');

        // Optionally store location in user profile for future use
        await _updateUserLocation(user, location);
      } else {
        print('AuthService: Could not get location');
      }
    } catch (e) {
      print('AuthService: Error fetching location: $e');
      // Silent fail - this is background initialization
    }
  }

  // Pre-load prayer times in background
  Future<void> _preloadPrayerTimesInBackground() async {
    try {
      print('AuthService: Pre-loading prayer times...');
      await PrayerTimeService.initializeInBackground();
      print('AuthService: Prayer times pre-loaded successfully');
    } catch (e) {
      print('AuthService: Error pre-loading prayer times: $e');
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

      print('AuthService: User location updated in Firestore');
    } catch (e) {
      print('AuthService: Error updating user location: $e');
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
      print(e.toString());
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return;
    }
  }
}
