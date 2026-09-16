import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/scan.dart';
import 'package:paw_check/core/models/urgency_level.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';

final _lowScan = Scan(
  id: 'scan-1',
  photoUrl: 'https://example.com/photo.jpg',
  timestamp: DateTime.utc(2026, 1, 15),
  aiDescription: 'A red patch of irritated skin.',
  urgencyLevel: UrgencyLevel.low,
);

final _monitorScan = Scan(
  id: 'scan-2',
  photoUrl: 'https://example.com/photo2.jpg',
  timestamp: DateTime.utc(2026, 1, 20),
  aiDescription: 'Mild swelling near the paw.',
  urgencyLevel: UrgencyLevel.monitor,
);

void main() {
  test('watchScans starts empty for a pet with no seeded history', () async {
    final repository = InMemoryScanRepository();

    expect(await repository.watchScans('pet-1').first, isEmpty);
  });

  test('addScan is visible to a subsequent watch for the same pet', () async {
    final repository = InMemoryScanRepository();

    await repository.addScan('pet-1', _lowScan);

    expect(await repository.watchScans('pet-1').first, [_lowScan]);
  });

  test('scans are scoped per pet id', () async {
    final repository = InMemoryScanRepository();

    await repository.addScan('pet-1', _lowScan);
    await repository.addScan('pet-2', _monitorScan);

    expect(await repository.watchScans('pet-1').first, [_lowScan]);
    expect(await repository.watchScans('pet-2').first, [_monitorScan]);
  });

  test('addScan pushes an update to an already-listening watcher', () async {
    final repository = InMemoryScanRepository();
    final events = <List<Scan>>[];
    final subscription = repository.watchScans('pet-1').listen(events.add);
    // Lets the stream's initial (empty) snapshot actually reach the
    // listener before triggering the mutation below — otherwise the two
    // could race within the same microtask and coalesce into a single
    // emission instead of two distinct ones.
    await Future<void>.delayed(Duration.zero);

    await repository.addScan('pet-1', _lowScan);
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      [],
      [_lowScan],
    ]);
    await subscription.cancel();
  });

  test('deleteScan removes only the matching scan for that pet', () async {
    final repository = InMemoryScanRepository(
      initialScans: {
        'pet-1': [_lowScan, _monitorScan],
      },
    );

    await repository.deleteScan('pet-1', _lowScan.id);

    expect(await repository.watchScans('pet-1').first, [_monitorScan]);
  });
}
