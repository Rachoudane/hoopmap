import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../router/routes.dart';
import '../../theme/app_spacing.dart';
import '../widgets/app_message_view.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.notFoundTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppEmptyView(
          icon: Icons.signpost_outlined,
          title: AppStrings.notFoundTitle,
          message: AppStrings.notFoundMessage,
          actionLabel: AppStrings.notFoundAction,
          onAction: () => context.go(Routes.home),
        ),
      ),
    );
  }
}
