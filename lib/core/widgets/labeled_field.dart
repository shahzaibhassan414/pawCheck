import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A caption-style label sitting above a form field, with the field's own
/// `InputDecoration.labelText` left unset — a floating/placeholder-style
/// label reads as the field's content before it's focused, then jumps up
/// once you start typing, which briefly makes the field itself look
/// unlabeled. This puts the field's name in a fixed position instead, so
/// [child]'s own `hintText` can stay a pure example value rather than
/// doing double duty as the field's definition.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        child,
      ],
    );
  }
}
