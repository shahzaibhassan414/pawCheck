import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gender selector chip — an optional field (unlike species), so tapping an
/// already-selected chip deselects it rather than being a hard single-pick;
/// callers wire that toggle behavior themselves via [onTap]. Pill-shaped
/// per the app's general chip/tag convention (`AppTheme.radiusPill`),
/// smaller and icon-led rather than the illustrated `SpeciesOptionCard`
/// style — there's no dedicated character art for gender, and it's a
/// lighter-weight, optional field.
class GenderOptionChip extends StatelessWidget {
  const GenderOptionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
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
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.motionCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLg,
            vertical: AppTheme.spaceMd,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                label,
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
