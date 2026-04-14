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

/// Vehicle Type Enum
class VehicleTypeEnum {
  static const String FIRE_TRUCK = 'FIRE_TRUCK';
  static const String WATER_TENDER = 'WATER_TENDER';
  static const String LADDER_TRUCK = 'LADDER_TRUCK';
  static const String RESCUE_TRUCK = 'RESCUE_TRUCK';
  static const String AMBULANCE = 'AMBULANCE';
  static const String ADVANCED_AMBULANCE = 'ADVANCED_AMBULANCE';
  static const String COMMAND_VEHICLE = 'COMMAND_VEHICLE';

  static const List<String> values = [
    FIRE_TRUCK, WATER_TENDER, LADDER_TRUCK, RESCUE_TRUCK,
    AMBULANCE, ADVANCED_AMBULANCE, COMMAND_VEHICLE,
  ];

  static const List<String> fireTypes = [
    FIRE_TRUCK, WATER_TENDER, LADDER_TRUCK, RESCUE_TRUCK, COMMAND_VEHICLE,
  ];

  static const List<String> medicalTypes = [
    AMBULANCE, ADVANCED_AMBULANCE,
  ];

  static String getLabel(String value) {
    switch (value) {
      case FIRE_TRUCK: return 'Fire Truck';
      case WATER_TENDER: return 'Water Tender';
      case LADDER_TRUCK: return 'Ladder Truck';
      case RESCUE_TRUCK: return 'Rescue Truck';
      case AMBULANCE: return 'Ambulance';
      case ADVANCED_AMBULANCE: return 'Advanced Life Support Ambulance';
      case COMMAND_VEHICLE: return 'Command Vehicle';
      default: return value;
    }
  }

  static Color getColor(String value) {
    switch (value) {
      case FIRE_TRUCK:
      case WATER_TENDER:
      case LADDER_TRUCK:
      case RESCUE_TRUCK:
        return const Color(0xFFEF4444);
      case AMBULANCE:
      case ADVANCED_AMBULANCE:
        return const Color(0xFF10B981);
      case COMMAND_VEHICLE:
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static IconData getIcon(String value) {
    switch (value) {
      case FIRE_TRUCK: return Icons.local_fire_department_rounded;
      case WATER_TENDER: return Icons.water_drop_rounded;
      case LADDER_TRUCK: return Icons.fire_truck_rounded;
      case RESCUE_TRUCK: return Icons.emergency_rounded;
      case AMBULANCE: return Icons.medical_services_rounded;
      case ADVANCED_AMBULANCE: return Icons.local_hospital_rounded;
      case COMMAND_VEHICLE: return Icons.directions_car_rounded;
      default: return Icons.directions_car_rounded;
    }
  }
}

/// Vehicle Status Enum
class VehicleStatusEnum {
  static const String AVAILABLE = 'AVAILABLE';
  static const String DISPATCHED = 'DISPATCHED';
  static const String EN_ROUTE = 'EN_ROUTE';
  static const String ON_SCENE = 'ON_SCENE';
  static const String RETURNING = 'RETURNING';
  static const String MAINTENANCE = 'MAINTENANCE';
  static const String OUT_OF_SERVICE = 'OUT_OF_SERVICE';

  static const List<String> values = [
    AVAILABLE, DISPATCHED, EN_ROUTE, ON_SCENE, RETURNING,
    MAINTENANCE, OUT_OF_SERVICE,
  ];

  static String getLabel(String value) {
    switch (value) {
      case AVAILABLE: return 'Available';
      case DISPATCHED: return 'Dispatched';
      case EN_ROUTE: return 'En Route';
      case ON_SCENE: return 'On Scene';
      case RETURNING: return 'Returning';
      case MAINTENANCE: return 'Maintenance';
      case OUT_OF_SERVICE: return 'Out of Service';
      default: return value;
    }
  }

  static Color getColor(String value) {
    switch (value) {
      case AVAILABLE: return const Color(0xFF10B981);
      case DISPATCHED: return const Color(0xFF2E5BFF);
      case EN_ROUTE: return const Color(0xFFF59E0B);
      case ON_SCENE: return const Color(0xFFEF4444);
      case RETURNING: return const Color(0xFF8B5CF6);
      case MAINTENANCE: return const Color(0xFFEC4899);
      case OUT_OF_SERVICE: return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }
}

/// Dispatch Status Enum
class DispatchStatusEnum {
  static const String PENDING = 'PENDING';
  static const String ACKNOWLEDGED = 'ACKNOWLEDGED';
  static const String EN_ROUTE = 'EN_ROUTE';
  static const String ON_SCENE = 'ON_SCENE';
  static const String CLEARED = 'CLEARED';
  static const String CANCELLED = 'CANCELLED';

  static const List<String> values = [
    PENDING, ACKNOWLEDGED, EN_ROUTE, ON_SCENE, CLEARED, CANCELLED,
  ];

  static String getLabel(String value) {
    switch (value) {
      case PENDING: return 'Pending';
      case ACKNOWLEDGED: return 'Acknowledged';
      case EN_ROUTE: return 'En Route';
      case ON_SCENE: return 'On Scene';
      case CLEARED: return 'Cleared';
      case CANCELLED: return 'Cancelled';
      default: return value;
    }
  }

  static Color getColor(String value) {
    switch (value) {
      case PENDING: return const Color(0xFFF59E0B);
      case ACKNOWLEDGED: return const Color(0xFF2E5BFF);
      case EN_ROUTE: return const Color(0xFF8B5CF6);
      case ON_SCENE: return const Color(0xFFEF4444);
      case CLEARED: return const Color(0xFF10B981);
      case CANCELLED: return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }
}