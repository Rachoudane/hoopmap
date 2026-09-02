import 'package:flutter/material.dart';

/// Caps content at a comfortable reading width and centres it.
///
/// A tablet in landscape hands the app 1112 logical pixels. Nothing here is
/// a spreadsheet: a paragraph, a form field or a court card stretched across
/// all of it gives lines the eye loses track of halfway, and buttons that
/// reach from one bezel to the other. On a phone the cap is never reached,
/// so this is invisible where most of the users are.
///
/// Not applied to the map, which is the one thing in the app that genuinely
/// wants every pixel.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = defaultMaxWidth,
  });

  /// Wide enough for a court card and a form field, short enough that a
  /// paragraph stays one comfortable line-length.
  static const double defaultMaxWidth = 640;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
