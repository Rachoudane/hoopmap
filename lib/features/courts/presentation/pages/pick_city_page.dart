import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/location/location_opt_in_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/city.dart';
import '../browse_city_provider.dart';

/// Where to look for courts, for anyone who can't or won't share a location.
///
/// The list is short and bundled (see [browsableCities]), so it answers
/// instantly and offline — and because it will never hold everyone's town,
/// the page says out loud that the map covers the rest.
class PickCityPage extends ConsumerStatefulWidget {
  const PickCityPage({super.key});

  @override
  ConsumerState<PickCityPage> createState() => _PickCityPageState();
}

class _PickCityPageState extends ConsumerState<PickCityPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _choose(City city) async {
    await ref.read(browseCityProvider.notifier).choose(city);
    if (mounted) context.pop();
  }

  /// Goes back to the user's own position, asking for it (with the usual
  /// explanation) if it has never been granted.
  Future<void> _useMyLocation() async {
    final navigator = Navigator.of(context);
    await ref.read(browseCityProvider.notifier).clear();
    if (!mounted) return;
    await requestLocationOptIn(context, ref);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cities = searchCities(_query);
    final selected = ref.watch(browseCityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.pickCityTitle)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: AppStrings.pickCitySearchLabel,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text(AppStrings.pickCityUseMyLocation),
              onTap: _useMyLocation,
            ),
            const Divider(height: 1),
            Expanded(
              child: cities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        AppStrings.pickCityNoMatch,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: cities.length,
                      itemBuilder: (context, index) {
                        final city = cities[index];
                        return ListTile(
                          leading: const Icon(Icons.location_city_outlined),
                          title: Text(city.name),
                          subtitle: Text(city.country),
                          trailing: city == selected
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          onTap: () => _choose(city),
                        );
                      },
                    ),
            ),
            // The list is a shortcut, not the limit of the app: whoever
            // isn't on it has a map that goes everywhere.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.pickCityPanTheMapHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
