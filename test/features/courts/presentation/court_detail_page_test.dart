import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/domain/court.dart';
import 'package:hoopmap/features/courts/presentation/court_detail_provider.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';

const _courtId = 'court-a';

Court _court() => Court(
  id: _courtId,
  name: 'Terrain Central',
  latitude: 48.8566,
  longitude: 2.3522,
  hoopCount: 4,
  isOutdoor: true,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets('displays the name, hoop count and indoor/outdoor information', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(
            _courtId,
          ).overrideWith((ref) => Stream.value(_court())),
        ],
        child: const MaterialApp(home: CourtDetailPage(courtId: _courtId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terrain Central'), findsOneWidget);
    expect(find.text('4 panier(s)'), findsOneWidget);
    expect(find.text('Terrain extérieur'), findsOneWidget);
  });

  testWidgets('displays an error message instead of an empty screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courtDetailProvider(
            _courtId,
          ).overrideWith((ref) => Stream.error(Exception('boom'))),
        ],
        child: const MaterialApp(home: CourtDetailPage(courtId: _courtId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Erreur'), findsOneWidget);
    expect(find.text('Terrain Central'), findsNothing);
  });
}
