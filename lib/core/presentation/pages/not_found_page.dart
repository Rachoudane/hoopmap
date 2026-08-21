import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';
import '../../theme/app_spacing.dart';
import '../widgets/app_message_view.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppEmptyView(
          icon: Icons.signpost_outlined,
          title: 'Page introuvable',
          message: "Cette page n'existe pas ou plus.",
          actionLabel: "Retour à l'accueil",
          onAction: () => context.go(Routes.home),
        ),
      ),
    );
  }
}
