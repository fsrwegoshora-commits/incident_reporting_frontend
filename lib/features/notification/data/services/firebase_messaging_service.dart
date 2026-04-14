import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:incident_reporting_frontend/features/notification/presentation/handlers/real_time_notification_handler.dart';
import 'package:incident_reporting_frontend/core/network/api_service.dart';
import 'package:go_router/go_router.dart';

import 'notifications_service.dart';

// Firebase Messaging is only supported on Android and iOS
bool get _isFirebaseSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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

    if (!_isFirebaseSupported) {
      print("ℹ️ Firebase Messaging skipped — not supported on ${Platform.operatingSystem}");
      return;
    }

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
        // ✅ NEW: Make sure user UID is saved
        final prefs = await SharedPreferences.getInstance();
        String? userUid = prefs.getString('user_uid');

        // If not saved, try to fetch from REST
        if (userUid == null) {
          print("⚠️  User UID not found, fetching from API...");
          try {
            final api = ApiService();
            final response = await api.getMe();
            final user = response['data'];

            if (user != null && user['uid'] != null) {
              userUid = user['uid'];
              await prefs.setString('user_uid', userUid!);
              print("✅ Saved user UID: $userUid");
            }
          } catch (e) {
            print("⚠️  Could not fetch user UID: $e");
          }
        }

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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // Create main channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);

    print("✅ Local notifications initialized");
  }


  static const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
    'main_channel',
    'Default Notifications',
    description: 'Uses system default sound',
    importance: Importance.max,
    enableVibration: true,
    enableLights: true,
    // No sound → system will choose user's notification tone
  );


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
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Default Notifications',
      channelDescription: 'Uses system default sound',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['screen'] ?? '/notifications',
    );
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

      String? userUid = prefs.getString('user_uid');

      print("🔍 Checking user UID...");
      print("   Current UID in SharedPreferences: ${userUid ?? 'NOT FOUND'}");

      // If not in preferences, try to get from REST
      if (userUid == null || userUid.isEmpty) {
        print("⚠️  User UID not in SharedPreferences, fetching from API...");

        try {
          final api = ApiService();
          final response = await api.getMe();

          if (response['status'] == 'Error') {
            print("❌ API error: ${response['message']}");
          } else {
            final user = response['data'];

            if (user != null && user['uid'] != null) {
              userUid = user['uid'];
              await prefs.setString('user_uid', userUid!);
              print("✅ Retrieved and saved user UID from API: $userUid");
            } else {
              print("❌ No user data in API response");
            }
          }
        } catch (e) {
          print("⚠️  Error fetching from API: $e");
        }
      }

      // If still null, skip registration
      if (userUid == null || userUid.isEmpty) {
        print("❌ Cannot register device token - User UID is null");
        print("   (User might not be logged in yet)");
        return;
      }

      print("✅ Found user UID: $userUid");

      final api = ApiService();

      print("📱 Registering device token for user: $userUid");

      final response = await api.registerDeviceToken(
        userUid: userUid,
        token: token,
        deviceType: 'FLUTTER',
        appVersion: '1.0.0',
      );

      if (response['status'] == 'Error') {
        print("❌ Error registering device token: ${response['message']}");
      } else {
        final data = response['data'];
        print("📡 Response status: ${response['status']}");
        print("📡 Response message: ${response['message']}");

        if (data != null) {
          await prefs.setString('device_token', token);
          print("✅ Device token registered successfully!");
          print("   Device Type: ${data['deviceType']}");
          print("   Active: ${data['isActive']}");
        } else {
          print("⚠️  Registration returned no data");
          print("   Message: ${response['message']}");
        }
      }
    } catch (e) {
      print("❌ Error registering device token: $e");
      e.toString().contains('SocketException') ?
      print("   (Network error - will retry on next token refresh)") : null;
    }
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  Future<String?> getToken() async {
    if (!_isFirebaseSupported) return null;
    return await _firebaseMessaging.getToken();
  }

  Future<void> removeDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('device_token');

      if (token == null) return;

      final api = ApiService();
      await api.removeDeviceToken(token);
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