import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String themeKey = 'isDarkMode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    loadTheme();
  }

  // CHANGED: Removed underscore to make it public
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
      _isDarkMode = false;
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(themeKey, _isDarkMode);
      notifyListeners();
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  Future<void> setTheme(bool darkMode) async {
    _isDarkMode = darkMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(themeKey, _isDarkMode);
      notifyListeners();
    } catch (e) {
      print('Error setting theme: $e');
    }
  }

  ThemeData get currentTheme => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
}