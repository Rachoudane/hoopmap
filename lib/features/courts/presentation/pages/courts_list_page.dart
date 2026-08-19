import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../nearby_courts_notifier.dart';

String _formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final kilometers = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$kilometers km';
}

class CourtsListPage extends ConsumerWidget {
  const CourtsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(nearbyCourtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terrains'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => context.goNamed(Routes.mapName),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.goNamed(Routes.addCourtName),
        child: const Icon(Icons.add),
      ),
      body: courtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Erreur : ${error.runtimeType}')),
        data: (courts) {
          if (courts.isEmpty) {
            return const Center(child: Text('Aucun terrain à proximité'));
          }
          return ListView.builder(
            itemCount: courts.length,
            itemBuilder: (context, index) {
              final courtWithDistance = courts[index];
              return ListTile(
                title: Text(courtWithDistance.court.name),
                subtitle: Text(
                  _formatDistance(courtWithDistance.distanceInMeters),
                ),
                onTap: () => context.goNamed(
                  Routes.courtDetailName,
                  pathParameters: {
                    Routes.courtIdParam: courtWithDistance.court.id,
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
