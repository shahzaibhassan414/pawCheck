/// Urgency rating returned by the AI triage service. Exactly one of these
/// four — see PRD Section 7. Unknown/malformed values must not silently
/// resolve to `low`; callers should treat a parse failure as an error and
/// err toward the higher urgency, not the lower one.
enum UrgencyLevel {
  low,
  monitor,
  seeVetSoon,
  emergency;

  static const _wireValues = {
    UrgencyLevel.low: 'Low',
    UrgencyLevel.monitor: 'Monitor',
    UrgencyLevel.seeVetSoon: 'See a vet soon',
    UrgencyLevel.emergency: 'Emergency',
  };

  String get wireValue => _wireValues[this]!;

  /// Parses the AI's urgency string, tolerating whitespace/casing
  /// differences. Throws [FormatException] on anything unrecognized —
  /// callers must not default an unparseable value to `low`.
  static UrgencyLevel parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final entry in _wireValues.entries) {
      if (entry.value.toLowerCase() == normalized) return entry.key;
    }
    throw FormatException('Unrecognized UrgencyLevel: "$raw"');
  }

  bool get showsFindVetCta => this != UrgencyLevel.low;
}
