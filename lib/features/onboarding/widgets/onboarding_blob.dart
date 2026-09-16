import 'dart:math' as math;

import 'package:flutter/material.dart';

/// PawCheck's shared illustration language: a literal, hand-drawn-feeling
/// paw print (one large main pad + four toe pads) rather than a generic
/// circular blob or a stock Material icon. It's the one visual motif that
/// repeats — at different sizes, tilts, and tones — across the splash
/// screen, onboarding, and the pet profile form, so those three screens
/// read as one connected identity instead of three separate designs.
///
/// [PawMark] is the bold, foreground hero version (near-solid fill, soft
/// drop shadow, optional glossy highlight, optional small icon "badge"
/// sticker on one corner). [PawFieldBackdrop] reuses the exact same pad
/// geometry at a handful of fixed positions/rotations and a very low alpha
/// to lay down a subtle wallpaper texture behind a screen's content.
class PawMark extends StatelessWidget {
  const PawMark({
    super.key,
    required this.color,
    this.accentColor,
    this.size = 168,
    this.rotation = 0,
    this.badgeIcon,
    this.badgeColor,
    this.ringColor = Colors.white,
    this.withEffects = true,
  });

  /// Tint for the main (largest) pad.
  final Color color;

  /// Tint for the four toe pads. Defaults to [color] when omitted.
  final Color? accentColor;

  final double size;

  /// Rotation in radians applied to the whole mark, for a hand-placed,
  /// slightly-off-kilter sticker feel rather than a perfectly upright icon.
  final double rotation;

  /// When set, overlays a small circular icon "sticker" on the mark's
  /// upper-right corner — used to carry a page's topical icon (camera,
  /// shield, ...) while keeping the paw shape as the constant brand anchor.
  final IconData? badgeIcon;
  final Color? badgeColor;

  /// Ring color drawn around the badge, meant to match the surface the
  /// mark sits on so the badge reads as a separate layered sticker.
  final Color ringColor;

  /// Soft shadow + gloss highlight, on by default for the hero use case.
  /// Turned off for smaller/denser decorative uses.
  final bool withEffects;

  @override
  Widget build(BuildContext context) {
    final toeColor = accentColor ?? color;
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PawPainter(
                  mainColor: color,
                  toeColor: toeColor,
                  withEffects: withEffects,
                ),
              ),
            ),
            if (badgeIcon != null)
              Positioned(
                right: -size * 0.05,
                top: -size * 0.02,
                child: Transform.rotate(
                  angle: -rotation,
                  child: Container(
                    padding: EdgeInsets.all(size * 0.09),
                    decoration: BoxDecoration(
                      color: badgeColor ?? color,
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: size * 0.028),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: size * 0.06,
                          offset: Offset(0, size * 0.02),
                        ),
                      ],
                    ),
                    child: Icon(
                      badgeIcon,
                      size: size * 0.16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A full-bleed, purely decorative scatter of small low-alpha paw prints —
/// meant to sit as the first child of a [Stack] behind a screen's real
/// content, giving every screen in this flow the same faint "walked
/// across" wallpaper texture. Static (no animation, no state) and cheap to
/// paint, so it carries no motion-safety risk of its own.
class PawFieldBackdrop extends StatelessWidget {
  const PawFieldBackdrop({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    // `SizedBox.expand` rather than `Positioned.fill` — this widget is used
    // both as a direct `Stack` child (onboarding, pet form) and wrapped in a
    // `FadeTransition` (splash), and `Positioned` is only valid directly
    // inside a `Stack`; wrapping it in any other single-child widget throws
    // "Incorrect use of ParentDataWidget". `SizedBox.expand` fills whatever
    // constraints it's given either way.
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(painter: _PawFieldPainter(color: color)),
      ),
    );
  }
}

/// Builds a soft, rounded-but-irregular blob path by perturbing points on a
/// circle and connecting them with smooth quadratic curves. Shared by every
/// pad in [_paintPawPads] so the whole mark keeps one consistent, slightly
/// hand-drawn wobble rather than looking machine-perfect.
Path _wobblyBlob(
  Offset center,
  double radius,
  double wobble,
  List<double> seq,
) {
  const points = 8;
  final vertices = List.generate(points, (i) {
    final angle = (2 * math.pi / points) * i;
    final r = radius * (1 + seq[i % seq.length] * wobble);
    return center + Offset(math.cos(angle), math.sin(angle)) * r;
  });

  final path = Path()..moveTo(vertices[0].dx, vertices[0].dy);
  for (var i = 0; i < points; i++) {
    final current = vertices[i];
    final next = vertices[(i + 1) % points];
    final mid = Offset((current.dx + next.dx) / 2, (current.dy + next.dy) / 2);
    path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}

/// Paints one paw print — a large main pad plus four smaller toe pads —
/// centered on the canvas origin within a `size`-edge bounding box. Shared
/// by both [_PawPainter] (one big hero mark) and [_PawFieldPainter] (many
/// tiny background prints) so the same silhouette repeats at every scale.
void _paintPawPads(
  Canvas canvas, {
  required double size,
  required Color mainColor,
  required Color toeColor,
  double mainAlpha = 0.85,
  double toeAlpha = 0.78,
  bool withEffects = false,
}) {
  Offset p(double fx, double fy) =>
      Offset((fx - 0.5) * size, (fy - 0.5) * size);

  final main = _wobblyBlob(p(0.5, 0.66), 0.30 * size, 0.09, const [
    0.0,
    0.6,
    -0.4,
    0.3,
    -0.7,
    0.5,
    -0.2,
    0.6,
  ]);
  final toeA = _wobblyBlob(p(0.19, 0.35), 0.145 * size, 0.12, const [
    0.3,
    -0.5,
    0.6,
    -0.2,
    0.4,
    -0.6,
    0.2,
    -0.3,
  ]);
  final toeB = _wobblyBlob(p(0.395, 0.155), 0.165 * size, 0.10, const [
    -0.4,
    0.5,
    -0.2,
    0.6,
    -0.5,
    0.3,
    -0.3,
    0.4,
  ]);
  final toeC = _wobblyBlob(p(0.61, 0.155), 0.165 * size, 0.10, const [
    0.4,
    -0.3,
    0.5,
    -0.6,
    0.3,
    -0.4,
    0.6,
    -0.2,
  ]);
  final toeD = _wobblyBlob(p(0.81, 0.35), 0.145 * size, 0.12, const [
    -0.3,
    0.4,
    -0.6,
    0.2,
    -0.4,
    0.5,
    -0.2,
    0.3,
  ]);

  if (withEffects) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.045);
    for (final pad in [main, toeA, toeB, toeC, toeD]) {
      canvas.drawPath(
        pad.shift(Offset(size * 0.035, size * 0.05)),
        shadowPaint,
      );
    }
  }

  final toePaint = Paint()..color = toeColor.withValues(alpha: toeAlpha);
  for (final pad in [toeA, toeB, toeC, toeD]) {
    canvas.drawPath(pad, toePaint);
  }

  final mainPaint = Paint()..color = mainColor.withValues(alpha: mainAlpha);
  canvas.drawPath(main, mainPaint);

  if (withEffects) {
    final glossPaint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    canvas.drawPath(
      _wobblyBlob(p(0.40, 0.56), 0.12 * size, 0.15, const [
        0.2,
        -0.4,
        0.5,
        -0.2,
        0.3,
        -0.5,
        0.4,
        -0.1,
      ]),
      glossPaint,
    );
  }
}

class _PawPainter extends CustomPainter {
  const _PawPainter({
    required this.mainColor,
    required this.toeColor,
    this.withEffects = true,
  });

  final Color mainColor;
  final Color toeColor;
  final bool withEffects;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    _paintPawPads(
      canvas,
      size: size.shortestSide,
      mainColor: mainColor,
      toeColor: toeColor,
      withEffects: withEffects,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PawPainter oldDelegate) =>
      oldDelegate.mainColor != mainColor ||
      oldDelegate.toeColor != toeColor ||
      oldDelegate.withEffects != withEffects;
}

class _PawFieldPainter extends CustomPainter {
  const _PawFieldPainter({required this.color});

  final Color color;

  // (fractionX, fractionY, scale-of-shortest-side, rotation-radians)
  static const _prints = [
    (0.10, 0.12, 0.30, -0.35),
    (0.88, 0.08, 0.20, 0.5),
    (0.78, 0.34, 0.36, -0.15),
    (0.16, 0.80, 0.28, 0.30),
    (0.92, 0.88, 0.24, -0.4),
    (0.46, 0.95, 0.16, 0.10),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (dx, dy, scale, rotation) in _prints) {
      final printSize = size.shortestSide * scale;
      canvas.save();
      canvas.translate(size.width * dx, size.height * dy);
      canvas.rotate(rotation);
      _paintPawPads(
        canvas,
        size: printSize,
        mainColor: color,
        toeColor: color,
        mainAlpha: 0.06,
        toeAlpha: 0.05,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PawFieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
