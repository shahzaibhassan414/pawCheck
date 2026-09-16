import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_check/features/paywall/paywall_screen.dart';

void main() {
  Widget buildScreen({Future<bool> Function()? restorePurchases}) {
    return MaterialApp(
      home: PaywallScreen(
        restorePurchases: restorePurchases ?? (() async => false),
      ),
    );
  }

  testWidgets(
    'renders both pricing options with the annual plan selected by default',
    (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('paywall_option_monthly')), findsOneWidget);
      expect(find.byKey(const Key('paywall_option_annual')), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Annual'), findsOneWidget);
      expect(find.textContaining('Best value'), findsOneWidget);
    },
  );

  testWidgets('tapping Continue pops true', (tester) async {
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(
                context,
              ).push<bool>(MaterialPageRoute(builder: (_) => PaywallScreen()));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paywall_continue_button')));
    await tester.pumpAndSettle();

    expect(poppedValue, isTrue);
  });

  testWidgets('closing without subscribing pops false', (tester) async {
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(
                context,
              ).push<bool>(MaterialPageRoute(builder: (_) => PaywallScreen()));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paywall_close_button')));
    await tester.pumpAndSettle();

    expect(poppedValue, isFalse);
  });

  testWidgets('a successful restore pops true without tapping Continue', (
    tester,
  ) async {
    bool? poppedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              poppedValue = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      PaywallScreen(restorePurchases: () async => true),
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

    await tester.tap(find.byKey(const Key('paywall_restore_button')));
    await tester.pumpAndSettle();

    expect(poppedValue, isTrue);
  });

  testWidgets('a failed restore shows a snackbar and stays on the paywall', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(restorePurchases: () async => false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paywall_restore_button')));
    await tester.pumpAndSettle();

    expect(find.text('No previous purchases found.'), findsOneWidget);
    expect(find.byType(PaywallScreen), findsOneWidget);
  });
}
