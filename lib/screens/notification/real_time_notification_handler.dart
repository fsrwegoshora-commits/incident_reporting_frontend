import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../services/notifications_service.dart';

// ============================================================================
// REAL-TIME NOTIFICATION HANDLER
// ============================================================================

class RealTimeNotificationHandler {
  final NotificationsService notificationsService;

  RealTimeNotificationHandler({required this.notificationsService});

  // ============================================================================
  // HANDLE INCOMING REMOTE MESSAGE
  // ============================================================================

  void handleRemoteMessage(RemoteMessage message) {
    print("📬 Remote Message Received: ${message.notification?.title}");
    print("Data: ${message.data}");

    final notificationType = message.data['type'];
    final relatedEntityUid = message.data['relatedEntityUid'];
    final relatedEntityType = message.data['relatedEntityType'];

    // Create notification model from remote message
    final notification = NotificationModel(
      uid: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? 'New Notification',
      message: message.notification?.body,
      type: notificationType ?? 'NOTIFICATION',
      relatedEntityUid: relatedEntityUid,
      relatedEntityType: relatedEntityType,
      sentAt: DateTime.now(),
      isRead: false,
      channels: ['PUSH'],
    );

    // Handle specific notification types
    switch (notificationType?.toUpperCase()) {
      case 'CHAT_MESSAGE':
        _handleChatMessage(notification, message);
        break;
      case 'INCIDENT_REPORTED':
        _handleIncidentReported(notification, message);
        break;
      case 'INCIDENT_ASSIGNED':
        _handleIncidentAssigned(notification, message);
        break;
      case 'INCIDENT_RESOLVED':
        _handleIncidentResolved(notification, message);
        break;
      case 'SHIFT_ASSIGNED':
        _handleShiftAssigned(notification, message);
        break;
      case 'SHIFT_REASSIGNED':
        _handleShiftReassigned(notification, message);
        break;
      case 'SHIFT_EXCUSED':
        _handleShiftExcused(notification, message);
        break;
      default:
        _handleGenericNotification(notification, message);
    }
  }

  // ============================================================================
  // CHAT MESSAGE HANDLER
  // ============================================================================

  void _handleChatMessage(NotificationModel notification, RemoteMessage message) {
    print("💬 Chat Message Notification: ${notification.title}");
    print("Incident UID: ${notification.relatedEntityUid}");

    // Add to notifications service so it appears in UI
    notificationsService.addNotification(notification);

    // You can trigger additional actions:
    // - Play sound
    // - Vibrate
    // - Show specific UI toast
    // - Auto-refresh chat if chat screen is open

    _playNotificationSound();
    _showChatMessageToast(notification.message ?? '');
  }

  // ============================================================================
  // INCIDENT HANDLERS
  // ============================================================================

  void _handleIncidentReported(NotificationModel notification, RemoteMessage message) {
    print("🚨 New Incident Reported: ${notification.title}");
    print("Incident UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    // If user is admin/station admin, show alert
    _playNotificationSound();
    _showIncidentAlert(
      title: 'New Incident Reported',
      message: notification.message ?? '',
      incidentUid: notification.relatedEntityUid,
    );
  }

  void _handleIncidentAssigned(NotificationModel notification, RemoteMessage message) {
    print("📋 Incident Assigned To You: ${notification.title}");
    print("Incident UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    _playNotificationSound();
    _showIncidentAlert(
      title: 'Incident Assigned',
      message: notification.message ?? '',
      incidentUid: notification.relatedEntityUid,
    );
  }

  void _handleIncidentResolved(NotificationModel notification, RemoteMessage message) {
    print("✅ Incident Resolved: ${notification.title}");
    print("Incident UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    _playNotificationSound();
  }

  // ============================================================================
  // SHIFT HANDLERS
  // ============================================================================

  void _handleShiftAssigned(NotificationModel notification, RemoteMessage message) {
    print("📅 Shift Assigned: ${notification.title}");
    print("Shift UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    _playNotificationSound();
    _showShiftAlert(
      title: 'Shift Assigned',
      message: notification.message ?? '',
      shiftUid: notification.relatedEntityUid,
    );
  }

  void _handleShiftReassigned(NotificationModel notification, RemoteMessage message) {
    print("🔄 Shift Reassigned: ${notification.title}");
    print("Shift UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    _playNotificationSound();
    _showShiftAlert(
      title: 'Shift Reassigned',
      message: notification.message ?? '',
      shiftUid: notification.relatedEntityUid,
    );
  }

  void _handleShiftExcused(NotificationModel notification, RemoteMessage message) {
    print("✅ Shift Excused: ${notification.title}");
    print("Shift UID: ${notification.relatedEntityUid}");

    notificationsService.addNotification(notification);

    _playNotificationSound();
    _showShiftAlert(
      title: 'Shift Excused',
      message: notification.message ?? '',
      shiftUid: notification.relatedEntityUid,
    );
  }

  // ============================================================================
  // GENERIC HANDLER
  // ============================================================================

  void _handleGenericNotification(NotificationModel notification, RemoteMessage message) {
    print("📬 Generic Notification: ${notification.title}");

    notificationsService.addNotification(notification);
    _playNotificationSound();
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  void _playNotificationSound() {
    // Notification sound handled by Firebase, but you can add custom sound here
    print("🔔 Playing notification sound...");
  }

  void _showChatMessageToast(String message) {
    print("💬 Chat Toast: $message");
    // You can show a custom toast or snackbar here
  }

  void _showIncidentAlert({
    required String title,
    required String message,
    String? incidentUid,
  }) {
    print("🚨 Incident Alert: $title - $message");
    // Trigger UI update or show dialog
  }

  void _showShiftAlert({
    required String title,
    required String message,
    String? shiftUid,
  }) {
    print("📅 Shift Alert: $title - $message");
    // Trigger UI update or show dialog
  }
}