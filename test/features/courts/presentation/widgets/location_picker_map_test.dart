import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/presentation/widgets/location_picker_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'does not overflow when embedded in a narrow container (regression: '
    'the previous SimpleAttributionWidget-based attribution overflowed by '
    'a few pixels when this map was embedded in AddCourtPage, narrower '
    'than a full-screen map)',
    (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 220,
                child: LocationPickerMap(
                  mapController: controller,
                  initialCenter: const LatLng(48.8566, 2.3522),
                  onCenterChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
