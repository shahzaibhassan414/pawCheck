# PawCheck

Snap a photo of what's worrying you about your pet, get an instant, plain-language read on what it might be and whether it's urgent — with an ongoing timeline to track how it's healing.

PawCheck is a Flutter app, iOS-first (Android as a fast-follow). It is **not** a veterinary diagnosis tool — it never states a diagnosis as fact, never gives treatment/medication advice, and always points to a real vet for anything above "Low" urgency. See [Pawcheck-overview.md](./Pawcheck-overview.md) for the full product pitch, target audience, monetization, and safety/positioning boundaries.

## Status

Early development. Onboarding, pet profile setup, a placeholder home/scan screen, and a splash screen are in place; the AI triage flow, timeline, and paywall are still to come.

## Tech stack

- **App**: Flutter
- **AI**: Gemini API (image + text vision)
- **Backend**: Firebase (Auth, Firestore)
- **Payments**: RevenueCat
- **Analytics**: Firebase Analytics / PostHog (free tier)

## Getting started

```
flutter pub get                      # install dependencies
flutter run                          # run on a connected simulator/device
flutter analyze                      # static analysis
flutter test                         # run unit + widget tests
flutter test test/widget_test.dart   # run a single test file
flutter test --plain-name "test name"  # run a single test by name
```

Firebase, RevenueCat, and Gemini are not wired up yet — API keys are read via `--dart-define-from-file=env.json` (copy `env.example.json` to a gitignored `env.json` and fill in real values once those accounts exist).

## Project structure

```
lib/
  core/        # shared models, theme, config
  features/
    onboarding/
    scan/
    splash/
```
