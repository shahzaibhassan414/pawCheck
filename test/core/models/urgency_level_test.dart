import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/urgency_level.dart';

void main() {
  group('UrgencyLevel.parse', () {
    test('parses exact wire values', () {
      expect(UrgencyLevel.parse('Low'), UrgencyLevel.low);
      expect(UrgencyLevel.parse('Monitor'), UrgencyLevel.monitor);
      expect(UrgencyLevel.parse('See a vet soon'), UrgencyLevel.seeVetSoon);
      expect(UrgencyLevel.parse('Emergency'), UrgencyLevel.emergency);
    });

    test('tolerates unexpected casing and surrounding whitespace', () {
      expect(UrgencyLevel.parse('  low  '), UrgencyLevel.low);
      expect(UrgencyLevel.parse('EMERGENCY'), UrgencyLevel.emergency);
      expect(UrgencyLevel.parse('sEe A vEt SooN'), UrgencyLevel.seeVetSoon);
    });

    test('throws FormatException on an unrecognized value', () {
      expect(
        () => UrgencyLevel.parse('Critical'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('wireValue round-trips through parse', () {
    for (final level in UrgencyLevel.values) {
      expect(UrgencyLevel.parse(level.wireValue), level);
    }
  });

  test('showsFindVetCta is false only for Low', () {
    expect(UrgencyLevel.low.showsFindVetCta, isFalse);
    expect(UrgencyLevel.monitor.showsFindVetCta, isTrue);
    expect(UrgencyLevel.seeVetSoon.showsFindVetCta, isTrue);
    expect(UrgencyLevel.emergency.showsFindVetCta, isTrue);
  });
}
