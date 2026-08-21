import 'package:flutter/material.dart';

/// Street-basketball palette: ball orange as the single primary accent, a
/// muted court teal as the one secondary accent, asphalt darks and chalk
/// off-whites for surfaces. Every other widget in the app should read its
/// colors from [Theme.of(context).colorScheme] (or [AppColors] only where a
/// token has no `ColorScheme` slot) rather than hard-coding values.
abstract final class AppColors {
  static const Color ballOrange = Color(0xFFF2661A);
  static const Color ballOrangeLight = Color(0xFFFF8A47);
  static const Color courtTeal = Color(0xFF1FA6A0);
  static const Color courtTealLight = Color(0xFF4BC9C3);

  static const Color asphalt = Color(0xFF14171B);
  static const Color asphaltSurface = Color(0xFF1D2126);
  static const Color asphaltSurfaceElevated = Color(0xFF262B31);
  static const Color asphaltOutline = Color(0xFF3A4048);

  static const Color chalk = Color(0xFFF6F3EE);
  static const Color chalkSurface = Color(0xFFFFFFFF);
  static const Color chalkSurfaceElevated = Color(0xFFFBF9F5);
  static const Color chalkOutline = Color(0xFFDDD8CF);

  static const Color textDark = Color(0xFF1A1A18);
  static const Color textDarkSecondary = Color(0xFF5B5F66);
  static const Color textLight = Color(0xFFF2F0EC);
  static const Color textLightSecondary = Color(0xFFA7ACB3);

  static const Color error = Color(0xFFD6432E);
  static const Color errorDark = Color(0xFFFF6B57);

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: ballOrange,
    onPrimary: Colors.white,
    secondary: courtTeal,
    onSecondary: Colors.white,
    error: error,
    onError: Colors.white,
    surface: chalkSurface,
    onSurface: textDark,
    surfaceContainerHighest: chalkSurfaceElevated,
    onSurfaceVariant: textDarkSecondary,
    outline: chalkOutline,
    outlineVariant: chalkOutline,
    inverseSurface: asphaltSurface,
    onInverseSurface: textLight,
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: ballOrangeLight,
    onPrimary: asphalt,
    secondary: courtTealLight,
    onSecondary: asphalt,
    error: errorDark,
    onError: asphalt,
    surface: asphaltSurface,
    onSurface: textLight,
    surfaceContainerHighest: asphaltSurfaceElevated,
    onSurfaceVariant: textLightSecondary,
    outline: asphaltOutline,
    outlineVariant: asphaltOutline,
    inverseSurface: chalkSurface,
    onInverseSurface: textDark,
  );
}
