import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/brand_assets.dart';
import '../../core/models/pet.dart';
import '../../core/models/scan.dart';
import '../../core/services/firestore_pet_repository.dart';
import '../../core/services/firestore_scan_repository.dart';
import '../../core/services/pet_repository.dart';
import '../../core/services/scan_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/photo_image_provider.dart';
import '../../core/widgets/pet_form_screen.dart';
import '../paywall/paywall_screen.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import 'scan_screen.dart';
import 'widgets/fade_slide_in.dart';

/// Home / pet selector, per section 4 of the "Paw Check claude design"
/// handoff doc (see that folder's README.md at the repo root): a header
/// with the logo+wordmark, a horizontal row of pet chips with a trailing
/// "+ Add" chip, and a large circular scan CTA. The bottom nav is a later
/// deviation from the doc's own mockup — see `_BottomTabBar`'s doc
/// comment.
///
/// This widget owns all three top-level tabs (Home/Timeline/Settings), not
/// just Home's own content — `build()` branches on `_activeTab` and
/// returns `TimelineScreen`/`SettingsScreen` directly instead of pushing
/// them as separate routes. This is deliberate, at the user's explicit
/// request: tapping Timeline or Settings in the bottom nav should feel
/// like switching tabs (instant, no slide transition, no back chevron),
/// not navigating to a new screen. Genuine forward navigation — scanning,
/// editing a pet, reopening a historical result — still pushes normally;
/// only these three peer destinations share one nav bar and swap in
/// place. See `TimelineScreen`/`SettingsScreen`'s `bottomNavigationBar`
/// param doc comments for the other half of this.
///
/// Multi-pet state is in-memory only (`_pets`, seeded from [pet]) — there's
/// no persistence layer yet (still blocked on the Milestone 0 Firebase
/// setup; see CHANGELOG), so added pets don't survive an app restart. The
/// doc's "Last scan" summary card is omitted entirely rather than faked —
/// it's spec'd to show "only if they have scan history", and no scan
/// persistence/history wiring exists between screens yet either.
class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    required this.pets,
    this.accountEmail,
    this.addPetPickPhoto = _defaultPickAddPetPhoto,
    PetRepository? petRepository,
    ScanRepository? scanRepository,
  }) : petRepository = petRepository ?? FirestorePetRepository(),
       scanRepository = scanRepository ?? FirestoreScanRepository();

  /// The pets to show initially — from Account Setup (a single freshly
  /// created pet) or Splash's already-loaded list for a returning user.
  /// Must be non-empty. [petRepository]'s live stream takes over from here.
  final List<Pet> pets;

  /// As entered on the Account Setup screen — optional there, so this can
  /// be null (Settings' Account section falls back to a placeholder in
  /// that case). Not wired to a real backend yet, same as everywhere else
  /// still blocked on Milestone 0.
  final String? accountEmail;

  /// Forwarded into the add-pet dialog's photo slot — matches
  /// [ImagePicker.pickImage]'s signature so tests can inject a fake
  /// without touching the platform channel the real plugin uses (same
  /// pattern as `features/scan/scan_screen.dart`'s `ImagePickerFn`).
  final Future<XFile?> Function() addPetPickPhoto;

  /// Defaults to the real Firestore-backed repositories — every automated
  /// test must inject `InMemoryPetRepository`/`InMemoryScanRepository`
  /// instead (same "never touch live services in tests" rule already
  /// followed for `AiTriageService`).
  final PetRepository petRepository;
  final ScanRepository scanRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Pet> _pets = List.of(widget.pets);
  int _selectedIndex = 0;

  late final StreamSubscription<List<Pet>> _petsSubscription;
  StreamSubscription<List<Scan>>? _scansSubscription;
  String? _scansSubscribedPetId;
  List<Scan> _scansForSelectedPet = const [];

  /// 0 = Home, 1 = Timeline, 2 = Settings — which bottom-nav tab is
  /// currently shown. Switching tabs is a plain `setState`, never a
  /// `Navigator.push`: the user explicitly asked for tapping Timeline/
  /// Settings to swap content in place rather than navigate to a new
  /// screen (no slide transition, no back chevron), matching how bottom
  /// tab bars normally behave. Genuine forward navigation (editing a pet,
  /// scanning, reopening a historical result) still pushes as normal —
  /// this only affects the three top-level peer destinations.
  int _activeTab = 0;

  // Free-scan gating (PRD Milestone 7). Per-install, not per-pet — the
  // decision CLAUDE.md flagged as an open PRD question, settled this
  // session. Both are in-memory only: no RevenueCat entitlement check
  // exists yet (still blocked on Milestone 0), so this is a UI-first mock
  // that a real integration will replace with an actual purchase/
  // entitlement lookup, not something this session pretends is secure.
  bool _freeScanUsed = false;
  bool _isSubscribed = false;

  Pet get _selectedPet => _pets[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _petsSubscription = widget.petRepository.watchPets().listen(_onPetsUpdated);
    _subscribeToScans();
  }

  /// Keeps `_pets` in sync with the repository's live list, preserving
  /// whichever pet was already selected (by id, not index — the stream can
  /// reorder). Local mutations (`_addPet`/`_editPet`/`_deletePet`) also
  /// update `_pets` optimistically for an instant UI response; this handler
  /// is what reconciles that with the source of truth once the write lands.
  void _onPetsUpdated(List<Pet> pets) {
    if (!mounted || pets.isEmpty) return;
    final selectedId = _pets.isNotEmpty ? _selectedPet.id : null;
    setState(() {
      _pets = pets;
      final index = selectedId == null
          ? -1
          : _pets.indexWhere((p) => p.id == selectedId);
      _selectedIndex = index != -1 ? index : 0;
    });
    _subscribeToScans();
  }

  /// Re-subscribes to the selected pet's scan stream whenever the selection
  /// changes — `TimelineScreen`'s data only ever needs the currently
  /// selected pet's history, not every pet's at once.
  void _subscribeToScans() {
    final petId = _selectedPet.id;
    if (_scansSubscribedPetId == petId) return;
    _scansSubscribedPetId = petId;
    _scansSubscription?.cancel();
    _scansForSelectedPet = const [];
    _scansSubscription = widget.scanRepository.watchScans(petId).listen((
      scans,
    ) {
      if (!mounted) return;
      setState(() => _scansForSelectedPet = scans);
    });
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Couldn't save changes. Check your connection."),
      ),
    );
  }

  void _selectPet(int index) {
    setState(() => _selectedIndex = index);
    _subscribeToScans();
  }

  Future<void> _addPet() async {
    final newPet = await Navigator.of(context).push<Pet>(
      MaterialPageRoute(
        builder: (_) => PetFormScreen(pickPhoto: widget.addPetPickPhoto),
      ),
    );
    if (newPet == null) return;
    setState(() {
      _pets = [..._pets, newPet];
      _selectedIndex = _pets.length - 1;
    });
    _subscribeToScans();
    try {
      await widget.petRepository.addPet(newPet);
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  void _editPet(Pet updated) async {
    setState(() {
      final index = _pets.indexWhere((p) => p.id == updated.id);
      if (index != -1) _pets[index] = updated;
    });
    try {
      await widget.petRepository.updatePet(updated);
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  void _deletePet(Pet pet) async {
    final removingSelected = _selectedPet.id == pet.id;
    setState(() {
      _pets = _pets.where((p) => p.id != pet.id).toList();
      if (removingSelected || _selectedIndex >= _pets.length) {
        _selectedIndex = 0;
      }
    });
    _subscribeToScans();
    try {
      await widget.petRepository.deletePet(pet.id);
    } catch (_) {
      if (!mounted) return;
      _showSaveError();
    }
  }

  Future<void> _openScan() async {
    if (_freeScanUsed && !_isSubscribed) {
      final subscribed = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const PaywallScreen()));
      if (subscribed != true) return;
      if (!mounted) return;
      setState(() => _isSubscribed = true);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          pet: _selectedPet,
          scanRepository: widget.scanRepository,
          onScanCompleted: () => setState(() => _freeScanUsed = true),
        ),
      ),
    );
  }

  void _showHomeTab() => setState(() => _activeTab = 0);
  void _showTimelineTab() => setState(() => _activeTab = 1);
  void _showSettingsTab() => setState(() => _activeTab = 2);

  Widget _bottomNav(int activeIndex) => _BottomTabBar(
    activeIndex: activeIndex,
    onHomeTap: _showHomeTab,
    onTimelineTap: _showTimelineTab,
    onSettingsTap: _showSettingsTab,
  );

  @override
  void dispose() {
    _petsSubscription.cancel();
    _scansSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_activeTab) {
      case 1:
        return TimelineScreen(
          pet: _selectedPet,
          scans: _scansForSelectedPet,
          onDelete: (scan) =>
              widget.scanRepository.deleteScan(_selectedPet.id, scan.id),
          bottomNavigationBar: _bottomNav(1),
        );
      case 2:
        return SettingsScreen(
          pets: _pets,
          onAddPet: _addPet,
          onEditPet: _editPet,
          onDeletePet: _deletePet,
          pickPhoto: widget.addPetPickPhoto,
          accountEmail: widget.accountEmail,
          petRepository: widget.petRepository,
          bottomNavigationBar: _bottomNav(2),
        );
      default:
        return _buildHomeTab(context);
    }
  }

  Widget _buildHomeTab(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(BrandAssets.logo, width: 32, height: 32),
            const SizedBox(width: AppTheme.spaceSm),
            Text('PawCheck', style: textTheme.headlineSmall),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 68,
              child: _PetChipRow(
                pets: _pets,
                selectedIndex: _selectedIndex,
                onSelect: _selectPet,
                onAdd: _addPet,
              ),
            ),
            Expanded(
              // Same "center if it fits, scroll if it doesn't" pattern as
              // the onboarding screen — see that file for why a bare
              // `mainAxisAlignment: center` isn't enough on its own.
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
                      child: Center(
                        child: FadeSlideIn(
                          child: _ScanCta(pet: _selectedPet, onTap: _openScan),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(0),
    );
  }
}

/// "Horizontal scrollable row of pet chips ... trailing chip: dashed-border
/// '+ Add' chip" per the doc.
class _PetChipRow extends StatelessWidget {
  const _PetChipRow({
    required this.pets,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Pet> pets;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLg,
        vertical: AppTheme.spaceSm,
      ),
      children: [
        for (var i = 0; i < pets.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spaceSm),
            child: _PetChip(
              key: Key('pet_chip_${pets[i].id}'),
              pet: pets[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          ),
        _AddPetChip(key: const Key('add_pet_chip'), onTap: onAdd),
      ],
    );
  }
}

/// One pet chip: "small circular avatar (initial letter, sage-500 bg
/// normally, violet bg + white text when selected) + pet name, pill-shaped,
/// surface bg (violet-100 bg when selected)" per the doc — since overridden
/// at the user's explicit request to show the pet's real photo
/// ([Pet.photoUrl]) in that avatar when one's been set, falling back to the
/// original initial-letter design only when it hasn't.
class _PetChip extends StatelessWidget {
  const _PetChip({
    super.key,
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial = pet.name.isEmpty ? '?' : pet.name[0].toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.only(
            left: 6,
            right: AppTheme.spaceMd,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: selected
                    ? colorScheme.primary
                    : colorScheme.secondary,
                backgroundImage: pet.photoUrl != null
                    ? photoImageProvider(pet.photoUrl!)
                    : null,
                child: pet.photoUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                pet.name,
                style: textTheme.labelLarge?.copyWith(
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPetChip extends StatelessWidget {
  const _AddPetChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: CustomPaint(
          painter: _DashedPillBorderPainter(color: colorScheme.outline),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: AppTheme.spaceSm + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed pill border — Flutter's `Border` has no dashed style
/// built in. Static (no animation), so it carries no motion-safety risk.
class _DashedPillBorderPainter extends CustomPainter {
  const _DashedPillBorderPainter({required this.color});

  final Color color;

  static const _dashWidth = 4.0;
  static const _dashSpace = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPillBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "Center: large circular violet button (132px) with a camera icon ...
/// 'Scan {pet name}' / 'Photograph the area of concern'" per the doc.
class _ScanCta extends StatelessWidget {
  const _ScanCta({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Material(
          color: colorScheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('shutter_button'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 132,
              height: 132,
              child: Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLg),
        Text('Scan ${pet.name}', style: textTheme.headlineSmall),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          'Photograph the area of concern',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Floating bottom nav — 3 icon-only tabs (Home, Timeline, Settings) in a
/// dark pill that floats above the page with a visible gap on every side,
/// rather than a full-width bar. Deliberately off the app's normal cream/
/// violet surface palette, same category as Splash/Camera's dark
/// exceptions — this near-black-pill-with-a-solid-violet-active-icon look
/// was a specific user reference-image request, replacing the doc's own
/// section 4 mockup (a 2-tab, icon+label, surface-colored bar with
/// rounded top corners only). Settings moved here as the third tab
/// instead of an AppBar action, so all three top-level destinations read
/// as equal-weight nav items.
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.activeIndex,
    required this.onHomeTap,
    required this.onTimelineTap,
    required this.onSettingsTap,
  });

  /// 0 = Home, 1 = Timeline, 2 = Settings.
  final int activeIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onTimelineTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceXl,
          vertical: AppTheme.spaceSm,
        ),
        // `Row` here (not `Center`) deliberately — `Scaffold` gives
        // `bottomNavigationBar` loose-but-large height constraints, and
        // `Center`/`Align` at this position would greedily expand to
        // fill that entire loose height by default (their documented
        // behavior absent a width/heightFactor), ballooning this bar to
        // consume most of the screen and squeezing the body to near
        // zero. `Row(mainAxisAlignment: center)` shrink-wraps vertically
        // to its child's own height while still centering it
        // horizontally.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF211E27),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXs,
                  vertical: AppTheme.spaceXs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabItem(
                      key: const Key('home_tab'),
                      icon: Icons.home_rounded,
                      active: activeIndex == 0,
                      onTap: onHomeTap,
                      activeColor: colorScheme.primary,
                      activeIconColor: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    _TabItem(
                      key: const Key('timeline_tab'),
                      icon: Icons.watch_later_outlined,
                      active: activeIndex == 1,
                      onTap: onTimelineTap,
                      activeColor: colorScheme.primary,
                      activeIconColor: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    _TabItem(
                      key: const Key('settings_tab'),
                      icon: Icons.settings_outlined,
                      active: activeIndex == 2,
                      onTap: onSettingsTap,
                      activeColor: colorScheme.primary,
                      activeIconColor: colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.activeIconColor,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color activeIconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.motionCurve,
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeColor : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 22,
            color: active ? activeIconColor : Colors.white70,
          ),
        ),
      ),
    );
  }
}

Future<XFile?> _defaultPickAddPetPhoto() =>
    ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
