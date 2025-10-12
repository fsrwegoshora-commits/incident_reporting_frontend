import 'package:flutter/material.dart';

class AppTheme {
  // ========== PRIMARY COLOR PALETTE ==========
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueLight = Color(0xFF5E92F3);
  static const Color primaryBlueDark = Color(0xFF003C8F);

  // ========== SECONDARY COLORS ==========
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color accentOrangeLight = Color(0xFFFF9F40);
  static const Color accentOrangeDark = Color(0xFFC43E00);

  // ========== NEUTRAL COLORS ==========
  static const Color surfaceWhite = Color(0xFFFAFAFA);
  static const Color surfaceGrey = Color(0xFFF5F5F5);
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color borderColor = Color(0xFFE1E1E1);

  // ========== STATUS COLORS ==========
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color successGreenLight = Color(0xFF81C784);
  static const Color successGreenDark = Color(0xFF388E3C);

  static const Color warningAmber = Color(0xFFFF9800);
  static const Color warningAmberLight = Color(0xFFFFB74D);
  static const Color warningAmberDark = Color(0xFFF57C00);

  static const Color errorRed = Color(0xFFE53935);
  static const Color errorRedLight = Color(0xFFEF5350);
  static const Color errorRedDark = Color(0xFFD32F2F);

  static const Color infoBlue = Color(0xFF2196F3);
  static const Color infoBlueLight = Color(0xFF64B5F6);
  static const Color infoBlueDark = Color(0xFF1976D2);

  // ========== GRADIENT DEFINITIONS ==========
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
    stops: [0.0, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardWhite, surfaceGrey],
    stops: [0.0, 1.0],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successGreen, successGreenDark],
    stops: [0.0, 1.0],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warningAmber, warningAmberDark],
    stops: [0.0, 1.0],
  );

  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [errorRed, errorRedDark],
    stops: [0.0, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentOrange, accentOrangeDark],
    stops: [0.0, 1.0],
  );

  static const LinearGradient acceptGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.teal, Colors.tealAccent],
    stops: [0.0, 1.0],
  );

  static const LinearGradient infoBlueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [infoBlue, infoBlueDark],
    stops: [0.0, 1.0],
  );

  // ========== TEXT STYLES ==========
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.0,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.25,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.4,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.5,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
    height: 1.2,
  );

  // ========== BUTTON TEXT STYLES ==========
  static const TextStyle buttonTextLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: cardWhite,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonTextMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: cardWhite,
    letterSpacing: 0.25,
  );

  static const TextStyle buttonTextSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: cardWhite,
    letterSpacing: 0.4,
  );

  // ========== SHADOWS ==========
  static const BoxShadow lightShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 1),
    spreadRadius: 0,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
    spreadRadius: 0,
  );

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x1F000000),
    blurRadius: 16,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );

  static const BoxShadow deepShadow = BoxShadow(
    color: Color(0x29000000),
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: 0,
  );

  // ========== BORDER RADIUS ==========
  static const BorderRadius extraSmallRadius = BorderRadius.all(Radius.circular(4));
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(50));

  // ========== SPACING CONSTANTS ==========
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // ========== ANIMATION DURATIONS ==========
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // ========== COMMON DECORATIONS ==========
  static BoxDecoration get primaryCardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: cardRadius,
    boxShadow: [cardShadow],
    border: Border.all(color: borderColor.withOpacity(0.1)),
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: cardRadius,
    boxShadow: [elevatedShadow],
  );

  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: buttonRadius,
    boxShadow: [cardShadow],
  );

  static BoxDecoration get successButtonDecoration => BoxDecoration(
    gradient: successGradient,
    borderRadius: buttonRadius,
    boxShadow: [cardShadow],
  );

  static BoxDecoration get errorButtonDecoration => BoxDecoration(
    gradient: errorGradient,
    borderRadius: buttonRadius,
    boxShadow: [cardShadow],
  );

  static BoxDecoration get warningButtonDecoration => BoxDecoration(
    gradient: warningGradient,
    borderRadius: buttonRadius,
    boxShadow: [cardShadow],
  );

  // ========== INPUT DECORATIONS ==========
  static InputDecoration getInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconPressed,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: textSecondary) : null,
      suffixIcon: suffixIcon != null
          ? IconButton(
        icon: Icon(suffixIcon, color: textSecondary),
        onPressed: onSuffixIconPressed,
      )
          : null,
      border: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: BorderSide(color: errorRed, width: 2),
      ),
      filled: true,
      fillColor: surfaceWhite,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: bodyMedium,
      hintStyle: bodyMedium.copyWith(color: textSecondary.withOpacity(0.6)),
    );
  }

  // ========== HELPER METHODS ==========
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'COMPLETED':
      case 'RESOLVED':
        return successGreen;
      case 'WARNING':
      case 'PENDING':
      case 'IN_PROGRESS':
        return warningAmber;
      case 'ERROR':
      case 'FAILED':
      case 'CANCELLED':
        return errorRed;
      case 'INFO':
      case 'NEW':
        return infoBlue;
      default:
        return textSecondary;
    }
  }

  static LinearGradient getStatusGradient(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
      case 'COMPLETED':
      case 'RESOLVED':
        return successGradient;
      case 'WARNING':
      case 'PENDING':
      case 'IN_PROGRESS':
        return warningGradient;
      case 'ERROR':
      case 'FAILED':
      case 'CANCELLED':
        return errorGradient;
      default:
        return primaryGradient;
    }
  }

  static ThemeData get lightTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: surfaceWhite,
    cardColor: cardWhite,
    dividerColor: dividerColor,
    textTheme: TextTheme(
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: cardWhite,
      elevation: 0,
      titleTextStyle: titleLarge.copyWith(color: cardWhite),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: cardWhite,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        textStyle: buttonTextMedium,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: cardWhite,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: primaryBlue,
      unselectedItemColor: textSecondary,
      backgroundColor: cardWhite,
      elevation: 8,
    ),
  );
}