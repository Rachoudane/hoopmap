/// Spacing, radius and elevation tokens, defined once and reused everywhere
/// so no widget hard-codes its own magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class AppElevation {
  static const double flat = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 6;
}

/// Minimum tappable size (Android/Material accessibility guidance).
abstract final class AppTouchTarget {
  static const double minimum = 48;
}
