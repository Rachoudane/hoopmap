import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';

class _CourtListItem {
  const _CourtListItem({required this.id, required this.label});

  final String id;
  final String label;
}

const List<_CourtListItem> _fakeCourts = [
  _CourtListItem(id: 'court-a', label: 'Terrain A'),
  _CourtListItem(id: 'court-b', label: 'Terrain B'),
  _CourtListItem(id: 'court-c', label: 'Terrain C'),
];

class CourtsListPage extends StatelessWidget {
  const CourtsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terrains')),
      body: ListView.builder(
        itemCount: _fakeCourts.length,
        itemBuilder: (context, index) {
          final court = _fakeCourts[index];
          return ListTile(
            title: Text(court.label),
            onTap: () => context.goNamed(
              Routes.courtDetailName,
              pathParameters: {Routes.courtIdParam: court.id},
            ),
          );
        },
      ),
    );
  }
}
