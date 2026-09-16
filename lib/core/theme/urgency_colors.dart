import 'package:flutter/material.dart';

import '../models/urgency_level.dart';

/// Per-urgency-tier colors from the "Paw Check claude design" handoff doc
/// (see that folder's README.md, "Urgency tier colors"). Deliberately
/// **independent** of `AppTheme`'s violet `ColorScheme` — the doc calls
/// this out explicitly ("semantic, independent of the violet accent") so
/// urgency always reads the same regardless of the app's own brand color.
/// Shared across the Results screen (banner, buttons) and, later, the
/// Timeline screen (per-scan urgency dot/badge) — see PRD Section 8.
///
/// [UrgencyLevel.emergency] is the one tier the doc treats completely
/// differently: not a tint on the normal layout, but a full-screen solid
/// takeover (`emergencyBackground`) with white text/icons — see
/// `ResultScreen`'s `_EmergencyView`.
class UrgencyTierColors {
  const UrgencyTierColors({
    required this.backgroundTint,
    required this.iconAndBorder,
    required this.textOnTint,
  });

  /// The card/banner fill color for this tier.
  final Color backgroundTint;

  /// Icon and border color — reads clearly against [backgroundTint].
  final Color iconAndBorder;

  /// Body text color when sitting on [backgroundTint].
  final Color textOnTint;

  static const low = UrgencyTierColors(
    backgroundTint: Color(0xFFF0FAE1),
    iconAndBorder: Color(0xFF8FA073),
    textOnTint: Color(0xFF3D472B),
  );

  static const monitor = UrgencyTierColors(
    backgroundTint: Color(0xFFFFF3D6),
    iconAndBorder: Color(0xFFC98A12),
    textOnTint: Color(0xFF6B4A0C),
  );

  static const seeVetSoon = UrgencyTierColors(
    backgroundTint: Color(0xFFFFE1D0),
    iconAndBorder: Color(0xFFB2622D),
    textOnTint: Color(0xFF643312),
  );

  /// Emergency's full-screen solid background — not a "tint" like the
  /// other three tiers.
  static const emergencyBackground = Color(0xFF9C1C2E);

  /// Looks up the tint/border/text triplet for a non-Emergency tier.
  /// Emergency has no triplet — it doesn't use this class's tint model at
  /// all, so it's not one of the cases here; callers must branch on
  /// [UrgencyLevel.emergency] separately (as `ResultScreen` does).
  static UrgencyTierColors forLevel(UrgencyLevel level) => switch (level) {
    UrgencyLevel.low => low,
    UrgencyLevel.monitor => monitor,
    UrgencyLevel.seeVetSoon => seeVetSoon,
    UrgencyLevel.emergency => throw ArgumentError(
      'UrgencyLevel.emergency has no tint triplet — it uses '
      'emergencyBackground and a full-screen takeover layout instead. '
      'Check for UrgencyLevel.emergency before calling forLevel().',
    ),
  };
}
