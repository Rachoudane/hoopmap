import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/app.dart';
import 'package:hoopmap/features/courts/presentation/pages/court_detail_page.dart';

void main() {
  testWidgets('displays the 3 fake courts and navigates to detail on tap', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HoopmapApp()));
    await tester.pumpAndSettle();

    expect(find.text('Terrain A'), findsOneWidget);
    expect(find.text('Terrain B'), findsOneWidget);
    expect(find.text('Terrain C'), findsOneWidget);

    await tester.tap(find.text('Terrain A'));
    await tester.pumpAndSettle();

    expect(find.byType(CourtDetailPage), findsOneWidget);
  });
}
