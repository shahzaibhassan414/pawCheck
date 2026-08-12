# PawCheck — Product Overview

*Working name — swap before you register app store listings.*

## One-line pitch
Snap a photo of what's worrying you about your pet, get an instant, plain-language read on what it might be and whether it's urgent — with an ongoing timeline so you can track how it's healing.

## The problem
Pet owners hit a moment of low-grade panic constantly: a weird patch on the skin, an odd-colored stool, a limp, a swollen eye. Google gives generic, scary results. A vet visit for every one of these is expensive and often unnecessary. There's no fast, calm, specific first read — and almost nobody has built a genuinely good version of this for pets, even though the equivalent exists for human skin and symptoms.

## The solution
PawCheck lets a user photograph the issue, adds an optional note, and gets back:
- A plain-language description of what's visible
- 2–4 plausible, non-diagnostic explanations
- An urgency rating (Low / Monitor / See a vet soon / Emergency)
- A saved entry in that pet's timeline, so the same issue can be re-scanned and compared over time

The timeline is the retention hook — a one-off scanner gets deleted after use; a healing tracker gets reopened.

## Target audience
- Dog and cat owners, primarily first-time or anxious pet owners
- Skews toward people already spending on pet health/wellness apps and products
- English-language market first (US/UK/AU/CA), expand later

## Why now / why this niche
- AI vision-scanner utilities (photo → instant answer) currently have the best revenue-per-install of any micro-utility category
- Human-health photo scanners (skin, calorie) are saturated; a well-designed pet-specific version is not
- The mechanic is proven (snap photo → AI read → urgency flag) — the differentiation is audience and execution, not invention

## Monetization
- Freemium subscription: 1 free scan, then paywall
- $4.99/month or $29.99/year, hybrid with an optional lifetime tier later
- RevenueCat handles billing/entitlements across iOS and Android

## Tech stack (all free-tier to start)
- **App**: Flutter (iOS-first, Android port once funnel converts)
- **AI**: Gemini API (free tier) for image + text vision calls
- **Backend/data**: Firebase (Auth, Firestore for scan history) — free tier
- **Payments**: RevenueCat — free until real revenue, then a rev-share
- **Analytics**: Firebase Analytics or PostHog free tier

## Safety and positioning boundaries
- Never states a diagnosis as fact — always "possible causes"
- Never gives treatment or medication/dosing advice
- Always pushes to a real vet for anything above Low urgency
- Framed throughout as informational, not veterinary advice — this matters for App Store review and for user trust

## Success looks like
- Month 1–3: validated ASO keywords ranking, first paying subscribers, sub-$500 MRR
- Month 3–6: retention signal from the timeline feature (re-opens, repeat scans per pet)
- Stretch: a keyword cluster or short-form video hit pushes past $1K MRR

## Explicitly out of scope for v1
- Multi-pet household management beyond simple profiles
- Vet telehealth / chat with a real vet
- Prescription or treatment guidance
- Breed-specific health records or vaccination tracking