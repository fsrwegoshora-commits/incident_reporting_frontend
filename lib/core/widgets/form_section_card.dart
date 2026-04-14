import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── FormSectionCard ──────────────────────────────────────────────────────────

/// White card with gray-200 border and an optional section heading.
/// The standard container for every group of form fields.
///
/// ```dart
/// FormSectionCard(
///   title: 'Personal Information',
///   icon: Icons.person_outline,
///   children: [
///     FormTextInput(label: 'Full Name', icon: Icons.badge_outlined),
///     const SizedBox(height: AppTheme.spaceM),
///     PhoneTextInput(controller: _phoneController),
///   ],
/// )
/// ```
class FormSectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const FormSectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    required this.children,
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final borderC = isDark ? AppTheme.darkBorder : AppTheme.gray200;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: borderC),
        boxShadow: const [AppTheme.lightShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            _CardHeader(
              title: title!,
              subtitle: subtitle,
              icon: icon,
              trailing: trailing,
              isDark: isDark,
              borderC: borderC,
            ),
          Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool isDark;
  final Color borderC;

  const _CardHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    required this.isDark,
    required this.borderC,
  });

  @override
  Widget build(BuildContext context) {
    final textC = isDark ? AppTheme.darkTextPrimary : AppTheme.gray900;
    final subC  = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          if (icon != null) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textC)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: 12, color: subC)),
            ],
          )),
          if (trailing != null) trailing!,
        ]),
      ),
      Divider(height: 1, thickness: 1, color: borderC),
    ]);
  }
}

// ─── FormHeaderCard ───────────────────────────────────────────────────────────

/// Full-page form header: icon badge + title + optional subtitle.
/// Placed as the first card on every form page.
///
/// ```dart
/// FormHeaderCard(
///   icon: Icons.local_police_outlined,
///   title: 'Register Police Officer',
///   subtitle: 'Add a new officer to the station',
/// )
/// ```
class FormHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  const FormHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final borderC = isDark ? AppTheme.darkBorder : AppTheme.gray200;
    final titleC  = isDark ? AppTheme.darkTextPrimary : AppTheme.gray900;
    final subC    = isDark ? AppTheme.darkTextSecondary : AppTheme.gray500;
    final iColor  = iconColor ?? AppTheme.primaryBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceL),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: borderC),
        boxShadow: const [AppTheme.lightShadow],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: iColor.withOpacity(0.08),
            borderRadius: AppTheme.mediumRadius,
            border: Border.all(color: iColor.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 26, color: iColor),
        ),
        const SizedBox(width: AppTheme.spaceM),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: titleC)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 13, color: subC)),
            ],
          ],
        )),
      ]),
    );
  }
}

// ─── StatusBadge ──────────────────────────────────────────────────────────────

/// Pill-shaped status badge (active, pending, error, etc.)
///
/// ```dart
/// StatusBadge(label: 'Active',  status: 'ACTIVE')
/// StatusBadge(label: 'Pending', status: 'PENDING')
/// ```
class StatusBadge extends StatelessWidget {
  final String label;
  final String? status;
  final Color? color;

  const StatusBadge({super.key, required this.label, this.status, this.color});

  @override
  Widget build(BuildContext context) {
    final c  = color ?? AppTheme.getStatusColor(status ?? '');
    final bg = AppTheme.getStatusBg(status ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppTheme.pillRadius,
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

// ─── FormInfoBox ──────────────────────────────────────────────────────────────

/// Coloured info/hint box. Types: info (default), success, warning, error.
///
/// ```dart
/// FormInfoBox(message: 'Badge numbers are unique across all stations.')
/// FormInfoBox(title: 'Note', message: 'Phone must start with +255.', type: InfoBoxType.warning)
/// ```
enum InfoBoxType { info, success, warning, error }

class FormInfoBox extends StatelessWidget {
  final String message;
  final String? title;
  final InfoBoxType type;
  final List<String>? bullets;

  const FormInfoBox({
    super.key,
    required this.message,
    this.title,
    this.type = InfoBoxType.info,
    this.bullets,
  });

  _Pal get _pal {
    switch (type) {
      case InfoBoxType.info:    return _Pal(AppTheme.infoBlue,    AppTheme.infoBg,    Icons.info_outline_rounded);
      case InfoBoxType.success: return _Pal(AppTheme.successGreen,AppTheme.successBg, Icons.check_circle_outline_rounded);
      case InfoBoxType.warning: return _Pal(AppTheme.warningAmber,AppTheme.warningBg, Icons.warning_amber_rounded);
      case InfoBoxType.error:   return _Pal(AppTheme.errorRed,    AppTheme.errorBg,   Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceM),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: p.color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(p.icon, size: 16, color: p.color),
          const SizedBox(width: AppTheme.spaceS),
          Expanded(child: Text(
            title ?? message,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.color),
          )),
        ]),
        if (title != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(message, style: TextStyle(fontSize: 13, color: p.color.withOpacity(0.8))),
          ),
        ],
        if (bullets != null)
          ...bullets!.map((b) => Padding(
            padding: const EdgeInsets.only(top: 4, left: 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(fontSize: 13, color: p.color)),
              Expanded(child: Text(b, style: TextStyle(fontSize: 13, color: p.color.withOpacity(0.8)))),
            ]),
          )),
      ]),
    );
  }
}

class _Pal {
  final Color color;
  final Color bg;
  final IconData icon;
  const _Pal(this.color, this.bg, this.icon);
}

// ─── SectionDivider ───────────────────────────────────────────────────────────

/// A lightweight labeled divider for separating content inside a single card.
class SectionDivider extends StatelessWidget {
  final String? label;
  const SectionDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return const Divider(height: AppTheme.spaceL, thickness: 1, color: AppTheme.gray200);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceM),
      child: Row(children: [
        const Expanded(child: Divider(thickness: 1, color: AppTheme.gray200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceS),
          child: Text(label!, style: AppTheme.labelSmall),
        ),
        const Expanded(child: Divider(thickness: 1, color: AppTheme.gray200)),
      ]),
    );
  }
}
