import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';

/// The OpenStreetMap credit, in a form that survives a narrow screen.
///
/// Not `SimpleAttributionWidget`: it lays its content out in a Row with no
/// constraint, so on a 320 dp phone it overflows the map by a few hundred
/// pixels — and an attribution the app is legally required to show is the
/// last thing that should be replaced by warning stripes. This one clips
/// gracefully instead, and says the same thing.
///
/// The colours are deliberately fixed rather than themed: this sits on map
/// tiles, which look the same whichever theme the app is in.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: const Text(
          AppStrings.openStreetMapAttribution,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
