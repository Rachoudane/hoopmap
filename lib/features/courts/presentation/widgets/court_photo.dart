import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/commons_attribution.dart';
import '../../data/commons_urls.dart';

/// A court photo, shown only once its Wikimedia Commons author/license
/// has been resolved (a legal requirement for displaying it — see
/// data/commons_attribution.dart). Falls back to [fallback] while that's
/// pending, on failure, or when there is no photo at all: never an empty
/// area or a broken-image icon.
class CourtPhoto extends ConsumerWidget {
  const CourtPhoto({
    super.key,
    required this.imageUrl,
    required this.fallback,
    required this.borderRadius,
    this.showAttribution = false,
  });

  final String? imageUrl;
  final Widget fallback;
  final BorderRadius borderRadius;
  final bool showAttribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = imageUrl;
    if (url == null) {
      return ClipRRect(borderRadius: borderRadius, child: fallback);
    }

    final fileTitle = commonsFileTitleFromUrl(url);
    if (fileTitle == null) {
      return ClipRRect(borderRadius: borderRadius, child: fallback);
    }

    final attribution = ref.watch(commonsAttributionProvider(fileTitle));

    return attribution.when(
      loading: () => ClipRRect(borderRadius: borderRadius, child: fallback),
      error: (error, stackTrace) =>
          ClipRRect(borderRadius: borderRadius, child: fallback),
      data: (attribution) {
        if (attribution == null) {
          return ClipRRect(borderRadius: borderRadius, child: fallback);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: borderRadius,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => fallback,
              ),
            ),
            if (showAttribution) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.photoAttribution(
                  attribution.author,
                  attribution.licenseShortName,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}
