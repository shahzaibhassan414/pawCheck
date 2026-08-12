import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/widgets/onboarding_blob.dart';

/// The first Flutter-rendered frame the user sees, shown for a short,
/// deliberate moment after the OS-level native splash (see
/// `flutter_native_splash` in `pubspec.yaml`, which just paints a solid
/// color before the engine boots) hands off, and before onboarding starts.
///
/// Purely presentational: there's no persistence layer yet (see
/// CLAUDE.md/CHANGELOG — still blocked on Firebase account setup), so this
/// always leads to [OnboardingScreen]. It never branches on "already
/// onboarded" state or makes any async/service calls.
///
/// The entrance (blob mark + wordmark fading/scaling in) is driven entirely
/// by a single [AnimationController] rather than `Future.delayed`/`Timer` —
/// same discipline as `FadeSlideIn`: a bare `Timer` can outlive a disposed
/// widget in tests and trips flutter_test's "Timer is still pending"
/// invariant. Auto-navigation fires off the controller's own
/// `AnimationStatus.completed` callback instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Total time the splash is shown before navigating to onboarding —
  /// exposed so tests can pump exactly this far without guessing at timing.
  static const totalDuration = Duration(milliseconds: 1200);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.totalDuration,
    );

    // The entrance itself finishes at 70% of the timeline; the remaining
    // 30% is a deliberate calm hold before auto-navigating, so the brand
    // mark isn't whisked away the instant it settles.
    final entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: AppTheme.motionCurve),
    );
    _fade = entrance;
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(entrance);

    _controller.addStatusListener(_onStatusChanged);
    _controller.forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _navigateToOnboarding();
    }
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
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
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OnboardingBlob(
                  icon: Icons.pets_rounded,
                  color: colorScheme.primary,
                  size: 132,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                Text('PawCheck', style: textTheme.displaySmall),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'A calmer first look',
                  style: textTheme.bodyLarge?.copyWith(
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
