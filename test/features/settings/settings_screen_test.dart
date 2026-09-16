import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/fake_auth_service.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/features/settings/settings_screen.dart';
import 'package:paw_check/features/splash/splash_screen.dart';

const _biscuit = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');
const _coco = Pet(id: 'pet-2', name: 'Coco', species: 'Cat');

Future<XFile?> _unusedPickPhoto() async =>
    throw StateError('photo picker should not be invoked in this test');

void main() {
  Widget buildScreen({
    required List<Pet> pets,
    VoidCallback? onAddPet,
    ValueChanged<Pet>? onEditPet,
    ValueChanged<Pet>? onDeletePet,
    String? accountEmail,
    Future<XFile?> Function()? pickPhoto,
    Future<bool> Function(Uri uri)? launchUrl,
  }) {
    return MaterialApp(
      home: SettingsScreen(
        pets: pets,
        onAddPet: onAddPet ?? () {},
        onEditPet: onEditPet ?? (_) {},
        onDeletePet: onDeletePet ?? (_) {},
        accountEmail: accountEmail,
        pickPhoto: pickPhoto ?? _unusedPickPhoto,
        launchUrl: launchUrl ?? (_) async => true,
        signOut: () async {},
        authService: FakeAuthService(),
        petRepository: InMemoryPetRepository(),
      ),
    );
  }

  Future<void> scrollUntilVisible(WidgetTester tester, Finder target) =>
      tester.dragUntilVisible(
        target,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );

  testWidgets(
    'renders the account section, a row per pet, and the subscription link',
    (tester) async {
      await tester.pumpWidget(
        buildScreen(pets: [_biscuit, _coco], accountEmail: 'a@b.com'),
      );
      await tester.pumpAndSettle();

      expect(find.text('a@b.com'), findsOneWidget);
      expect(find.text('Pawcheck account'), findsOneWidget);
      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('Coco'), findsOneWidget);
      expect(find.text('+ Add another pet'), findsOneWidget);

      // The subscription section sits below the fold in a plain `ListView`,
      // which (like `ListView.builder`) lazily materializes children — see
      // the same gotcha documented in `result_screen_test.dart`.
      final subscriptionFinder = find.text('Manage subscription');
      await scrollUntilVisible(tester, subscriptionFinder);
      expect(subscriptionFinder, findsOneWidget);
    },
  );

  testWidgets('falls back to a placeholder when no account email was given', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(pets: [_biscuit]));
    await tester.pumpAndSettle();

    expect(find.text('No email added'), findsOneWidget);
  });

  testWidgets('"+ Add another pet" calls onAddPet', (tester) async {
    var called = false;
    await tester.pumpWidget(
      buildScreen(pets: [_biscuit], onAddPet: () => called = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Add another pet'));
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets(
    'editing a pet through the dialog calls onEditPet with the update',
    (tester) async {
      Pet? edited;
      await tester.pumpWidget(
        buildScreen(pets: [_biscuit], onEditPet: (pet) => edited = pet),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('edit_pet_${_biscuit.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Edit pet'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('edit_pet_name_field')),
        'Biscuit Jr.',
      );
      await tester.tap(find.byKey(const Key('edit_pet_submit_button')));
      await tester.pumpAndSettle();

      expect(edited, isNotNull);
      expect(edited!.id, _biscuit.id);
      expect(edited!.name, 'Biscuit Jr.');
      expect(edited!.species, _biscuit.species);
    },
  );

  testWidgets('deleting the only pet is blocked with a message', (
    tester,
  ) async {
    var deleteCalled = false;
    await tester.pumpWidget(
      buildScreen(pets: [_biscuit], onDeletePet: (_) => deleteCalled = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('delete_pet_${_biscuit.id}')));
    await tester.pump();

    expect(find.text('You need at least one pet profile.'), findsOneWidget);
    expect(deleteCalled, isFalse);
  });

  testWidgets(
    'deleting one of several pets confirms first, then calls onDeletePet',
    (tester) async {
      Pet? deleted;
      await tester.pumpWidget(
        buildScreen(
          pets: [_biscuit, _coco],
          onDeletePet: (pet) => deleted = pet,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('delete_pet_${_coco.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Delete Coco?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, _coco);
    },
  );

  testWidgets('tapping "Manage subscription" launches the subscriptions URL', (
    tester,
  ) async {
    Uri? launched;
    await tester.pumpWidget(
      buildScreen(
        pets: [_biscuit],
        launchUrl: (uri) async {
          launched = uri;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final subscriptionFinder = find.text('Manage subscription');
    await scrollUntilVisible(tester, subscriptionFinder);
    await tester.tap(subscriptionFinder);
    await tester.pump();

    expect(launched, isNotNull);
    expect(launched.toString(), contains('apps.apple.com'));
  });

  testWidgets('the reminders switch toggles local state', (tester) async {
    await tester.pumpWidget(buildScreen(pets: [_biscuit]));
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const Key('reminders_switch'));
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets(
    'the units control defaults to Metric and can switch to Imperial',
    (tester) async {
      await tester.pumpWidget(buildScreen(pets: [_biscuit]));
      await tester.pumpAndSettle();

      final segmented = find.byKey(const Key('units_segmented_button'));
      await scrollUntilVisible(tester, segmented);
      expect(
        tester
            .widget<SegmentedButton<Object?>>(segmented)
            .selected
            .single
            .toString(),
        contains('metric'),
      );

      await tester.tap(find.text('Imperial'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SegmentedButton<Object?>>(segmented)
            .selected
            .single
            .toString(),
        contains('imperial'),
      );
    },
  );

  testWidgets(
    'shows the exact non-diagnostic disclaimer text and legal links',
    (tester) async {
      await tester.pumpWidget(buildScreen(pets: [_biscuit]));
      await tester.pumpAndSettle();

      final disclaimer = find.textContaining(
        "Pawcheck gives plain-language guidance, not a diagnosis.",
      );
      await scrollUntilVisible(tester, disclaimer);
      expect(disclaimer, findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
    },
  );

  testWidgets('confirming sign out resets the app back to Splash', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(pets: [_biscuit]));
    await tester.pumpAndSettle();

    final signOut = find.byKey(const Key('sign_out_button'));
    await scrollUntilVisible(tester, signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    // Not pumpAndSettle: SplashScreen auto-advances to Onboarding after
    // 1.5s via its own AnimationController (see splash_screen.dart) —
    // settling here would run straight past the state this test wants to
    // check into whatever comes after Splash. The push/remove transition
    // needs a few incremental pumps to actually finish removing the old
    // route — a single big pump(duration) jump doesn't reliably do it —
    // so step up to ~400ms in small hops, well under that 1.5s timer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('cancelling sign out stays on Settings', (tester) async {
    await tester.pumpWidget(buildScreen(pets: [_biscuit]));
    await tester.pumpAndSettle();

    final signOut = find.byKey(const Key('sign_out_button'));
    await scrollUntilVisible(tester, signOut);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
