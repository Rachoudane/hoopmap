import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../../router/routes.dart';
import '../../presentation/widgets/readable_width.dart';
import '../../theme/app_spacing.dart';
import '../app_info.dart';
import '../settings_providers.dart';

/// Everything the user can change about the app, in one place.
///
/// Deliberately short: a settings screen is where a product admits which of
/// its decisions it got wrong for someone, and Hoopmap only has two of those
/// (the theme it guessed, and the radius it picked). The rest of the screen
/// is there to be read rather than changed — what language it speaks, whose
/// data it shows, and which build this is.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final radius = ref.watch(searchRadiusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              const _SectionHeader(AppStrings.settingsAppearanceSection),
              RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (selected) {
                  if (selected != null) {
                    ref.read(themeModeProvider.notifier).set(selected);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: Text(AppStrings.settingsThemeSystem),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text(AppStrings.settingsThemeLight),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text(AppStrings.settingsThemeDark),
                    ),
                  ],
                ),
              ),

              const Divider(),
              const _SectionHeader(AppStrings.settingsSearchSection),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.settingsSearchRadiusTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.settingsSearchRadiusSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final choice in searchRadiusChoices)
                          ChoiceChip(
                            label: Text(AppStrings.settingsRadiusLabel(choice)),
                            selected: choice == radius,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(searchRadiusProvider.notifier)
                                    .set(choice);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: AppSpacing.xxl),
              const _SectionHeader(AppStrings.settingsLanguageSection),
              // Not a choice, and shown anyway: someone looking for their own
              // language deserves an answer rather than an absence.
              const ListTile(
                leading: Icon(Icons.translate),
                title: Text(AppStrings.settingsLanguageTitle),
                subtitle: Text(AppStrings.settingsLanguageSubtitle),
              ),

              const Divider(),
              const _SectionHeader(AppStrings.settingsLegalSection),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text(AppStrings.settingsTermsTitle),
                subtitle: const Text(AppStrings.settingsTermsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(Routes.termsName),
              ),
              const ListTile(
                leading: Icon(Icons.public),
                title: Text(AppStrings.settingsAttributionTitle),
                subtitle: Text(AppStrings.settingsAttributionSubtitle),
              ),

              const Divider(),
              const _SectionHeader(AppStrings.settingsAboutSection),
              const ListTile(
                leading: Icon(Icons.sports_basketball),
                title: Text(AppInfo.name),
                subtitle: Text(AppStrings.settingsAboutSubtitle),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(AppStrings.settingsVersion(AppInfo.versionLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
