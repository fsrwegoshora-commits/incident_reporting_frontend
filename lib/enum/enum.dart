import 'package:flutter/material.dart';

/// Shift Time Period Enum
/// Defines the three shift periods for a day
class ShiftTimeEnum {
  static const String MORNING = 'MORNING';
  static const String EVENING = 'EVENING';
  static const String NIGHT = 'NIGHT';

  static const List<String> values = [MORNING, EVENING, NIGHT];

  /// Get display label for shift time
  static String getLabel(String value) {
    switch (value) {
      case MORNING:
        return 'Morning (06:00 - 14:00)';
      case EVENING:
        return 'Evening (14:00 - 22:00)';
      case NIGHT:
        return 'Night (22:00 - 06:00)';
      default:
        return value;
    }
  }

  /// Get start and end times for shift period
  static Map<String, Map<String, TimeOfDay>> getTimings() {
    return {
      MORNING: {
        'start': const TimeOfDay(hour: 6, minute: 0),
        'end': const TimeOfDay(hour: 14, minute: 0),
      },
      EVENING: {
        'start': const TimeOfDay(hour: 14, minute: 0),
        'end': const TimeOfDay(hour: 22, minute: 0),
      },
      NIGHT: {
        'start': const TimeOfDay(hour: 22, minute: 0),
        'end': const TimeOfDay(hour: 6, minute: 0),
      },
    };
  }
}

/// Shift Duty Type Enum
/// Defines the types of duties an officer can be assigned
class ShiftDutyTypeEnum {
  static const String STATION_DUTY = 'STATION_DUTY';
  static const String CHECKPOINT_DUTY = 'CHECKPOINT_DUTY';
  static const String PATROL = 'PATROL';
  static const String ESCORT = 'ESCORT';
  static const String COURT = 'COURT';
  static const String SPECIAL_OPERATION = 'SPECIAL_OPERATION';
  static const String OFF = 'OFF';

  static const List<String> values = [
    STATION_DUTY,
    CHECKPOINT_DUTY,
    PATROL,
    ESCORT,
    COURT,
    SPECIAL_OPERATION,
    OFF,
  ];

  /// Get display label for duty type
  static String getLabel(String value) {
    switch (value) {
      case STATION_DUTY:
        return 'Station Duty';
      case CHECKPOINT_DUTY:
        return 'Checkpoint Duty';
      case PATROL:
        return 'Patrol';
      case ESCORT:
        return 'Escort';
      case COURT:
        return 'Court';
      case SPECIAL_OPERATION:
        return 'Special Operation';
      case OFF:
        return 'Off';
      default:
        return value;
    }
  }

  /// Get color for duty type
  static Color getColor(String value) {
    switch (value) {
      case STATION_DUTY:
        return const Color(0xFF2E5BFF); // Blue
      case CHECKPOINT_DUTY:
        return const Color(0xFFFFB75E); // Orange
      case PATROL:
        return const Color(0xFF4CAF50); // Green
      case ESCORT:
        return const Color(0xFFFF6B6B); // Red
      case COURT:
        return const Color(0xFF9C27B0); // Purple
      case SPECIAL_OPERATION:
        return const Color(0xFFFF5722); // Deep Orange
      case OFF:
        return const Color(0xFF9E9E9E); // Grey
      default:
        return const Color(0xFF2E5BFF);
    }
  }

  /// Get icon for duty type
  static IconData getIcon(String value) {
    switch (value) {
      case STATION_DUTY:
        return Icons.domain;
      case CHECKPOINT_DUTY:
        return Icons.security;
      case PATROL:
        return Icons.directions_walk;
      case ESCORT:
        return Icons.shield;
      case COURT:
        return Icons.gavel;
      case SPECIAL_OPERATION:
        return Icons.military_tech;
      case OFF:
        return Icons.event_busy;
      default:
        return Icons.schedule;
    }
  }

  /// Get description for duty type
  static String getDescription(String value) {
    switch (value) {
      case STATION_DUTY:
        return 'Regular duty at police station';
      case CHECKPOINT_DUTY:
        return 'Assigned to traffic checkpoint';
      case PATROL:
        return 'Foot or vehicle patrol';
      case ESCORT:
        return 'Escort duty assignment';
      case COURT:
        return 'Court proceedings attendance';
      case SPECIAL_OPERATION:
        return 'Special operation duty';
      case OFF:
        return 'Officer is off duty';
      default:
        return value;
    }
  }
}