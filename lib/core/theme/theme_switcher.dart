import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'app_theme.dart';

/// A polished theme-mode selector.
/// Drop it anywhere — profile page, settings drawer, etc.
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<ThemeProvider>();
    final isDark    = provider.isDarkMode;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final subColor  = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.borderColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: borderCol),
        boxShadow: [isDark ? AppTheme.darkCardShadow : AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppTheme.darkPrimaryGradient
                        : AppTheme.primaryGradient,
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    Text(provider.modeLabel,
                        style: TextStyle(fontSize: 12, color: subColor)),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderCol),

          // ── Mode Selector ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: _ModeSegmentedControl(
              current: provider.mode,
              isDark: isDark,
              onChanged: (m) => context.read<ThemeProvider>().setMode(m),
            ),
          ),

          // ── Schedule Panel (shown only in scheduled mode) ─────────────────
          AnimatedSize(
            duration: AppTheme.normalAnimation,
            curve: Curves.easeInOut,
            child: provider.mode == AppThemeMode.scheduled
                ? _SchedulePanel(provider: provider, isDark: isDark)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Segmented control ───────────────────────────────────────────────────────

class _ModeSegmentedControl extends StatelessWidget {
  final AppThemeMode current;
  final bool isDark;
  final ValueChanged<AppThemeMode> onChanged;

  const _ModeSegmentedControl({
    required this.current,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceGrey,
        borderRadius: AppTheme.buttonRadius,
      ),
      child: Row(
        children: AppThemeMode.values.map((mode) {
          final selected = mode == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: AppTheme.normalAnimation,
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? (isDark ? AppTheme.primaryBlueLight : AppTheme.primaryBlue)
                      : Colors.transparent,
                  borderRadius: AppTheme.smallRadius,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(mode),
                      size: 18,
                      color: selected
                          ? Colors.white
                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _labelFor(mode),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconFor(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light:     return Icons.light_mode_rounded;
      case AppThemeMode.dark:      return Icons.dark_mode_rounded;
      case AppThemeMode.system:    return Icons.brightness_auto_rounded;
      case AppThemeMode.scheduled: return Icons.schedule_rounded;
    }
  }

  String _labelFor(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.light:     return 'Light';
      case AppThemeMode.dark:      return 'Dark';
      case AppThemeMode.system:    return 'Auto';
      case AppThemeMode.scheduled: return 'Schedule';
    }
  }
}

// ─── Schedule panel ──────────────────────────────────────────────────────────

class _SchedulePanel extends StatelessWidget {
  final ThemeProvider provider;
  final bool isDark;

  const _SchedulePanel({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor  = isDark ? AppTheme.darkTextPrimary  : AppTheme.textPrimary;
    final subColor   = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final borderCol  = isDark ? AppTheme.darkBorder        : AppTheme.borderColor;

    return Column(
      children: [
        Divider(height: 1, color: borderCol),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    'Dark mode turns on automatically',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'Turn on',
                      icon: Icons.nights_stay_rounded,
                      time: provider.scheduleStartTime,
                      isDark: isDark,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: provider.scheduleStartTime,
                          helpText: 'Dark mode turns ON at',
                        );
                        if (picked != null) {
                          await provider.setSchedule(
                            start: picked,
                            end: provider.scheduleEndTime,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeTile(
                      label: 'Turn off',
                      icon: Icons.wb_sunny_rounded,
                      time: provider.scheduleEndTime,
                      isDark: isDark,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: provider.scheduleEndTime,
                          helpText: 'Dark mode turns OFF at',
                        );
                        if (picked != null) {
                          await provider.setSchedule(
                            start: provider.scheduleStartTime,
                            end: picked,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Preview bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: AppTheme.pillRadius,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.15),
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlueDark,
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withOpacity(0.15),
                    ],
                    stops: _scheduleStops(provider),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(provider.scheduleStartTime),
                      style: TextStyle(fontSize: 10, color: subColor)),
                  Text('Dark', style: TextStyle(fontSize: 10, color: subColor)),
                  Text(_fmt(provider.scheduleEndTime),
                      style: TextStyle(fontSize: 10, color: subColor)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<double> _scheduleStops(ThemeProvider p) {
    final start = p.scheduleStart / (24 * 60);
    final end   = p.scheduleEnd   / (24 * 60);
    if (start < end) return [start, start, end, end, 1.0];
    return [end, end, start, start, 1.0];
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final bool isDark;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.icon,
    required this.time,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isDark ? AppTheme.darkSurface   : AppTheme.surfaceGrey;
    final border = isDark ? AppTheme.darkBorder     : AppTheme.borderColor;
    final text   = isDark ? AppTheme.darkTextPrimary: AppTheme.textPrimary;
    final sub    = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppTheme.smallRadius,
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: sub)),
                Text(
                  '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: text),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_rounded, size: 14, color: sub),
          ],
        ),
      ),
    );
  }
}
