# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This repo is currently an untouched `flutter create` scaffold (`lib/main.dart` is still the counter demo). The real product is defined in two docs at the repo root — read these before building anything, they are the source of truth, not this file:

- `Pawcheck-overview.md` — product pitch, target audience, monetization, tech stack, safety/positioning boundaries
- `Pawcheck-prd .md` — functional requirements, AI prompt design, data model, and an 11-milestone build plan (Milestone 0 → Milestone 10)

## Commands

```
flutter pub get                      # install dependencies
flutter run                          # run on connected simulator/device
flutter analyze                      # static analysis (must return no errors)
flutter test                         # run all unit + widget tests
flutter test test/widget_test.dart   # run a single test file
flutter test --plain-name "test name"  # run a single test by name
flutter test integration_test        # run integration tests (once the integration_test package is added)
```

No Firebase, RevenueCat, or Gemini SDK is wired up yet — `flutterfire configure` and RevenueCat/Gemini API key setup are part of Milestone 0 in the PRD.

## Build plan and sequencing

The PRD's Section 13 defines the build order as discrete milestones (data models → Gemini service layer → onboarding → scan screen → result screen → timeline → paywall → settings → notifications → App Store prep). Each milestone has an explicit "done" checklist. **Do not start milestone N+1 until milestone N's tests pass** — this ordering is intentional (e.g. the mock `AiTriageService` built in Milestone 2 is what every later UI milestone's tests depend on).

Planned structure, per PRD Milestone 0 (not yet created):
```
lib/features/scan/
lib/features/timeline/
lib/features/paywall/
lib/features/settings/
lib/core/        # shared models/services
```

## Testing approach (per PRD Section 12)

- Unit tests (`flutter test`) for pure logic: model JSON (de)serialization, urgency-level enum mapping, paywall gating, timeline sorting.
- Widget tests for individual screens with mocked data.
- Integration tests (`integration_test` package) for full flows: onboarding → scan → result → paywall, and scan → timeline → reopen.
- **Never call the live Gemini API in automated tests.** Use the mock `AiTriageService` implementation (built in Milestone 2) with canned responses covering Low, Monitor, See a vet soon, Emergency, and a malformed/error response.
- Before starting a new milestone, run the full existing test suite — don't move on with red tests.

## AI output constraints (non-negotiable, per PRD Section 7 and overview's safety boundaries)

Every Gemini call uses the system prompt in PRD Section 7. Any code that builds prompts or parses/renders AI output must preserve these rules:

- Never state a diagnosis as fact — only "possible causes."
- Never output medication names, dosages, or treatment instructions. The `AiTriageService` must have a guardrail layer that strips/flags this even though the prompt should prevent it — don't rely on the prompt alone.
- Urgency is exactly one of: `Low`, `Monitor`, `See a vet soon`, `Emergency`. When uncertain, err toward the higher urgency.
- Non-pet or inconclusive images default to `Monitor` with a retake/watch note rather than a hard failure.
- "Find a vet nearby" CTA shows for `Monitor` and above, not for `Low`.
- Output is structured JSON (`description`, `causes[]`, `urgency`, `vet_recommended`) so the app can render it without free-text parsing.

## Data model (PRD Section 8)

`User` → `Pets[]` (id, name, species, breed?, age?) → `Scans[]` (id, photoUrl, note, timestamp, aiDescription, aiCauses[], urgencyLevel, resolved). Deleting a pet must cascade-delete its scans (no orphaned Firestore documents).

## Platform/scope constraints

- iOS-first (iOS 15+); Android is a fast-follow, not launch scope.
- No vet telehealth, no treatment/medication guidance, no multi-user households, no offline mode — these are explicit non-goals for v1.
- Everything must run on free-tier infra (Gemini, Firebase, RevenueCat) until there's paying revenue — avoid introducing paid services or infra that breaks this.
- Free-scan limit (per install vs. per pet) is an explicit open question in the PRD — check it's been decided before touching Milestone 7 (paywall) gating logic.
