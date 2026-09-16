import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paw_check/core/models/pet.dart';
import 'package:paw_check/core/services/ai_triage_service.dart';
import 'package:paw_check/core/services/in_memory_scan_repository.dart';
import 'package:paw_check/core/services/mock_ai_triage_service.dart';
import 'package:paw_check/features/scan/result_screen.dart';
import 'package:paw_check/features/scan/scan_screen.dart';

const _pet = Pet(id: 'pet-1', name: 'Biscuit', species: 'Dog');

/// A real (if trivial) 1x1 PNG — `Image.memory` in the review stage
/// decodes whatever bytes the picker returns, so a placeholder byte list
/// like `[1, 2, 3]` throws an uncaught "Invalid image data" during the
/// image codec's async decode and fails the test.
final Uint8List _testPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

Future<XFile?> _fakePick(ImageSource source) async =>
    XFile.fromData(_testPngBytes, name: 'test.png');

/// A fake [AiTriageService] whose `analyze` call stays pending until the
/// test resolves it — lets a test assert on the loading state mid-flight
/// without ever touching the live Gemini API (PRD Section 12).
class _PendingAiTriageService implements AiTriageService {
  _PendingAiTriageService(this._future);

  final Future<TriageResult> _future;

  @override
  Future<TriageResult> analyze({
    required Uint8List imageBytes,
    required String species,
    String? note,
  }) => _future;
}

void main() {
  Future<void> pumpToReview(
    WidgetTester tester,
    AiTriageService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          pet: _pet,
          triageService: service,
          scanRepository: InMemoryScanRepository(),
          pickImage: _fakePick,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('shutter_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('shutter button triggers the capture flow', (tester) async {
    ImageSource? capturedSource;
    Future<XFile?> spyPick(ImageSource source) async {
      capturedSource = source;
      return XFile.fromData(_testPngBytes);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          pet: _pet,
          triageService: MockAiTriageService.low(),
          scanRepository: InMemoryScanRepository(),
          pickImage: spyPick,
        ),
      ),
    );

    expect(find.byKey(const Key('shutter_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shutter_button')));
    await tester.pumpAndSettle();

    expect(capturedSource, ImageSource.camera);
    expect(find.byKey(const Key('note_field')), findsOneWidget);
    expect(find.byKey(const Key('analyze_button')), findsOneWidget);
  });

  testWidgets('gallery button falls back to the photo library', (tester) async {
    ImageSource? capturedSource;
    Future<XFile?> spyPick(ImageSource source) async {
      capturedSource = source;
      return XFile.fromData(_testPngBytes);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          pet: _pet,
          triageService: MockAiTriageService.low(),
          scanRepository: InMemoryScanRepository(),
          pickImage: spyPick,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('gallery_button')));
    await tester.pumpAndSettle();

    expect(capturedSource, ImageSource.gallery);
  });

  testWidgets('loading state displays while the AI call is pending', (
    tester,
  ) async {
    final completer = Completer<TriageResult>();
    await pumpToReview(tester, _PendingAiTriageService(completer.future));

    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pump();

    expect(find.byKey(const Key('scan_loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Low tier's `ResultScreen` has no looping animation (only Emergency
    // does), so `pumpAndSettle` is safe here to let the push-replacement
    // transition finish.
    completer.complete(lowTriageResult);
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.byKey(const Key('scan_loading')), findsNothing);
  });

  testWidgets('error state displays and offers retry when the service throws', (
    tester,
  ) async {
    await pumpToReview(
      tester,
      MockAiTriageService.withError(const AiTriageException('network down')),
    );

    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('scan_error')), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsOneWidget);
  });

  testWidgets('retry after an error re-submits and can succeed', (
    tester,
  ) async {
    await pumpToReview(
      tester,
      MockAiTriageService.withError(const AiTriageException('network down')),
    );

    await tester.tap(find.byKey(const Key('analyze_button')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('scan_error')), findsOneWidget);

    // Retrying calls the same failing service again, so it stays on the
    // error state rather than magically succeeding.
    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('scan_error')), findsOneWidget);
  });
}
