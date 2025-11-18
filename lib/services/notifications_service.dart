import 'package:flutter/material.dart';
import '../services/graphql_service.dart';
import '../utils/graphql_query.dart';

// ============================================================================
// NOTIFICATION MODEL
// ============================================================================

class NotificationModel {
  final String uid;
  final String title;
  final String? message;
  final String type; // INCIDENT_REPORTED, INCIDENT_ASSIGNED, CHAT_MESSAGE, etc
  final String? relatedEntityUid;
  final String? relatedEntityType;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isRead;
  final List<String> channels; // IN_APP, PUSH, SMS

  NotificationModel({
    required this.uid,
    required this.title,
    this.message,
    required this.type,
    this.relatedEntityUid,
    this.relatedEntityType,
    required this.sentAt,
    this.readAt,
    required this.isRead,
    required this.channels,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      uid: json['uid'] ?? '',
      title: json['title'] ?? '',
      message: json['message'],
      type: json['type'] ?? '',
      relatedEntityUid: json['relatedEntityUid'],
      relatedEntityType: json['relatedEntityType'],
      sentAt: DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isRead: json['read'] ?? false,
      channels: List<String>.from(json['channels'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'title': title,
      'message': message,
      'type': type,
      'relatedEntityUid': relatedEntityUid,
      'relatedEntityType': relatedEntityType,
      'sentAt': sentAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'read': isRead,
      'channels': channels,
    };
  }

  String getTypeLabel() {
    switch (type.toUpperCase()) {
      case 'INCIDENT_REPORTED':
        return '🚨 Incident Reported';
      case 'INCIDENT_ASSIGNED':
        return '📋 Incident Assigned';
      case 'INCIDENT_RESOLVED':
        return '✅ Incident Resolved';
      case 'CHAT_MESSAGE':
        return '💬 New Message';
      case 'SHIFT_ASSIGNED':
        return '📅 Shift Assigned';
      case 'SHIFT_REASSIGNED':
        return '🔄 Shift Changed';
      default:
        return '📬 Notification';
    }
  }

  Color getTypeColor() {
    switch (type.toUpperCase()) {
      case 'INCIDENT_REPORTED':
        return Color(0xFFFF6B6B); // Red
      case 'INCIDENT_ASSIGNED':
        return Color(0xFF2E5BFF); // Blue
      case 'INCIDENT_RESOLVED':
        return Color(0xFF51CF66); // Green
      case 'CHAT_MESSAGE':
        return Color(0xFF868E96); // Gray
      case 'SHIFT_ASSIGNED':
      case 'SHIFT_REASSIGNED':
        return Color(0xFFFFA500); // Orange
      default:
        return Color(0xFF2E5BFF); // Blue
    }
  }

  IconData getTypeIcon() {
    switch (type.toUpperCase()) {
      case 'INCIDENT_REPORTED':
        return Icons.warning_amber_rounded;
      case 'INCIDENT_ASSIGNED':
        return Icons.assignment_rounded;
      case 'INCIDENT_RESOLVED':
        return Icons.check_circle_rounded;
      case 'CHAT_MESSAGE':
        return Icons.chat_bubble_rounded;
      case 'SHIFT_ASSIGNED':
      case 'SHIFT_REASSIGNED':
        return Icons.calendar_today_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}

// ============================================================================
// NOTIFICATIONS SERVICE
// ============================================================================

class NotificationsService extends ChangeNotifier {
  final GraphQLService _gql = GraphQLService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============================================================================
  // NOTIFICATIONS FETCHING
  // ============================================================================

  Future<void> fetchNotifications({int page = 0, int size = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      const String query = '''
        query getUserNotifications(\$pageableParam: PageableParamInput!) {
          getUserNotifications(pageableParam: \$pageableParam) {
            status
            message
            data {
              uid
              title
              message
              type
              relatedEntityUid
              relatedEntityType
              sentAt
              readAt
              read
              channels
            }
            page
            size
            pages
            elements
          }
        }
      ''';

      final response = await _gql.sendAuthenticatedQuery(query, {
        'pageableParam': {
          'page': page,
          'size': size,
        }
      });

      if (response.containsKey('errors')) {
        _error = 'Failed to fetch notifications';
        print("❌ Error fetching notifications: ${response['errors']}");
      } else {
        final data = response['data']?['getUserNotifications']?['data'];
        if (data != null) {
          _notifications = (data as List)
              .map((item) => NotificationModel.fromJson(item))
              .toList();
          print("✅ Fetched ${_notifications.length} notifications");
        }
      }
    } catch (e) {
      _error = 'Error fetching notifications: $e';
      print("❌ $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // MARK AS READ
  // ============================================================================

  Future<void> markAsRead(String notificationUid) async {
    try {
      const String mutation = '''
        mutation markAsRead(\$notificationUid: String!) {
          markAsRead(notificationUid: \$notificationUid) {
            status
            message
            data {
              uid
              read
              readAt
            }
          }
        }
      ''';

      final response = await _gql.sendAuthenticatedQuery(mutation, {
        'notificationUid': notificationUid,
      });

      if (!response.containsKey('errors')) {
        // Update local notification
        final index = _notifications.indexWhere((n) => n.uid == notificationUid);
        if (index >= 0) {
          final notification = _notifications[index];
          _notifications[index] = NotificationModel(
            uid: notification.uid,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            relatedEntityUid: notification.relatedEntityUid,
            relatedEntityType: notification.relatedEntityType,
            sentAt: notification.sentAt,
            readAt: DateTime.now(),
            isRead: true,
            channels: notification.channels,
          );
          print("✅ Marked notification as read");
        }
        notifyListeners();
      }
    } catch (e) {
      print("❌ Error marking notification as read: $e");
    }
  }

  Future<void> markMultipleAsRead(List<String> notificationUids) async {
    for (final uid in notificationUids) {
      await markAsRead(uid);
    }
  }

  // ============================================================================
  // UNREAD COUNT
  // ============================================================================

  Future<void> fetchUnreadCount() async {
    try {
      const String query = '''
        query getUnreadCount {
          getUnreadCount {
            status
            message
            data
          }
        }
      ''';

      final response = await _gql.sendAuthenticatedQuery(query, {});

      if (!response.containsKey('errors')) {
        _unreadCount = response['data']?['getUnreadCount']?['data'] ?? 0;
        print("📊 Unread count: $_unreadCount");
        notifyListeners();
      }
    } catch (e) {
      print("❌ Error fetching unread count: $e");
    }
  }

  // ============================================================================
  // CLEAR NOTIFICATIONS
  // ============================================================================

  Future<bool> clearNotifications(String userUid) async {
    try {
      _isLoading = true;
      notifyListeners();

      const String mutation = '''
        mutation clearNotifications(\$userUid: String!) {
          clearNotifications(userUid: \$userUid) {
            status
            message
            data {
              uid
              title
              message
              type
              read
            }
          }
        }
      ''';

      final response = await _gql.sendAuthenticatedQuery(mutation, {
        'userUid': userUid,
      });

      if (response.containsKey('errors')) {
        _error = 'Failed to clear notifications: ${response['errors']}';
        print("❌ Error clearing notifications: ${response['errors']}");
        return false;
      } else {
        _notifications.clear();
        _unreadCount = 0;
        print("✅ All notifications cleared successfully");
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Error clearing notifications: $e';
      print("❌ $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // REFRESH
  // ============================================================================

  Future<void> refresh() async {
    await Future.wait([
      fetchNotifications(),
      fetchUnreadCount(),
    ]);
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  List<NotificationModel> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  void addNotification(NotificationModel notification) {
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}