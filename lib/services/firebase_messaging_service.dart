import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/real_time_notification_handler.dart';
import '../services/graphql_service.dart';
import 'package:go_router/go_router.dart';

import 'notifications_service.dart';

// ============================================================================
// FIREBASE MESSAGING SERVICE - WITH REAL-TIME HANDLING
// ============================================================================

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();

  factory FirebaseMessagingService() {
    return _instance;
  }

  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Real-time notification handler
  RealTimeNotificationHandler? _realtimeHandler;

  // Callback for when app is in foreground
  Function(RemoteMessage)? onMessageCallback;

  // Callback for when notification is tapped
  Function(String?, String?)? onNotificationTapped;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  Future<void> initialize(BuildContext context, {required NotificationsService notificationsService}) async {
    print("🔔 Initializing Firebase Messaging Service");

    try {
      // Initialize real-time handler
      _realtimeHandler = RealTimeNotificationHandler(notificationsService: notificationsService);

      // Request notification permissions (iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print("📱 Notification permission status: ${settings.authorizationStatus}");

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        print("✅ FCM Token: $token");

        // Register token with backend
        if (token != null) {
          await _registerDeviceToken(token);
        }

        // Initialize local notifications
        await _initializeLocalNotifications();

        // Handle foreground messages with real-time processing
        _setupForegroundMessageHandler();

        // Handle background messages (when app is terminated)
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Handle notification taps
        _setupNotificationTapHandler(context);

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print("🔄 FCM Token Refreshed: $newToken");
          _registerDeviceToken(newToken);
        });

        print("✅ Firebase Messaging initialized successfully");
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print("⚠️ Provisional notification permission granted");
      } else {
        print("❌ Notification permissions denied");
      }
    } catch (e) {
      print("❌ Error initializing Firebase Messaging: $e");
    }
  }

  // ============================================================================
  // LOCAL NOTIFICATIONS SETUP
  // ============================================================================

  Future<void> _initializeLocalNotifications() async {
    try {
      // Android setup
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS setup
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print("📲 Local notification tapped: ${response.payload}");
          _handleNotificationTap(response.payload);
        },
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        sound: RawResourceAndroidNotificationSound('notification'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print("✅ Local notifications initialized");
    } catch (e) {
      print("❌ Error initializing local notifications: $e");
    }
  }

  // ============================================================================
  // FOREGROUND MESSAGE HANDLER - WITH REAL-TIME PROCESSING
  // ============================================================================

  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📬 Foreground message received: ${message.notification?.title}");
      print("Message data: ${message.data}");

      // Process with real-time handler
      if (_realtimeHandler != null) {
        _realtimeHandler!.handleRemoteMessage(message);
      }

      // Show local notification in foreground
      _showLocalNotification(message);

      // Call callback if set
      if (onMessageCallback != null) {
        onMessageCallback!(message);
      }
    });
  }

  // ============================================================================
  // BACKGROUND MESSAGE HANDLER
  // ============================================================================

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("🔄 Background message received: ${message.notification?.title}");
    print("Data: ${message.data}");

    // Note: In background, you can't update UI directly
    // Just log or save data for later processing
    // When app comes to foreground, real-time handler will process it
  }

  // ============================================================================
  // LOCAL NOTIFICATION DISPLAY
  // ============================================================================

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;

      if (notification == null) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'High priority notifications for incidents',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        enableLights: true,
        color: Color.fromARGB(255, 46, 91, 255),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: message.data['screen'] ?? '/notifications',
      );
    } catch (e) {
      print("❌ Error showing local notification: $e");
    }
  }

  // ============================================================================
  // NOTIFICATION TAP HANDLER
  // ============================================================================

  void _setupNotificationTapHandler(BuildContext context) {
    // When notification is tapped from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🎯 Notification tapped (background): ${message.notification?.title}");
      _handleNotificationNavigation(message, context);
    });
  }

  void _handleNotificationTap(String? payload) {
    print("🎯 Local notification tapped: $payload");
    if (onNotificationTapped != null) {
      onNotificationTapped!(payload, null);
    }
  }

  void _handleNotificationNavigation(RemoteMessage message, BuildContext context) {
    final data = message.data;
    final screen = data['screen'] ?? '/notifications';
    final relatedEntityUid = data['relatedEntityUid'];
    final relatedEntityType = data['relatedEntityType'];

    print("📍 Navigating to: $screen with entity: $relatedEntityUid");

    // Navigate based on screen
    if (context.mounted) {
      switch (screen) {
        case '/incidentDetails':
          if (relatedEntityUid != null && relatedEntityUid.isNotEmpty) {
            context.push('/incident-details/$relatedEntityUid');
          }
          break;
        case '/chat':
          if (relatedEntityUid != null && relatedEntityUid.isNotEmpty) {
            context.push('/incident-chat/$relatedEntityUid');
          }
          break;
        case '/shifts':
          context.push('/officer-shifts');
          break;
        case '/notifications':
        default:
          context.push('/notifications');
          break;
      }
    }

    if (onNotificationTapped != null) {
      onNotificationTapped!(screen, relatedEntityUid);
    }
  }

  // ============================================================================
  // DEVICE TOKEN REGISTRATION
  // ============================================================================

  Future<void> _registerDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userUid = prefs.getString('user_uid');

      if (userUid == null) {
        print("⚠️ User UID not found in SharedPreferences");
        return;
      }

      final gql = GraphQLService();

      const String mutation = '''
        mutation registerDeviceToken(
          \$userUid: String!
          \$token: String!
          \$deviceType: String!
          \$appVersion: String!
        ) {
          registerDeviceToken(
            userUid: \$userUid
            token: \$token
            deviceType: \$deviceType
            appVersion: \$appVersion
          ) {
            success
            message
            data {
              uid
              token
              deviceType
              isActive
              lastUsedAt
            }
          }
        }
      ''';

      final response = await gql.sendAuthenticatedQuery(mutation, {
        'userUid': userUid,
        'token': token,
        'deviceType': 'FLUTTER',
        'appVersion': '1.0.0',
      });

      if (response.containsKey('errors')) {
        print("❌ Error registering device token: ${response['errors']}");
      } else {
        final data = response['data']?['registerDeviceToken']?['data'];
        if (data != null) {
          await prefs.setString('device_token', token);
          print("✅ Device token registered successfully");
        }
      }
    } catch (e) {
      print("❌ Error registering device token: $e");
    }
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> removeDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('device_token');

      if (token == null) return;

      final gql = GraphQLService();

      const String mutation = '''
        mutation removeDeviceToken(\$token: String!) {
          removeDeviceToken(token: \$token) {
            success
            message
          }
        }
      ''';

      await gql.sendAuthenticatedQuery(mutation, {'token': token});
      await prefs.remove('device_token');
      print("✅ Device token removed");
    } catch (e) {
      print("❌ Error removing device token: $e");
    }
  }

  void dispose() {
    // Cleanup if needed
  }
}