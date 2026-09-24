import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale from DESIGN.md. Inter for UI, JetBrains Mono for quantities/formulas.
class AppText {
  AppText._();

  static TextStyle _inter(double size, FontWeight w, double line,
          {double ls = 0, Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
          fontSize: size, fontWeight: w, height: line / size, letterSpacing: ls, color: color);

  static TextStyle _mono(double size, FontWeight w, double line,
          {double ls = 0, Color color = AppColors.onSurface}) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, fontWeight: w, height: line / size, letterSpacing: ls, color: color);

  static TextStyle get headlineLg => _inter(28, FontWeight.w700, 34, ls: -0.56);
  static TextStyle get headlineMd => _inter(22, FontWeight.w600, 28, ls: -0.22);
  static TextStyle get headlineSm => _inter(18, FontWeight.w600, 24);
  static TextStyle get titleMd => _inter(15, FontWeight.w600, 20);
  static TextStyle get titleSm => _inter(13, FontWeight.w600, 18);
  static TextStyle get bodyLg => _inter(15, FontWeight.w400, 22);
  static TextStyle get bodyMd => _inter(13, FontWeight.w400, 18);
  static TextStyle get bodySm => _inter(11, FontWeight.w400, 16);
  static TextStyle get monoLg => _mono(14, FontWeight.w500, 18, ls: -0.14);
  static TextStyle get monoMd => _mono(12, FontWeight.w500, 16);
  static TextStyle get monoSm => _mono(10, FontWeight.w500, 14, ls: 0.2);
}

class AppDeco {
  AppDeco._();

  /// "Level 1" card: white, hairline shadow (DESIGN.md Elevation).
  static BoxDecoration card({Color color = AppColors.surfaceLowest, double radius = 12}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 2, offset: Offset(0, 1))],
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.interTextTheme()
          .apply(bodyColor: AppColors.onSurface, displayColor: AppColors.onSurface),
      dividerColor: AppColors.hairline,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLowest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
        suffixStyle: AppText.monoSm.copyWith(color: AppColors.outline),
        border: border(AppColors.hairline),
        enabledBorder: border(AppColors.hairline),
        focusedBorder: border(AppColors.primaryContainer, 1.6),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppText.bodyMd.copyWith(color: AppColors.inverseOnSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppText.titleSm,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
