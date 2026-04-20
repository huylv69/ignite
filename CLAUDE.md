# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the app (requires connected device/emulator)
flutter build apk        # Build Android APK
flutter build ios        # Build iOS (requires macOS)
flutter analyze          # Static analysis
dart format lib/         # Format code
flutter test             # Run all tests
flutter test test/path/to/file_test.dart  # Run a single test
```

## Architecture

Flutter app for managing Codemagic CI/CD pipelines. Uses **Riverpod** for state management, **GoRouter** for routing, and talks directly to the Codemagic REST API (`https://api.codemagic.io`).

```
lib/
├── main.dart                         # Entry point, GoRouter setup, auth redirect guards
└── core/
    ├── models/app_model.dart         # CmApplication, CmBuild, CmWorkflow, CmArtifact, BuildStats
    ├── services/codemagic_api.dart   # HTTP client; throws CodemagicApiException on errors
    ├── providers/
    │   ├── auth_provider.dart        # Token stored in SharedPreferences; drives nav guards
    │   └── codemagic_provider.dart   # FutureProviders wrapping API calls
    ├── theme/app_theme.dart          # Dark Material 3 theme with purple/teal accents
    └── presentation/pages/           # LoginPage, AppsPage, AppDetailPage
```

### Key patterns

- **Auth flow**: User enters API token → saved to SharedPreferences → injected into every API request. GoRouter `redirect` reads auth state to guard all routes.
- **Data fetching**: Pages use `ref.watch(someProvider)` on `FutureProvider`s that call the API service. No local cache — every navigation triggers a fresh fetch.
- **Error handling**: `CodemagicApiException` propagates from the service layer; UI catches with try/catch and shows SnackBars.
- **Providers**: `codemagicApiProvider` is a lazy-loaded `Provider` that reads the stored token. All data providers (`appsProvider`, `buildsProvider`, etc.) depend on it.
