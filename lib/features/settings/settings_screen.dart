import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/pet.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_pet_repository.dart';
import '../../core/services/pet_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pet_form_screen.dart';
import '../splash/splash_screen.dart';

Future<void> _defaultSignOut() async {
  await FirebaseAuth.instance.signOut();
}

typedef SettingsUrlLauncherFn = Future<bool> Function(Uri uri);

Future<bool> _defaultLaunchUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// iOS's native "Manage Subscriptions" deep link — opens the account's
/// subscriptions list on a real device even before any purchase exists.
/// No Android equivalent is wired: Android is an explicit fast-follow,
/// not launch scope, per CLAUDE.md.
Uri _manageSubscriptionUri() =>
    Uri.parse('https://apps.apple.com/account/subscriptions');

/// Placeholder legal URLs — no real hosted pages exist yet for a
/// pre-launch app, matching this build's "don't fake infra that isn't
/// wired up yet" stance everywhere else. Point these at the real policy
/// pages once they're published.
Uri _privacyPolicyUri() => Uri.parse('https://pawcheck.app/privacy');
Uri _termsUri() => Uri.parse('https://pawcheck.app/terms');

const _disclaimerText =
    "Pawcheck gives plain-language guidance, not a diagnosis. It doesn't "
    'store or share your pet\'s medical history with third parties.';

/// Settings, per `settings-screen-content.md` at the repo root (the
/// authoritative content/structure spec for this screen — found after an
/// initial build that only covered PRD Milestone 8's bare checklist;
/// this rewrite reconciles the two). Like the paywall, this isn't one of
/// the "Paw Check claude design" doc's 7 screens, so its visual language
/// (grouped sections of list rows) is this build's own extrapolation of
/// that doc's tokens, but its *content* now follows the dedicated content
/// doc section by section: Account, Your pets, Preferences, Subscription,
/// Legal, a disclaimer note, and Sign out.
///
/// [pets]/[onAddPet]/[onEditPet]/[onDeletePet] and the account email are
/// all owned by the caller (`HomeScreen` holds the real in-memory session
/// state) — this screen never mutates anything itself, same ownership
/// pattern as `TimelineScreen`'s `onDelete`. The notifications toggle and
/// units choice are local-only: neither is read anywhere else in the app
/// yet (no Milestone 9 reminders, no measurement values shown anywhere),
/// so there's nothing to lift to `HomeScreen` the way the pets are. There's
/// deliberately no account photo/avatar picker here — nothing during
/// sign-up ever collects one, so offering to change one in Settings would
/// be a dead-end affordance. "Sign out" ends the real email-OTP session
/// (see `AuthService.signOut`) and resets the navigation stack back to
/// Splash, which re-resolves auth state and routes to `OnboardingScreen`
/// for the now-signed-out user.
///
/// [bottomNavigationBar], if given, lets `HomeScreen` embed this screen as
/// one of its bottom-nav tabs (rendered directly, not pushed) while
/// keeping the same floating nav bar visible — see `HomeScreen`'s class
/// doc comment for why tapping Timeline/Settings no longer navigates at
/// all. Left null when Settings is used standalone (as every existing
/// test here does).
class SettingsScreen extends StatefulWidget {
  SettingsScreen({
    super.key,
    required this.pets,
    required this.onAddPet,
    required this.onEditPet,
    required this.onDeletePet,
    this.accountEmail,
    this.pickPhoto,
    this.launchUrl = _defaultLaunchUrl,
    this.bottomNavigationBar,
    Future<void> Function()? signOut,
    AuthService? authService,
    PetRepository? petRepository,
  }) : signOut = signOut ?? _defaultSignOut,
       authService = authService ?? FirebaseAuthService(),
       petRepository = petRepository ?? FirestorePetRepository();

  final List<Pet> pets;
  final VoidCallback onAddPet;
  final ValueChanged<Pet> onEditPet;
  final ValueChanged<Pet> onDeletePet;
  final String? accountEmail;
  final Future<XFile?> Function()? pickPhoto;
  final SettingsUrlLauncherFn launchUrl;
  final Widget? bottomNavigationBar;

  /// All default to the real Firebase-backed behavior — every automated
  /// test must inject a no-op `signOut`, `FakeAuthService`, and
  /// `InMemoryPetRepository` instead (same "never touch live services in
  /// tests" rule already followed for `AiTriageService`). [authService]/
  /// [petRepository] are only used to hand the same services on to the
  /// [SplashScreen] pushed after sign-out.
  final Future<void> Function() signOut;
  final AuthService authService;
  final PetRepository petRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Units { metric, imperial }

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remindersEnabled = false;
  _Units _units = _Units.metric;

  Future<void> _editPet(Pet pet) async {
    final updated = await Navigator.of(context).push<Pet>(
      MaterialPageRoute(
        builder: (_) => widget.pickPhoto == null
            ? PetFormScreen(initialPet: pet)
            : PetFormScreen(initialPet: pet, pickPhoto: widget.pickPhoto!),
      ),
    );
    if (updated != null) widget.onEditPet(updated);
  }

  Future<void> _confirmDeletePet(Pet pet) async {
    if (widget.pets.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one pet profile.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${pet.name}?'),
        content: const Text(
          "This removes the pet's profile and can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDeletePet(pet);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to set up your account and pets again on this "
          'device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => SplashScreen(
          authService: widget.authService,
          petRepository: widget.petRepository,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        // When embedded as a bottom-nav tab (`bottomNavigationBar` given),
        // this must never grow a back chevron — it's a peer destination,
        // not a pushed screen. Can't rely on `Navigator.canPop(context)`
        // alone: the real app's actual route stack is
        // `[OnboardingScreen, HomeScreen]` (Onboarding `push`ed
        // AccountSetup, which then `pushReplacement`d itself with
        // HomeScreen), so `canPop` is genuinely `true` here even though
        // this screen has nothing of its own to pop back to.
        automaticallyImplyLeading: widget.bottomNavigationBar == null,
        titleSpacing: AppTheme.spaceMd,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: const Icon(Icons.person_outline),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Settings',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    widget.pets.length == 1
                        ? '1 pet profile'
                        : '${widget.pets.length} pet profiles',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          children: [
            _SectionLabel('ACCOUNT'),
            Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Row(
                  children: [
                    CircleAvatar(
                      key: const Key('account_avatar'),
                      radius: 36,
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      child: const Icon(Icons.person_outline, size: 32),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.accountEmail ?? 'No email added',
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            'Pawcheck account',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _SectionLabel('YOUR PETS'),
            for (final pet in widget.pets)
              _PetRow(
                key: Key('settings_pet_${pet.id}'),
                pet: pet,
                onEdit: () => _editPet(pet),
                onDelete: () => _confirmDeletePet(pet),
              ),
            _SettingsTile(
              key: const Key('add_another_pet_tile'),
              icon: Icons.add_circle_outline,
              title: '+ Add another pet',
              onTap: widget.onAddPet,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _SectionLabel('PREFERENCES'),
            Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: SwitchListTile(
                key: const Key('reminders_switch'),
                value: _remindersEnabled,
                onChanged: (value) => setState(() => _remindersEnabled = value),
                title: const Text('Scan reminders'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Units'),
                    SegmentedButton<_Units>(
                      key: const Key('units_segmented_button'),
                      segments: const [
                        ButtonSegment(
                          value: _Units.metric,
                          label: Text('Metric'),
                        ),
                        ButtonSegment(
                          value: _Units.imperial,
                          label: Text('Imperial'),
                        ),
                      ],
                      selected: {_units},
                      onSelectionChanged: (selection) =>
                          setState(() => _units = selection.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _SectionLabel('SUBSCRIPTION'),
            _SettingsTile(
              key: const Key('manage_subscription_tile'),
              icon: Icons.workspace_premium_outlined,
              title: 'Manage subscription',
              onTap: () => widget.launchUrl(_manageSubscriptionUri()),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _SectionLabel('LEGAL'),
            _SettingsTile(
              key: const Key('privacy_policy_tile'),
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy',
              onTap: () => widget.launchUrl(_privacyPolicyUri()),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            _SettingsTile(
              key: const Key('terms_tile'),
              icon: Icons.description_outlined,
              title: 'Terms of service',
              onTap: () => widget.launchUrl(_termsUri()),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              child: Text(
                _disclaimerText,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            TextButton(
              key: const Key('sign_out_button'),
              onPressed: _confirmSignOut,
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceSm,
        AppTheme.spaceMd,
        AppTheme.spaceSm,
        AppTheme.spaceSm,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({
    super.key,
    required this.pet,
    required this.onEdit,
    required this.onDelete,
  });

  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial = pet.name.isEmpty ? '?' : pet.name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                child: Text(initial),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: textTheme.titleMedium),
                    Text(
                      pet.species,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('edit_pet_${pet.id}'),
                icon: const Icon(Icons.edit_outlined),
                color: colorScheme.onSurfaceVariant,
                onPressed: onEdit,
              ),
              IconButton(
                key: Key('delete_pet_${pet.id}'),
                icon: const Icon(Icons.delete_outline),
                color: colorScheme.onSurfaceVariant,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceMd,
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(child: Text(title, style: textTheme.bodyMedium)),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
