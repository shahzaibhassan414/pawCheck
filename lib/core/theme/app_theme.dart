import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PawCheck's app-wide theme, following the design tokens from the
/// "Paw Check claude design" handoff doc (a full Claude Design spec for
/// the whole app — see that folder's README.md at the repo root). This is
/// the "foundation" layer only — colors, type, shape — applied to the
/// screens that already exist; the doc's per-screen layouts (a combined
/// Account+Add-Pet screen, Camera, Results with its urgency-tier system,
/// Timeline) are follow-up work, not done here.
///
/// The native launch screens configured by `flutter_native_splash` (see
/// `pubspec.yaml`) intentionally still use the *previous* light background
/// (`0xFFFAFAF7`), not [_lightBackground] below — the design doc's actual
/// Splash screen is a full-bleed violet takeover, completely different
/// from today's `SplashScreen` widget, and changing the pre-Flutter-engine
/// splash color to match a screen that doesn't exist yet would introduce
/// exactly the native-splash-vs-first-frame flash this project has
/// otherwise been careful to avoid. Revisit both together when the Splash
/// screen itself is rebuilt to match the doc.
abstract final class AppTheme {
  /// Primary violet accent — matches the design doc's `#7C3AED` exactly
  /// (no change from the previous rebrand).
  static const _seedColor = Color(0xFF7C3AED);

  /// The design doc's full violet ramp (`100`–`900`) — hand-specified,
  /// not `ColorScheme.fromSeed`'s algorithmic tonal palette, since this is
  /// a designed system with exact intended values at each step. Public
  /// (unlike the other tokens on this class) because the design doc
  /// refers to specific steps by name ("violet-200", etc.) on almost every
  /// screen — e.g. an inactive progress-bar segment, a hover/pressed
  /// state — not just for building [ColorScheme] roles below.
  static const violet100 = Color(0xFFF4EEFF);
  static const violet200 = Color(0xFFE6D6FF);
  static const violet300 = Color(0xFFCFB0FF);
  static const violet400 = Color(0xFFAF7FFB);
  static const violet500 = Color(0xFF9159F2);
  static const violet600 = Color(0xFF6D28D9); // doc: "hover"
  static const violet700 = Color(0xFF591DB3); // doc: "pressed/text-on-tint"
  static const violet800 = Color(0xFF3F1483);
  static const violet900 = Color(0xFF2A0F5C);

  /// Doc: "Background (cream) — `--color-bg`" — the screen background.
  static const _lightBackground = Color(0xFFF5EAD8);

  /// Doc: "Surface (card fill) — `--color-surface`" — deliberately a
  /// richer/darker tone than [_lightBackground] so cards read as raised
  /// against the page, not the usual (near-)white-on-white Material
  /// default.
  static const _lightCardSurface = Color(0xFFEBDDC5);

  /// Doc: "Text — `--color-text`".
  static const _lightText = Color(0xFF201E1D);

  /// Doc: "Secondary accent (sage, from base design system, unused for
  /// primary actions)" — decorative use only (e.g. an unselected pet
  /// avatar chip), never a button/CTA color.
  static const _secondaryAccent = Color(0xFF7A8A5E);

  /// Shared spacing rhythm — screens should build paddings/gaps from these
  /// rather than inventing one-off numbers, so vertical rhythm stays
  /// consistent across onboarding, the pet form, and home.
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 16.0;
  static const spaceLg = 24.0;
  static const spaceXl = 32.0;
  static const spaceXxl = 48.0;

  /// Shared corner radii.
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const radiusPill = 999.0;

  /// Shared motion constants — kept short and finite by design. Nothing in
  /// this app should animate forever: a calm, trustworthy surface earns its
  /// motion budget with purposeful one-shot transitions, not ambient loops.
  static const motionFast = Duration(milliseconds: 150);
  static const motionMedium = Duration(milliseconds: 320);
  static const motionSlow = Duration(milliseconds: 500);
  static const motionCurve = Curves.easeOutCubic;

  static ThemeData get light => _themeFor(brightness: .light);

  static ThemeData get dark => _themeFor(brightness: .dark);

  static ThemeData _themeFor({required Brightness brightness}) {
    // `ColorScheme.fromSeed` fills in every M3 role algorithmically first
    // (error, tertiary, inverse*, etc. — the design doc doesn't specify
    // these), then the design doc's exact hand-picked values override the
    // roles it *does* specify. The doc is light-mode only — dark mode
    // stays fully algorithmic for now rather than inventing an unspecified
    // dark palette; see the class doc comment.
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final colorScheme = brightness == Brightness.light
        ? baseScheme.copyWith(
            primary: _seedColor,
            onPrimary: Colors.white,
            primaryContainer: violet100,
            onPrimaryContainer: violet700,
            secondary: _secondaryAccent,
            onSecondary: Colors.white,
            surface: _lightBackground,
            onSurface: _lightText,
            onSurfaceVariant: _lightText.withValues(alpha: 0.7),
            surfaceContainerHighest: _lightCardSurface,
            outlineVariant: _lightText.withValues(alpha: 0.16),
          )
        : baseScheme;

    // Same value used for `scaffoldBackgroundColor` — an `AppBar` with no
    // title/actions (as on the pet profile screen) would otherwise be a
    // flat block of the raw `colorScheme.surface`, a visibly different
    // tone that shows up as a hard seam right at the app bar's edge.
    final scaffoldBackground = colorScheme.surface;

    // Fraunces (display) + Figtree (body) — swapped from the design doc's
    // original Caprasimo/Figtree pairing at the user's explicit request
    // ("the font doesn't look good"): Caprasimo's heavy, cartoonish slab
    // read as less polished than intended. Fraunces is a warm, soft-serif
    // display face — keeps some personality (fitting PawCheck's caring
    // tone) without Caprasimo's blocky weight. Reserved for display/
    // headline/title styles only: a distinctive display face whose density
    // makes paragraph-length body text feel heavy and harder to scan,
    // which is why body/label styles get Figtree instead, throughout.
    final displayTextTheme = GoogleFonts.frauncesTextTheme(_textTheme);
    final bodyTextTheme = GoogleFonts.figtreeTextTheme(_textTheme);
    final textTheme = _textTheme.copyWith(
      displaySmall: displayTextTheme.displaySmall,
      headlineMedium: displayTextTheme.headlineMedium,
      headlineSmall: displayTextTheme.headlineSmall,
      titleLarge: displayTextTheme.titleLarge,
      titleMedium: displayTextTheme.titleMedium,
      titleSmall: displayTextTheme.titleSmall,
      bodyLarge: bodyTextTheme.bodyLarge,
      bodyMedium: bodyTextTheme.bodyMedium,
      bodySmall: bodyTextTheme.bodySmall,
      labelLarge: bodyTextTheme.labelLarge,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      // A calm, iOS-flavored slide/fade even on platforms that would
      // otherwise get a Material "Y-axis fade through" — PawCheck is
      // iOS-first and this keeps push/pop motion consistent everywhere.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      // Doc's Shape tokens: "Buttons, tags, chips, avatars: fully
      // pill/circular (999px or 50%)" — distinct from cards/containers,
      // which stay at radiusMd/radiusLg.
      //
      // Explicitly filled with `colorScheme.primary`/`onPrimary` below —
      // Material 3's own `ElevatedButton` default is a *light, surface-
      // colored* button with primary-colored text (that's `FilledButton`'s
      // job in stock M3, not `ElevatedButton`'s). Every screen in this app
      // uses plain `ElevatedButton()` for its primary CTA relying entirely
      // on this theme, so leaving the M3 default in place meant every
      // "Continue"/"Add pet"/"Scan" button rendered as a pale, low-contrast
      // button with violet text instead of the bold solid-violet pill the
      // design doc actually calls for — the concrete cause of "buttons
      // look basic" feedback, not a matter of taste on top of a correct
      // base.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              disabledBackgroundColor: colorScheme.primary.withValues(
                alpha: 0.35,
              ),
              disabledForegroundColor: colorScheme.onPrimary.withValues(
                alpha: 0.7,
              ),
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              elevation: 2,
              shadowColor: colorScheme.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusPill),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? Colors.white.withValues(alpha: 0.12)
                    : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: spaceMd,
                vertical: spaceSm,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusPill),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : null,
              ),
            ),
      ),
      // Fields previously had `BorderSide.none` on every border except
      // focus/error — meaning an untouched field had no edge at all, just
      // a filled rounded rect the same shape as any other card on the
      // page, with nothing to read as "this is an input" until it was
      // actively focused. Gave every state a real (if quiet) 1px border
      // instead, so a field's boundary is legible at rest, not just when
      // something's already wrong or already focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorStyle: TextStyle(
          color: colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: spaceXl,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
    );
  }

  static const _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 32,
      height: 1.2,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(fontWeight: FontWeight.w700, height: 1.25),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.35),
    labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
  );
}
