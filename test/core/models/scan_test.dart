import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/scan.dart';
import 'package:paw_check/core/models/urgency_level.dart';

void main() {
  final scan = Scan(
    id: 'scan-1',
    photoUrl: 'https://example.com/photo.jpg',
    note: 'scratching for 2 days',
    timestamp: DateTime.utc(2026, 1, 15, 9, 30),
    aiDescription: 'A red patch of irritated skin near the left ear.',
    aiCauses: const ['Allergic reaction', 'Mild dermatitis'],
    urgencyLevel: UrgencyLevel.monitor,
  );

  test('serializes to JSON and back without data loss', () {
    final roundTripped = Scan.fromJson(scan.toJson());

    expect(roundTripped, scan);
  });

  test('defaults resolved to false and aiCauses to empty when absent', () {
    final json = {
      'id': 'scan-2',
      'photoUrl': 'https://example.com/photo2.jpg',
      'timestamp': DateTime.utc(2026, 1, 16).toIso8601String(),
      'aiDescription': 'Inconclusive image.',
      'urgencyLevel': 'Monitor',
    };

    final parsed = Scan.fromJson(json);

    expect(parsed.resolved, isFalse);
    expect(parsed.aiCauses, isEmpty);
    expect(parsed.note, isNull);
  });

  group('fromJson failure handling', () {
    test('throws a catchable FormatException for a missing required field', () {
      final json = scan.toJson()..remove('aiDescription');

      expect(() => Scan.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('throws a catchable FormatException for an unparseable timestamp', () {
      final json = scan.toJson();
      json['timestamp'] = 'not-a-date';

      expect(() => Scan.fromJson(json), throwsA(isA<FormatException>()));
    });

    test(
      'throws a catchable FormatException for a malformed urgency string, '
      'never silently defaulting to a lower urgency',
      () {
        final json = scan.toJson();
        json['urgencyLevel'] = 'sort of urgent??';

        expect(() => Scan.fromJson(json), throwsA(isA<FormatException>()));
      },
    );
  });
}
