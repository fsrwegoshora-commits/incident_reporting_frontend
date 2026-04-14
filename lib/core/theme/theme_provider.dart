import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum AppThemeMode { light, dark, system, scheduled }

class ThemeProvider with ChangeNotifier, WidgetsBindingObserver {
  // ─── Prefs keys ────────────────────────────────────────────────────────────
  static const _keyMode          = 'theme_mode';
  static const _keyScheduleStart = 'theme_schedule_start'; // minutes from midnight
  static const _keyScheduleEnd   = 'theme_schedule_end';

  // ─── State ─────────────────────────────────────────────────────────────────
  AppThemeMode _mode          = AppThemeMode.system;
  int          _scheduleStart = 20 * 60; // 20:00 default
  int          _scheduleEnd   = 6  * 60; //  6:00 default
  Timer?       _scheduleTimer;

  // ─── Initialisation ────────────────────────────────────────────────────────
  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleTimer?.cancel();
    super.dispose();
  }

  /// Called by Flutter when the OS theme changes.
  @override
  void didChangePlatformBrightness() {
    if (_mode == AppThemeMode.system) {
      _applySystemChrome();
      notifyListeners();
    }
  }

  // ─── Public getters ────────────────────────────────────────────────────────
  AppThemeMode get mode          => _mode;
  int          get scheduleStart => _scheduleStart; // minutes from midnight
  int          get scheduleEnd   => _scheduleEnd;

  bool get isDarkMode {
    switch (_mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
      case AppThemeMode.scheduled:
        return _isScheduledDarkNow();
    }
  }

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:     return ThemeMode.light;
      case AppThemeMode.dark:      return ThemeMode.dark;
      case AppThemeMode.system:    return ThemeMode.system;
      case AppThemeMode.scheduled: return isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
  }

  ThemeData get currentTheme => isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  TimeOfDay get scheduleStartTime => TimeOfDay(
    hour:   _scheduleStart ~/ 60,
    minute: _scheduleStart  % 60,
  );

  TimeOfDay get scheduleEndTime => TimeOfDay(
    hour:   _scheduleEnd ~/ 60,
    minute: _scheduleEnd  % 60,
  );

  String get modeLabel {
    switch (_mode) {
      case AppThemeMode.light:     return 'Light';
      case AppThemeMode.dark:      return 'Dark';
      case AppThemeMode.system:    return 'System';
      case AppThemeMode.scheduled: return 'Scheduled';
    }
  }

  // ─── Public setters ────────────────────────────────────────────────────────
  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    _scheduleTimer?.cancel();
    if (mode == AppThemeMode.scheduled) _startScheduleTimer();
    await _save();
    _applySystemChrome();
    notifyListeners();
  }

  Future<void> setSchedule({
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    _scheduleStart = start.hour * 60 + start.minute;
    _scheduleEnd   = end.hour   * 60 + end.minute;
    await _save();
    _applySystemChrome();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await setMode(isDarkMode ? AppThemeMode.light : AppThemeMode.dark);
  }

  // ─── System chrome sync ────────────────────────────────────────────────────
  void applySystemChrome() => _applySystemChrome();

  void _applySystemChrome() {
    final dark = isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:            Colors.transparent,
      statusBarIconBrightness:   dark ? Brightness.light : Brightness.dark,
      statusBarBrightness:       dark ? Brightness.dark  : Brightness.light,
      systemNavigationBarColor:  dark ? AppTheme.darkSurface : AppTheme.cardWhite,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
  }

  // ─── Scheduled logic ───────────────────────────────────────────────────────
  bool _isScheduledDarkNow() {
    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;

    // Overnight range (e.g. 20:00 → 06:00)
    if (_scheduleStart > _scheduleEnd) {
      return nowMins >= _scheduleStart || nowMins < _scheduleEnd;
    }
    // Same-day range (e.g. 22:00 → 23:00)
    return nowMins >= _scheduleStart && nowMins < _scheduleEnd;
  }

  void _startScheduleTimer() {
    _scheduleTimer?.cancel();
    // Check every minute; fire immediately at the next minute boundary.
    final now      = DateTime.now();
    final nextMin  = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final delay    = nextMin.difference(now);

    _scheduleTimer = Timer(delay, () {
      _applySystemChrome();
      notifyListeners();
      // Then tick every 60 seconds
      _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _applySystemChrome();
        notifyListeners();
      });
    });
  }

  // ─── Persistence ───────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_keyMode) ?? AppThemeMode.system.index;
      _mode          = AppThemeMode.values[modeIndex.clamp(0, AppThemeMode.values.length - 1)];
      _scheduleStart = prefs.getInt(_keyScheduleStart) ?? 20 * 60;
      _scheduleEnd   = prefs.getInt(_keyScheduleEnd)   ?? 6  * 60;

      if (_mode == AppThemeMode.scheduled) _startScheduleTimer();
      _applySystemChrome();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyMode,          _mode.index);
      await prefs.setInt(_keyScheduleStart, _scheduleStart);
      await prefs.setInt(_keyScheduleEnd,   _scheduleEnd);
    } catch (_) {}
  }
}
