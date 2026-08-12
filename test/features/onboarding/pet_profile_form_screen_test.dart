import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/onboarding/pet_profile_form_screen.dart';
import 'package:paw_check/features/scan/home_screen.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: PetProfileFormScreen()),
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

    await tester.enterText(
      find.byKey(const Key('pet_name_field')),
      'Biscuit',
    );
    await tester.tap(find.byKey(const Key('pet_species_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dog').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pet_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Biscuit'), findsWidgets);
  });
}
