import 'package:flutter/material.dart';

/// Plays a single fade + upward-slide entrance for [child] when this widget
/// first mounts, then stops. Deliberately one-shot (no repeat/reverse) so it
/// never leaves an animation ticking in the background — long-running
/// implicit/repeating animations make `tester.pumpAndSettle()` hang, and
/// more importantly a calm, trustworthy screen shouldn't be in constant
/// motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // The delay is folded into the controller's own timeline (as a leading
    // Interval) rather than a `Future.delayed` — a raw Dart Timer can
    // outlive a disposed widget in tests and trip flutter_test's
    // "Timer is still pending" invariant check. Driving everything off one
    // vsync-ticked controller avoids that entirely and still settles
    // cleanly under `pumpAndSettle`.
    final totalMicros =
        widget.delay.inMicroseconds + widget.duration.inMicroseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: totalMicros),
    );
    final delayFraction = totalMicros == 0
        ? 0.0
        : widget.delay.inMicroseconds / totalMicros;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delayFraction.clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(curved);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Plays a single fade + scale "pop" entrance for [child] when this widget
/// first mounts, then stops — a bolder companion to [FadeSlideIn] for hero
/// illustrations, using a physics-feeling overshoot ([Curves.elasticOut] by
/// default) instead of a plain ease. Still driven entirely by one
/// vsync-ticked [AnimationController] with the delay folded into the
/// controller's own timeline (never `Future.delayed`/`Timer`), so it always
/// reaches [AnimationStatus.completed] and stays there — safe under
/// `pumpAndSettle()` and never left ticking in the background.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 640),
    this.beginScale = 0.55,
    this.curve = Curves.elasticOut,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final totalMicros =
        widget.delay.inMicroseconds + widget.duration.inMicroseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(microseconds: totalMicros),
    );
    final delayFraction = totalMicros == 0
        ? 0.0
        : widget.delay.inMicroseconds / totalMicros;

    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          delayFraction.clamp(0.0, 1.0),
          1.0,
          curve: widget.curve,
        ),
      ),
    );
    // The fade resolves faster than the elastic scale settles, so the mark
    // is fully opaque well before its last little overshoot wobble — a
    // barely-visible sticker shouldn't still be bouncing.
    final fadeEnd = (delayFraction + (1 - delayFraction) * 0.55).clamp(
      0.0,
      1.0,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delayFraction.clamp(0.0, 1.0),
        fadeEnd,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
