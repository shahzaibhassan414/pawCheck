import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/pet.dart';
import '../../core/models/scan.dart';
import '../../core/services/ai_triage_service.dart';
import '../../core/services/firestore_scan_repository.dart';
import '../../core/services/gemini_ai_triage_service.dart';
import '../../core/services/scan_repository.dart';
import '../../core/theme/app_theme.dart';
import 'result_screen.dart';

/// Picks an image from [source] and returns it, or null if the user
/// cancelled. Matches [ImagePicker.pickImage]'s signature so tests can
/// inject a fake without touching the platform channel the real plugin
/// uses under the hood (PRD Milestone 4: "mock the camera plugin").
typedef ImagePickerFn = Future<XFile?> Function(ImageSource source);

/// `maxWidth`/`imageQuality` keep a captured photo small enough to store as
/// a base64 `data:` URI directly in its Firestore `Scan` document — there's
/// no Firebase Storage in this app (it now requires the Blaze billing plan
/// even to create a bucket, which conflicts with staying on free-tier infra
/// per CLAUDE.md), so the photo has to fit comfortably inside Firestore's
/// ~1MiB document cap. A 1024px-wide JPEG at quality 55 typically lands
/// well under that even after base64's ~33% size inflation.
Future<XFile?> _defaultPickImage(ImageSource source) =>
    ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 55);

enum _Stage { capture, review, loading, error }

/// Camera capture, per section 5 of the "Paw Check claude design" handoff
/// doc (see that folder's README.md at the repo root): near-black
/// background, a bracketed viewfinder, and a gallery/shutter/flip-camera
/// bottom row — deliberately the one other screen off the app's normal
/// cream/violet design system besides Splash, for the same reason a
/// camera UI usually is (maximum contrast against whatever's being
/// photographed).
///
/// The doc's shutter tap goes straight to a processing scrim with no
/// separate confirm step, because its mockup assumes a live camera feed.
/// This app picks images via `image_picker` instead of the `camera`
/// package (a deliberate Milestone 4 choice — simpler, no live-preview/
/// permissions plumbing), so the OS's own camera UI already handles
/// "retake or use this photo" before control returns here. A review step
/// (picked photo + optional note + Retake/Analyze) still exists on top of
/// that for two reasons the doc's mockup doesn't need to address: PRD FR2
/// requires a free-text note, and a gallery-picked photo has no native
/// retake step of its own.
///
/// [triageService] defaults to the live [GeminiAiTriageService]; every
/// automated test must inject `MockAiTriageService` instead (PRD Section
/// 12 — never call the live API in tests). On success, `pushReplacement`s
/// to the real `ResultScreen` (doc section 6 / PRD Milestone 5).
class ScanScreen extends StatefulWidget {
  ScanScreen({
    super.key,
    required this.pet,
    AiTriageService? triageService,
    ScanRepository? scanRepository,
    this.pickImage = _defaultPickImage,
    this.onScanCompleted,
  }) : triageService = triageService ?? GeminiAiTriageService(),
       scanRepository = scanRepository ?? FirestoreScanRepository();

  final Pet pet;
  final AiTriageService triageService;

  /// Defaults to the real Firestore-backed repository — every automated
  /// test must inject `InMemoryScanRepository` instead (same "never touch
  /// live services in tests" rule already followed for [triageService]).
  final ScanRepository scanRepository;
  final ImagePickerFn pickImage;

  /// Called once a scan finishes analyzing successfully, right before
  /// navigating to [ResultScreen] — lets a caller mark the free-scan
  /// counter used (PRD Milestone 7) without this screen knowing anything
  /// about entitlement/paywall state itself.
  final VoidCallback? onScanCompleted;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _noteController = TextEditingController();
  _Stage _stage = _Stage.capture;
  Uint8List? _imageBytes;

  Future<void> _pick(ImageSource source) async {
    final file = await widget.pickImage(source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _stage = _Stage.review;
    });
  }

  void _retake() {
    setState(() {
      _imageBytes = null;
      _stage = _Stage.capture;
    });
  }

  Future<void> _submit() async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() => _stage = _Stage.loading);

    try {
      final trimmedNote = _noteController.text.trim();
      final result = await widget.triageService.analyze(
        imageBytes: bytes,
        species: widget.pet.species,
        note: trimmedNote.isEmpty ? null : trimmedNote,
      );
      final scanDate = DateTime.now();
      final scan = Scan(
        id: scanDate.microsecondsSinceEpoch.toString(),
        photoUrl: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        timestamp: scanDate,
        aiDescription: result.description,
        aiCauses: result.causes,
        urgencyLevel: result.urgencyLevel,
        note: trimmedNote.isEmpty ? null : trimmedNote,
      );
      await widget.scanRepository.addScan(widget.pet.id, scan);
      if (!mounted) return;
      widget.onScanCompleted?.call();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            pet: widget.pet,
            result: result,
            photo: MemoryImage(bytes),
            scanDate: scanDate,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ScanColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // "back chevron, 'Scanning {pet name}', spacer" — the invisible
        // trailing spacer keeps the title visually centered against the
        // real back chevron on the leading edge.
        title: Text('Scanning ${widget.pet.name}'),
        actions: const [SizedBox(width: 48)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: switch (_stage) {
            _Stage.capture => _CaptureView(
              onTakePhoto: () => _pick(ImageSource.camera),
              onPickFromGallery: () => _pick(ImageSource.gallery),
            ),
            _Stage.review => _ReviewView(
              imageBytes: _imageBytes!,
              noteController: _noteController,
              onRetake: _retake,
              onSubmit: _submit,
            ),
            _Stage.loading => _LoadingView(imageBytes: _imageBytes!),
            _Stage.error => _ErrorView(onRetry: _submit),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}

/// This screen's own fixed dark palette — deliberately not pulled from
/// `Theme.of(context)`, which is tuned for the app's normal cream/violet
/// surfaces. See the class doc comment on [ScanScreen] for why this screen
/// is an intentional exception.
abstract final class _ScanColors {
  static const background = Color(0xFF15131A);
  static const viewfinderFill = Color(0x0FFFFFFF); // white @ ~6%
  static const iconCircleFill = Color(0x1FFFFFFF); // white @ ~12%
  static const mutedText = Color(0xB3FFFFFF); // white @ ~70%
}

class _CaptureView extends StatelessWidget {
  const _CaptureView({
    required this.onTakePhoto,
    required this.onPickFromGallery,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: _Viewfinder()),
        const SizedBox(height: AppTheme.spaceLg),
        const Text(
          'Fill the frame, hold steady, and use natural light.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _ScanColors.mutedText, fontSize: 13),
        ),
        const SizedBox(height: AppTheme.spaceXl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconCircleButton(
              key: const Key('gallery_button'),
              icon: Icons.photo_library_outlined,
              onTap: onPickFromGallery,
            ),
            _Shutter(key: const Key('shutter_button'), onTap: onTakePhoto),
            // "spacer (right, flip-camera icon placeholder)" — inert by
            // design; there's no live front/back camera feed to flip
            // between when capture goes through `image_picker`.
            const _IconCircleButton(icon: Icons.cameraswitch_outlined),
          ],
        ),
      ],
    );
  }
}

/// "Large rounded-rect (24px radius) dark placeholder area ... with 4
/// corner focus brackets (white, 3px, only corners) overlaid" per the doc.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        color: _ScanColors.viewfinderFill,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                Icons.photo_camera_outlined,
                color: Colors.white.withValues(alpha: 0.25),
                size: 48,
              ),
            ),
            CustomPaint(painter: _CornerBracketsPainter()),
          ],
        ),
      ),
    );
  }
}

/// Paints 4 L-shaped corner brackets — Flutter has no built-in "viewfinder
/// corners" decoration. Static (no animation), so it carries no
/// motion-safety risk.
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter();

  static const _inset = 18.0;
  static const _armLength = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * _armLength, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * _armLength), paint);
    }

    corner(_inset, _inset, 1, 1);
    corner(size.width - _inset, _inset, -1, 1);
    corner(_inset, size.height - _inset, 1, -1);
    corner(size.width - _inset, size.height - _inset, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}

/// "Large white circular shutter button (68px, center, translucent white
/// ring)" per the doc.
class _Shutter extends StatefulWidget {
  const _Shutter({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.92 : 1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 3,
                ),
              ),
            ),
            AnimatedScale(
              scale: _scale,
              duration: AppTheme.motionFast,
              curve: Curves.easeOut,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 68, height: 68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? _ScanColors.iconCircleFill : const Color(0x0AFFFFFF),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.3),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.imageBytes,
    required this.noteController,
    required this.onRetake,
    required this.onSubmit,
  });

  final Uint8List imageBytes;
  final TextEditingController noteController;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.memory(
              imageBytes,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        const Text(
          'Add a note (optional)',
          style: TextStyle(
            color: _ScanColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXs),
        TextField(
          key: const Key('note_field'),
          controller: noteController,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'e.g. scratching for 2 days',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: const Icon(
              Icons.edit_note_outlined,
              color: _ScanColors.mutedText,
            ),
            filled: true,
            fillColor: _ScanColors.iconCircleFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('retake_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: onRetake,
                child: const Text('Retake'),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              flex: 2,
              // Solid white on dark — the same "inverted from the app's
              // normal violet CTA" treatment the doc uses for its
              // Emergency screen's primary button, applied here since
              // Camera is likewise a dark-background exception.
              child: ElevatedButton(
                key: const Key('analyze_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _ScanColors.background,
                ),
                onPressed: onSubmit,
                child: const Text('Analyze'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Viewfinder dims with a translucent scrim, a spinner + 'Reading the
/// photo…' shows for ~1.3s" per the doc.
class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(imageBytes, fit: BoxFit.cover),
                Container(color: Colors.black.withValues(alpha: 0.55)),
                Center(
                  child: Column(
                    key: const Key('scan_loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'Reading the photo…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        key: const Key('scan_error'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Text(
            'Something went wrong',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          const Text(
            'We couldn\'t analyze that photo. Check your connection and '
            'try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _ScanColors.mutedText),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          ElevatedButton(
            key: const Key('retry_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _ScanColors.background,
            ),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
