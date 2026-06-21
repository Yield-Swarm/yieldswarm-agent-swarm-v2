# Kairo Flutter Foundation (K-FOUNDATION 1–3)

> **Branch:** `cursor/kairo-flutter-foundation-9c82` → `development`  
> **App path:** `kairo/mobile/`  
> **Backend proxy:** `http://localhost:8080/api/kairo`

## God Prompt delivery map

| Prompt | Delivered |
|--------|-----------|
| **K-FOUNDATION-1** | Flutter clean architecture, Riverpod 2, GoRouter, driver onboarding |
| **K-FOUNDATION-2** | Identity via `/drivers`, signed telemetry batches, consent, DePIN dashboard |
| **K-FOUNDATION-3** | Matching engine, 1% / 2× fare math, ride requests, earnings UX |

## Architecture

```
kairo/mobile/lib/
  core/
    config/         AppConfig, Colorado bounds
    network/        Dio → YieldSwarm :8080/api/kairo
    router/         GoRouter deep links
    location/       geolocator + Colorado guard
    depin/          TelemetryCollector (batch → Mandelbrot)
    matching/       MatchingEngine (ride scoring)
    payments/       EarningsCalculator (mirrors kairoFare.js)
  features/
    driver/         onboarding, availability, 2× earnings hero
    customer/       ride request, 1% fee transparency
    depin/          contribution + Akash DePIN status
  data/
    models/         DriverIdentity, TelemetrySample, JobRequest
    repositories/   identity, telemetry, rides
```

## Run locally

```bash
# Terminal 1 — integration backend
npm run dev   # or node backend/src/server.js

# Terminal 2 — optional Kairo Python API
python -m kairo.api.routes   # :8091

# Terminal 3 — Flutter
cd kairo/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=KAIRO_API_BASE=http://10.0.2.2:8080/api/kairo
```

## DePIN telemetry test

```bash
curl -X POST http://localhost:8080/api/kairo/telemetry/ingest \
  -H 'Content-Type: application/json' \
  -d '{"driver_id":"driver-demo-1","signedBatch":"0xabc","samples":[{"latitude":39.74,"longitude":-104.99,"speed_kmh":40}]}'
```

## TestFlight / Play Store checklist (7–10 day target)

1. `flutter build ipa` / `flutter build appbundle`
2. Mapbox token via `--dart-define=MAPBOX_TOKEN=...` (Vault: `runtime/kairo`)
3. Firebase `google-services.json` / `GoogleService-Info.plist`
4. App Store privacy nutrition labels (location, telemetry)
5. Colorado insurance / TNC compliance review

## Answers to tuning questions (defaults)

| Question | Default |
|----------|---------|
| App name | **Kairo** |
| Priority | **Driver app first** (onboarding → availability → earnings) |
| Framework | **Flutter** (`kairo/mobile/`) — React web stays at `kairo/frontend/` |
| Colorado hooks | `ColoradoBounds` guard in `location_service.dart`; power permitting = future Wave 2 |

## Bounty track

- **0.5 SOL** — Postgres persistence + live Stripe webhook (Linear task)
- **Immunefi** — identity key rotation + telemetry ZK proofs (`docs/BUG_BOUNTY_V1.md`)

## Merge

```bash
git checkout development
git merge cursor/kairo-flutter-foundation-9c82
cd kairo/mobile && flutter analyze && flutter test
```
