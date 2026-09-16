import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/urgency_level.dart';
import 'package:paw_check/core/services/ai_triage_service.dart';
import 'package:paw_check/core/services/gemini_ai_triage_service.dart';

void main() {
  group('GeminiAiTriageService.parseResponse', () {
    test('parses a canned Low response', () {
      const raw = '''
      {
        "description": "The coat looks healthy with no visible irritation.",
        "causes": ["Normal shedding", "Recent bath"],
        "urgency": "Low",
        "vet_recommended": false
      }
      ''';

      final result = GeminiAiTriageService.parseResponse(raw);

      expect(
        result.description,
        'The coat looks healthy with no visible irritation.',
      );
      expect(result.causes, ['Normal shedding', 'Recent bath']);
      expect(result.urgencyLevel, UrgencyLevel.low);
      expect(result.vetRecommended, isFalse);
      expect(result.guardrailTriggered, isFalse);
    });

    test('parses a canned Emergency response with vet_recommended true', () {
      const raw = '''
      {
        "description": "The abdomen appears distended and the gums look pale.",
        "causes": ["Bloat", "Internal bleeding", "Shock"],
        "urgency": "Emergency",
        "vet_recommended": true
      }
      ''';

      final result = GeminiAiTriageService.parseResponse(raw);

      expect(result.urgencyLevel, UrgencyLevel.emergency);
      expect(result.vetRecommended, isTrue);
    });

    test('tolerates a markdown code fence around the JSON', () {
      const raw = '''
      ```json
      {"description": "Fine", "causes": ["a", "b"], "urgency": "Monitor", "vet_recommended": true}
      ```
      ''';

      final result = GeminiAiTriageService.parseResponse(raw);

      expect(result.urgencyLevel, UrgencyLevel.monitor);
    });

    test('throws AiTriageException for a non-JSON response', () {
      const raw = 'Sorry, I cannot help with that.';

      expect(
        () => GeminiAiTriageService.parseResponse(raw),
        throwsA(isA<AiTriageException>()),
      );
    });

    test('throws AiTriageException when required fields are missing', () {
      const raw = '{"causes": ["a"], "urgency": "Low"}';

      expect(
        () => GeminiAiTriageService.parseResponse(raw),
        throwsA(isA<AiTriageException>()),
      );
    });

    test('throws AiTriageException for an unrecognized urgency value', () {
      const raw = '{"description": "x", "causes": [], "urgency": "Severe"}';

      expect(
        () => GeminiAiTriageService.parseResponse(raw),
        throwsA(isA<AiTriageException>()),
      );
    });

    test('strips a medication name and dosage as a guardrail safety net, '
        'even though the prompt should already prevent them', () {
      const raw = '''
        {
          "description": "Looks like a mild skin reaction. Give them 10mg of Benadryl for the itching.",
          "causes": ["Allergic reaction", "Give 5mg ibuprofen if swelling persists"],
          "urgency": "Monitor",
          "vet_recommended": true
        }
        ''';

      final result = GeminiAiTriageService.parseResponse(raw);

      expect(result.guardrailTriggered, isTrue);
      expect(result.description.toLowerCase(), isNot(contains('benadryl')));
      expect(result.description, isNot(contains('10mg')));
      expect(
        result.causes.join(' ').toLowerCase(),
        isNot(contains('ibuprofen')),
      );
      expect(result.causes.join(' '), isNot(contains('5mg')));
    });
  });
}
