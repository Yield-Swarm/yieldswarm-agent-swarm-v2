# Kairo Mobile (Flutter)

Driver-first Colorado DePIN yield app — clean architecture, Riverpod 2, GoRouter.

## Structure

```
lib/
  core/          auth, config, network, router, identity, location, payments
  features/      driver, customer, depin
  data/          models, repositories, datasources
  shared/        providers, widgets, theme
```

## Quick start

```bash
cd kairo/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=KAIRO_API_BASE=http://10.0.2.2:8080/api/kairo
```

Backend must be running (`npm run dev` or integration backend on `:8080`).
Kairo Python API optional on `:8091` (proxied via `/api/kairo`).

## Flavors

```bash
flutter run --dart-define=FLAVOR=dev --dart-define=KAIRO_API_BASE=http://localhost:8080/api/kairo
```

## TestFlight / Play Store

See `docs/KAIRO_FLUTTER_FOUNDATION.md` for release checklist.
