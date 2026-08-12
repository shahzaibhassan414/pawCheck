import 'package:flutter/material.dart';

import '../../core/models/pet.dart';
import '../../core/theme/app_theme.dart';
import '../scan/home_screen.dart';
import 'widgets/fade_slide_in.dart';

const _speciesOptions = ['Dog', 'Cat'];

class PetProfileFormScreen extends StatefulWidget {
  const PetProfileFormScreen({super.key});

  @override
  State<PetProfileFormScreen> createState() => _PetProfileFormScreenState();
}

class _PetProfileFormScreenState extends State<PetProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  String? _species;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final pet = Pet(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      species: _species!,
      breed: _breedController.text.trim().isEmpty
          ? null
          : _breedController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
    );

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(pet: pet)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Kept deliberately compact top-to-bottom (a slim intro row rather than
    // a full illustrated header, tight field spacing) so every field and
    // the submit button stay within the viewport without scrolling on
    // small phones — this form is a quick, one-time step, not a place to
    // make someone hunt for the button.
    return Scaffold(
      appBar: AppBar(title: const Text('Add your pet')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceMd,
              AppTheme.spaceLg,
              AppTheme.spaceLg,
            ),
            children: [
              FadeSlideIn(
                child: Row(
                  children: [
                    _SpeciesPreviewAvatar(species: _species, size: 44),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Text(
                        'Tell us about your pet',
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: TextFormField(
                  key: const Key('pet_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a name'
                      : null,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              FadeSlideIn(
                delay: const Duration(milliseconds: 90),
                child: DropdownButtonFormField<String>(
                  key: const Key('pet_species_field'),
                  initialValue: _species,
                  decoration: const InputDecoration(
                    labelText: 'Species',
                    prefixIcon: Icon(Icons.pets_outlined),
                  ),
                  items: _speciesOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) => setState(() => _species = value),
                  validator: (value) =>
                      value == null ? 'Select a species' : null,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: TextFormField(
                  key: const Key('pet_breed_field'),
                  controller: _breedController,
                  decoration: const InputDecoration(
                    labelText: 'Breed (optional)',
                    prefixIcon: Icon(Icons.pattern_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: TextFormField(
                  key: const Key('pet_age_field'),
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age in years (optional)',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('pet_submit_button'),
                    onPressed: _submit,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}

/// A small live preview avatar that swaps icon/tint as the user picks a
/// species — purely presentational feedback, no effect on the submitted
/// [Pet].
class _SpeciesPreviewAvatar extends StatelessWidget {
  const _SpeciesPreviewAvatar({required this.species, this.size = 88});

  final String? species;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (species?.toLowerCase()) {
      'cat' => Icons.pets,
      'dog' => Icons.pets_outlined,
      _ => Icons.add_a_photo_outlined,
    };

    return AnimatedContainer(
      duration: AppTheme.motionMedium,
      curve: AppTheme.motionCurve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: AnimatedSwitcher(
        duration: AppTheme.motionFast,
        child: Icon(
          icon,
          key: ValueKey(icon),
          size: size * 0.42,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
