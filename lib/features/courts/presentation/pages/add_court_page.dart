import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_providers.dart';
import '../add_court_controller.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un terrain')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                if (length < 3 || length > 60) {
                  return 'Le nom doit contenir entre 3 et 60 caractères';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _hoopCountController,
              decoration: const InputDecoration(labelText: 'Nombre de paniers'),
              keyboardType: TextInputType.number,
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < 1 || parsed > 20) {
                  return 'Entre 1 et 20 paniers';
                }
                return null;
              },
            ),
            SwitchListTile(
              title: const Text('Terrain extérieur'),
              value: _isOutdoor,
              onChanged: (value) => setState(() => _isOutdoor = value),
            ),
            TextFormField(
              controller: _latitudeController,
              decoration: const InputDecoration(labelText: 'Latitude'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < -90 || parsed > 90) {
                  return 'Latitude entre -90 et 90';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _longitudeController,
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < -180 || parsed > 180) {
                  return 'Longitude entre -180 et 180';
                }
                return null;
              },
            ),
            if (submitState.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'Erreur : ${submitState.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSubmitting ? null : _submit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
