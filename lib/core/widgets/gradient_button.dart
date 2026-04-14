import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Button variant — maps to a solid background color.
enum ButtonVariant { primary, success, error, warning, accent, neutral }

/// Full-width (or sized) solid-color button — Untitled UI style.
/// No gradients; uses flat color with subtle shadow on press.
///
/// ```dart
/// AppButton(label: 'Save Officer', icon: Icons.save, onPressed: _submit)
/// AppButton(label: 'Delete', variant: ButtonVariant.error, onPressed: _delete)
/// AppButton(label: 'Saving…', isLoading: true, onPressed: null)
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height = 44,
    this.padding,
    this.fullWidth = true,
  });

  Color get _bg {
    switch (variant) {
      case ButtonVariant.primary: return AppTheme.primaryBlue;
      case ButtonVariant.success: return AppTheme.successGreen;
      case ButtonVariant.error:   return AppTheme.errorRed;
      case ButtonVariant.warning: return AppTheme.warningAmber;
      case ButtonVariant.accent:  return AppTheme.accentOrange;
      case ButtonVariant.neutral: return AppTheme.gray100;
    }
  }

  Color get _fg {
    if (variant == ButtonVariant.neutral) return AppTheme.gray700;
    return AppTheme.cardWhite;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      width: fullWidth ? double.infinity : width,
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _bg : AppTheme.gray200,
          foregroundColor: enabled ? _fg : AppTheme.gray400,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
          disabledBackgroundColor: AppTheme.gray100,
          disabledForegroundColor: AppTheme.gray400,
        ),
        child: _content(),
      ),
    );
  }

  Widget _content() {
    if (isLoading) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_fg),
          ),
        ),
        const SizedBox(width: AppTheme.spaceS),
        Text('Please wait…',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _fg)),
      ]);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: _fg),
        const SizedBox(width: AppTheme.spaceS),
      ],
      Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _fg)),
    ]);
  }
}

// Keep old name as alias so existing code doesn't break
typedef GradientButton = AppButton;

/// Secondary outlined button (white + border).
///
/// ```dart
/// SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(context))
/// ```
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? width;
  final bool fullWidth;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
    this.width,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryBlue;
    return SizedBox(
      width: fullWidth ? double.infinity : width,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: AppTheme.gray300),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
          backgroundColor: AppTheme.cardWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: c), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
        ]),
      ),
    );
  }
}

// Keep legacy alias
typedef OutlineButton = SecondaryButton;
