import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../presentation/widgets/readable_width.dart';
import '../../theme/app_spacing.dart';
import '../terms_of_use_content.dart';
import '../terms_providers.dart';

/// Displays the Terms of Use.
///
/// Used two ways: as a plain reference screen reachable from the courts
/// list app bar ([requireAcceptance] false), and as a mandatory gate pushed
/// before the first court submission when the user hasn't accepted yet
/// ([requireAcceptance] true) — see courts_list_page.dart. In gate mode,
/// accepting pops `true` and declining pops `false`/null, so the caller
/// knows whether it's safe to continue to the add-court form.
class TermsOfUsePage extends ConsumerWidget {
  const TermsOfUsePage({super.key, this.requireAcceptance = false});

  final bool requireAcceptance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.termsOfUseTitle)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: Column(
            children: [
              if (requireAcceptance)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  child: Text(
                    AppStrings.termsGateIntro,
                    style: textTheme.bodyMedium,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.termsOfUseEffectiveDate(
                          termsOfUseEffectiveDate,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(termsOfUseIntro, style: textTheme.bodyMedium),
                      for (final section in termsOfUseSections) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(section.heading, style: textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(section.body, style: textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
              if (requireAcceptance)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(false),
                          child: const Text(AppStrings.termsDecline),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref
                                .read(termsAcceptedProvider.notifier)
                                .accept();
                            if (context.mounted) context.pop(true);
                          },
                          child: const Text(AppStrings.termsAccept),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
