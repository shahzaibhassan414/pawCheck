import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/urgency_level.dart';
import 'package:paw_check/core/services/ai_triage_service.dart';
import 'package:paw_check/core/services/mock_ai_triage_service.dart';

void main() {
  final emptyImage = Uint8List(0);

  group('MockAiTriageService canned factories', () {
    test('.low() returns a Low result', () async {
      final result = await MockAiTriageService.low().analyze(
        imageBytes: emptyImage,
        species: 'Dog',
      );

      expect(result.urgencyLevel, UrgencyLevel.low);
    });

    test('.monitor() returns a Monitor result', () async {
      final result = await MockAiTriageService.monitor().analyze(
        imageBytes: emptyImage,
        species: 'Cat',
      );

      expect(result.urgencyLevel, UrgencyLevel.monitor);
    });

    test('.seeVetSoon() returns a See a vet soon result', () async {
      final result = await MockAiTriageService.seeVetSoon().analyze(
        imageBytes: emptyImage,
        species: 'Dog',
      );

      expect(result.urgencyLevel, UrgencyLevel.seeVetSoon);
    });

    test('.emergency() returns an Emergency result', () async {
      final result = await MockAiTriageService.emergency().analyze(
        imageBytes: emptyImage,
        species: 'Cat',
      );

      expect(result.urgencyLevel, UrgencyLevel.emergency);
      expect(result.vetRecommended, isTrue);
    });
  });

  test('.withError() rethrows the configured error instead of returning', () {
    final service = MockAiTriageService.withError(
      const AiTriageException('boom'),
    );

    expect(
      () => service.analyze(imageBytes: emptyImage, species: 'Dog'),
      throwsA(isA<AiTriageException>()),
    );
  });
}
