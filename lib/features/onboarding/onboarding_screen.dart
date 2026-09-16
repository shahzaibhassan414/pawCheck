import 'package:flutter/material.dart';

import '../../core/config/brand_assets.dart';
import '../../core/config/species_assets.dart';
import '../../core/theme/app_theme.dart';
import 'email_verification_screen.dart';
import 'widgets/fade_slide_in.dart';

/// The onboarding flow — rebuilt as a photo-style 3-slide carousel at the
/// user's explicit request, referencing a different app's onboarding
/// (colored scalloped hero panel, big pet image, dot progress, pill nav
/// bar with a back-arrow chip). Restyled in PawCheck's own violet/cream
/// theme with its own illustrated pet art (`SpeciesAssets` — there's no
/// real pet photography in this project), not that reference's colors or
/// copy. Step 1 still carries the required not-a-vet disclaimer directly
/// in its body copy, visible with no tap needed — this is a legal/safety
/// requirement (CLAUDE.md / PRD Section 10) preserved from the original
/// 2-step design, not something the visual rework should bury behind
/// navigation. Step 2 is genuinely new content (how the scan flow works);
/// step 3 keeps the original photo-taking tips.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      imagePath: SpeciesAssets.dog,
      title: 'A calm second opinion for your pet',
      body:
          "PawCheck gives you a plain-language second look at what you're "
          "seeing — a starting point, not a diagnosis. It's not a "
          "substitute for professional veterinary advice, so always "
          "follow up with a vet for anything you're unsure about.",
      buttonLabel: 'Continue',
    ),
    _OnboardingPageData(
      imagePath: SpeciesAssets.cat,
      title: 'Snap a photo, get clarity',
      body:
          "Spot something odd? Take a photo and we'll walk you through "
          'possible causes and how urgent it might be — so you know what '
          'to do next.',
      buttonLabel: 'Continue',
    ),
    _OnboardingPageData(
      imagePath: SpeciesAssets.dog,
      title: 'Get a photo that reads clearly',
      body: 'A clear photo helps us give you a better read:',
      tips: [
        _Tip(icon: Icons.wb_sunny_outlined, text: 'Use natural light'),
        _Tip(icon: Icons.crop_free_rounded, text: 'Fill the frame'),
        _Tip(icon: Icons.back_hand_outlined, text: 'Hold steady'),
      ],
      buttonLabel: 'Get started',
    ),
  ];

  bool get _isFirstPage => _page == 0;
  bool get _isLastPage => _page == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => EmailVerificationScreen()));
      return;
    }
    _pageController.nextPage(
      duration: AppTheme.motionMedium,
      curve: AppTheme.motionCurve,
    );
  }

  void _back() {
    if (_isFirstPage) return;
    _pageController.previousPage(
      duration: AppTheme.motionMedium,
      curve: AppTheme.motionCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              child: _ProgressDots(count: _pages.length, current: _page),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                0,
                AppTheme.spaceLg,
                AppTheme.spaceLg,
              ),
              child: Row(
                children: [
                  if (!_isFirstPage) ...[
                    _BackButton(onTap: _back),
                    const SizedBox(width: AppTheme.spaceMd),
                  ],
                  Expanded(
                    child: _ContinueButton(
                      label: _pages[_page].buttonLabel,
                      onTap: _next,
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.imagePath,
    required this.title,
    required this.body,
    required this.buttonLabel,
    this.tips = const [],
  });

  final String imagePath;
  final String title;
  final String body;
  final String buttonLabel;
  final List<_Tip> tips;
}

class _Tip {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(child: _HeroPanel(imagePath: data.imagePath)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceLg,
              AppTheme.spaceLg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Text(data.title, style: textTheme.headlineSmall),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: Text(
                    data.body,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (data.tips.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceLg),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        for (final tip in data.tips)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spaceSm,
                            ),
                            child: _TipRow(tip: tip),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The colored, scallop-bottomed hero panel — the reference's signature
/// visual, adapted to this app's own illustrated pet art
/// ([SpeciesAssets]) instead of photography, and violet instead of that
/// reference's blue.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipPath(
      clipper: _ScallopClipper(),
      child: Container(
        height: 300,
        width: double.infinity,
        color: colorScheme.primaryContainer,
        child: Stack(
          children: [
            Positioned(
              top: AppTheme.spaceLg,
              left: AppTheme.spaceLg,
              child: Row(
                children: [
                  Image.asset(BrandAssets.logo, width: 22, height: 22),
                  const SizedBox(width: AppTheme.spaceXs),
                  Text(
                    'PawCheck',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 50,
              right: 36,
              child: Icon(
                Icons.pets,
                size: 20,
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            Positioned(
              top: 90,
              right: 70,
              child: Icon(
                Icons.pets,
                size: 14,
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(imagePath, height: 220),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A handful of downward-bulging quadratic-bezier lobes across the bottom
/// edge — a soft "cloud" silhouette rather than the panel's default hard
/// rectangle edge.
class _ScallopClipper extends CustomClipper<Path> {
  static const _scallopCount = 5;
  static const _bumpDepth = 20.0;

  @override
  Path getClip(Size size) {
    final scallopWidth = size.width / _scallopCount;
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height);

    for (var i = _scallopCount; i > 0; i--) {
      final x0 = (i - 1) * scallopWidth;
      final xMid = x0 + scallopWidth / 2;
      path.quadraticBezierTo(xMid, size.height + _bumpDepth, x0, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// One "surface-colored card row (icon + text)" per the doc's step 2 spec.
class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip});

  final _Tip tip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(tip.icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              tip.text,
              textAlign: TextAlign.left,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot-style progress indicator — the active dot stretches into a pill,
/// replacing the original 2-segment filled bar to match the reference's
/// dot rhythm.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.spaceXs),
          AnimatedContainer(
            duration: AppTheme.motionFast,
            curve: AppTheme.motionCurve,
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? colorScheme.primary : AppTheme.violet200,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
        ],
      ],
    );
  }
}

/// Circular back chip, matching the reference's bottom-nav back arrow —
/// only shown from step 2 onward (see [_OnboardingScreenState._isFirstPage]
/// — there's nowhere within onboarding to go back to from step 1).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('onboarding_back_button'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

/// The pill CTA with a small icon capsule — matching the reference's
/// button style (an icon-in-a-circle leading the label) rather than a
/// plain text button.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        key: const Key('onboarding_next_button'),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.favorite,
                size: 14,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Text(label),
          ],
        ),
      ),
    );
  }
}
