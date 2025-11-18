import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:convert';
import 'notifications_service.dart';

// ============================================================================
// WEBSOCKET NOTIFICATIONS SERVICE - REAL-TIME (IMPROVED VERSION)
// ============================================================================

class WebSocketNotificationsService {
  static final WebSocketNotificationsService _instance =
  WebSocketNotificationsService._internal();

  factory WebSocketNotificationsService() => _instance;
  WebSocketNotificationsService._internal();

  late StompClient _stompClient;
  bool _isConnected = false;
  String? _userId;
  String? _token; // STORE TOKEN FOR RECONNECTION
  NotificationsService? _notificationsService;

  // Callback when new notification arrives
  Function(NotificationModel)? onNotificationReceived;

  // Callback when connection status changes
  Function(bool)? onConnectionStatusChanged;

  // ============================================================================
  // CONNECT TO WEBSOCKET (IMPROVED)
  // ============================================================================

  Future<void> connect(String userId, String token,
      {required NotificationsService notificationsService}) async {
    try {
      _userId = userId;
      _token = token; // STORE TOKEN FOR RECONNECTION
      _notificationsService = notificationsService;

      print("🔌 Connecting to WebSocket for user: $userId");

      // Close existing connection if any
      if (_stompClient.connected) {
        _stompClient.deactivate();
        await Future.delayed(Duration(milliseconds: 500));
      }

      _stompClient = StompClient(
        config: StompConfig(
          url: 'ws://10.29.242.163:8080/ws-notifications',
          onConnect: _onConnect,
          onDisconnect: _onDisconnect,
          onStompError: _onStompError,

          // ADDED HEADERS FOR BETTER AUTHENTICATION
          stompConnectHeaders: {
            'Authorization': 'Bearer $token',
            'user-id': userId,
            'client-type': 'FLUTTER',
          },

          webSocketConnectHeaders: {
            'Authorization': 'Bearer $token',
          },

          // 🔥 FIX: USE Duration OBJECTS INSTEAD OF INTEGERS
          heartbeatOutgoing: Duration(seconds: 15), // 15 seconds
          heartbeatIncoming: Duration(seconds: 15), // 15 seconds

          // ADDED CONNECTION TIMEOUT
          connectionTimeout: Duration(seconds: 10),

          // IMPROVED ERROR HANDLING
          onWebSocketError: (error) {
            print("❌ WebSocket Error: $error");
            _scheduleReconnect();
          },

          // ADDED: Callback before connection attempt
          beforeConnect: () async {
            print("🔄 Attempting WebSocket connection...");
            await Future.delayed(Duration(milliseconds: 100));
          },

          // ADDED: Auto-reconnect
          reconnectDelay: Duration(seconds: 5),

          // ADDED: STOMP debug messages
          onDebugMessage: (message) {
            print("🔧 STOMP Debug: $message");
          },
        ),
      );

      _stompClient.activate();

      // SET CONNECTION TIMEOUT CHECK
      _setupConnectionTimeout();

    } catch (e) {
      print("❌ WebSocket connection error: $e");
      _isConnected = false;
      onConnectionStatusChanged?.call(false);
      _scheduleReconnect();
    }
  }

  // ============================================================================
  // ON CONNECT (IMPROVED)
  // ============================================================================

  void _onConnect(StompFrame connectFrame) {
    print("✅ WebSocket Connected Successfully!");
    print("🔧 Connection frame: ${connectFrame.headers}");

    _isConnected = true;
    onConnectionStatusChanged?.call(true);

    // Subscribe to user notifications
    _subscribeToNotifications();

    // SEND TEST MESSAGE TO VERIFY CONNECTION
    _sendConnectionTestMessage();
  }

  // ============================================================================
  // SUBSCRIBE TO NOTIFICATIONS (IMPROVED)
  // ============================================================================

  void _subscribeToNotifications() {
    if (!_isConnected || _userId == null) {
      print("⚠️ Cannot subscribe - not connected or userId missing");
      return;
    }

    try {
      // Subscribe to user-specific queue (MOST IMPORTANT)
      _stompClient.subscribe(
        destination: '/user/$_userId/queue/notifications',
        callback: _onNotificationMessage,
        headers: {'id': 'user-notifications-$_userId'}, // ADDED HEADER FOR TRACKING
      );

      print("✅ Subscribed to user notifications: /user/$_userId/queue/notifications");

      // ALSO subscribe to user-specific topic (ALTERNATIVE PATH)
      _stompClient.subscribe(
        destination: '/topic/user/$_userId/notifications',
        callback: _onNotificationMessage,
        headers: {'id': 'user-topic-$_userId'},
      );

      print("✅ Subscribed to user topic: /topic/user/$_userId/notifications");

      // Subscribe to broadcast notifications (OPTIONAL)
      _stompClient.subscribe(
        destination: '/topic/notifications',
        callback: _onBroadcastNotification,
        headers: {'id': 'broadcast-notifications'},
      );

      print("✅ Subscribed to broadcast notifications");

    } catch (e) {
      print("❌ Subscription error: $e");
    }
  }

  // ============================================================================
  // ON NOTIFICATION MESSAGE (IMPROVED)
  // ============================================================================

  void _onNotificationMessage(StompFrame frame) {
    try {
      if (frame.body == null) {
        print("⚠️ Empty notification message received");
        return;
      }

      print("📬 RAW WebSocket notification: ${frame.body}");
      print("🔧 Headers: ${frame.headers}");

      // Parse JSON with better error handling
      final dynamic jsonData;
      try {
        jsonData = jsonDecode(frame.body!);
      } catch (e) {
        print("❌ JSON parsing error: $e");
        return;
      }

      // Handle different JSON formats
      NotificationModel notification;
      if (jsonData is Map<String, dynamic>) {
        notification = NotificationModel.fromJson(jsonData);
      } else {
        print("❌ Unexpected notification format: ${jsonData.runtimeType}");
        return;
      }

      print("✅ Parsed notification: ${notification.title} (Type: ${notification.type})");

      // Update local notifications list
      if (_notificationsService != null) {
        _notificationsService!.addNotification(notification);
        print("🔔 Notification added to service: ${notification.title}");
      } else {
        print("⚠️ NotificationsService not available");
      }

      // Call callback
      onNotificationReceived?.call(notification);

      // SHOW DEBUG SNACKBAR (Optional - remove in production)
      _showDebugSnackbar(notification);

    } catch (e) {
      print("❌ Error processing notification: $e");
      print("❌ Stack trace: ${e.toString()}");
    }
  }

  // ============================================================================
  // ON BROADCAST NOTIFICATION (IMPROVED)
  // ============================================================================

  void _onBroadcastNotification(StompFrame frame) {
    try {
      if (frame.body == null) {
        print("⚠️ Empty broadcast message");
        return;
      }

      print("📢 Broadcast notification: ${frame.body}");

      final jsonData = jsonDecode(frame.body!);
      final notification = NotificationModel.fromJson(jsonData);

      if (_notificationsService != null) {
        _notificationsService!.addNotification(notification);
        print("🔔 Broadcast notification added: ${notification.title}");
      }

      onNotificationReceived?.call(notification);

    } catch (e) {
      print("❌ Error processing broadcast notification: $e");
    }
  }

  // ============================================================================
  // ON DISCONNECT (IMPROVED WITH RECONNECTION)
  // ============================================================================

  void _onDisconnect(StompFrame frame) {
    print("⚠️ WebSocket Disconnected");
    print("🔧 Disconnect frame: ${frame.body}");

    _isConnected = false;
    onConnectionStatusChanged?.call(false);

    // Auto-reconnect after delay
    _scheduleReconnect();
  }

  // ============================================================================
  // ON STOMP ERROR (IMPROVED)
  // ============================================================================

  void _onStompError(StompFrame frame) {
    print("❌ STOMP Error: ${frame.body}");
    print("🔧 Error headers: ${frame.headers}");

    // Try to reconnect on error
    _scheduleReconnect();
  }

  // ============================================================================
  // RECONNECTION LOGIC (NEW)
  // ============================================================================

  void _scheduleReconnect() {
    print("🔄 Scheduling reconnection in 5 seconds...");

    Future.delayed(Duration(seconds: 5), () {
      if (_userId != null && _token != null && _notificationsService != null) {
        print("🔄 Attempting to reconnect WebSocket...");
        connect(_userId!, _token!, notificationsService: _notificationsService!);
      } else {
        print("❌ Cannot reconnect - missing user ID, token, or service");
      }
    });
  }

  // ============================================================================
  // CONNECTION TIMEOUT (NEW)
  // ============================================================================

  void _setupConnectionTimeout() {
    Future.delayed(Duration(seconds: 15), () {
      if (!_isConnected) {
        print("⏰ WebSocket connection timeout - server not responding");
        _scheduleReconnect();
      }
    });
  }

  // ============================================================================
  // TEST MESSAGE (NEW)
  // ============================================================================

  void _sendConnectionTestMessage() {
    if (!_isConnected) return;

    try {
      _stompClient.send(
        destination: '/app/connection-test',
        body: json.encode({
          'message': 'Flutter client connected',
          'userId': _userId,
          'clientType': 'FLUTTER',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {
          'user-id': _userId!,
          'content-type': 'application/json',
        },
      );
      print("✅ Connection test message sent");
    } catch (e) {
      print("❌ Error sending test message: $e");
    }
  }
// ============================================================================
// ADD THIS FUNCTION TO YOUR WebSocketNotificationsService CLASS
// ============================================================================

  void sendTestMessage() {
    if (!_isConnected) {
      print("❌ Cannot send test - WebSocket not connected");
      return;
    }

    try {
      _stompClient.send(
        destination: '/app/test',
        body: json.encode({
          'message': 'Test from Flutter',
          'userId': _userId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      print("✅ Test message sent to WebSocket");
    } catch (e) {
      print("❌ Error sending test message: $e");
    }
  }
  // ============================================================================
  // SEND TEST NOTIFICATION (NEW - FOR DEBUGGING)
  // ============================================================================

  void sendTestNotification() {
    if (!_isConnected) {
      print("❌ Cannot send test - WebSocket not connected");
      return;
    }

    try {
      _stompClient.send(
        destination: '/app/test-notification',
        body: json.encode({
          'userId': _userId,
          'title': 'Test Notification',
          'message': 'This is a test from Flutter',
          'type': 'TEST',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      print("✅ Test notification request sent");
    } catch (e) {
      print("❌ Error sending test notification: $e");
    }
  }

  // ============================================================================
  // GET CONNECTION STATUS (NEW)
  // ============================================================================

  Map<String, dynamic> getConnectionStatus() {
    return {
      'connected': _isConnected,
      'userId': _userId,
      'stompConnected': _stompClient.connected,
    };
  }

  // ============================================================================
  // DISCONNECT (IMPROVED)
  // ============================================================================

  void disconnect() {
    try {
      if (_stompClient.connected) {
        _stompClient.deactivate();
        print("✅ WebSocket manually disconnected");
      } else {
        print("ℹ️ WebSocket already disconnected");
      }
      _isConnected = false;
      onConnectionStatusChanged?.call(false);
    } catch (e) {
      print("❌ Error disconnecting WebSocket: $e");
    }
  }

  // ============================================================================
  // DEBUG SNACKBAR (NEW - REMOVE IN PRODUCTION)
  // ============================================================================

  void _showDebugSnackbar(NotificationModel notification) {
    // This is for debugging - shows a snackbar when notification arrives
    // Remove this in production or make it configurable
     try {
    //   final context = _notificationsService?.context;
    //   if (context != null) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text('🔔 ${notification.title}'),
    //         duration: Duration(seconds: 3),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //   }
    print("🔔 DEBUG: Would show snackbar for: ${notification.title}");
    } catch (e) {
      // Ignore errors in snackbar (context might not be available)
    }
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  bool get isConnected => _isConnected;
  String? get userId => _userId;
  bool get stompConnected => _stompClient.connected;
}