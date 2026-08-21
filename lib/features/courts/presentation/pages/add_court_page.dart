import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_providers.dart';
import '../../../../core/router/back_to_home_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../add_court_controller.dart';
import '../court_error_messages.dart';
import '../widgets/location_picker_map.dart';

// Used when the device position can't be read at all (permission denied,
// service disabled, ...) so the map picker always has somewhere to start.
const LatLng _fallbackMapCenter = LatLng(48.8566, 2.3522);

class AddCourtPage extends ConsumerStatefulWidget {
  const AddCourtPage({super.key});

  @override
  ConsumerState<AddCourtPage> createState() => _AddCourtPageState();
}

class _AddCourtPageState extends ConsumerState<AddCourtPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hoopCountController = TextEditingController(text: '2');
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _mapController = MapController();
  bool _isOutdoor = true;
  bool _locatingCurrentPosition = false;

  // Null until the map picker has somewhere to start (current position, or
  // the fallback once it's clear the current position isn't available).
  LatLng? _initialMapCenter;

  @override
  void initState() {
    super.initState();
    _useCurrentPosition(isInitial: true);
  }

  Future<void> _useCurrentPosition({bool isInitial = false}) async {
    setState(() => _locatingCurrentPosition = true);
    LatLng resolved;
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      resolved = LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Position unavailable: fall back so the map picker still has a
      // starting point, and the user can place the marker manually.
      resolved = _fallbackMapCenter;
    }
    if (!mounted) return;
    setState(() {
      _setSelectedPosition(resolved);
      _initialMapCenter ??= resolved;
      _locatingCurrentPosition = false;
    });
    if (!isInitial) {
      _mapController.move(resolved, _mapController.camera.zoom);
    }
  }

  void _setSelectedPosition(LatLng point) {
    _latitudeController.text = point.latitude.toStringAsFixed(6);
    _longitudeController.text = point.longitude.toStringAsFixed(6);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hoopCountController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(addCourtControllerProvider.notifier)
        .submit(
          name: _nameController.text.trim(),
          hoopCount: int.parse(_hoopCountController.text.trim()),
          isOutdoor: _isOutdoor,
          latitude: double.parse(_latitudeController.text.trim()),
          longitude: double.parse(_longitudeController.text.trim()),
        );

    if (!mounted) return;
    if (ref.read(addCourtControllerProvider).hasError) return;

    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Terrain ajouté avec succès')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(addCourtControllerProvider);
    final isSubmitting = submitState.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ajouter un terrain')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Informations', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du terrain',
                  hintText: 'Ex. City Stade Voltaire',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 3 || length > 60) {
                    return 'Le nom doit contenir entre 3 et 60 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _hoopCountController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de paniers',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 1 || parsed > 20) {
                    return 'Entre 1 et 20 paniers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: SwitchListTile(
                  title: const Text('Terrain extérieur'),
                  subtitle: Text(
                    _isOutdoor
                        ? 'Le terrain est en extérieur'
                        : 'Le terrain est en intérieur',
                    style: textTheme.bodySmall,
                  ),
                  value: _isOutdoor,
                  onChanged: (value) => setState(() => _isOutdoor = value),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Position', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Déplacez la carte pour placer le repère sur le terrain.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: 220,
                  child: _initialMapCenter == null
                      ? ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : LocationPickerMap(
                          mapController: _mapController,
                          initialCenter: _initialMapCenter!,
                          onCenterChanged: (point) =>
                              setState(() => _setSelectedPosition(point)),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _latitudeController.text.isEmpty
                          ? 'Position à choisir'
                          : 'Position choisie : ${_latitudeController.text}, '
                                '${_longitudeController.text}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _locatingCurrentPosition
                        ? null
                        : () => _useCurrentPosition(),
                    icon: _locatingCurrentPosition
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Ma position actuelle'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // Keeps the lat/lng fields registered with the Form (and
                  // thus validated on submit) even while collapsed, instead
                  // of only once the user has expanded the tile at least
                  // once.
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Saisir les coordonnées'),
                  childrenPadding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (parsed == null ||
                                  parsed < -90 ||
                                  parsed > 90) {
                                return 'Entre -90 et 90';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (parsed == null ||
                                  parsed < -180 ||
                                  parsed > 180) {
                                return 'Entre -180 et 180';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (submitState.hasError) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          courtErrorMessage(submitState.error!),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: (isSubmitting || _initialMapCenter == null)
                    ? null
                    : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajouter le terrain'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
