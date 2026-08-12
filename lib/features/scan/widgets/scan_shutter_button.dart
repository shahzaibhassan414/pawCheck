import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The home screen's primary call to action. A large circular shutter with
/// a soft halo behind it (static — not animated, so it reads as "featured"
/// without looping) and a bounded press-scale for tactile feedback.
class ScanShutterButton extends StatefulWidget {
  const ScanShutterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<ScanShutterButton> createState() => _ScanShutterButtonState();
}

class _ScanShutterButtonState extends State<ScanShutterButton> {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.94 : 1);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: 108,
        height: 108,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Static soft halo — gives the button presence without an
            // ambient/looping animation.
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            AnimatedScale(
              scale: _scale,
              duration: AppTheme.motionFast,
              curve: Curves.easeOut,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
