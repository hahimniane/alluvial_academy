import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  debugPrint('Message notification: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  /// Get the FCM token for this device
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Request permission for iOS
      await _requestPermission();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Configure foreground notification presentation
      await _configureForegroundNotificationPresentation();

      // Setup message handlers
      _setupMessageHandlers();

      // Setup token refresh listener
      _setupTokenRefreshListener();

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Request notification permissions (especially important for iOS)
  Future<void> _requestPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notification permission');
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  /// Initialize Flutter Local Notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'high_importance_channel', // Must match the ID in AndroidManifest.xml
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Get FCM token (with retry for iOS)
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // On iOS, token might be null initially - retry after a delay
      if (_fcmToken == null && Platform.isIOS) {
        debugPrint('⏳ iOS: Token null on first attempt, retrying in 3 seconds...');
        await Future.delayed(const Duration(seconds: 3));
        _fcmToken = await _firebaseMessaging.getToken();
        debugPrint('FCM Token after retry: $_fcmToken');
      }
      
      // Token will be saved on app launch via main.dart
      // No need to save here as it happens too early in the init process
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Configure how notifications are presented when app is in foreground
  Future<void> _configureForegroundNotificationPresentation() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state by tapping notification
    _checkInitialMessage();
  }

  /// Handle messages when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      // Show local notification when in foreground
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap (from background)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Message data: ${message.data}');

    // TODO: Navigate to appropriate screen based on message data
    _navigateBasedOnMessage(message);
  }

  /// Check if app was opened from terminated state via notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification: ${initialMessage.messageId}');
      _navigateBasedOnMessage(initialMessage);
    }
  }

  /// Handle notification tap from local notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    
    if (response.payload == null) return;
    
    try {
      final data = Map<String, dynamic>.from(
        // ignore: inference_failure_on_untyped_parameter
        (response.payload!.isNotEmpty ? 
          Map<String, dynamic>.from(response.payload as Map) : <String, dynamic>{})
      );
      
      _handleNotificationNavigation(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }
  
  /// Handle navigation based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    debugPrint('🔔 Handling notification navigation: $data');
    
    final type = data['type'] as String?;
    
    if (type == 'form_required') {
      // Store the navigation data for the app to handle
      // This will be picked up by the main app when it's ready
      _pendingNavigation = data;
      debugPrint('📋 Stored pending form navigation: ${data['shiftId']}');
    }
  }
  
  // Store pending navigation data
  Map<String, dynamic>? _pendingNavigation;
  
  /// Get and clear pending navigation data
  Map<String, dynamic>? getPendingNavigation() {
    final data = _pendingNavigation;
    _pendingNavigation = null;
    return data;
  }

  /// Setup listener for token refresh
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      _fcmToken = newToken;
      
      // Automatically update token if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('🔄 Auto-saving refreshed token for user: ${currentUser.uid}');
        await saveTokenToFirestore(userId: currentUser.uid);
        debugPrint('✅ Refreshed FCM token saved to Firestore');
      } else {
        debugPrint('⚠️ Token refreshed but no user logged in - will save on next login');
      }
    });
  }

  /// Navigate to appropriate screen based on message data
  void _navigateBasedOnMessage(RemoteMessage message) {
    final data = message.data;
    
    // Example: Navigate based on notification type
    if (data.containsKey('type')) {
      final type = data['type'];
      debugPrint('Navigating based on type: $type');
      
      // TODO: Implement navigation logic
      // Example:
      // switch (type) {
      //   case 'chat':
      //     // Navigate to chat screen
      //     break;
      //   case 'shift':
      //     // Navigate to shift screen
      //     break;
      //   case 'timesheet':
      //     // Navigate to timesheet screen
      //     break;
      // }
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Get the current platform name
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Save FCM token to Firestore with platform information
  Future<void> saveTokenToFirestore({String? userId}) async {
    try {
      AppLogger.debug('📱 saveTokenToFirestore called');
      
      var token = _fcmToken;
      
      // If token is null (common on iOS on first launch), try to get it now
      if (token == null) {
        AppLogger.debug('⚠️ Token is null, attempting to fetch now...');
        token = await _firebaseMessaging.getToken();
        _fcmToken = token;
        
        // On iOS, wait a bit and retry if still null
        if (token == null && Platform.isIOS) {
          AppLogger.debug('⏳ iOS: Token still null, waiting 3 seconds and retrying...');
          await Future.delayed(const Duration(seconds: 3));
          token = await _firebaseMessaging.getToken();
          _fcmToken = token;
        }
      }
      
      AppLogger.debug('📱 FCM Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
      
      if (token == null) {
        AppLogger.debug('❌ No FCM token available to save after retries');
        if (Platform.isIOS) {
          AppLogger.debug('❌ iOS: Make sure APNs is configured and device has network connectivity');
          AppLogger.info('❌ iOS: Token will be saved automatically when it becomes available via token refresh listener');
        }
        return;
      }

      // Get user ID - either from parameter or current auth user
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      AppLogger.debug('📱 User ID: $uid');
      
      if (uid == null) {
        AppLogger.debug('❌ No user ID available - user not logged in');
        return;
      }

      final platform = _getPlatformName();
      AppLogger.debug('📱 Platform: $platform');
      
      // Use Timestamp.now() for array elements (serverTimestamp doesn't work in arrays)
      final now = Timestamp.now();

      // Create token data object
      final tokenData = {
        'token': token,
        'platform': platform,
        'lastUpdated': now,
      };

      // Get reference to user document
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      AppLogger.debug('📱 Checking if user document exists...');
      
      final userDoc = await userRef.get();
      AppLogger.debug('📱 User document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        AppLogger.debug('📱 User document does not exist, creating with FCM token');
        // Create user document with token
        await userRef.set({
          'fcmTokens': [tokenData],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        AppLogger.info('✅ Created user document with FCM token');
      } else {
        // Get existing tokens
        final data = userDoc.data();
        final existingTokens = data?['fcmTokens'] as List<dynamic>? ?? [];
        AppLogger.debug('📱 Existing tokens count: ${existingTokens.length}');

        // Check if this exact token already exists for this platform
        final tokenExists = existingTokens.any((t) => 
          t is Map && 
          t['token'] == token && 
          t['platform'] == platform
        );
        AppLogger.debug('📱 Token already exists: $tokenExists');

        if (tokenExists) {
          // Update the timestamp for existing token
          final updatedTokens = existingTokens.map((t) {
            if (t is Map && t['token'] == token && t['platform'] == platform) {
              return {
                'token': token,
                'platform': platform,
                'lastUpdated': now,
              };
            }
            return t;
          }).toList();

          await userRef.update({
            'fcmTokens': updatedTokens,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.info('✅ Updated existing FCM token for $platform');
        } else {
          // Add new token to the array
          AppLogger.debug('📱 Adding new token to array...');
          await userRef.update({
            'fcmTokens': FieldValue.arrayUnion([tokenData]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          AppLogger.error('✅ Added new FCM token for $platform');
        }
      }

      AppLogger.error('✅ FCM Token saved successfully to Firestore for user $uid on $platform');
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error saving FCM token to Firestore: $e');
      AppLogger.error('❌ Stack trace: $stackTrace');
    }
  }

  /// Remove a specific token from Firestore (call this on logout)
  Future<void> removeTokenFromFirestore({String? userId}) async {
    try {
      final token = _fcmToken;
      if (token == null) return;

      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final existingTokens = data?['fcmTokens'] as List<dynamic>? ?? [];

        // Remove tokens matching this device's token
        final updatedTokens = existingTokens
            .where((t) => t is Map && t['token'] != token)
            .toList();

        await userRef.update({
          'fcmTokens': updatedTokens,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        debugPrint('Removed FCM token from Firestore');
      }
    } catch (e) {
      debugPrint('Error removing FCM token from Firestore: $e');
    }
  }

  /// Show a local notification manually
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

