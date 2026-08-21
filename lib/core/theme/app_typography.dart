import 'package:flutter/material.dart';

/// Two-family type system: Oswald (condensed, sporty) for headings and
/// titles, Inter (neutral, highly legible) for body and label text. Both
/// are bundled under assets/fonts/ and declared in pubspec.yaml, so nothing
/// is downloaded at runtime.
abstract final class AppTypography {
  static const String headingFontFamily = 'Oswald';
  static const String bodyFontFamily = 'Inter';

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 40,
        height: 1.15,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 32,
        height: 1.18,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        height: 1.2,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 26,
        height: 1.2,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        height: 1.22,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 20,
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 19,
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.35,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.45,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
        color: onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.3,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 1.3,
        letterSpacing: 0.3,
        color: onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 1.3,
        letterSpacing: 0.3,
        color: onSurfaceVariant,
      ),
    );
    return base;
  }
}
