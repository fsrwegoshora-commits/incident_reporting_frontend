import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a styled floating SnackBar — Untitled UI toast style.
///
/// ```dart
/// AppSnackbar.success(context, 'Officer registered successfully!');
/// AppSnackbar.error(context, 'Failed to save: $error');
/// AppSnackbar.warning(context, 'Station has no active officers.');
/// AppSnackbar.info(context, 'Changes take effect on next login.');
/// ```
class AppSnackbar {
  static void _show(
    BuildContext context,
    String message, {
    required Color bg,
    required Color fg,
    required Color border,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: border),
            boxShadow: const [AppTheme.cardShadow],
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: fg.withOpacity(0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Icon(icon, color: fg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg)),
            ),
          ]),
        ),
      ));
  }

  static void success(BuildContext context, String message) => _show(
    context, message,
    bg: AppTheme.successBg,
    fg: AppTheme.successGreenDark,
    border: AppTheme.successGreen.withOpacity(0.2),
    icon: Icons.check_circle_outline_rounded,
  );

  static void error(BuildContext context, String message) => _show(
    context, message,
    bg: AppTheme.errorBg,
    fg: AppTheme.errorRedDark,
    border: AppTheme.errorRed.withOpacity(0.2),
    icon: Icons.error_outline_rounded,
  );

  static void warning(BuildContext context, String message) => _show(
    context, message,
    bg: AppTheme.warningBg,
    fg: AppTheme.warningAmberDark,
    border: AppTheme.warningAmber.withOpacity(0.2),
    icon: Icons.warning_amber_rounded,
  );

  static void info(BuildContext context, String message) => _show(
    context, message,
    bg: AppTheme.infoBg,
    fg: AppTheme.infoBlueDark,
    border: AppTheme.infoBlue.withOpacity(0.2),
    icon: Icons.info_outline_rounded,
  );
}
