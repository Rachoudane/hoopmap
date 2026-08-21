import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopmap/features/courts/data/commons_attribution.dart';
import 'package:hoopmap/features/courts/presentation/widgets/court_photo.dart';

const _fallbackKey = Key('fallback');

Widget _courtPhotoUnder(ProviderScope scope) =>
    MaterialApp(home: Scaffold(body: scope));

Widget _photo(String? imageUrl) => CourtPhoto(
  imageUrl: imageUrl,
  borderRadius: BorderRadius.zero,
  showAttribution: true,
  fallback: const ColoredBox(key: _fallbackKey, color: Colors.grey),
);

void main() {
  testWidgets('shows the fallback when there is no imageUrl', (tester) async {
    await tester.pumpWidget(
      _courtPhotoUnder(ProviderScope(child: _photo(null))),
    );
    await tester.pump();

    expect(find.byKey(_fallbackKey), findsOneWidget);
  });

  testWidgets(
    'shows the fallback when the imageUrl is not a resolvable Commons file',
    (tester) async {
      await tester.pumpWidget(
        _courtPhotoUnder(
          ProviderScope(child: _photo('https://example.com/photo.jpg')),
        ),
      );
      await tester.pump();

      expect(find.byKey(_fallbackKey), findsOneWidget);
    },
  );

  testWidgets('shows the fallback while attribution is resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      _courtPhotoUnder(
        ProviderScope(
          overrides: [
            commonsAttributionProvider(
              'Court.jpg',
            ).overrideWith((ref) => Completer<CommonsAttribution?>().future),
          ],
          child: _photo(
            'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
            '?width=800',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(_fallbackKey), findsOneWidget);
  });

  testWidgets(
    'shows the fallback when attribution resolves to null (no usable author)',
    (tester) async {
      await tester.pumpWidget(
        _courtPhotoUnder(
          ProviderScope(
            overrides: [
              commonsAttributionProvider(
                'Court.jpg',
              ).overrideWith((ref) async => null),
            ],
            child: _photo(
              'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
              '?width=800',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(_fallbackKey), findsOneWidget);
    },
  );

  testWidgets(
    'shows the photo and its attribution once resolved with an author',
    (tester) async {
      await tester.pumpWidget(
        _courtPhotoUnder(
          ProviderScope(
            overrides: [
              commonsAttributionProvider('Court.jpg').overrideWith(
                (ref) async => const CommonsAttribution(
                  author: 'Jane Doe',
                  licenseShortName: 'CC BY-SA 4.0',
                ),
              ),
            ],
            child: _photo(
              'https://commons.wikimedia.org/wiki/Special:FilePath/Court.jpg'
              '?width=800',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(_fallbackKey), findsNothing);
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(
        find.text('Photo : Jane Doe · Wikimedia Commons (CC BY-SA 4.0)'),
        findsOneWidget,
      );
    },
  );
}
