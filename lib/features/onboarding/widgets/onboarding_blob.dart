import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A soft, hand-drawn-feeling backdrop for an onboarding icon. Purely
/// decorative — an organic blob (not a plain circle) painted behind the
/// icon in a muted tint of [color], with a smaller offset "echo" blob for
/// depth. Keeps the onboarding illustrations feeling designed rather than
/// like default Material icon placeholders, without pulling in any image
/// assets or new packages.
class OnboardingBlob extends StatelessWidget {
  const OnboardingBlob({
    super.key,
    required this.icon,
    required this.color,
    this.size = 168,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlobPainter(color: color),
        child: Center(
          child: Icon(icon, size: size * 0.4, color: color),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Echo blob: smaller, softer, offset toward the top-left for a subtle
    // sense of depth behind the main shape.
    final echoPaint = Paint()..color = color.withValues(alpha: 0.10);
    canvas.drawPath(
      _organicPath(
        center + Offset(-radius * 0.12, -radius * 0.10),
        radius * 0.86,
      ),
      echoPaint,
    );

    final mainPaint = Paint()..color = color.withValues(alpha: 0.14);
    canvas.drawPath(_organicPath(center, radius), mainPaint);
  }

  /// Builds a soft, rounded-but-irregular blob path by perturbing points
  /// on a circle and connecting them with smooth cubic curves.
  Path _organicPath(Offset center, double radius) {
    const points = 8;
    const wobble = 0.07;
    // Fixed per-vertex offsets (not random) so the shape is stable across
    // rebuilds/frames instead of jittering.
    const wobbleSeq = [0.0, 1.0, -0.6, 0.4, -1.0, 0.6, -0.3, 0.8];

    final vertices = List.generate(points, (i) {
      final angle = (2 * math.pi / points) * i;
      final r = radius * (1 + wobbleSeq[i] * wobble);
      return center + Offset(math.cos(angle), math.sin(angle)) * r;
    });

    final path = Path()..moveTo(vertices[0].dx, vertices[0].dy);
    for (var i = 0; i < points; i++) {
      final current = vertices[i];
      final next = vertices[(i + 1) % points];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) =>
      oldDelegate.color != color;
}
