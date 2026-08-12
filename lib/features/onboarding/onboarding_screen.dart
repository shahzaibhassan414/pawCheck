import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'pet_profile_form_screen.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/onboarding_blob.dart';

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
      icon: Icons.camera_alt_rounded,
      title: 'Snap a photo, get instant clarity',
      body:
          'Worried about a weird patch of skin, a limp, or something in '
          "your pet's stool? Take a photo and get a plain-language read on "
          "what's visible and how urgent it is.",
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      title: "PawCheck isn't a vet",
      body:
          'PawCheck provides general information only and is not a '
          'substitute for professional veterinary advice. Always consult a '
          'real veterinarian for diagnosis or treatment.',
    ),
  ];

  bool get _isLastPage => _page == _pages.length - 1;

  void _next() {
    if (_isLastPage) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PetProfileFormScreen()));
      return;
    }
    _pageController.nextPage(
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
            _PageIndicator(count: _pages.length, current: _page),
            const SizedBox(height: AppTheme.spaceLg),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                0,
                AppTheme.spaceLg,
                AppTheme.spaceLg,
              ),
              child: _NextButton(isLastPage: _isLastPage, onPressed: _next),
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
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeSlideIn(
            child: OnboardingBlob(icon: data.icon, color: colorScheme.primary),
          ),
          const SizedBox(height: AppTheme.spaceXxl),
          FadeSlideIn(
            delay: const Duration(milliseconds: 90),
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              style: textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: Text(
              data.body,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.motionCurve,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
        );
      }),
    );
  }
}

/// The bottom CTA. Uses a tap-scale press effect (bounded — settles as soon
/// as the finger lifts) rather than any ambient/looping animation, and
/// cross-fades its label between "Next" and "Get started".
class _NextButton extends StatefulWidget {
  const _NextButton({required this.isLastPage, required this.onPressed});

  final bool isLastPage;
  final VoidCallback onPressed;

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.97 : 1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: AppTheme.motionFast,
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('onboarding_next_button'),
            onPressed: widget.onPressed,
            child: AnimatedSwitcher(
              duration: AppTheme.motionFast,
              child: Row(
                key: ValueKey(widget.isLastPage),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.isLastPage ? 'Get started' : 'Next'),
                  const SizedBox(width: AppTheme.spaceSm),
                  Icon(
                    widget.isLastPage
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
