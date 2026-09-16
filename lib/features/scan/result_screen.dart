import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/pet.dart';
import '../../core/models/urgency_level.dart';
import '../../core/services/ai_triage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/urgency_colors.dart';

/// Matches [url_launcher]'s `launchUrl` signature so tests can inject a
/// fake instead of actually opening a URL (same DI pattern as this
/// feature's `ImagePickerFn`/`PhotoPickerFn`).
typedef UrlLauncherFn = Future<bool> Function(Uri uri);

Future<bool> _defaultLaunchUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Uri _vetSearchUri() => Uri.parse(
  'https://www.google.com/maps/search/?api=1&query=veterinarian+near+me',
);

/// "This is not a diagnosis..." — present on every tier per the doc,
/// verbatim, never reworded (non-diagnostic language is a PRD Section 7
/// requirement, not just copy).
const _findVetDisclaimer =
    "This is not a diagnosis. It's a starting point based on the photo — "
    'for anything you\'re unsure about, a vet exam is the way to be sure.';

/// Scan results, per section 6 of the "Paw Check claude design" handoff
/// doc (see that folder's README.md at the repo root) — the screen the
/// doc itself calls out as needing the most design care. Two genuinely
/// different layouts, not a color swap: [_NormalResultView] for Low/
/// Monitor/See-a-vet-soon, and [_EmergencyView] as a full-screen red
/// takeover for Emergency.
///
/// One deliberate deviation from the doc: CLAUDE.md states, as a
/// non-negotiable safety rule (PRD Section 7 / the overview's safety
/// boundaries), that "Find a vet nearby" must not show at all for Low
/// tier. The design doc's own mockup instead shows an outlined version of
/// that button for Low. Per this repo's CLAUDE.md ("These instructions
/// OVERRIDE any default behavior"), the button is hidden for Low here,
/// not just de-emphasized.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.pet,
    required this.result,
    required this.photo,
    required this.scanDate,
    this.launchUrl = _defaultLaunchUrl,
  });

  final Pet pet;
  final TriageResult result;
  final ImageProvider photo;
  final DateTime scanDate;
  final UrlLauncherFn launchUrl;

  Future<void> _findVetNearby() => launchUrl(_vetSearchUri());

  @override
  Widget build(BuildContext context) {
    if (result.urgencyLevel == UrgencyLevel.emergency) {
      return _EmergencyView(result: result, onFindVet: _findVetNearby);
    }
    return _NormalResultView(
      pet: pet,
      result: result,
      photo: photo,
      scanDate: scanDate,
      onFindVet: _findVetNearby,
    );
  }
}

class _NormalResultView extends StatelessWidget {
  const _NormalResultView({
    required this.pet,
    required this.result,
    required this.photo,
    required this.scanDate,
    required this.onFindVet,
  });

  final Pet pet;
  final TriageResult result;
  final ImageProvider photo;
  final DateTime scanDate;
  final Future<void> Function() onFindVet;

  @override
  Widget build(BuildContext context) {
    final tier = UrgencyTierColors.forLevel(result.urgencyLevel);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // CLAUDE.md non-negotiable rule — see class doc comment on
    // [ResultScreen].
    final showFindVet = result.urgencyLevel != UrgencyLevel.low;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pet.name, style: textTheme.titleMedium),
            Text(
              _formatDate(scanDate),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image(
                image: photo,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 150,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _UrgencyBanner(
              key: const Key('urgency_banner'),
              tier: tier,
              urgencyLevel: result.urgencyLevel,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            _WhatWeSawCard(
              description: result.description,
              causes: result.causes,
            ),
            const SizedBox(height: AppTheme.spaceLg),
            const _DisclaimerRow(),
            if (showFindVet) ...[
              const SizedBox(height: AppTheme.spaceLg),
              _FindVetButton(
                key: const Key('find_vet_button'),
                tier: tier,
                onTap: onFindVet,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// "Full-width rounded card, tier bg-tint color, icon (circle with
/// exclamation) + 'Urgency' label (10px uppercase) + tier label large
/// (18px, Caprasimo). This must read at a glance." per the doc.
class _UrgencyBanner extends StatelessWidget {
  const _UrgencyBanner({
    super.key,
    required this.tier,
    required this.urgencyLevel,
  });

  final UrgencyTierColors tier;
  final UrgencyLevel urgencyLevel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: tier.backgroundTint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(Icons.priority_high_rounded, color: tier.iconAndBorder),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URGENCY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: tier.textOnTint.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  urgencyLevel.wireValue,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    color: tier.textOnTint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "'What we saw' card (surface bg): kicker label + 1–2 sentence
/// plain-language explanation (never a diagnosis, never a drug/treatment
/// name)" per the doc. Also shows the 2–4 tag-style possible causes
/// (PRD FR4/Section 5) — the doc's summary bullet doesn't itemize these,
/// but they're an explicit "Must" requirement elsewhere in the PRD.
class _WhatWeSawCard extends StatelessWidget {
  const _WhatWeSawCard({required this.description, required this.causes});

  final String description;
  final List<String> causes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT WE SAW',
            style: textTheme.labelLarge?.copyWith(
              fontSize: 11,
              letterSpacing: 1,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(description, style: textTheme.bodyLarge),
          if (causes.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Wrap(
              spacing: AppTheme.spaceXs,
              runSpacing: AppTheme.spaceXs,
              children: [
                for (final cause in causes)
                  Chip(
                    label: Text(cause),
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "A muted disclaimer row (info icon + small text) ... present on every
/// tier" per the doc.
class _DisclaimerRow extends StatelessWidget {
  const _DisclaimerRow();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Text(
            _findVetDisclaimer,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Primary 'Find a vet near you' button ... solid tier-color fill for
/// Monitor/See-a-vet-soon" per the doc (Low's outlined variant is skipped
/// entirely — see class doc comment on [ResultScreen]).
class _FindVetButton extends StatelessWidget {
  const _FindVetButton({super.key, required this.tier, required this.onTap});

  final UrgencyTierColors tier;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: tier.iconAndBorder,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        icon: const Icon(Icons.location_on_outlined),
        label: const Text('Find a vet nearby'),
      ),
    );
  }
}

/// "Emergency (full-screen takeover — deliberately breaks the normal
/// layout) ... Entire screen becomes deep red, white text/icons" per the
/// doc.
class _EmergencyView extends StatefulWidget {
  const _EmergencyView({required this.result, required this.onFindVet});

  final TriageResult result;
  final Future<void> Function() onFindVet;

  @override
  State<_EmergencyView> createState() => _EmergencyViewState();
}

class _EmergencyViewState extends State<_EmergencyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Deliberate, documented exception to this app's "no ambient/looping
    // animation" rule (see e.g. `FadeSlideIn`/`PopIn`'s doc comments) —
    // the design doc explicitly specifies a looping pulse here ("scale
    // 1→2.1, fade out, looping ~1.6s"), and a genuine medical-emergency
    // alert is exactly the one case where sustained motion is the
    // correct, intentional signal rather than decorative noise: it's
    // meant to keep grabbing attention, not to feel calm. Tests that pump
    // this view must NEVER call `pumpAndSettle()` — it will never settle.
    // Use bounded `tester.pump(duration)` calls instead.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.result.description.trim().isNotEmpty
        ? widget.result.description
        : 'This combination of signs is one vets treat as urgent — please '
              'seek care right away.';

    return Scaffold(
      backgroundColor: UrgencyTierColors.emergencyBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingSirenIcon(controller: _pulseController),
                      const SizedBox(height: AppTheme.spaceXl),
                      const Text(
                        'URGENT — ACT NOW',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      const Text(
                        'This needs a vet right away',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('find_emergency_vet_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: UrgencyTierColors.emergencyBackground,
                  ),
                  onPressed: widget.onFindVet,
                  child: const Text('Find emergency vets near you'),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              const Text(
                _findVetDisclaimer,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Pulsing ring animation (scale 1→2.1, fade out, looping ~1.6s) behind a
/// siren icon in a translucent white circle (96px)" per the doc.
class _PulsingSirenIcon extends StatelessWidget {
  const _PulsingSirenIcon({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final scale = 1 + controller.value * 1.1;
              final opacity = (1 - controller.value).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }
}
