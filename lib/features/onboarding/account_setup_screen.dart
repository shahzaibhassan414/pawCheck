import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/brand_assets.dart';
import '../../core/config/species_assets.dart';
import '../../core/models/pet.dart';
import '../../core/services/firestore_pet_repository.dart';
import '../../core/services/firestore_scan_repository.dart';
import '../../core/services/pet_repository.dart';
import '../../core/services/scan_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gender_option_chip.dart';
import '../../core/widgets/labeled_field.dart';
import '../../core/widgets/pet_photo_slot.dart';
import '../../core/widgets/species_option_card.dart';
import '../scan/home_screen.dart';
import 'widgets/fade_slide_in.dart';

/// Picks a photo for the pet-photo slot — matches [ImagePicker.pickImage]'s
/// signature so tests can inject a fake without touching the platform
/// channel the real plugin uses (same pattern as `features/scan/
/// scan_screen.dart`'s `ImagePickerFn`).
typedef PhotoPickerFn = Future<XFile?> Function();

/// `maxWidth`/`imageQuality` keep the photo small enough to store as a
/// base64 `data:` URI directly in the pet's Firestore document — same
/// reasoning as `features/scan/scan_screen.dart`'s `_defaultPickImage`.
Future<XFile?> _defaultPickPhoto() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 1024,
  imageQuality: 85,
);

/// The "add first pet" screen, per section 3 of the "Paw Check claude
/// design" handoff doc (see that folder's README.md at the repo root) —
/// replaces what was previously a pet-only profile form
/// (`PetProfileFormScreen`). Collects an optional pet photo, the pet's
/// name, and species, then creates the pet and goes to Home.
///
/// Reached only after [EmailVerificationScreen] has already verified
/// [accountEmail] via [AuthService.sendOtp]/`verifyOtp` — this screen no
/// longer collects or validates an email itself.
class AccountSetupScreen extends StatefulWidget {
  AccountSetupScreen({
    super.key,
    required this.accountEmail,
    this.pickPhoto = _defaultPickPhoto,
    PetRepository? petRepository,
    ScanRepository? scanRepository,
  }) : petRepository = petRepository ?? FirestorePetRepository(),
       scanRepository = scanRepository ?? FirestoreScanRepository();

  /// The already-verified email this account is signed in as (see
  /// [EmailVerificationScreen]) — forwarded straight to [HomeScreen].
  final String accountEmail;
  final PhotoPickerFn pickPhoto;

  /// Both default to the real Firestore-backed repositories — every
  /// automated test must inject `InMemoryPetRepository`/
  /// `InMemoryScanRepository` instead (same "never touch live services in
  /// tests" rule already followed for `AiTriageService`). [scanRepository]
  /// is only used to hand off to the [HomeScreen] this screen creates.
  final PetRepository petRepository;
  final ScanRepository scanRepository;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _species;
  String? _gender;
  File? _photo;
  bool _submitting = false;

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
    if (!_formKey.currentState!.validate() || _submitting) return;

    final photo = _photo;
    final pet = Pet(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      species: _species!,
      gender: _gender,
      photoUrl: photo == null
          ? null
          : 'data:image/jpeg;base64,${base64Encode(await photo.readAsBytes())}',
    );

    setState(() => _submitting = true);
    try {
      await widget.petRepository.addPet(pet);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save your pet. Check your connection."),
        ),
      );
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          pets: [pet],
          accountEmail: widget.accountEmail,
          petRepository: widget.petRepository,
          scanRepository: widget.scanRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: _FormBody(
                  photo: _photo,
                  onPickPhoto: _pickPhoto,
                  nameController: _nameController,
                  species: _species,
                  onSpeciesChanged: _setSpecies,
                  gender: _gender,
                  onGenderChanged: _setGender,
                ),
              ),
              _BottomBar(onContinue: _submit, submitting: _submitting),
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

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.photo,
    required this.onPickPhoto,
    required this.nameController,
    required this.species,
    required this.onSpeciesChanged,
    required this.gender,
    required this.onGenderChanged,
  });

  final File? photo;
  final VoidCallback onPickPhoto;
  final TextEditingController nameController;
  final String? species;
  final void Function(String species, FormFieldState<String> field)
  onSpeciesChanged;
  final String? gender;
  final ValueChanged<String> onGenderChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceLg,
        AppTheme.spaceXl,
      ),
      child: Column(
        children: [
          FadeSlideIn(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Image.asset(BrandAssets.logo, width: 40, height: 40),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    "Add your pet",
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    "Their details keep their scans separate from any other "
                    "pets you add later.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 70),
            child: Center(
              child: PetPhotoSlot(
                key: const Key('pet_photo_slot'),
                photo: photo,
                onTap: onPickPhoto,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: LabeledField(
              label: "Pet's name",
              child: TextFormField(
                key: const Key('pet_name_field'),
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Coco',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          FadeSlideIn(
            delay: const Duration(milliseconds: 150),
            child: FormField<String>(
              initialValue: species,
              validator: (value) => value == null ? 'Select a species' : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SpeciesOptionCard(
                          // Keyed on the actual tappable card, not a
                          // wrapping Row — a Row spanning both cards has
                          // its geometric center sitting in the gap
                          // between them, which WidgetController.tap()
                          // can't reliably resolve to real painted
                          // content.
                          key: const Key('pet_species_field'),
                          label: 'Dog',
                          imagePath: SpeciesAssets.dog,
                          selected: species == 'Dog',
                          onTap: () => onSpeciesChanged('Dog', field),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: SpeciesOptionCard(
                          label: 'Cat',
                          imagePath: SpeciesAssets.cat,
                          selected: species == 'Cat',
                          onTap: () => onSpeciesChanged('Cat', field),
                        ),
                      ),
                    ],
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceSm,
                        AppTheme.spaceXs,
                        0,
                        0,
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
          ),
          const SizedBox(height: AppTheme.spaceMd),
          FadeSlideIn(
            delay: const Duration(milliseconds: 190),
            child: LabeledField(
              label: 'Gender (optional)',
              child: Row(
                children: [
                  GenderOptionChip(
                    key: const Key('pet_gender_male'),
                    label: 'Male',
                    icon: Icons.male,
                    selected: gender == 'Male',
                    onTap: () => onGenderChanged('Male'),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  GenderOptionChip(
                    key: const Key('pet_gender_female'),
                    label: 'Female',
                    icon: Icons.female,
                    selected: gender == 'Female',
                    onTap: () => onGenderChanged('Female'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Bottom: primary pill button 'Continue'" per the doc. The doc also
/// specifies a "Skip for now" ghost button, deliberately omitted here at
/// the user's request — adding a pet is required to proceed.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onContinue, this.submitting = false});

  final VoidCallback onContinue;
  final bool submitting;

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
            key: const Key('pet_submit_button'),
            onPressed: submitting ? null : onContinue,
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
