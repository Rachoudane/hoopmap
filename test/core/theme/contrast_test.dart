import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/core/theme/app_colors.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// The WCAG contrast ratio between two opaque colours, 1:1 to 21:1.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// AA for body text.
const double _textThreshold = 4.5;

/// AA for large text, icons and the outlines that carry a shape.
const double _nonTextThreshold = 3.0;

void _expectContrast(
  Color foreground,
  Color background, {
  required String pair,
  required double atLeast,
}) {
  final ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(atLeast),
    reason:
        '$pair is ${ratio.toStringAsFixed(2)}:1, under the '
        '${atLeast.toStringAsFixed(1)}:1 threshold',
  );
}

/// Both palettes, each with the background the scaffold actually paints
/// behind them — which is not a `ColorScheme` slot, so it has to come along.
const List<(String, ColorScheme, Color)> _schemes = [
  ('light', AppColors.light, AppColors.chalk),
  ('dark', AppColors.dark, AppColors.asphalt),
];

void main() {
  // Computed from lib/core/theme/app_colors.dart itself, so the numbers
  // cannot drift from the palette the app ships — which is what
  // tool/check_contrast.py, with its hand-copied hexes, cannot promise.
  group('palette contrast', () {
    for (final (name, scheme, scaffold) in _schemes) {
      group(name, () {
        test('body text is readable on every surface it lands on', () {
          _expectContrast(
            scheme.onSurface,
            scheme.surface,
            pair: '$name onSurface on surface',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.onSurface,
            scaffold,
            pair: '$name onSurface on the scaffold',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.onSurface,
            scheme.surfaceContainerHighest,
            pair: '$name onSurface on a raised surface',
            atLeast: _textThreshold,
          );
        });

        test('secondary text is readable too, being text', () {
          _expectContrast(
            scheme.onSurfaceVariant,
            scheme.surface,
            pair: '$name onSurfaceVariant on surface',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.onSurfaceVariant,
            scaffold,
            pair: '$name onSurfaceVariant on the scaffold',
            atLeast: _textThreshold,
          );
        });

        test('labels on filled buttons are readable', () {
          _expectContrast(
            scheme.onPrimary,
            scheme.primary,
            pair: '$name onPrimary on primary',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.onSecondary,
            scheme.secondary,
            pair: '$name onSecondary on secondary',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.onError,
            scheme.error,
            pair: '$name onError on error',
            atLeast: _textThreshold,
          );
        });

        test('accent-coloured text on the app\'s own surfaces is readable', () {
          // The distance on a court card, the price-free "primary" text the
          // app uses as emphasis: it is text, so it clears the text bar.
          _expectContrast(
            scheme.primary,
            scheme.surface,
            pair: '$name primary text on surface',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.primary,
            scaffold,
            pair: '$name primary text on the scaffold',
            atLeast: _textThreshold,
          );
          _expectContrast(
            scheme.error,
            scheme.surface,
            pair: '$name error text on surface',
            atLeast: _textThreshold,
          );
        });

        test('outlines that carry a shape stand on their own', () {
          // Text fields, outlined buttons, pills: not text, so 3:1 — but
          // they have to be visible, which outlineVariant (a divider) does
          // not have to be.
          _expectContrast(
            scheme.outline,
            scaffold,
            pair: '$name outline on the scaffold',
            atLeast: _nonTextThreshold,
          );
          _expectContrast(
            scheme.outline,
            scheme.surface,
            pair: '$name outline on surface',
            atLeast: _nonTextThreshold,
          );
          // The tightest of the three, and the one a card or a dialog
          // actually paints behind a text field.
          _expectContrast(
            scheme.outline,
            scheme.surfaceContainerHighest,
            pair: '$name outline on a raised surface',
            atLeast: _nonTextThreshold,
          );
        });

        test('the inverse surface used by snack bars is readable', () {
          _expectContrast(
            scheme.onInverseSurface,
            scheme.inverseSurface,
            pair: '$name onInverseSurface on inverseSurface',
            atLeast: _textThreshold,
          );
        });
      });
    }
  });

  group('contrastRatio', () {
    test('is 21:1 between black and white', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('is 1:1 for a colour against itself, whichever way round', () {
      const color = Color(0xFF3A7BD5);
      expect(contrastRatio(color, color), closeTo(1, 0.001));
      expect(
        contrastRatio(AppColors.ballOrange, AppColors.chalk),
        closeTo(contrastRatio(AppColors.chalk, AppColors.ballOrange), 0.001),
      );
    });
  });
}
