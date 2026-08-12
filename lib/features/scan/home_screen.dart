import 'package:flutter/material.dart';

import '../../core/models/pet.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/fade_slide_in.dart';
import 'widgets/scan_shutter_button.dart';

/// Landing screen reached after onboarding. Camera capture (Milestone 4)
/// isn't wired up yet — the shutter button is a visual stand-in so the
/// onboarding -> home flow has somewhere real to land.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.pet});

  final Pet pet;

  bool get _isCat => pet.species.toLowerCase() == 'cat';

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scan screen is coming in the next milestone'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                AppTheme.spaceSm,
                AppTheme.spaceLg,
                AppTheme.spaceXxl,
              ),
              sliver: SliverList.list(
                children: [
                  FadeSlideIn(
                    child: _PetHeader(pet: pet, isCat: _isCat),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: const _HowItHelpsRow(),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 130),
                    child: _EmptyTimelineCard(petName: pet.name),
                  ),
                  const SizedBox(height: AppTheme.spaceXxl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: Column(
                      children: [
                        ScanShutterButton(
                          key: const Key('shutter_button'),
                          onTap: () => _showComingSoon(context),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        Text(
                          'Tap the shutter to check on something',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

class _PetHeader extends StatelessWidget {
  const _PetHeader({required this.pet, required this.isCat});

  final Pet pet;
  final bool isCat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.6),
            child: Icon(
              isCat ? Icons.pets : Icons.pets_outlined,
              size: 28,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    pet.species,
                    if (pet.breed != null) pet.breed,
                    if (pet.age != null) '${pet.age} yr',
                  ].join(' · '),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _HowItHelpsRow extends StatelessWidget {
  const _HowItHelpsRow();

  static const _steps = [
    (icon: Icons.photo_camera_outlined, label: 'Snap'),
    (icon: Icons.auto_awesome_outlined, label: 'Understand'),
    (icon: Icons.health_and_safety_outlined, label: 'Know what to do'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final step in _steps)
          Expanded(
            child: _StepTile(icon: step.icon, label: step.label),
          ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: colorScheme.primary),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyTimelineCard extends StatelessWidget {
  const _EmptyTimelineCard({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Row(
          children: [
            Icon(Icons.timeline_outlined, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No scans yet', style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    "$petName's history will show up here after your first scan.",
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
    );
  }
}
