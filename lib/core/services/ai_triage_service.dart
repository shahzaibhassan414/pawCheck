import 'dart:typed_data';

import '../models/urgency_level.dart';

/// Thrown when a Gemini response can't be turned into a [TriageResult] —
/// malformed JSON, missing fields, or an unrecognized urgency value.
/// Callers must catch this specifically rather than letting it propagate
/// as an uncaught type error (PRD Section 12, Milestone 2 test checklist).
class AiTriageException implements Exception {
  const AiTriageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'AiTriageException: $message'
      : 'AiTriageException: $message (cause: $cause)';
}

/// Parsed, guardrailed output of a triage request — shapes the
/// `aiDescription`/`aiCauses`/`urgencyLevel` fields a caller uses to build
/// a `Scan` (PRD Section 8), plus [vetRecommended] for the "Find a vet
/// nearby" CTA and [guardrailTriggered] for observability.
class TriageResult {
  const TriageResult({
    required this.description,
    required this.urgencyLevel,
    this.causes = const [],
    this.vetRecommended = false,
    this.guardrailTriggered = false,
  });

  final String description;
  final List<String> causes;
  final UrgencyLevel urgencyLevel;
  final bool vetRecommended;
  final bool guardrailTriggered;

  /// Throws [AiTriageException] on missing/invalid required fields or an
  /// unrecognized urgency value — never silently defaults urgency to a
  /// lower level (PRD Section 7: "always err toward a higher urgency").
  factory TriageResult.fromJson(Map<String, dynamic> json) {
    final description = json['description'];
    final causesRaw = json['causes'];
    final urgencyRaw = json['urgency'];
    final vetRecommendedRaw = json['vet_recommended'];

    if (description is! String || description.trim().isEmpty) {
      throw const AiTriageException(
        'Gemini response missing or invalid "description"',
      );
    }
    if (urgencyRaw is! String) {
      throw const AiTriageException(
        'Gemini response missing or invalid "urgency"',
      );
    }

    final UrgencyLevel urgencyLevel;
    try {
      urgencyLevel = UrgencyLevel.parse(urgencyRaw);
    } on FormatException {
      throw AiTriageException(
        'Gemini response had an unrecognized "urgency" value: "$urgencyRaw"',
      );
    }

    return TriageResult(
      description: description.trim(),
      causes: causesRaw is List
          ? causesRaw.whereType<String>().toList()
          : const [],
      urgencyLevel: urgencyLevel,
      vetRecommended: vetRecommendedRaw is bool
          ? vetRecommendedRaw
          : urgencyLevel.showsFindVetCta,
    );
  }

  TriageResult copyWith({
    String? description,
    List<String>? causes,
    bool? guardrailTriggered,
  }) => TriageResult(
    description: description ?? this.description,
    causes: causes ?? this.causes,
    urgencyLevel: urgencyLevel,
    vetRecommended: vetRecommended,
    guardrailTriggered: guardrailTriggered ?? this.guardrailTriggered,
  );

  @override
  bool operator ==(Object other) =>
      other is TriageResult &&
      other.description == description &&
      _listEquals(other.causes, causes) &&
      other.urgencyLevel == urgencyLevel &&
      other.vetRecommended == vetRecommended &&
      other.guardrailTriggered == guardrailTriggered;

  @override
  int get hashCode => Object.hash(
    description,
    Object.hashAll(causes),
    urgencyLevel,
    vetRecommended,
    guardrailTriggered,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Takes a pet photo + optional context, returns a parsed, guardrailed
/// triage result. See `GeminiAiTriageService` for the live implementation
/// and `MockAiTriageService` for the canned fake every other module's
/// tests must use instead (PRD Section 12 — never call the live API in
/// automated tests).
abstract interface class AiTriageService {
  Future<TriageResult> analyze({
    required Uint8List imageBytes,
    required String species,
    String? note,
  });
}
