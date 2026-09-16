import 'dart:typed_data';

import '../models/urgency_level.dart';
import 'ai_triage_service.dart';

/// Canned [TriageResult]s covering all four urgency levels, for every
/// module downstream of Milestone 2 to use in its widget/integration
/// tests. Never call the live Gemini API in automated tests (PRD
/// Section 12) — construct this instead.
class MockAiTriageService implements AiTriageService {
  const MockAiTriageService.withResult(this._result) : _error = null;
  const MockAiTriageService.withError(Object error)
    : _result = null,
      _error = error;

  factory MockAiTriageService.low() =>
      const MockAiTriageService.withResult(lowTriageResult);
  factory MockAiTriageService.monitor() =>
      const MockAiTriageService.withResult(monitorTriageResult);
  factory MockAiTriageService.seeVetSoon() =>
      const MockAiTriageService.withResult(seeVetSoonTriageResult);
  factory MockAiTriageService.emergency() =>
      const MockAiTriageService.withResult(emergencyTriageResult);

  final TriageResult? _result;
  final Object? _error;

  @override
  Future<TriageResult> analyze({
    required Uint8List imageBytes,
    required String species,
    String? note,
  }) async {
    final error = _error;
    if (error != null) throw error;
    return _result!;
  }
}

const TriageResult lowTriageResult = TriageResult(
  description:
      'The paw pad looks slightly pink but the skin appears intact, with '
      'no swelling or discharge visible.',
  causes: ['Mild surface irritation', 'Recent contact with rough terrain'],
  urgencyLevel: UrgencyLevel.low,
  vetRecommended: false,
);

const TriageResult monitorTriageResult = TriageResult(
  description:
      'A small patch of redness and light scratching is visible around '
      'the ear.',
  causes: [
    'Mild allergic reaction',
    'Insect bite',
    'Early-stage ear irritation',
  ],
  urgencyLevel: UrgencyLevel.monitor,
  vetRecommended: true,
);

const TriageResult seeVetSoonTriageResult = TriageResult(
  description:
      'The eye appears watery with some cloudiness, and the pet seems to '
      'be squinting.',
  causes: ['Corneal irritation', 'Conjunctivitis', 'Foreign object in the eye'],
  urgencyLevel: UrgencyLevel.seeVetSoon,
  vetRecommended: true,
);

const TriageResult emergencyTriageResult = TriageResult(
  description:
      "The abdomen appears visibly swollen and the pet's gum color looks "
      'pale in the photo.',
  causes: [
    'Bloat / gastric distension',
    'Internal bleeding',
    'Severe systemic reaction',
  ],
  urgencyLevel: UrgencyLevel.emergency,
  vetRecommended: true,
);
