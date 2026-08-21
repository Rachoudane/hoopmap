import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'court_repository_provider.dart';

class CommonsAttribution {
  const CommonsAttribution({required this.author, this.licenseShortName});

  final String author;
  final String? licenseShortName;
}

/// Fetches the author and license of a Commons file from its extended
/// metadata. Resolves to null when the file can't be found, the request
/// fails, or the API returns no usable author — all cases where the
/// caller must fall back to not displaying the photo, since it cannot be
/// attributed.
final commonsAttributionProvider =
    FutureProvider.family<CommonsAttribution?, String>((ref, fileTitle) async {
      final client = ref.watch(httpClientProvider);
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'titles': 'File:$fileTitle',
        'prop': 'imageinfo',
        'iiprop': 'extmetadata',
        'format': 'json',
        'formatversion': '2',
      });

      final http.Response response;
      try {
        response = await client.get(uri).timeout(const Duration(seconds: 10));
      } catch (_) {
        return null;
      }
      if (response.statusCode != 200) return null;

      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final pages =
            (decoded['query'] as Map<String, dynamic>)['pages'] as List;
        if (pages.isEmpty) return null;
        final page = pages.first as Map<String, dynamic>;
        final imageInfo = page['imageinfo'] as List?;
        if (imageInfo == null || imageInfo.isEmpty) return null;
        final metadata =
            (imageInfo.first as Map<String, dynamic>)['extmetadata']
                as Map<String, dynamic>?;
        if (metadata == null) return null;

        final artistHtml =
            (metadata['Artist'] as Map<String, dynamic>?)?['value'] as String?;
        final author = _stripHtml(artistHtml)?.trim();
        if (author == null || author.isEmpty) return null;

        final license =
            (metadata['LicenseShortName'] as Map<String, dynamic>?)?['value']
                as String?;

        return CommonsAttribution(author: author, licenseShortName: license);
      } catch (_) {
        return null;
      }
    });

String? _stripHtml(String? value) {
  if (value == null) return null;
  return value.replaceAll(RegExp(r'<[^>]*>'), '');
}
