import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Species selector card — a side-by-side Dog/Cat pair per the "Paw Check
/// claude design" doc's section 3, illustrated with the user-supplied
/// character art (`SpeciesAssets`) rather than the doc's plain line icon.
/// Selected/unselected styling follows the doc's exact spec (2px violet
/// border + violet-100 fill + violet text when selected; divider-color
/// border + card-surface fill + default text otherwise). Shared between
/// the full account setup screen and Home's add-pet dialog.
class SpeciesOptionCard extends StatelessWidget {
  const SpeciesOptionCard({
    super.key,
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String imagePath;
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
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.motionCurve,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(imagePath, width: 56, height: 56),
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
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
