import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/species_assets.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import 'gender_option_chip.dart';
import 'labeled_field.dart';
import 'pet_photo_slot.dart';
import 'species_option_card.dart';

/// `maxWidth`/`imageQuality` keep the photo small enough to store as a
/// base64 `data:` URI directly in the pet's Firestore document — same
/// reasoning as `features/scan/scan_screen.dart`'s `_defaultPickImage`.
Future<XFile?> _defaultPickPhoto() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 1024,
  imageQuality: 85,
);

/// Add-or-edit pet, shared between `HomeScreen`'s "+ Add" chip and the
/// Settings screen's "edit pet" action. Originally a `Dialog` (matching
/// the design doc's section 4 "add-pet dialog" language), rebuilt as a
/// full screen at the user's explicit request — the modal felt cramped
/// for a photo slot + two text/selection fields, and the user disliked
/// both the popup format and the dialog's plainer styling. Now mirrors
/// `AccountSetupScreen`'s already-polished full-screen form layout
/// (centered heading/body, `FadeSlideIn`'d fields, bottom pill button)
/// instead of inventing a new look, since it's functionally the same
/// form minus the email field.
///
/// [initialPet] null means add mode (returns a freshly created [Pet] via
/// `Navigator.pop`); non-null means edit mode (returns a [Pet] with the
/// same `id`/`breed`/`age` but name/species/photo/gender updated — built
/// directly rather than via `copyWith`, since `copyWith`'s `field ?? this.
/// field` merge can't express clearing gender back to null, which
/// [_setGender]'s deselect-on-reselect toggle needs). Edit mode pre-fills
/// the photo slot from [Pet.photoUrl]; picking a new photo replaces it,
/// and leaving the slot untouched keeps the existing one.
class PetFormScreen extends StatefulWidget {
  const PetFormScreen({
    super.key,
    this.initialPet,
    this.pickPhoto = _defaultPickPhoto,
  });

  final Pet? initialPet;
  final Future<XFile?> Function() pickPhoto;

  bool get isEditMode => initialPet != null;

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initialPet?.name ?? '',
  );
  late String? _species = widget.initialPet?.species;
  late String? _gender = widget.initialPet?.gender;
  File? _photo;

  String get _keyPrefix => widget.isEditMode ? 'edit_pet' : 'add_pet';

  Future<void> _pickPhoto() async {
    final file = await widget.pickPhoto();
    if (file == null) return;
    if (!mounted) return;
    setState(() => _photo = File(file.path));
  }

  void _setSpecies(String species, FormFieldState<String> field) {
    setState(() => _species = species);
    field.didChange(species);
  }

  /// Unlike [_setSpecies] (required, hard single-select), gender is
  /// optional — tapping the already-selected option deselects it.
  void _setGender(String gender) {
    setState(() => _gender = _gender == gender ? null : gender);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final photo = _photo;
    final photoUrl = photo == null
        ? null
        : 'data:image/jpeg;base64,${base64Encode(await photo.readAsBytes())}';
    // Not `copyWith` for the edit branch: its `field ?? this.field` merge
    // pattern can't express "clear this back to null" — needed here since
    // [_setGender] lets a user deselect gender entirely, and `copyWith`
    // would just silently keep the old value in that case.
    final pet = widget.isEditMode
        ? Pet(
            id: widget.initialPet!.id,
            name: name,
            species: _species!,
            breed: widget.initialPet!.breed,
            age: widget.initialPet!.age,
            photoUrl: photoUrl ?? widget.initialPet!.photoUrl,
            gender: _gender,
          )
        : Pet(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            species: _species!,
            photoUrl: photoUrl,
            gender: _gender,
          );
    if (!mounted) return;
    Navigator.of(context).pop(pet);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditMode ? 'Edit pet' : 'Add a pet')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceXl,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              (constraints.maxHeight - AppTheme.spaceXl * 2)
                                  .clamp(0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.isEditMode
                                  ? "Update their details"
                                  : 'Tell us about them',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppTheme.spaceSm),
                            Text(
                              widget.isEditMode
                                  ? "Change their name or species below."
                                  : "A name and species is all we need to "
                                        'tell their scans apart.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceXl),
                            PetPhotoSlot(
                              key: Key('${_keyPrefix}_photo_slot'),
                              photo: _photo,
                              existingPhotoUrl: widget.initialPet?.photoUrl,
                              onTap: _pickPhoto,
                            ),
                            const SizedBox(height: AppTheme.spaceLg),
                            LabeledField(
                              label: "Pet's name",
                              child: TextFormField(
                                key: Key('${_keyPrefix}_name_field'),
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Coco',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty)
                                    ? 'Enter a name'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            FormField<String>(
                              initialValue: _species,
                              validator: (value) =>
                                  value == null ? 'Select a species' : null,
                              builder: (field) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SpeciesOptionCard(
                                          key: Key('${_keyPrefix}_species_dog'),
                                          label: 'Dog',
                                          imagePath: SpeciesAssets.dog,
                                          selected: _species == 'Dog',
                                          onTap: () =>
                                              _setSpecies('Dog', field),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spaceMd),
                                      Expanded(
                                        child: SpeciesOptionCard(
                                          key: Key('${_keyPrefix}_species_cat'),
                                          label: 'Cat',
                                          imagePath: SpeciesAssets.cat,
                                          selected: _species == 'Cat',
                                          onTap: () =>
                                              _setSpecies('Cat', field),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (field.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppTheme.spaceXs,
                                      ),
                                      child: Text(
                                        field.errorText!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            LabeledField(
                              label: 'Gender (optional)',
                              child: Row(
                                children: [
                                  GenderOptionChip(
                                    key: Key('${_keyPrefix}_gender_male'),
                                    label: 'Male',
                                    icon: Icons.male,
                                    selected: _gender == 'Male',
                                    onTap: () => _setGender('Male'),
                                  ),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  GenderOptionChip(
                                    key: Key('${_keyPrefix}_gender_female'),
                                    label: 'Female',
                                    icon: Icons.female,
                                    selected: _gender == 'Female',
                                    onTap: () => _setGender('Female'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _BottomBar(
                keyPrefix: _keyPrefix,
                isEditMode: widget.isEditMode,
                onSubmit: _submit,
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
    super.dispose();
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.keyPrefix,
    required this.isEditMode,
    required this.onSubmit,
  });

  final String keyPrefix;
  final bool isEditMode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceLg,
          AppTheme.spaceMd,
          AppTheme.spaceLg,
          AppTheme.spaceMd,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: Key('${keyPrefix}_submit_button'),
            onPressed: onSubmit,
            child: Text(isEditMode ? 'Save changes' : 'Add pet'),
          ),
        ),
      ),
    );
  }
}
