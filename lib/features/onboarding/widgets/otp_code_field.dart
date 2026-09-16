import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A 6-digit code entry, rendered as individual boxed cells rather than one
/// plain text field (per the user's reference design), restyled in the
/// app's own violet/cream theme instead of copying that reference's
/// colors. Under the hood this is still one real [TextField] — an
/// invisible one stacked over the decorative boxes, capturing all input —
/// rather than six separate focus nodes, which would need per-box
/// backspace/paste handling for little visible benefit here (the user
/// types a code they didn't compose digit-by-digit, they paste or type it
/// straight through).
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int length;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _DigitBoxes(
              text: controller.text,
              length: length,
            ),
          ),
          Opacity(
            // Fully transparent would still let VoiceOver/TalkBack find
            // it (opacity doesn't remove semantics), but a real cursor
            // blink needs *something* rendered — 0.0 opacity, not
            // `Visibility`, keeps the field focusable and the OS
            // autofill/SMS-code suggestion bar working.
            opacity: 0.0,
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: length,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitBoxes extends StatelessWidget {
  const _DigitBoxes({required this.text, required this.length});

  final String text;
  final int length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeIndex = text.length.clamp(0, length - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final digit = index < text.length ? text[index] : '';
        final isActive = index == activeIndex;

        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : AppTheme.spaceSm),
          child: AnimatedContainer(
            duration: AppTheme.motionFast,
            curve: AppTheme.motionCurve,
            width: 44,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Text(
              digit,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }
}
