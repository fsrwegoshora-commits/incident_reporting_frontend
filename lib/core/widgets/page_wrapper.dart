import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard page body: gray-50 bg, optional loading overlay, scrollable.
///
/// ```dart
/// Scaffold(
///   appBar: AppTopBar(title: 'Register Officer'),
///   body: PageWrapper(isLoading: _loading, child: Form(...)),
/// )
/// ```
class PageWrapper extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String loadingText;
  final EdgeInsetsGeometry padding;

  const PageWrapper({
    super.key,
    required this.child,
    this.isLoading = false,
    this.loadingText = 'Please wait…',
    this.padding = const EdgeInsets.all(AppTheme.spaceM),
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.getBackgroundColor(context);
    if (isLoading) {
      return ColoredBox(color: bg, child: Center(child: _Spinner(text: loadingText)));
    }
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  final String text;
  const _Spinner({required this.text});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 40, height: 40,
        child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryBlue),
      ),
      const SizedBox(height: AppTheme.spaceM),
      Text(text, style: AppTheme.bodyMedium),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────

/// Untitled-UI style AppBar: brand-blue background, clean, no elevation.
///
/// ```dart
/// Scaffold(
///   appBar: AppTopBar(title: 'Officers', subtitle: 'Manage station officers'),
/// )
/// ```
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? leading;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.leading,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 68 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: AppTheme.cardWhite,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: leading ??
          (showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                )
              : null),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.cardWhite)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.cardWhite.withOpacity(0.75))),
        ],
      ),
      actions: actions,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Delete / action confirmation dialog.
///
/// ```dart
/// final ok = await ConfirmDialog.show(context,
///   title: 'Delete officer', message: 'This cannot be undone.');
/// if (ok == true) _delete();
/// ```
class ConfirmDialog {
  static Future<bool?> show(
    BuildContext context, {
    String title = 'Confirm',
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool isDangerous = true,
  }) {
    final color = isDangerous ? AppTheme.errorRed : AppTheme.primaryBlue;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              isDangerous ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
              color: color, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AppTheme.titleMedium)),
        ]),
        content: Text(message, style: AppTheme.bodyMedium),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel,
                style: AppTheme.labelLarge.copyWith(color: AppTheme.gray700)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: AppTheme.cardWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.buttonRadius),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
