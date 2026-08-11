import 'package:flutter/material.dart';

class CourtDetailPage extends StatelessWidget {
  const CourtDetailPage({super.key, required this.courtId});

  final String courtId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du terrain')),
      body: Center(child: Text('Terrain sélectionné : $courtId')),
    );
  }
}
