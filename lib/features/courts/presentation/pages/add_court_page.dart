import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_providers.dart';
import '../../../../core/router/back_to_home_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../add_court_controller.dart';
import '../court_error_messages.dart';

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
  bool _isOutdoor = true;

  @override
  void initState() {
    super.initState();
    _prefillCurrentPosition();
  }

  Future<void> _prefillCurrentPosition() async {
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });
    } catch (_) {
      // Position unavailable: the fields stay empty and the user fills them
      // in manually.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hoopCountController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
                'Pré-remplie avec votre position actuelle si disponible ; '
                'vous pouvez la corriger.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < -90 || parsed > 90) {
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
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < -180 || parsed > 180) {
                          return 'Entre -180 et 180';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
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
                onPressed: isSubmitting ? null : _submit,
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
