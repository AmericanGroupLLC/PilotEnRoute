# AGENTS.md — PilotEnRoute

AI-oriented map of this repo. Keep dense and accurate. Deeper detail: `docs/DESIGN.md`.

## What
Flutter (Dart) aviation training platform "PilotEnRoute" for iOS / Android / Web from one codebase.
~40 feature screens: FAA education, AI flight sim (Flame), logbook, flight planner, live weather,
flight tracking, exams/flashcards, drone (Part 107), notifications, monetization (AdMob + IAP).
Mostly free public APIs, no first-party server required; optional AmericanGroupLLC backend for auth/AI.

## Run
```bash
flutter pub get                 # REQUIRED first; stale package_config => 12k phantom analyzer errors
flutter analyze                 # 0 errors / 0 warnings / ~33 info (lint suggestions)
flutter test
flutter run                     # device/emulator;  -d chrome for web
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...   # enables live AI assistant
```
SDK: Flutter 3.44.x / Dart 3. Flutter SDK used here: `/Users/spatchava/agl/.flutter-sdk/bin/flutter`.

## Architecture (1 line)
`main.dart` boots services, registers them as `provider` `ChangeNotifier`s in a `MultiProvider`, and a `MaterialApp` with ~45 named routes renders screens that `context.watch/read` services which call HTTP APIs + local storage.

## File map
| Path | Role |
|---|---|
| `lib/main.dart` | Entry: init (Hive, tz, notifications, AdMob, auth), MultiProvider, theme, named routes |
| `lib/config/backend_config.dart` | AmericanGroupLLC backend URLs + client-public keys/OAuth IDs |
| `lib/screens/*.dart` (41) | One screen per feature/route (~27.6k LOC total) |
| `lib/services/*.dart` (23) | Business logic + API clients + persistence; most are `ChangeNotifier` |
| `lib/widgets/*.dart` (6) | Shared UI: `app_drawer`, `module_card`, `news_ticker`, `daily_quote_card`, `ad_banner_widget`, `premium_gate` |
| `assets/data/*.json` | Bundled content: FAA questions, flashcards, career paths, endorsements, ICARA, affiliate products |
| `assets/logo/` | Brand source SVGs + rendered PNG master (icon + wordmark) |
| `assets/images/` | App icon master, splash, store screenshots/graphics |
| `test/` | Widget + service unit tests |
| `android/`, `ios/`, `web/` | Platform projects |
| `web_marketing/` | Static marketing site (separate from the Flutter web build) |
| `store_submission/` | App Store / Play Store metadata |

## Key services
| Service | Does | Backing store / API |
|---|---|---|
| `auth_service` | Email/pw, social OAuth (WebView), Firebase phone OTP; singleton `AuthService.instance` | AmericanGroupLLC backend; JWT in shared_preferences |
| `weather_service` | METAR/TAF/PIREP + live flights | Aviation Weather Center, OpenSky |
| `aviation_api_service` | ATPL questions, airports, glossary, daily quote/quiz | RotatePilot API |
| `logbook_service` | FAA logbook CRUD + PDF export | sqflite |
| `navdb_service` | Nav database | sqflite + Hive |
| `flashcard_service` | Spaced repetition | shared_preferences |
| `premium_service` | IAP tiers + feature gates | in_app_purchase + shared_preferences |
| `ad_service` | AdMob banners/interstitials | google_mobile_ads |
| `ai_service` | AI instructor chat; offline reference fallback | Anthropic API (Claude) via `--dart-define` key, or backend `/ai/chat` |
| `notification_service` | Pilot-level reminders (medical, currency, BFR…) | flutter_local_notifications + timezone |
| `cloud_sync_service` | Backup/restore stub (same-device only; swappable `BackendClient`) | shared_preferences |
| `news_service` | Aviation RSS | AOPA/AVweb feeds (xml) |

## Flow
App launch → `main()` inits Hive/tz/notifications/AdMob/auth → `MultiProvider` → `MaterialApp` initialRoute `/` → `HomeScreen` (sliver app bar + bottom nav + `AppDrawer`). `HomeScreen.initState` post-frame fetches daily quote, quiz-of-day, news. Navigation = `Navigator.pushNamed(context, '/route')` from drawer/cards. Screens read services via Provider; services fetch APIs, persist locally, `notifyListeners()`, UI rebuilds.

## State management
`provider` (`ChangeNotifierProvider`) only. No Bloc/Riverpod. Persistence: **shared_preferences** (dominant, ~22 files), **sqflite** (logbook, navdb), **Hive** (init + navdb + cloud_sync snapshots).

## Where to change X
| Task | Location |
|---|---|
| Add a screen/route | Create `lib/screens/x_screen.dart`; register import + `'/x'` route in `lib/main.dart`; add drawer entry in `lib/widgets/app_drawer.dart` |
| Add a service | `lib/services/x_service.dart`; if stateful add `ChangeNotifierProvider` in `main.dart` |
| Theme / colors | `_buildTheme()` in `lib/main.dart` (primary `#00BCD4`, secondary `#FFB300`, bg `#0A1628`, Orbitron+Inter fonts) |
| Backend URL / keys / OAuth IDs | `lib/config/backend_config.dart` |
| IAP product IDs | `lib/services/premium_service.dart` (`kMonthlyProductId` etc.) |
| AdMob ad unit IDs | `lib/services/ad_service.dart` |
| AI model/key | `lib/services/ai_service.dart` (`ANTHROPIC_API_KEY` dart-define) |
| Bundled content | `assets/data/*.json` |
| App icons | regenerate from `assets/logo/master_1024.png` → iOS `AppIcon.appiconset/*`, Android `mipmap-*/ic_launcher.png` |
| Android app id | `android/app/build.gradle.kts` + Kotlin pkg dir + `MainActivity.kt` |
| iOS bundle id | `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |

## Gotchas
- **`flutter pub get` first.** A stale `.dart_tool/package_config.json` makes `flutter analyze` report ~12k phantom "uri_does_not_exist" errors (every file). After pub get: 0 errors.
- **`go_router` is a dependency but UNUSED** — routing is `MaterialApp.routes` (Navigator 1.0 named routes). Don't assume declarative routing.
- **Bundle IDs differ per platform:** Android `com.americangroupllc.pilot_enroute`, iOS `com.americangroup.pilotenroute` (no underscore — matches IAP product IDs / appleClientId). Keep them as-is; changing iOS would break IAP/OAuth.
- `backend_config.dart` intentionally ships client-public values (anon key, OAuth client IDs, Firebase project id) — no server secrets. Don't add service-role secrets here.
- `ai_service` runs an honest "offline reference" mode when no API key is supplied; it never fakes a live AI.
- `cloud_sync_service` is a same-device stub, not real multi-device sync.
- AdMob/IAP still use placeholder/test IDs — replace before store release (see README checklist).
- Android release currently signs with the debug keystore (TODO in `build.gradle.kts`).
- Two asset dirs (`assets/icons/`, `assets/lottie/`) exist only as placeholders (`.gitkeep`) to satisfy pubspec declarations.

---

## Auth / Backend (Supabase) — authoritative

**Backend = org Supabase.** Email/password sign-in goes through Supabase Auth.

- `lib/services/supabase_config.dart` → `SupabaseConfig`: `url`, `anonKey`
  (publishable), `qaEmail`/`qaPassword`, `devEmail`/`devPassword`. Use these
  constants; do not hardcode credentials.
- `lib/main.dart` → `Supabase.initialize(url: SupabaseConfig.url, anonKey:
  SupabaseConfig.anonKey)` in a `try/catch` before `runApp`.
- `lib/services/auth_service.dart`:
  - `loginEmail()` → `Supabase.instance.client.auth.signInWithPassword(...)`.
  - `signInWithTestAccount()` → QA account from `SupabaseConfig` (one-tap "Use
    test account" button in `login_screen.dart`).
  - **Offline fallback**: network/socket error + creds match a `SupabaseConfig`
    QA/Dev account → persisted local demo session (`shared_preferences`). A
    Supabase `AuthException` never falls back. `AuthRetryableFetchException`
    (transport-retryable) is treated as a network error and may fall back.
  - `signOut()` clears **both** the Supabase session and the local demo session.
  - `init()` restores a live Supabase session (preferred), else a persisted
    local demo session, else a legacy backend-token session.
- Social login + Firebase phone OTP still use the AmericanGroupLLC gateway in
  `lib/config/backend_config.dart` (`account_screen.dart`); unchanged.

**Where to change auth:** `auth_service.dart` (logic), `login_screen.dart` (UI),
`supabase_config.dart` (endpoints/test creds).
