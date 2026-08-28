import 'package:flutter/material.dart';

/// The "you are here" dot.
///
/// Deliberately not shaped like [CourtMarker]: it is not a place the user can
/// tap or travel to, it is where they already are. A small ringed disc in the
/// scheme's secondary colour reads as "me" against the orange court markers
/// without competing with them for attention.
class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key});

  static const double size = 18;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            shape: BoxShape.circle,
            // A white ring keeps the dot legible over dark tiles (parks,
            // water) as well as light ones.
            border: Border.all(color: colorScheme.surface, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
