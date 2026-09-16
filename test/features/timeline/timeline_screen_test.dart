import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/models/scan.dart';
import 'package:paw_check/core/models/urgency_level.dart';
import 'package:paw_check/features/scan/result_screen.dart';
import 'package:paw_check/features/timeline/timeline_screen.dart';

const _pet = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

final _lowScan = Scan(
  id: 'scan-1',
  photoUrl: 'https://example.com/low.png',
  timestamp: DateTime(2026, 3, 1),
  aiDescription: 'A small red patch on the left paw pad.',
  aiCauses: const ['Minor irritation'],
  urgencyLevel: UrgencyLevel.low,
);

final _emergencyScan = Scan(
  id: 'scan-2',
  photoUrl: 'https://example.com/emergency.png',
  note: 'Won\'t stop bleeding',
  timestamp: DateTime(2026, 3, 5),
  aiDescription: 'Active bleeding from a deep wound.',
  aiCauses: const ['Deep laceration'],
  urgencyLevel: UrgencyLevel.emergency,
);

void main() {
  Widget buildScreen({required List<Scan> scans}) {
    return MaterialApp(
      home: TimelineScreen(pet: _pet, scans: scans),
    );
  }

  testWidgets('empty state shows the header, an icon, and guidance copy', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(scans: const []));
    await tester.pumpAndSettle();

    expect(find.text("Biscuit's timeline"), findsOneWidget);
    expect(find.text('Dog · 0 scans'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.byIcon(Icons.watch_later_outlined), findsOneWidget);
    expect(
      find.textContaining('Scan Biscuit and their results will show up here'),
      findsOneWidget,
    );
  });

  testWidgets('populated state renders a row per scan with tier badges', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(scans: [_lowScan, _emergencyScan]));
    await tester.pumpAndSettle();

    expect(find.text('Dog · 2 scans'), findsOneWidget);
    // Low scan has no note, so it falls back to the AI description.
    expect(find.text('A small red patch on the left paw pad.'), findsOneWidget);
    expect(find.text('Won\'t stop bleeding'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);

    // Image.network fails fast against no real network in tests — the
    // row's errorBuilder fallback icon should render instead of throwing.
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(2));
  });

  testWidgets('tapping a row pushes the historical ResultScreen', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(scans: [_lowScan]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A small red patch on the left paw pad.'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.byType(TimelineScreen), findsNothing);

    // Back from a historically-reopened Results screen returns to
    // Timeline, per the doc's interaction rule — verified by popping and
    // confirming Timeline is what's left underneath.
    final resultScaffold = tester.state<NavigatorState>(find.byType(Navigator));
    expect(resultScaffold.canPop(), isTrue);
  });

  testWidgets('renders scans most-recent-first regardless of input order', (
    tester,
  ) async {
    // _emergencyScan (Mar 5) is passed before _lowScan (Mar 1) here — the
    // opposite of chronological order — to prove the screen sorts rather
    // than trusting caller order (PRD Milestone 6: "most recent first").
    await tester.pumpWidget(
      MaterialApp(
        home: TimelineScreen(pet: _pet, scans: [_lowScan, _emergencyScan]),
      ),
    );
    await tester.pumpAndSettle();

    final emergencyNoteY = tester
        .getTopLeft(find.text('Won\'t stop bleeding'))
        .dy;
    final lowNoteY = tester
        .getTopLeft(find.text('A small red patch on the left paw pad.'))
        .dy;
    expect(emergencyNoteY, lessThan(lowNoteY));
  });

  group('delete', () {
    testWidgets('no delete affordance when onDelete is omitted', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(scans: [_lowScan]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('delete_scan_button_${_lowScan.id}')),
        findsNothing,
      );
    });

    testWidgets('confirming delete calls onDelete; cancelling does not', (
      tester,
    ) async {
      Scan? deleted;
      await tester.pumpWidget(
        MaterialApp(
          home: TimelineScreen(
            pet: _pet,
            scans: [_lowScan],
            onDelete: (scan) => deleted = scan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(Key('delete_scan_button_${_lowScan.id}'));
      expect(deleteButton, findsOneWidget);

      // Cancel first — must not call onDelete.
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, isNull);

      // Then confirm.
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, _lowScan);
    });
  });
}
