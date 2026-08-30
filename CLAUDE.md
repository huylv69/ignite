# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the app (requires connected device/emulator)
flutter build apk        # Build Android APK
flutter build ios        # Build iOS (requires macOS)
flutter build web        # Build the web target
flutter analyze          # Static analysis — must report "No issues found!"
dart format lib/         # Format code
flutter test             # Run all tests
flutter test test/path/to/file_test.dart  # Run a single test
```

## Architecture

Flutter app for managing Codemagic CI/CD pipelines. Uses **Riverpod** for state
management, **GoRouter** for routing, and talks directly to the Codemagic REST
API (`https://api.codemagic.io`).

```
lib/
├── main.dart                              # Entry point, GoRouter setup, auth + lock guards
├── core/
│   ├── models/
│   │   ├── account_model.dart             # AccountModel (multi-account persistence)
│   │   └── app_model.dart                 # CmApplication, CmBuild, CmBuildAction, CmWorkflow,
│   │                                      #   CmArtifact, CmCache, CmVariable, BuildStats
│   ├── services/
│   │   ├── codemagic_api.dart             # HTTP client; throws CodemagicApiException
│   │   └── workflow_cache.dart            # Remembers workflow ids for private file-based apps
│   ├── providers/
│   │   ├── auth_provider.dart             # Legacy single-token store (kept for migration)
│   │   ├── accounts_provider.dart         # Multi-account state; activeTokenProvider
│   │   ├── biometric_provider.dart        # Device unlock gate (skipped on web)
│   │   ├── app_info_provider.dart         # Package version, author links
│   │   └── codemagic_provider.dart        # FutureProviders wrapping the API + app search
│   └── theme/app_theme.dart               # Dark Material 3 theme, orange accent
└── presentation/
    ├── pages/
    │   ├── login_page.dart                # Token entry; also the add-account flow
    │   ├── lock_page.dart                 # Biometric unlock
    │   ├── apps_page.dart                 # App list, search, last-build status, account switcher
    │   ├── app_detail_page.dart           # Builds + Stats tabs, trigger menu, caches/vars menu
    │   ├── yaml_trigger_page.dart         # Workflow/branch-or-tag/instance-type trigger
    │   ├── step_log_page.dart             # Raw log for one build step
    │   ├── caches_page.dart               # Cache list and deletion
    │   └── variables_page.dart            # Environment variable CRUD
    └── widgets/
        ├── build_detail_sheet.dart        # Build info, steps, artifacts
        ├── account_sheet.dart             # Switch / rename / remove / add account
        └── skeletons.dart                 # Shimmer placeholders
```

### Key patterns

- **Auth flow**: User enters API token → saved to SharedPreferences via `AccountsNotifier` → injected into every API request. GoRouter `redirect` reads auth + biometric state to guard all routes.
- **Data fetching**: Pages use `ref.watch(someProvider)` on `FutureProvider`s that call the API service. No local cache — every navigation triggers a fresh fetch.
- **Error handling**: `CodemagicApiException` propagates from the service layer; UI catches with try/catch and shows SnackBars.
- **Providers**: `codemagicApiProvider` is a lazy-loaded `Provider` that reads the active account's token. All data providers depend on it.

## Codemagic API facts not in their docs

Verified by hand against the live API. Getting these wrong is silent:

- **Cancelling is `POST /builds/:id/cancel`.** `DELETE /builds/:id` answers
  **405 METHOD_NOT_ALLOWED**. A `208` means the build had already finished and
  should be treated as success.
- **`GET /builds` ignores `page`.** Pagination is `skip`. `appId`, `limit`,
  `status`, `branch` and `workflowId` all work.
- **`GET /apps/:id/variables` returns a bare JSON array**, not an object — it
  needs a different decoder from every other endpoint.
- **`GET /builds/:id/step/:stepId` returns `text/plain`**, not JSON. It is the
  only way to read build logs; there is no whole-build log endpoint.
- Builds age out of `GET /builds` but stay readable via `GET /builds/:id`. An
  empty Builds tab does not mean the app never built.
- Artefacts use the British spelling `artefacts`, and their `path` field is the
  `secureFilename` the public-url endpoint is addressed by.
- `fileWorkflowIds` comes back empty even for `settingsSource: "file"` apps,
  which is why YAML workflows are still read from the repository directly.
