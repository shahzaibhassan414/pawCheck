import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/ai_triage_service.dart';
import 'package:paw_check/core/services/mock_ai_triage_service.dart';
import 'package:paw_check/core/theme/urgency_colors.dart';
import 'package:paw_check/features/scan/result_screen.dart';

const _pet = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

/// A real 1x1 PNG — `Image.memory` decodes whatever bytes it's given, and
/// arbitrary placeholder bytes throw an uncaught "Invalid image data".
final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  Widget buildScreen({
    required TriageResult result,
    Future<bool> Function(Uri uri)? launchUrl,
  }) {
    return MaterialApp(
      home: ResultScreen(
        pet: _pet,
        result: result,
        photo: MemoryImage(_testPngBytes),
        scanDate: DateTime(2026, 3, 5),
        launchUrl: launchUrl ?? (_) async => true,
      ),
    );
  }

  group('normal tiers (Low / Monitor / See a vet soon)', () {
    // The normal layout's content lives in a plain `ListView`, which —
    // like `ListView.builder` — lazily materializes children based on
    // viewport + cache extent. Content below the default test-viewport
    // fold isn't just offstage, it may not be *built* at all yet, so
    // `skipOffstage: false` alone doesn't find it. `dragUntilVisible`
    // repeatedly scrolls the list a bit at a time, re-checking after each
    // step, until the target is both built and onstage.
    Future<void> scrollUntilVisible(WidgetTester tester, Finder target) =>
        tester.dragUntilVisible(
          target,
          find.byType(Scrollable).first,
          const Offset(0, -150),
        );

    testWidgets('Low tier renders content but hides Find a vet nearby', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(result: lowTriageResult));
      await tester.pumpAndSettle();

      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text(lowTriageResult.description), findsOneWidget);
      for (final cause in lowTriageResult.causes) {
        expect(find.text(cause), findsOneWidget);
      }

      final disclaimer = find.textContaining('This is not a diagnosis');
      await scrollUntilVisible(tester, disclaimer);
      expect(disclaimer, findsOneWidget);

      // CLAUDE.md non-negotiable rule: no "Find a vet nearby" CTA for Low,
      // even though the design doc's own mockup shows an outlined one —
      // scroll all the way to the bottom first to be sure it's genuinely
      // absent, not just further down than we've scrolled.
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -600),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('find_vet_button')), findsNothing);
    });

    testWidgets('Monitor tier shows a solid Find a vet nearby button', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(result: monitorTriageResult));
      await tester.pumpAndSettle();

      expect(find.text('Monitor'), findsOneWidget);

      final button = find.byKey(const Key('find_vet_button'));
      await scrollUntilVisible(tester, button);
      expect(button, findsOneWidget);
    });

    testWidgets('See a vet soon tier shows a solid Find a vet nearby button', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(result: seeVetSoonTriageResult));
      await tester.pumpAndSettle();

      expect(find.text('See a vet soon'), findsOneWidget);

      final button = find.byKey(const Key('find_vet_button'));
      await scrollUntilVisible(tester, button);
      expect(button, findsOneWidget);
    });

    testWidgets('tapping Find a vet nearby launches a maps search URI', (
      tester,
    ) async {
      Uri? launchedUri;
      await tester.pumpWidget(
        buildScreen(
          result: monitorTriageResult,
          launchUrl: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('find_vet_button'));
      await scrollUntilVisible(tester, button);
      await tester.tap(button);
      await tester.pump();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['query'], 'veterinarian near me');
    });
  });

  group('Emergency tier — full-screen takeover', () {
    // NEVER call tester.pumpAndSettle() in this group — the pulsing ring
    // is a deliberate, documented looping animation (see
    // `_EmergencyViewState.initState`) and pumpAndSettle would hang
    // forever waiting for it to finish. Bounded tester.pump() calls only.

    testWidgets('renders the full-screen red takeover with its own copy', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(result: emergencyTriageResult));
      await tester.pump();

      final scaffoldFinder = find.byType(Scaffold);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, UrgencyTierColors.emergencyBackground);

      expect(find.text('URGENT — ACT NOW'), findsOneWidget);
      expect(find.text('This needs a vet right away'), findsOneWidget);
      expect(find.text(emergencyTriageResult.description), findsOneWidget);
      expect(find.textContaining('This is not a diagnosis'), findsOneWidget);
      // Pet name/date chrome from the normal layout must NOT appear here
      // — the doc calls for "small back chevron top-left only".
      expect(find.text('Biscuit'), findsNothing);
    });

    testWidgets('tapping the emergency CTA launches a maps search URI', (
      tester,
    ) async {
      Uri? launchedUri;
      await tester.pumpWidget(
        buildScreen(
          result: emergencyTriageResult,
          launchUrl: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('find_emergency_vet_button')));
      await tester.pump();

      expect(launchedUri, isNotNull);
      expect(launchedUri!.queryParameters['query'], 'veterinarian near me');
    });

    testWidgets('the pulse animation keeps running without erroring', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(result: emergencyTriageResult));

      // Advance well past several full 1.6s loop cycles — if the
      // animation ever threw or failed to loop, one of these pumps would
      // surface it.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(
        find.byKey(const Key('find_emergency_vet_button')),
        findsOneWidget,
      );
    });
  });
}
