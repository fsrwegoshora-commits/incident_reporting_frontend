import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Brand ────────────────────────────────────────────────────────────────
  static const Color primaryBlue     = Color(0xFF1565C0);
  static const Color primaryBlueLight= Color(0xFF5E92F3);
  static const Color primaryBlueDark = Color(0xFF003C8F);

  // ─── Untitled-UI Gray Scale ───────────────────────────────────────────────
  static const Color gray25  = Color(0xFFFCFCFD);
  static const Color gray50  = Color(0xFFF9FAFB);   // page background
  static const Color gray100 = Color(0xFFF3F4F6);   // subtle surface
  static const Color gray200 = Color(0xFFE4E7EC);   // borders / dividers
  static const Color gray300 = Color(0xFFD0D5DD);   // input borders
  static const Color gray400 = Color(0xFF98A2B3);   // placeholder
  static const Color gray500 = Color(0xFF667085);   // secondary text
  static const Color gray600 = Color(0xFF475467);   // tertiary text
  static const Color gray700 = Color(0xFF344054);   // strong secondary
  static const Color gray800 = Color(0xFF1D2939);
  static const Color gray900 = Color(0xFF101828);   // primary text

  // ─── Legacy aliases (keeps old code compiling) ───────────────────────────
  static const Color surfaceWhite   = gray25;
  static const Color surfaceGrey    = gray50;
  static const Color cardWhite      = Colors.white;
  static const Color textPrimary    = gray900;
  static const Color textSecondary  = gray500;
  static const Color dividerColor   = gray200;
  static const Color borderColor    = gray300;

  // ─── Secondary accent ─────────────────────────────────────────────────────
  static const Color accentOrange     = Color(0xFFFF6F00);
  static const Color accentOrangeLight= Color(0xFFFF9F40);
  static const Color accentOrangeDark = Color(0xFFC43E00);

  // ─── Status – Untitled-UI palette ─────────────────────────────────────────
  static const Color successGreen      = Color(0xFF039855);
  static const Color successGreenLight = Color(0xFF6CE9A6);
  static const Color successGreenDark  = Color(0xFF027A48);
  static const Color successBg         = Color(0xFFECFDF3);

  static const Color warningAmber      = Color(0xFFF79009);
  static const Color warningAmberLight = Color(0xFFFEC84B);
  static const Color warningAmberDark  = Color(0xFFB54708);
  static const Color warningBg         = Color(0xFFFFFAEB);

  static const Color errorRed          = Color(0xFFF04438);
  static const Color errorRedLight     = Color(0xFFFDA29B);
  static const Color errorRedDark      = Color(0xFFB42318);
  static const Color errorBg           = Color(0xFFFEF3F2);

  static const Color infoBlue          = Color(0xFF0BA5EC);
  static const Color infoBlueLight     = Color(0xFF7CD4FD);
  static const Color infoBlueDark      = Color(0xFF026AA2);
  static const Color infoBg            = Color(0xFFF0F9FF);

  // ─── Spacing ───────────────────────────────────────────────────────────────
  static const double spaceXS  = 4.0;
  static const double spaceS   = 8.0;
  static const double spaceM   = 16.0;
  static const double spaceL   = 24.0;
  static const double spaceXL  = 32.0;
  static const double spaceXXL = 48.0;

  // ─── Border radius ─────────────────────────────────────────────────────────
  static const BorderRadius extraSmallRadius = BorderRadius.all(Radius.circular(4));
  static const BorderRadius smallRadius      = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius     = BorderRadius.all(Radius.circular(10));
  static const BorderRadius cardRadius       = BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius      = BorderRadius.all(Radius.circular(16));
  static const BorderRadius buttonRadius     = BorderRadius.all(Radius.circular(8));
  static const BorderRadius pillRadius       = BorderRadius.all(Radius.circular(50));

  // ─── Animation ─────────────────────────────────────────────────────────────
  static const Duration fastAnimation   = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 250);
  static const Duration slowAnimation   = Duration(milliseconds: 400);

  // ─── Shadows ───────────────────────────────────────────────────────────────
  // Untitled UI uses very subtle single shadows
  static const BoxShadow lightShadow = BoxShadow(
    color: Color(0x08101828),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0F101828),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x14101828),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const BoxShadow deepShadow = BoxShadow(
    color: Color(0x1A101828),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
  // Dark shadows (kept for dark-theme consumers)
  static const BoxShadow darkLightShadow    = BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 4,  offset: Offset(0, 1));
  static const BoxShadow darkCardShadow     = BoxShadow(color: Color(0x29000000), blurRadius: 8,  offset: Offset(0, 2));
  static const BoxShadow darkElevatedShadow = BoxShadow(color: Color(0x3F000000), blurRadius: 16, offset: Offset(0, 4));

  // ─── Gradients (kept for gradient consumers) ──────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
  );
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [cardWhite, gray50],
  );
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [successGreen, successGreenDark],
  );
  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [warningAmber, warningAmberDark],
  );
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [errorRed, errorRedDark],
  );
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accentOrange, accentOrangeDark],
  );
  static const LinearGradient acceptGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Colors.teal, Colors.tealAccent],
  );
  static const LinearGradient infoBlueGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [infoBlue, infoBlueDark],
  );

  // ─── Dark theme tokens ─────────────────────────────────────────────────────
  static const Color darkBackground    = Color(0xFF0C111D);
  static const Color darkSurface       = Color(0xFF161B26);
  static const Color darkCard          = Color(0xFF1F242F);
  static const Color darkBorder        = Color(0xFF333741);
  static const Color darkDivider       = Color(0xFF1F242F);
  static const Color darkTextPrimary   = Color(0xFFF5F5F6);
  static const Color darkTextSecondary = Color(0xFF94969C);

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
  );
  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [darkCard, darkSurface],
  );
  static const LinearGradient darkSuccessGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF027A48), Color(0xFF054F31)],
  );

  // ─── Card decorations ──────────────────────────────────────────────────────
  /// Standard white card: white bg + gray-200 border + subtle shadow
  static BoxDecoration get elevatedCardDecoration => const BoxDecoration(
    color: cardWhite,
    borderRadius: cardRadius,
    border: Border.fromBorderSide(BorderSide(color: gray200)),
    boxShadow: [lightShadow],
  );

  static BoxDecoration get primaryCardDecoration => const BoxDecoration(
    color: cardWhite,
    borderRadius: cardRadius,
    border: Border.fromBorderSide(BorderSide(color: gray200)),
    boxShadow: [cardShadow],
  );

  // Dark equivalents
  static BoxDecoration get darkElevatedCardDecoration => const BoxDecoration(
    color: darkCard,
    borderRadius: cardRadius,
    border: Border.fromBorderSide(BorderSide(color: darkBorder)),
    boxShadow: [darkCardShadow],
  );
  static BoxDecoration get darkPrimaryCardDecoration => darkElevatedCardDecoration;

  // ─── Button decorations (kept for legacy, new code uses AppButton) ────────
  static BoxDecoration get primaryButtonDecoration => const BoxDecoration(
    color: primaryBlue, borderRadius: buttonRadius,
    boxShadow: [lightShadow],
  );
  static BoxDecoration get successButtonDecoration => const BoxDecoration(
    color: successGreen, borderRadius: buttonRadius,
    boxShadow: [lightShadow],
  );
  static BoxDecoration get errorButtonDecoration => const BoxDecoration(
    color: errorRed, borderRadius: buttonRadius,
    boxShadow: [lightShadow],
  );
  static BoxDecoration get warningButtonDecoration => const BoxDecoration(
    color: warningAmber, borderRadius: buttonRadius,
    boxShadow: [lightShadow],
  );
  static BoxDecoration get accentButtonDecoration => const BoxDecoration(
    color: accentOrange, borderRadius: buttonRadius,
    boxShadow: [lightShadow],
  );
  static BoxDecoration get darkPrimaryButtonDecoration => const BoxDecoration(
    gradient: darkPrimaryGradient, borderRadius: buttonRadius,
  );

  // ─── Text styles ───────────────────────────────────────────────────────────
  // Inter is applied at the ThemeData level; these act as size/weight tokens.
  static const TextStyle displayLarge  = TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: gray900, letterSpacing: -0.72, height: 1.22);
  static const TextStyle headlineLarge = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: gray900, letterSpacing: -0.6,  height: 1.27);
  static const TextStyle headlineMedium= TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: gray900, letterSpacing: -0.48, height: 1.33);
  static const TextStyle headlineSmall = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: gray900, letterSpacing: -0.4,  height: 1.35);

  static const TextStyle titleLarge  = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: gray900, letterSpacing: -0.18, height: 1.44);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: gray900, letterSpacing: -0.16, height: 1.5);
  static const TextStyle titleSmall  = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: gray700, letterSpacing: 0,     height: 1.43);

  static const TextStyle bodyLarge   = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: gray700, height: 1.5);
  static const TextStyle bodyMedium  = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: gray500, height: 1.43);
  static const TextStyle bodySmall   = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: gray500, height: 1.5);

  static const TextStyle labelLarge  = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: gray700, height: 1.43);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gray700, height: 1.5);
  static const TextStyle labelSmall  = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: gray500, height: 1.45);

  static const TextStyle buttonTextLarge  = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cardWhite, letterSpacing: 0.1);
  static const TextStyle buttonTextMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cardWhite, letterSpacing: 0.1);
  static const TextStyle buttonTextSmall  = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cardWhite, letterSpacing: 0.1);

  // Dark text
  static const TextStyle darkHeadlineLarge = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: darkTextPrimary, letterSpacing: -0.6,  height: 1.27);
  static const TextStyle darkHeadlineMedium= TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: darkTextPrimary, letterSpacing: -0.48, height: 1.33);
  static const TextStyle darkHeadlineSmall = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary, letterSpacing: -0.4,  height: 1.35);
  static const TextStyle darkTitleLarge  = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary, height: 1.44);
  static const TextStyle darkTitleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary, height: 1.5);
  static const TextStyle darkTitleSmall  = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary, height: 1.43);
  static const TextStyle darkBodyLarge   = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary, height: 1.5);
  static const TextStyle darkBodyMedium  = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: darkTextSecondary, height: 1.43);
  static const TextStyle darkBodySmall   = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: darkTextSecondary, height: 1.5);

  // ─── Input decoration ──────────────────────────────────────────────────────
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
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 18, color: gray400)
          : null,
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, size: 18, color: gray400),
              onPressed: onSuffixIconPressed,
            )
          : null,
      border: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: gray300)),
      enabledBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: gray300)),
      focusedBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: errorRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: errorRed, width: 1.5)),
      filled: true,
      fillColor: cardWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(fontSize: 14, color: gray500, fontWeight: FontWeight.w400),
      hintStyle: const TextStyle(fontSize: 14, color: gray400),
      errorStyle: const TextStyle(fontSize: 12, color: errorRed),
    );
  }

  static InputDecoration getDarkInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconPressed,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: darkTextSecondary) : null,
      suffixIcon: suffixIcon != null
          ? IconButton(icon: Icon(suffixIcon, size: 18, color: darkTextSecondary), onPressed: onSuffixIconPressed)
          : null,
      border: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: darkBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: darkBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: primaryBlueLight, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: errorRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: errorRed, width: 1.5)),
      filled: true,
      fillColor: darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(fontSize: 14, color: darkTextSecondary),
      hintStyle: TextStyle(fontSize: 14, color: darkTextSecondary.withOpacity(0.5)),
      errorStyle: const TextStyle(fontSize: 12, color: errorRed),
    );
  }

  static InputDecoration getAdaptiveInputDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixIconPressed,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? getDarkInputDecoration(labelText: labelText, hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon, onSuffixIconPressed: onSuffixIconPressed)
        : getInputDecoration(labelText: labelText, hintText: hintText, prefixIcon: prefixIcon, suffixIcon: suffixIcon, onSuffixIconPressed: onSuffixIconPressed);
  }

  // ─── Status helpers ────────────────────────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS': case 'COMPLETED': case 'RESOLVED': case 'ACTIVE':
        return successGreen;
      case 'WARNING': case 'PENDING': case 'IN_PROGRESS':
        return warningAmber;
      case 'ERROR': case 'FAILED': case 'CANCELLED':
        return errorRed;
      case 'INFO': case 'NEW':
        return infoBlue;
      default:
        return gray400;
    }
  }

  static Color getStatusBg(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS': case 'COMPLETED': case 'RESOLVED': case 'ACTIVE':
        return successBg;
      case 'WARNING': case 'PENDING': case 'IN_PROGRESS':
        return warningBg;
      case 'ERROR': case 'FAILED': case 'CANCELLED':
        return errorBg;
      case 'INFO': case 'NEW':
        return infoBg;
      default:
        return gray100;
    }
  }

  static LinearGradient getStatusGradient(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS': case 'COMPLETED': case 'RESOLVED':
        return successGradient;
      case 'WARNING': case 'PENDING': case 'IN_PROGRESS':
        return warningGradient;
      case 'ERROR': case 'FAILED': case 'CANCELLED':
        return errorGradient;
      default:
        return primaryGradient;
    }
  }

  // ─── Theme-aware helpers ───────────────────────────────────────────────────
  static Color getBackgroundColor(BuildContext context)   => Theme.of(context).brightness == Brightness.dark ? darkBackground  : gray50;
  static Color getSurfaceColor(BuildContext context)      => Theme.of(context).brightness == Brightness.dark ? darkSurface     : cardWhite;
  static Color getCardColor(BuildContext context)         => Theme.of(context).brightness == Brightness.dark ? darkCard        : cardWhite;
  static Color getTextPrimaryColor(BuildContext context)  => Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : gray900;
  static Color getTextSecondaryColor(BuildContext context)=> Theme.of(context).brightness == Brightness.dark ? darkTextSecondary: gray500;
  static Color getBorderColor(BuildContext context)       => Theme.of(context).brightness == Brightness.dark ? darkBorder      : gray200;

  static BoxDecoration getCardDecoration(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPrimaryCardDecoration : primaryCardDecoration;
  static BoxDecoration getElevatedCardDecoration(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkElevatedCardDecoration : elevatedCardDecoration;

  // ─── Light ThemeData ───────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: gray50,
      cardColor: cardWhite,
      dividerColor: gray200,
      canvasColor: gray50,
      dialogBackgroundColor: cardWhite,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: base.copyWith(
        displayLarge:  base.displayLarge?.merge(headlineLarge),
        headlineLarge: base.headlineLarge?.merge(headlineLarge),
        headlineMedium:base.headlineMedium?.merge(headlineMedium),
        headlineSmall: base.headlineSmall?.merge(headlineSmall),
        titleLarge:    base.titleLarge?.merge(titleLarge),
        titleMedium:   base.titleMedium?.merge(titleMedium),
        titleSmall:    base.titleSmall?.merge(titleSmall),
        bodyLarge:     base.bodyLarge?.merge(bodyLarge),
        bodyMedium:    base.bodyMedium?.merge(bodyMedium),
        bodySmall:     base.bodySmall?.merge(bodySmall),
        labelLarge:    base.labelLarge?.merge(labelLarge),
        labelMedium:   base.labelMedium?.merge(labelMedium),
        labelSmall:    base.labelSmall?.merge(labelSmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: cardWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: cardWhite),
        iconTheme: const IconThemeData(color: cardWhite, size: 22),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: cardWhite,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: gray300),
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardWhite,
        border: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: gray300)),
        enabledBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: gray300)),
        focusedBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: errorRed, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(fontSize: 14, color: gray500),
        hintStyle: const TextStyle(fontSize: 14, color: gray400),
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: const BorderSide(color: gray200),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: gray200, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: gray100,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gray700),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: pillRadius, side: const BorderSide(color: gray200)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: cardWhite,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryBlue,
        unselectedItemColor: gray400,
        backgroundColor: cardWhite,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: cardWhite,
        secondary: accentOrange,
        onSecondary: cardWhite,
        surface: cardWhite,
        onSurface: gray900,
        background: gray50,
        onBackground: gray900,
        error: errorRed,
        onError: cardWhite,
        outline: gray300,
        surfaceVariant: gray100,
      ),
    );
  }

  // ─── Dark ThemeData ────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryBlueLight,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkBorder,
      canvasColor: darkSurface,
      dialogBackgroundColor: darkCard,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: base.copyWith(
        headlineLarge: base.headlineLarge?.merge(darkHeadlineLarge),
        headlineMedium:base.headlineMedium?.merge(darkHeadlineMedium),
        headlineSmall: base.headlineSmall?.merge(darkHeadlineSmall),
        titleLarge:    base.titleLarge?.merge(darkTitleLarge),
        titleMedium:   base.titleMedium?.merge(darkTitleMedium),
        titleSmall:    base.titleSmall?.merge(darkTitleSmall),
        bodyLarge:     base.bodyLarge?.merge(darkBodyLarge),
        bodyMedium:    base.bodyMedium?.merge(darkBodyMedium),
        bodySmall:     base.bodySmall?.merge(darkBodySmall),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: darkTextPrimary),
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 22),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlueLight,
          foregroundColor: darkTextPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: darkBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: buttonRadius, borderSide: const BorderSide(color: primaryBlueLight, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(fontSize: 14, color: darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius, side: const BorderSide(color: darkBorder)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlueLight,
        foregroundColor: darkTextPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryBlueLight,
        unselectedItemColor: darkTextSecondary,
        backgroundColor: darkSurface,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlueLight,
        onPrimary: darkTextPrimary,
        secondary: accentOrangeLight,
        surface: darkCard,
        onSurface: darkTextPrimary,
        background: darkBackground,
        onBackground: darkTextPrimary,
        error: errorRed,
        outline: darkBorder,
      ),
    );
  }
}
