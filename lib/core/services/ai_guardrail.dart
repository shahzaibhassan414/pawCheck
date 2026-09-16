import 'ai_triage_service.dart';

/// Safety-net filter for [TriageResult] text — strips medication names,
/// dosage-like phrases, and "give them X" instructions even though the
/// Section 7 system prompt already tells Gemini not to produce them.
/// Never rely on prompt compliance alone (CLAUDE.md, PRD Milestone 2).
abstract final class AiGuardrail {
  static final RegExp _dosagePattern = RegExp(
    r'\d+(\.\d+)?\s?(mg|mcg|ml|cc|iu|milligrams?|micrograms?|milliliters?|units?)\b',
    caseSensitive: false,
  );

  static final RegExp _instructionPattern = RegExp(
    r'\b(give|administer|dose\s+with|dosage\s+of)\b[^.,;]*',
    caseSensitive: false,
  );

  static const List<String> _medicationNames = [
    'aspirin',
    'ibuprofen',
    'acetaminophen',
    'tylenol',
    'advil',
    'amoxicillin',
    'prednisone',
    'benadryl',
    'diphenhydramine',
    'metronidazole',
    'gabapentin',
    'tramadol',
    'rimadyl',
    'carprofen',
    'apoquel',
    'omeprazole',
  ];

  /// Returns [result] unchanged if nothing was flagged, otherwise a copy
  /// with offending text redacted and [TriageResult.guardrailTriggered] set.
  static TriageResult sanitize(TriageResult result) {
    var triggered = false;
    void flag() => triggered = true;

    final description = _sanitizeText(result.description, flag);
    final causes = result.causes.map((c) => _sanitizeText(c, flag)).toList();

    if (!triggered) return result;

    return result.copyWith(
      description: description,
      causes: causes,
      guardrailTriggered: true,
    );
  }

  static String _sanitizeText(String text, void Function() flag) {
    var sanitized = text;

    if (_dosagePattern.hasMatch(sanitized)) {
      flag();
      sanitized = sanitized.replaceAll(_dosagePattern, '[redacted]');
    }
    if (_instructionPattern.hasMatch(sanitized)) {
      flag();
      sanitized = sanitized.replaceAll(_instructionPattern, '[redacted]');
    }
    for (final name in _medicationNames) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(name) + r'\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(sanitized)) {
        flag();
        sanitized = sanitized.replaceAll(pattern, '[redacted]');
      }
    }

    return sanitized;
  }
}
