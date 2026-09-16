import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/brand_assets.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_info_service.dart';
import '../../core/services/device_recording.dart';
import '../../core/services/device_repository.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/firestore_device_repository.dart';
import '../../core/services/firestore_pet_repository.dart';
import '../../core/services/firestore_scan_repository.dart';
import '../../core/services/pet_repository.dart';
import '../../core/services/platform_device_info_service.dart';
import '../../core/services/scan_repository.dart';
import '../../core/theme/app_theme.dart';
import '../onboarding/account_setup_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../scan/home_screen.dart';

/// The first Flutter-rendered frame, shown after the OS-level native splash
/// hands off and before onboarding starts. Rebuilt to match the "Paw Check
/// claude design" handoff doc's Splash screen spec (see that folder's
/// README.md, section 1): a full-bleed violet takeover — deliberately the
/// one screen in the app that isn't on the cream/card design system, since
/// it's shown for only a moment and reads as a bold brand stamp rather than
/// a working surface.
///
/// Resolves the signed-in user's email ([AuthService.resolveSignedInEmail])
/// alongside the entrance animation, then routes three ways: not signed in
/// → [OnboardingScreen] (which leads into email verification); signed in
/// but no pets yet (an interrupted setup) → [AccountSetupScreen]; signed in
/// with pets → [HomeScreen]. This is Milestone 3's "don't show onboarding
/// again for an existing user" requirement, now keyed off a real verified
/// account instead of an anonymous install.
///
/// The entrance (mark fades/scales in, then the wordmark fades/slides up)
/// is driven entirely by a single [AnimationController] rather than
/// `Future.delayed`/`Timer` — a bare `Timer` can outlive a disposed widget
/// in tests and trips flutter_test's "Timer is still pending" invariant.
/// Auto-navigation fires off the controller's own `AnimationStatus.
/// completed` callback, once the auth/pets loads have also resolved. Per
/// the design doc ("Entire screen is tappable to continue... auto-advance
/// after a short delay and/or on tap"), a tap anywhere also jumps straight
/// ahead, waiting on the same loads if they haven't finished yet.
class SplashScreen extends StatefulWidget {
  SplashScreen({
    super.key,
    AuthService? authService,
    PetRepository? petRepository,
    ScanRepository? scanRepository,
    DeviceInfoService? deviceInfoService,
    DeviceRepository? deviceRepository,
  }) : authService = authService ?? FirebaseAuthService(),
       petRepository = petRepository ?? FirestorePetRepository(),
       scanRepository = scanRepository ?? FirestoreScanRepository(),
       deviceInfoService = deviceInfoService ?? PlatformDeviceInfoService(),
       deviceRepository = deviceRepository ?? FirestoreDeviceRepository();

  /// Total time the splash is shown before navigating onward —
  /// exposed so tests can pump exactly this far without guessing at timing.
  static const totalDuration = Duration(milliseconds: 1500);

  /// All default to the real Firebase-backed services — every automated
  /// test must inject `FakeAuthService`/`InMemoryPetRepository`/
  /// `InMemoryScanRepository`/`FakeDeviceInfoService`/
  /// `InMemoryDeviceRepository` instead (same "never touch live services in
  /// tests" rule already followed for `AiTriageService`). [scanRepository]
  /// is only used to hand off to [HomeScreen] for a returning user.
  /// [deviceInfoService]/[deviceRepository] back the "record this device on
  /// every launch" step for a signed-in user (see [_recordDevice]).
  final AuthService authService;
  final PetRepository petRepository;
  final ScanRepository scanRepository;
  final DeviceInfoService deviceInfoService;
  final DeviceRepository deviceRepository;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _markFade;
  late final Animation<double> _markScale;
  late final Animation<double> _wordFade;
  late final Animation<Offset> _wordSlide;
  late final Future<String?> _signedInEmailFuture;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _signedInEmailFuture = widget.authService.resolveSignedInEmail();
    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.totalDuration,
    );

    final markEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );
    _markFade = markEntrance;
    _markScale = Tween<double>(begin: 0.7, end: 1.0).animate(markEntrance);

    // Starts partway through the mark's entrance so the wordmark reads as
    // following it in, not appearing simultaneously.
    final wordEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    );
    _wordFade = wordEntrance;
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(wordEntrance);

    _controller.addStatusListener(_onStatusChanged);
    _controller.forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _navigate();
    }
  }

  /// Guarded by [_navigated] so a tap mid-animation and the animation's own
  /// completion can't both fire this. [_signedInEmailFuture] was already
  /// kicked off in [initState], so this typically resolves instantly — but
  /// a tap before it lands still correctly waits rather than racing ahead
  /// with a wrong routing decision.
  Future<void> _navigate() async {
    if (_navigated) return;
    _navigated = true;
    final email = await _signedInEmailFuture;
    if (!mounted) return;

    if (email == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Fire-and-forget: refreshes this device's row (id/type/FCM token) on
    // every launch for a signed-in user, without delaying navigation — a
    // failure here (no network, platform channel error, etc.) must never
    // block getting into the app. See [recordCurrentDevice]. A brand-new
    // sign-in also records its device separately, from
    // `EmailVerificationScreen` — this screen isn't in that flow's
    // navigation path at all.
    unawaited(
      recordCurrentDevice(
        deviceInfoService: widget.deviceInfoService,
        deviceRepository: widget.deviceRepository,
      ),
    );

    final pets = await widget.petRepository.loadPetsOnce();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => pets.isEmpty
            ? AccountSetupScreen(
                accountEmail: email,
                petRepository: widget.petRepository,
                scanRepository: widget.scanRepository,
              )
            : HomeScreen(
                pets: pets,
                accountEmail: email,
                petRepository: widget.petRepository,
                scanRepository: widget.scanRepository,
              ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('splash_screen'),
      // Full-bleed violet, not the app's usual cream — see class doc.
      backgroundColor: colorScheme.primary,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigate,
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -70,
              child: _DecorativeCircle(size: 260, opacity: 0.08),
            ),
            const Positioned(
              bottom: -110,
              left: -100,
              child: _DecorativeCircle(size: 320, opacity: 0.07),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _markFade,
                    child: ScaleTransition(
                      scale: _markScale,
                      // `logoDark` (pale near-white paw + solid violet
                      // pulse glyph) rather than `logo` (bold violet paw)
                      // — on this violet backdrop, the pale paw shows as a
                      // clean white silhouette, and the pulse glyph's
                      // violet exactly matches the background, so it reads
                      // as a genuine cutout rather than a visible shape —
                      // matching the design doc's "heartbeat cut through
                      // in the background color" logo description.
                      child: Image.asset(
                        BrandAssets.logoDark,
                        width: 88,
                        height: 88,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  FadeTransition(
                    opacity: _wordFade,
                    child: SlideTransition(
                      position: _wordSlide,
                      child: Column(
                        children: [
                          Text(
                            'PawCheck',
                            style: textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 30,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text(
                            'A calm second opinion for your pet',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
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

/// One of the two large, soft, barely-there circles decorating the splash
/// per the design doc — static (no animation), so it carries no
/// motion-safety risk of its own.
class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
