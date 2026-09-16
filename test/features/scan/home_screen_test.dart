import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';
import 'package:paw_check/features/paywall/paywall_screen.dart';
import 'package:paw_check/features/scan/home_screen.dart';
import 'package:paw_check/features/scan/scan_screen.dart';
import 'package:paw_check/features/settings/settings_screen.dart';
import 'package:paw_check/features/timeline/timeline_screen.dart';

const _biscuit = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

/// Never invoked in these tests (photo is optional and none of them tap
/// the photo slot), but present so `HomeScreen`'s default `ImagePicker()`
/// (which needs a real platform channel) is never reachable from a test.
Future<XFile?> _unusedPickPhoto() async =>
    throw StateError('photo picker should not be invoked in this test');

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          pets: [_biscuit],
          addPetPickPhoto: _unusedPickPhoto,
          petRepository: InMemoryPetRepository(initialPets: [_biscuit]),
          scanRepository: InMemoryScanRepository(),
        ),
      ),
    );
    // Let the scan CTA's one-shot FadeSlideIn entrance finish before tests
    // interact with it — tapping mid-fade can land on a zero-opacity
    // RenderAnimatedOpacity, which excludes itself from hit-testing.
    await tester.pumpAndSettle();
  }

  testWidgets('renders the initial pet as a selected chip', (tester) async {
    await pumpHome(tester);

    expect(find.text('Biscuit'), findsOneWidget);
    expect(find.text('Scan Biscuit'), findsOneWidget);
  });

  testWidgets('shutter button opens the scan screen for the selected pet', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('shutter_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets(
    'Timeline tab swaps in the timeline in place, without navigating',
    (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('timeline_tab')));
      await tester.pumpAndSettle();

      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.text("Biscuit's timeline"), findsOneWidget);
      // A tab swap, not a push — nothing to pop back to, and the same
      // floating nav bar (with Timeline now shown active) stays on
      // screen throughout.
      expect(
        Navigator.of(tester.element(find.byType(TimelineScreen))).canPop(),
        isFalse,
      );
      expect(find.byKey(const Key('timeline_tab')), findsOneWidget);

      // Tapping Home swaps straight back, still no navigation involved.
      await tester.tap(find.byKey(const Key('home_tab')));
      await tester.pumpAndSettle();
      expect(find.text('Scan Biscuit'), findsOneWidget);
      expect(find.byType(TimelineScreen), findsNothing);
    },
  );

  testWidgets('+ Add opens a screen that blocks submit when empty', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('add_pet_chip')));
    await tester.pumpAndSettle();

    expect(find.text('Add a pet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_pet_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Select a species'), findsOneWidget);
    // Still on the add-pet screen, not popped back to Home — validation
    // blocked the submit. (Home itself is a fully-covered route right
    // now, since this is a real page push rather than a dialog overlay,
    // so it isn't part of the built tree to assert against here.)
    expect(find.text('Add a pet'), findsOneWidget);
  });

  testWidgets('+ Add creates a new pet, adds a chip, and selects it', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('add_pet_chip')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('add_pet_name_field')), 'Coco');
    await tester.ensureVisible(find.byKey(const Key('add_pet_species_cat')));
    await tester.tap(find.byKey(const Key('add_pet_species_cat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_pet_submit_button')));
    await tester.pumpAndSettle();

    // Dialog closed, both chips present, and the CTA now targets the
    // newly-added (and newly-selected) pet.
    expect(find.text('Add a pet'), findsNothing);
    expect(find.text('Biscuit'), findsOneWidget);
    expect(find.text('Coco'), findsOneWidget);
    expect(find.text('Scan Coco'), findsOneWidget);
  });

  testWidgets(
    'the back chevron closes the add-pet screen without adding a pet',
    (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('add_pet_chip')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Add a pet'), findsNothing);
      expect(find.text('Scan Biscuit'), findsOneWidget);
    },
  );

  testWidgets('tapping a pet chip switches the selected pet', (tester) async {
    await pumpHome(tester);

    // Add a second pet first so there's something to switch to.
    await tester.tap(find.byKey(const Key('add_pet_chip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add_pet_name_field')), 'Coco');
    await tester.ensureVisible(find.byKey(const Key('add_pet_species_cat')));
    await tester.tap(find.byKey(const Key('add_pet_species_cat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_pet_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Scan Coco'), findsOneWidget);

    await tester.tap(find.text('Biscuit'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Biscuit'), findsOneWidget);
  });

  testWidgets('Settings tab swaps in Settings in place, without navigating', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('settings_tab')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Biscuit'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(SettingsScreen))).canPop(),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('home_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Scan Biscuit'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  group(
    'no back chevron on Timeline/Settings tabs, even with routes below',
    () {
      // The real app never has HomeScreen as the Navigator's only route —
      // Onboarding `push`es AccountSetup, which then `pushReplacement`s
      // itself with HomeScreen, leaving the actual stack as
      // `[OnboardingScreen, HomeScreen]`. That means `Navigator.canPop()`
      // is genuinely `true` at HomeScreen, unlike in `pumpHome`'s isolated
      // `MaterialApp(home: HomeScreen(...))` setup above — this group
      // reproduces that real shape so a regression here can't hide behind
      // an unrealistic test setup the way it did before.
      Future<void> pumpHomeWithRouteBelow(WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HomeScreen(
                          pets: [_biscuit],
                          addPetPickPhoto: _unusedPickPhoto,
                          petRepository: InMemoryPetRepository(
                            initialPets: [_biscuit],
                          ),
                          scanRepository: InMemoryScanRepository(),
                        ),
                      ),
                    ),
                    child: const Text('enter app'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('enter app'));
        await tester.pumpAndSettle();
      }

      testWidgets('Timeline tab shows no back chevron', (tester) async {
        await pumpHomeWithRouteBelow(tester);

        await tester.tap(find.byKey(const Key('timeline_tab')));
        await tester.pumpAndSettle();

        expect(find.byType(TimelineScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
      });

      testWidgets('Settings tab shows no back chevron', (tester) async {
        await pumpHomeWithRouteBelow(tester);

        await tester.tap(find.byKey(const Key('settings_tab')));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
      });
    },
  );

  group('free-scan gate (per-install, PRD Milestone 7)', () {
    testWidgets('first scan goes straight to ScanScreen, no paywall', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets(
      'a second scan attempt after one completes shows the paywall instead',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.byKey(const Key('shutter_button')));
        await tester.pumpAndSettle();

        // Simulate a completed scan without running the full capture/AI
        // flow — ScanScreen calls this right before navigating to
        // ResultScreen (see scan_screen.dart's `_submit`).
        final scanScreen = tester.widget<ScanScreen>(find.byType(ScanScreen));
        scanScreen.onScanCompleted!();
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('shutter_button')));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.byType(ScanScreen), findsNothing);
      },
    );

    testWidgets('"Continue" on the paywall unlocks scanning again', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();
      final scanScreen = tester.widget<ScanScreen>(find.byType(ScanScreen));
      scanScreen.onScanCompleted!();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall_continue_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsOneWidget);
    });

    testWidgets('closing the paywall without subscribing does not open scan', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();
      final scanScreen = tester.widget<ScanScreen>(find.byType(ScanScreen));
      scanScreen.onScanCompleted!();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shutter_button')));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('paywall_close_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ScanScreen), findsNothing);
      expect(find.byType(PaywallScreen), findsNothing);
    });
  });
}
