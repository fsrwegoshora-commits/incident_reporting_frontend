import 'package:flutter/material.dart';

class NotificationModel {
  final String uid;
  final String title;
  final String? message;
  final String type;
  final String? relatedEntityUid;
  final String? relatedEntityType;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isRead;
  final List<String> channels;

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

  // Helper methods for UI
  String getTypeLabel() {
    switch (type.toUpperCase()) {
      case 'INCIDENT_REPORTED':
        return 'Incident Reported';
      case 'INCIDENT_ASSIGNED':
        return 'Incident Assigned';
      case 'INCIDENT_RESOLVED':
        return 'Incident Resolved';
      case 'CHAT_MESSAGE':
        return 'New Message';
      case 'MEDIA_UPLOADED':
        return 'Media Uploaded';
      case 'SHIFT_ASSIGNED':
        return 'Shift Assigned';
      default:
        return 'Notification';
    }
  }

  Color getTypeColor() {
    switch (type.toUpperCase()) {
      case 'INCIDENT_REPORTED':
        return Color(0xFFFF6B6B);
      case 'INCIDENT_ASSIGNED':
        return Color(0xFF2E5BFF);
      case 'INCIDENT_RESOLVED':
        return Color(0xFF51CF66);
      case 'CHAT_MESSAGE':
        return Color(0xFF9C27B0);
      case 'MEDIA_UPLOADED':
        return Color(0xFFFF9800);
      case 'SHIFT_ASSIGNED':
        return Color(0xFF607D8B);
      default:
        return Color(0xFF2E5BFF);
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
      case 'MEDIA_UPLOADED':
        return Icons.photo_library_rounded;
      case 'SHIFT_ASSIGNED':
        return Icons.calendar_today_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}