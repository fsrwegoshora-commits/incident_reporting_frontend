import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:convert';
import '../../features/notification/data/services/notifications_service.dart';
import '../config/config_service.dart';


class WebSocketNotificationsService {
  static final WebSocketNotificationsService _instance =
  WebSocketNotificationsService._internal();

  factory WebSocketNotificationsService() => _instance;
  WebSocketNotificationsService._internal();

  final ConfigService _config = ConfigService();

  StompClient? _stompClient;
  bool _isConnected = false;
  String? _userId;
  String? _token;
  NotificationsService? _notificationsService;

  // ✅ NEW: Track reconnection attempts to prevent spam
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  String get wsUrl => _config.wsEndpoint;

  Function(NotificationModel)? onNotificationReceived;
  Function(bool)? onConnectionStatusChanged;

  // ============================================================================
  // CONNECT TO WEBSOCKET (WITH SOCKJS)
  // ============================================================================

  Future<void> connect(String userId, String token,
      {required NotificationsService notificationsService}) async {

    if (_isConnected || (_stompClient?.connected ?? false)) {
      print("⚠️ Already connected - skipping duplicate connect()");
      return;
    }

    print("🔌 Connecting WebSocket...");

    _userId = userId;
    _token = token;
    _notificationsService = notificationsService;

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onStompError,
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        heartbeatOutgoing: Duration(seconds: 15),
        heartbeatIncoming: Duration(seconds: 15),

        beforeConnect: () async {
          print("🔄 Preparing connection...");
        },

        onWebSocketError: (error) {
          print("❌ WS ERROR: $error");
          if (!_isConnected) _scheduleReconnect();
        },

        reconnectDelay: Duration(seconds: 5),
      ),
    );

    _stompClient!.activate();
  }


  // ============================================================================
  // ON CONNECT
  // ============================================================================

  void _onConnect(StompFrame connectFrame) {
    print("✅✅✅ WebSocket CONNECTED Successfully!");
    print("🔧 Version: ${connectFrame.headers?['version']}");

    _isConnected = true;
    _reconnectAttempts = 0; // ✅ Reset attempts
    onConnectionStatusChanged?.call(true);

    _subscribeToNotifications();
    _sendConnectionTestMessage();
  }

  // ============================================================================
  // SUBSCRIBE TO NOTIFICATIONS
  // ============================================================================

  void _subscribeToNotifications() {
    if (!_isConnected || _userId == null || _stompClient == null) {
      print("⚠️ Cannot subscribe - not ready");
      return;
    }

    try {
      // User-specific queue
      _stompClient!.subscribe(
        destination: '/user/$_userId/queue/notifications',
        callback: _onNotificationMessage,
        headers: {'id': 'user-notifications-$_userId'},
      );
      print("✅ Subscribed to /user/$_userId/queue/notifications");

      // User-specific topic
      _stompClient!.subscribe(
        destination: '/topic/user/$_userId/notifications',
        callback: _onNotificationMessage,
        headers: {'id': 'user-topic-$_userId'},
      );
      print("✅ Subscribed to /topic/user/$_userId/notifications");

      // Broadcast
      _stompClient!.subscribe(
        destination: '/topic/notifications',
        callback: _onBroadcastNotification,
        headers: {'id': 'broadcast-notifications'},
      );
      print("✅ Subscribed to /topic/notifications");

    } catch (e) {
      print("❌ Subscription error: $e");
    }
  }

  // ============================================================================
  // ON NOTIFICATION MESSAGE
  // ============================================================================

  void _onNotificationMessage(StompFrame frame) {
    try {
      if (frame.body == null) {
        print("⚠️ Empty notification");
        return;
      }

      print("📬 Notification received");

      final jsonData = jsonDecode(frame.body!);
      final notification = NotificationModel.fromJson(jsonData);

      print("✅ Parsed: ${notification.title}");

      if (_notificationsService != null) {
        _notificationsService!.addNotification(notification);
      }

      onNotificationReceived?.call(notification);

    } catch (e) {
      print("❌ Error processing notification: $e");
    }
  }

  // ============================================================================
  // ON BROADCAST NOTIFICATION
  // ============================================================================

  void _onBroadcastNotification(StompFrame frame) {
    try {
      if (frame.body == null) return;

      final jsonData = jsonDecode(frame.body!);
      final notification = NotificationModel.fromJson(jsonData);

      if (_notificationsService != null) {
        _notificationsService!.addNotification(notification);
      }

      onNotificationReceived?.call(notification);

    } catch (e) {
      print("❌ Broadcast error: $e");
    }
  }

  // ============================================================================
  // ON DISCONNECT
  // ============================================================================

  void _onDisconnect(StompFrame frame) {
    print("⚠️ WebSocket Disconnected");
    print("   Reason: ${frame.body ?? 'Unknown'}");

    _isConnected = false;
    onConnectionStatusChanged?.call(false);

    _scheduleReconnect();
  }

  // ============================================================================
  // ON STOMP ERROR
  // ============================================================================

  void _onStompError(StompFrame frame) {
    print("❌ STOMP Error: ${frame.body}");
    _scheduleReconnect();
  }

  // ============================================================================
  // RECONNECTION (✅ IMPROVED - Exponential backoff)
  // ============================================================================

  void _scheduleReconnect() {
    // ✅ Prevent infinite reconnect loop
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("❌ Max reconnect attempts reached. Please restart app.");
      return;
    }

    _reconnectAttempts++;

    // ✅ Exponential backoff: 5s, 10s, 20s, 40s, 80s
    final delaySeconds = 5 * (1 << (_reconnectAttempts - 1));
    print("🔄 Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySeconds}s...");

    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_userId != null && _token != null && _notificationsService != null) {
        print("🔄 Attempting reconnection...");
        connect(_userId!, _token!, notificationsService: _notificationsService!);
      }
    });
  }

  // ============================================================================
  // CONNECTION TIMEOUT
  // ============================================================================

  void _setupConnectionTimeout() {
    Future.delayed(Duration(seconds: 15), () {
      if (!_isConnected) {
        print("⏰ Connection timeout - retrying");
        _scheduleReconnect();
      }
    });
  }

  // ============================================================================
  // SEND TEST MESSAGE
  // ============================================================================

  void _sendConnectionTestMessage() {
    if (!_isConnected || _stompClient == null) return;

    try {
      _stompClient!.send(
        destination: '/app/connection-test',
        body: jsonEncode({
          'message': 'Flutter connected',
          'userId': _userId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      print("✅ Test message sent");
    } catch (e) {
      print("❌ Error sending test: $e");
    }
  }

  void sendTestMessage() {
    if (!_isConnected || _stompClient == null) {
      print("❌ Not connected");
      return;
    }

    try {
      _stompClient!.send(
        destination: '/app/test',
        body: jsonEncode({
          'message': 'Test from Flutter',
          'userId': _userId,
        }),
      );
      print("✅ Test sent");
    } catch (e) {
      print("❌ Error: $e");
    }
  }

  // ============================================================================
  // DISCONNECT (SAFE)
  // ============================================================================

  void disconnect() {
    try {
      if (_stompClient != null && _stompClient!.connected) {
        _stompClient!.deactivate();
        print("✅ WebSocket disconnected gracefully");
      } else {
        print("ℹ️ WebSocket already disconnected");
      }
    } catch (e) {
      print("⚠️ Error during disconnect: $e");
    }

    _isConnected = false;
    onConnectionStatusChanged?.call(false);
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  bool get isConnected => _isConnected;
  String? get userId => _userId;
  bool get stompConnected => _stompClient?.connected ?? false;
  int get reconnectAttempts => _reconnectAttempts;
}