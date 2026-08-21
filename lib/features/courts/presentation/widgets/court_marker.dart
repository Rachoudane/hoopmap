import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Custom map marker: an orange disc with a basketball glyph, replacing
/// flutter_map's default red pin.
class CourtMarker extends StatelessWidget {
  const CourtMarker({super.key, required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = selected ? 44.0 : 36.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // The visual disc is smaller than 48dp; centering it in a fixed
      // 48x48 box keeps the *tappable* area at the minimum touch target
      // without changing how the marker looks.
      child: SizedBox(
        width: AppTouchTarget.minimum,
        height: AppTouchTarget.minimum,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surface,
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.sports_basketball,
              color: colorScheme.onPrimary,
              size: selected ? 24 : 18,
            ),
          ),
        ),
      ),
    );
  }
}
