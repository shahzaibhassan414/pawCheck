# PawCheck — Product Requirements Document

*Working name. Version 0.1 — MVP scope.*

## 1. Purpose
Define the functional and non-functional requirements for PawCheck v1: an AI-powered pet symptom photo scanner built in Flutter, monetized via subscription, shipped by a solo developer within roughly 2–4 weeks.

## 2. Goals
- Ship a usable, App Store-approvable MVP fast
- Prove people will pay after one free scan
- Establish a retention loop via scan history/timeline
- Keep infrastructure cost at $0 until there's paying revenue

## 3. Non-goals (v1)
- No vet telehealth or human-in-the-loop review
- No treatment/medication guidance
- No multi-user/shared household accounts
- No offline mode
- No Android at launch (build for it, ship iOS first)

## 4. User personas
- **Anxious new pet owner** — first dog/cat, checks everything, high anxiety, most likely to convert to paid
- **Practical repeat owner** — has had pets for years, uses it for the odd genuinely confusing thing, lower frequency but sticky if trust is earned

## 5. Core user flow (MVP)

1. **Onboarding** — 1–2 screens explaining what the app does and does not do (not a vet, informational only). Add pet profile (name, species, optional breed/age).
2. **Home / Scan** — Camera-first screen. Big shutter button. Optional text field for a note ("scratching for 2 days").
3. **Processing** — Loading state while the image + note is sent to the Gemini API.
4. **Result screen** — Shows:
    - Plain-language description of what's visible
    - 2–4 possible explanations (tag-style, non-diagnostic)
    - Urgency badge: Low / Monitor / See a vet soon / Emergency
    - "Find a vet nearby" CTA (opens maps) shown for Monitor and above
    - Save to timeline (automatic)
5. **Timeline / History** — Per-pet chronological list of past scans with urgency dot + date. Tapping an entry reopens that result. Empty state invites a first scan.
6. **Paywall** — Triggered after the first free scan. Shows subscription options (monthly/annual). Hard paywall — no further scans without subscribing.
7. **Settings** — Manage pet profiles, subscription management link, notifications toggle, legal/privacy links.

## 6. Functional requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR1 | User can capture or upload a photo from camera/gallery | Must |
| FR2 | User can add an optional free-text note before submitting | Must |
| FR3 | App sends image + note + species context to Gemini vision API and receives structured output | Must |
| FR4 | Result screen renders description, possible causes, and urgency level from AI response | Must |
| FR5 | Every scan is saved to that pet's timeline with photo thumbnail, date, and urgency | Must |
| FR6 | First scan is free; subsequent scans require an active subscription | Must |
| FR7 | User can create/edit multiple pet profiles | Should |
| FR8 | "Find a vet nearby" opens device maps with a generic "veterinarian near me" query | Should |
| FR9 | Push notification reminder to re-check an open/Monitor-status issue after a set interval | Could |
| FR10 | User can delete individual scans or a whole pet profile (data control) | Must |

## 7. AI prompt design (Gemini)

**System framing for every request:**
> "You are a triage assistant helping a pet owner understand what they're seeing — you are not a veterinarian and must never provide a definitive diagnosis, treatment, or medication guidance. Given this photo of a [species] and this optional note, return: (1) a plain-language description of what is visible, (2) 2–4 plausible non-diagnostic explanations, (3) an urgency rating of exactly one of: Low, Monitor, See a vet soon, Emergency. Always err toward a higher urgency rating when uncertain. Always recommend a vet visit for Monitor and above."

**Output should be structured (JSON) so the app can render it reliably** — description, causes[], urgency enum, optional vet_recommended boolean.

**Guardrails:**
- Reject/flag non-pet images (redirect user to retake)
- Never output medication names, dosages, or "give them X" language
- If image is inconclusive, urgency defaults to "Monitor" with a note to retake or watch for changes

## 8. Data model (high level)

```
User
 └─ Pets []
     ├─ id, name, species, breed?, age?
     └─ Scans []
         ├─ id, photoUrl, note, timestamp
         ├─ aiDescription, aiCauses[], urgencyLevel
         └─ resolved: boolean (user can mark "resolved")
```

## 9. Non-functional requirements

- **Cost**: Stay within Gemini free-tier rate limits through early growth; RevenueCat and Firebase free tiers cover the rest
- **Performance**: Scan result returned within ~5–10 seconds; show a clear loading state
- **Privacy**: Photos are sensitive personal content — store securely, allow full deletion, disclose AI processing in privacy policy
- **Platform**: iOS 15+ first via Flutter; Android parity in fast-follow
- **Accessibility**: Standard Flutter accessibility support (screen reader labels, sufficient contrast)

## 10. App Store / compliance considerations

- Health-adjacent apps get extra App Store review scrutiny — copy must never claim to diagnose or treat
- Include a clear in-app and App Store description disclaimer: "PawCheck provides general information only and is not a substitute for professional veterinary advice."
- Privacy policy must disclose that photos are sent to a third-party AI provider (Google Gemini) for processing

## 11. Success metrics

- **Activation**: % of installs that complete a first scan
- **Conversion**: % of free-scan users who subscribe after paywall
- **Retention**: % of subscribers who log a second scan within 14 days (timeline re-engagement)
- **Revenue**: MRR at 30/60/90 days
- **ASO**: keyword rank for 15–20 target long-tail terms

## 12. Testing strategy

General approach: every module ships with its own tests before it's considered "done," not bolted on at the end. Use Flutter's built-in test framework throughout.

- **Unit tests** (`flutter test`) — pure logic: data models, JSON parsing of the Gemini response, urgency-level mapping, paywall gating logic, date/timeline sorting.
- **Widget tests** — individual screens in isolation with mocked data (e.g. render the result screen with a fake AI response and assert the urgency badge, causes list, and CTA all appear correctly).
- **Integration tests** (`integration_test` package) — full user flows on a simulator/device: onboarding → scan → result → paywall, and scan → timeline → reopen entry.
- **Manual/exploratory pass** — at the end of each milestone, a short manual checklist (below) run on a real device, since camera and push notifications don't fully simulate.
- **Mocking the AI call** — never hit the live Gemini API in automated tests. Build a fake/mock response layer with a handful of canned responses (Low, Monitor, See a vet soon, Emergency, and a malformed/error response) so tests are fast, free, and deterministic.
- **Regression habit** — before starting each new milestone, run the full test suite for everything built so far. Don't move on with red tests.

## 13. Milestones — detailed, module by module

Each milestone below is scoped to be handed to Claude Code (or worked through solo) as a self-contained unit: what to build, what "done" means, and what to test before moving to the next one. Do not start milestone N+1 until milestone N's tests pass.

---

### Milestone 0 — Project setup
**Build:**
- Flutter project scaffolded, folder structure decided (feature-first: `lib/features/scan`, `lib/features/timeline`, `lib/features/paywall`, `lib/features/settings`, `lib/core` for shared models/services)
- Firebase project created, `flutterfire configure` run, Firebase Auth (anonymous auth is fine for v1) and Firestore wired up
- RevenueCat project created, SDK added, API keys wired via environment config (never hardcoded)
- Gemini API key obtained, stored via environment config
- CI-friendly test setup: `flutter test` runs clean on an empty scaffold

**Test before moving on:**
- [ ] App builds and runs on iOS simulator with no errors
- [ ] `flutter analyze` returns no errors
- [ ] `flutter test` runs (even with zero real tests yet) and the harness works
- [ ] Firebase and RevenueCat both initialize without throwing on app start

---

### Milestone 1 — Data layer & models
**Build:**
- `Pet` model (id, name, species, breed?, age?)
- `Scan` model (id, photoUrl, note, timestamp, aiDescription, aiCauses[], urgencyLevel enum, resolved bool)
- `UrgencyLevel` enum: low, monitor, seeVetSoon, emergency
- Local repository layer (Firestore read/write for pets and scans)
- JSON serialization/deserialization for both models

**Test before moving on:**
- [ ] Unit test: `Pet` and `Scan` serialize to JSON and back without data loss
- [ ] Unit test: malformed/missing JSON fields fail gracefully (don't crash — default or throw a caught, handled error)
- [ ] Unit test: `UrgencyLevel` enum maps correctly to and from string values the AI might return (including unexpected casing/whitespace)
- [ ] Integration test: writing a `Pet` and `Scan` to Firestore and reading it back returns an equivalent object

---

### Milestone 2 — Gemini AI service layer
**Build:**
- `AiTriageService` class: takes an image + optional note + species, returns a parsed `Scan`-shaped result
- The system prompt from Section 7, sent with every request
- Structured JSON output parsing with error handling for malformed responses
- A mock/fake implementation of the same interface returning canned responses, used for all other modules' tests

**Test before moving on:**
- [ ] Unit test: given a canned "Low" response payload, service returns correctly parsed description/causes/urgency
- [ ] Unit test: given a canned "Emergency" response, urgency maps correctly and `vet_recommended` is true
- [ ] Unit test: given a malformed/non-JSON response, service throws a specific, catchable error rather than crashing
- [ ] Unit test: given a response with a medication name or dosage-like text (guardrail violation), the service flags/strips it rather than passing it through unfiltered — build this as a safety net even though the prompt should prevent it
- [ ] Manual test: one real call to the live Gemini API with an actual pet photo, confirm response quality and latency (~5–10s) before wiring into the UI

---

### Milestone 3 — Onboarding & pet profile
**Build:**
- 1–2 onboarding screens with the "not a vet" disclaimer copy
- Add/edit pet profile screen (name, species, optional breed/age)
- First-run flow: new user is routed through onboarding once, then straight to Home on subsequent opens

**Test before moving on:**
- [ ] Widget test: onboarding screen renders required disclaimer text
- [ ] Widget test: pet profile form validates required fields (name, species) before allowing submit
- [ ] Integration test: completing onboarding creates a pet profile in Firestore and lands the user on Home
- [ ] Manual test: force-quit and reopen the app — onboarding should not show again for an existing user

---

### Milestone 4 — Scan screen (camera capture)
**Build:**
- Camera-first screen with shutter button and gallery-import fallback
- Optional note text field
- Loading/processing state while awaiting the AI response
- Error state if the API call fails (timeout, no network, rate limit) with a retry option

**Test before moving on:**
- [ ] Widget test: shutter button triggers capture flow (mock the camera plugin)
- [ ] Widget test: loading state displays while `AiTriageService` call is pending (use the mock service)
- [ ] Widget test: error state displays and offers retry when the mock service throws
- [ ] Manual test: on a real device, capture an actual photo, confirm image quality/size is reasonable before upload (compress if needed — large images will be slow and costly)

---

### Milestone 5 — Result screen
**Build:**
- Renders description, causes list, urgency badge, "Find a vet nearby" CTA (shown conditionally for Monitor+)
- Save-to-timeline happens automatically on result display
- "Find a vet nearby" opens device maps with a generic query

**Test before moving on:**
- [ ] Widget test: all four urgency levels render the correct badge color/label
- [ ] Widget test: "Find a vet nearby" CTA is hidden for Low, shown for Monitor/See a vet soon/Emergency
- [ ] Widget test: causes list renders 2–4 tags correctly from mock data
- [ ] Integration test: completing a scan results in exactly one new entry in that pet's Firestore scan collection
- [ ] Manual test: tap "Find a vet nearby" on a real device and confirm maps opens correctly

---

### Milestone 6 — Timeline / history
**Build:**
- Per-pet chronological list of scans with urgency dot + date
- Tap to reopen a past result (read-only view of Milestone 5's screen)
- Empty state for a pet with zero scans
- Delete individual scan / delete pet profile (with confirmation)

**Test before moving on:**
- [ ] Widget test: timeline renders scans in correct chronological order (most recent first)
- [ ] Widget test: empty state displays correctly for a pet with no scans
- [ ] Widget test: delete action removes the item from the list and shows a confirmation step first
- [ ] Integration test: deleting a scan removes it from Firestore, not just the local list
- [ ] Integration test: deleting a pet cascades and removes its scans too (avoid orphaned data)

---

### Milestone 7 — Paywall & subscriptions
**Build:**
- Free-scan counter (1 free scan per install, or per pet — decide and document)
- Hard paywall screen triggered when the free scan is used
- RevenueCat-driven subscription options (monthly/annual)
- Restore purchases flow
- Gate the Scan screen's submit action behind entitlement check

**Test before moving on:**
- [ ] Unit test: free-scan counter logic correctly allows scan #1 and blocks scan #2 for a non-subscriber
- [ ] Widget test: paywall screen renders both pricing options correctly from RevenueCat sandbox data
- [ ] Integration test (RevenueCat sandbox): completing a sandbox purchase unlocks scanning immediately without app restart
- [ ] Integration test: "Restore purchases" correctly re-unlocks entitlement on a fresh install using the same test account
- [ ] Manual test: attempt to bypass the paywall by killing the app mid-flow, backgrounding, etc. — confirm entitlement check can't be trivially skipped

---

### Milestone 8 — Settings & data control
**Build:**
- Manage pet profiles (edit/delete)
- Subscription management deep link (App Store subscription settings)
- Notifications toggle
- Legal/privacy links

**Test before moving on:**
- [ ] Widget test: settings screen renders all required links and toggles
- [ ] Manual test: subscription management link correctly opens the platform's native subscription settings
- [ ] Manual test: notification toggle actually enables/disables the reminder notification from Milestone 9 (if built) or is a no-op stub otherwise

---

### Milestone 9 — Reminder notifications (should-have, can slip to v1.1)
**Build:**
- Local notification scheduled after a Monitor+ scan, prompting a re-check after N days
- Notification deep-links into that specific pet's scan screen

**Test before moving on:**
- [ ] Unit test: reminder scheduling logic picks the correct delay based on urgency level
- [ ] Manual test: on a real device, confirm the notification actually fires and deep-links correctly

---

### Milestone 10 — Full regression pass & App Store prep
**Build:**
- Full run-through of every integration test together
- App icon, screenshots, App Store listing copy, privacy policy page, ASO keyword pass
- Crash reporting wired in (Firebase Crashlytics) before submission

**Test before moving on:**
- [ ] Full automated test suite (`flutter test` + `integration_test`) passes end to end
- [ ] Manual full user journey on a real device: fresh install → onboarding → first free scan → paywall → subscribe (sandbox) → second scan → timeline → delete a scan → settings → subscription management
- [ ] Test on at least two physical device sizes (e.g. a smaller and a larger iPhone) for layout issues
- [ ] Submit a TestFlight build to yourself and one outside tester before public submission

---

## 14. Open questions
- Which vision model call is cheapest/most reliable for structured JSON output at free-tier limits — confirm current Gemini flash-tier rate limits before build
- Exact copy/legal review needed for health-disclaimer language per target market
- Whether to support cats and dogs only at launch, or design for extensibility to other pets
- Whether the free-scan limit is per install or per pet profile (affects Milestone 7 logic — decide before building it)