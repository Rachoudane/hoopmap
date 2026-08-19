import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/court.dart';
import '../court_detail_provider.dart';

class CourtDetailPage extends ConsumerWidget {
  const CourtDetailPage({super.key, required this.courtId});

  final String courtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtAsync = ref.watch(courtDetailProvider(courtId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du terrain')),
      body: courtAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Erreur : ${error.runtimeType}')),
        data: (court) => _CourtDetailBody(court: court),
      ),
    );
  }
}

class _CourtDetailBody extends StatelessWidget {
  const _CourtDetailBody({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final isFromOpenStreetMap = court.id.startsWith('osm:');
    final source = isFromOpenStreetMap
        ? 'Source : OpenStreetMap'
        : "Source : contribution d'utilisateur";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(court.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${court.hoopCount} panier(s)'),
          Text(court.isOutdoor ? 'Terrain extérieur' : 'Terrain intérieur'),
          Text(
            '${court.latitude.toStringAsFixed(5)}, '
            '${court.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openDirections(court),
            icon: const Icon(Icons.directions),
            label: const Text('Itinéraire'),
          ),
          const SizedBox(height: 16),
          Text(
            source,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

Future<void> _openDirections(Court court) async {
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '${court.latitude},${court.longitude}',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
