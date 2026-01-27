import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/features/chat/screens/chat_screen.dart';
import 'package:alluwalacademyadmin/features/chat/models/chat_user.dart';

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
  
  /// Global navigator key for navigation from notifications
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Track the currently open chat to suppress notifications for it
  static String? _currentOpenChatId;
  
  /// Set the currently open chat ID (call when entering a chat screen)
  static void setCurrentOpenChat(String? chatId) {
    _currentOpenChatId = chatId;
    debugPrint('NotificationService: Current open chat set to: $chatId');
  }
  
  /// Get the currently open chat ID
  static String? get currentOpenChatId => _currentOpenChatId;

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

  /// Create notification channels for Android
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;

    // High importance channel for general notifications
    const highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel', // Must match the ID in AndroidManifest.xml
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await androidPlugin.createNotificationChannel(highImportanceChannel);

    // Chat messages channel
    const chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages.',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await androidPlugin.createNotificationChannel(chatChannel);

    // Class reminders channel
    const classChannel = AndroidNotificationChannel(
      'class_reminders',
      'Class Reminders',
      description: 'Reminders for upcoming classes.',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await androidPlugin.createNotificationChannel(classChannel);
  }

  /// Get FCM token (with retry for iOS)
  Future<void> _getFCMToken() async {
    try {
      // On iOS, we need to wait for APNs token first
      if (Platform.isIOS) {
        debugPrint('📱 iOS: Waiting for APNs token...');
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        
        // If APNs token not ready, wait and retry
        int retryCount = 0;
        while (apnsToken == null && retryCount < 5) {
          retryCount++;
          debugPrint('⏳ iOS: APNs token not ready, retry $retryCount/5 in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }
        
        if (apnsToken != null) {
          debugPrint('✅ iOS: APNs token received');
        } else {
          debugPrint('⚠️ iOS: APNs token still not available after retries');
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // On iOS, token might be null initially - retry after a delay
      if (_fcmToken == null && Platform.isIOS) {
        debugPrint('⏳ iOS: FCM Token null on first attempt, retrying in 3 seconds...');
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
    final data = message.data;
    
    // Check if this is a chat message notification
    final notificationType = data['type'] as String?;
    final chatId = data['chatId'] as String?;
    
    // Suppress notification if user is currently viewing this chat
    if (notificationType == 'chat_message' && chatId != null) {
      if (_currentOpenChatId == chatId) {
        debugPrint('Suppressing notification - user is viewing this chat');
        return;
      }
    }

    if (notification != null) {
      // Determine which channel to use based on notification type
      String channelId = 'high_importance_channel';
      String channelName = 'High Importance Notifications';
      String channelDescription = 'This channel is used for important notifications.';
      
      if (notificationType == 'chat_message') {
        channelId = 'chat_messages';
        channelName = 'Chat Messages';
        channelDescription = 'Notifications for new chat messages';
      }
      
      // Show local notification when in foreground
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data), // Encode as JSON for proper parsing
      );
    }
  }

  /// Handle notification tap (from background)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    debugPrint('Message data: ${message.data}');

    // Navigate to chat if it's a chat message notification
    _navigateToChatIfNeeded(message.data);
  }

  /// Check if app was opened from terminated state via notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification: ${initialMessage.messageId}');
      // Store for later navigation (app may not be fully initialized yet)
      _pendingNavigation = initialMessage.data;
      debugPrint('📱 Stored initial message for navigation: ${initialMessage.data}');
    }
  }
  
  /// Process any pending navigation (call after app is fully initialized)
  Future<void> processPendingNavigation() async {
    final data = _pendingNavigation;
    if (data != null) {
      debugPrint('📱 Processing pending navigation: $data');
      _pendingNavigation = null;
      await _navigateToChatIfNeeded(data);
    }
  }

  /// Handle notification tap from local notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    
    if (response.payload == null || response.payload!.isEmpty) return;
    
    try {
      // Parse the JSON payload
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      debugPrint('📱 Parsed notification data: $data');
      
      _navigateToChatIfNeeded(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }
  
  /// Navigate to chat screen if notification is a chat message
  Future<void> _navigateToChatIfNeeded(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    
    if (type == 'chat_message') {
      final senderId = data['senderId'] as String?;
      final senderName = data['senderName'] as String?;
      final senderProfilePicture = data['senderProfilePicture'] as String?;
      final chatType = data['chatType'] as String?;
      
      if (senderId == null || senderName == null) {
        debugPrint('❌ Missing sender info in notification');
        return;
      }
      
      debugPrint('💬 Navigating to chat: $senderName ($senderId)');
      debugPrint('📷 Profile picture: ${senderProfilePicture ?? "none"}');
      
      // Create ChatUser from notification data
      final chatUser = ChatUser(
        id: senderId,
        name: senderName,
        email: '', // Email not available from notification, will be loaded in chat screen
        profilePicture: senderProfilePicture?.isNotEmpty == true ? senderProfilePicture : null,
        isGroup: chatType == 'group',
      );
      
      // Navigate to chat screen
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatUser: chatUser),
          ),
        );
      } else {
        debugPrint('⚠️ Navigator not available, storing pending navigation');
        _pendingNavigation = data;
      }
    } else {
      // Store for other types of navigation
      _handleNotificationNavigation(data);
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
    } else if (type == 'chat_message') {
      // Store chat navigation data
      _pendingNavigation = {
        'type': 'chat_message',
        'chatId': data['chatId'],
        'senderId': data['senderId'],
        'senderName': data['senderName'],
        'chatType': data['chatType'],
      };
      debugPrint('💬 Stored pending chat navigation: ${data['chatId']}');
    } else if (type == 'no_show_report') {
      // Store no-show report navigation data
      _pendingNavigation = {
        'type': 'no_show_report',
        'shiftId': data['shiftId'],
      };
      debugPrint('⚠️ Stored pending no-show navigation: ${data['shiftId']}');
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
    
    // Navigate based on notification type
    if (data.containsKey('type')) {
      final type = data['type'];
      debugPrint('Navigating based on type: $type');
      
      // Store navigation data for the app to handle
      switch (type) {
        case 'chat_message':
          _pendingNavigation = {
            'type': 'chat_message',
            'chatId': data['chatId'],
            'senderId': data['senderId'],
            'senderName': data['senderName'],
            'chatType': data['chatType'],
          };
          debugPrint('💬 Stored chat navigation from message');
          break;
        case 'no_show_report':
          _pendingNavigation = {
            'type': 'no_show_report',
            'shiftId': data['shiftId'],
          };
          break;
        case 'form_required':
          _pendingNavigation = {
            'type': 'form_required',
            'shiftId': data['shiftId'],
          };
          break;
        default:
          debugPrint('Unknown notification type: $type');
          break;
      }
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
        
        // On iOS, we need to wait for APNs token first
        if (Platform.isIOS) {
          AppLogger.debug('📱 iOS: Checking APNs token...');
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          
          // If APNs token not ready, wait and retry
          int retryCount = 0;
          while (apnsToken == null && retryCount < 5) {
            retryCount++;
            AppLogger.debug('⏳ iOS: APNs token not ready, retry $retryCount/5 in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
            apnsToken = await _firebaseMessaging.getAPNSToken();
          }
          
          if (apnsToken != null) {
            AppLogger.debug('✅ iOS: APNs token received, now getting FCM token');
          } else {
            AppLogger.debug('⚠️ iOS: APNs token still not available - will rely on token refresh listener');
            return; // Exit and let the token refresh listener handle this
          }
        }
        
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

        // Remove ALL old tokens for this platform and add the new one
        // This ensures only ONE token per platform (prevents duplicates)
        final filteredTokens = existingTokens
            .where((t) => t is Map && t['platform'] != platform)
            .toList();
        
        // Add the current token
        filteredTokens.add(tokenData);
        
        AppLogger.debug('📱 Updating tokens: removed old $platform tokens, new count: ${filteredTokens.length}');

        await userRef.update({
          'fcmTokens': filteredTokens,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        AppLogger.info('✅ Updated FCM token for $platform (replaced old token)');
      }

      AppLogger.info('✅ FCM Token saved successfully to Firestore for user $uid on $platform');
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

