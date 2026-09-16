import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/widgets/pet_form_screen.dart';
import 'package:paw_check/core/widgets/species_option_card.dart';

const _biscuit = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

Future<XFile?> _unusedPickPhoto() async =>
    throw StateError('photo picker should not be invoked in this test');

void main() {
  testWidgets(
    'edit mode pre-fills the name field and selects the current species',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PetFormScreen(
            initialPet: _biscuit,
            pickPhoto: _unusedPickPhoto,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit pet'), findsOneWidget);
      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      final dogCard = tester.widget<SpeciesOptionCard>(
        find.byKey(const Key('edit_pet_species_dog')),
      );
      final catCard = tester.widget<SpeciesOptionCard>(
        find.byKey(const Key('edit_pet_species_cat')),
      );
      expect(dogCard.selected, isTrue);
      expect(catCard.selected, isFalse);
    },
  );

  testWidgets('edit mode submits an updated Pet keeping the same id', (
    tester,
  ) async {
    Pet? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Pet>(
                MaterialPageRoute(
                  builder: (_) => PetFormScreen(
                    initialPet: _biscuit,
                    pickPhoto: _unusedPickPhoto,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('edit_pet_name_field')),
      'Biscuit Jr.',
    );
    await tester.tap(find.byKey(const Key('edit_pet_species_cat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_pet_submit_button')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, _biscuit.id);
    expect(result!.name, 'Biscuit Jr.');
    expect(result!.species, 'Cat');
  });

  testWidgets('the back chevron cancels without returning a Pet', (
    tester,
  ) async {
    Pet? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Pet>(
                MaterialPageRoute(
                  builder: (_) => PetFormScreen(pickPhoto: _unusedPickPhoto),
                ),
              );
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(result, isNull);
  });
}
