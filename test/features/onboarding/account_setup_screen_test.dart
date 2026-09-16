import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/core/services/in_memory_pet_repository.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';
import 'package:paw_check/features/onboarding/account_setup_screen.dart';
import 'package:paw_check/features/scan/home_screen.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: AccountSetupScreen(
        accountEmail: 'test@example.com',
        petRepository: InMemoryPetRepository(),
        scanRepository: InMemoryScanRepository(),
      ),
    ),
  );

  testWidgets('blocks submit and shows validation errors when empty', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('pet_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Select a species'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('submits and navigates to Home once name and species are set', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('pet_name_field')), 'Biscuit');
    await tester.ensureVisible(find.byKey(const Key('pet_species_field')));
    await tester.tap(find.byKey(const Key('pet_species_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Biscuit'), findsWidgets);
  });

  testWidgets('gender is optional — selecting one includes it on the pet', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('pet_name_field')), 'Coco');
    await tester.ensureVisible(find.byKey(const Key('pet_species_field')));
    await tester.tap(find.byKey(const Key('pet_species_field')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cat').last);
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('pet_gender_female')));
    await tester.tap(find.byKey(const Key('pet_gender_female')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet_submit_button')));
    await tester.pumpAndSettle();

    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(home.pets.single.gender, 'Female');
  });

  testWidgets('tapping an already-selected gender deselects it', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('pet_name_field')), 'Coco');
    await tester.ensureVisible(find.byKey(const Key('pet_species_field')));
    await tester.tap(find.byKey(const Key('pet_species_field')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cat').last);
    await tester.tap(find.text('Cat').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('pet_gender_male')));
    await tester.tap(find.byKey(const Key('pet_gender_male')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pet_gender_male')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet_submit_button')));
    await tester.pumpAndSettle();

    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(home.pets.single.gender, isNull);
  });
}
