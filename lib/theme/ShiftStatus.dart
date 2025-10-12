import 'package:flutter/cupertino.dart';

class ShiftStatus {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Color badgeColor;
  final bool isCompleted;

  ShiftStatus({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.badgeColor,
    required this.isCompleted,
  });
}