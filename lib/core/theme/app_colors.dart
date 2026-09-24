import 'package:flutter/material.dart';

/// Design tokens taken from the Stitch export (DESIGN.md front-matter + tailwind config).
class AppColors {
  AppColors._();

  static const surface = Color(0xFFFAF8FF);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF2F3FF);
  static const surfaceContainer = Color(0xFFEAEDFF);
  static const surfaceHigh = Color(0xFFE2E7FF);
  static const surfaceHighest = Color(0xFFDAE2FD);

  static const onSurface = Color(0xFF131B2E);
  static const onSurfaceVariant = Color(0xFF3E4947);
  static const outline = Color(0xFF6E7977);
  static const outlineVariant = Color(0xFFBDC9C6);

  static const primary = Color(0xFF005C55);
  static const primaryContainer = Color(0xFF0F766E);
  static const onPrimaryContainer = Color(0xFFA3FAEF);
  static const primaryFixed = Color(0xFF9CF2E8);
  static const onPrimaryFixed = Color(0xFF00201D);

  static const secondary = Color(0xFF006399);
  static const secondaryContainer = Color(0xFF7BC2FF);
  static const onSecondaryContainer = Color(0xFF004F7B);

  static const tertiary = Color(0xFF005E40);
  static const tertiaryContainer = Color(0xFF007954);
  static const tertiaryFixed = Color(0xFF85F8C4);
  static const onTertiaryFixed = Color(0xFF002114);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const inverseSurface = Color(0xFF283044);
  static const inverseOnSurface = Color(0xFFEEF0FF);

  // Stock alert tints (DESIGN.md "State & Stock Alert Tints").
  static const okFg = Color(0xFF059669);
  static const okBg = Color(0xFFD1FAE5);
  static const warnFg = Color(0xFFD97706);
  static const warnBg = Color(0xFFFEF3C7);
  static const critFg = Color(0xFFE11D48);
  static const critBg = Color(0xFFFFE4E6);

  static const hairline = Color(0xFFE2E8F0);
}
