# PilotEnRoute — Architecture & Design

Companion to `AGENTS.md`. This is the human-readable architecture reference.

## 1. Overview
PilotEnRoute is a cross-platform (iOS / Android / Web) Flutter application delivering an aviation
training and utility suite: FAA education, exams/flashcards, a Flame-powered 2D flight simulator,
digital logbook, flight planner, live weather and flight tracking, drone (Part 107) education,
E6B/weight-and-balance/fuel calculators, pilot notifications, and monetization (AdMob + in-app
purchases). It relies primarily on free public aviation APIs and on-device storage, with an optional
AmericanGroupLLC backend for authentication and a hosted AI assistant.

- **Framework:** Flutter 3.44.x, Dart 3 (`sdk: '>=3.0.0 <4.0.0'`)
- **State management:** `provider` (`ChangeNotifier`)
- **Package name:** `pilot_enroute`, version `1.0.0+1`

## 2. Layers
The codebase is a pragmatic 3-layer structure (no strict DDD/clean-architecture boundaries):

1. **Presentation** — `lib/screens/*` (one screen per route) and `lib/widgets/*` (shared UI).
   Screens are `StatefulWidget`/`StatelessWidget` that read services through `Provider`.
2. **Domain / services** — `lib/services/*`. Business logic, API clients, persistence, and
   monetization. Stateful services extend `ChangeNotifier` and are provided app-wide.
3. **Config / data** — `lib/config/backend_config.dart` for backend endpoints and client-public
   keys; `assets/data/*.json` for bundled content.

Wiring happens in `lib/main.dart`: it initializes platform subsystems, constructs the
`MultiProvider`, defines the `MaterialApp` theme, and maps ~45 named routes to screens.

## 3. Modules (feature screens)
Grouped roughly as the drawer presents them:

- **Training:** simulation (Flame), education hub, checklists, emergency trainer, drone, quiz,
  flashcards, FAA exam, endorsements, regulations, career, ICARA (international students).
- **Live data:** weather, airport lookup, aviation news, flight tracker, NOTAMs, alerts, charts.
- **Tools:** flight plan, map, E6B, weight & balance, fuel, wind, radio, nav DB, documents.
- **Account / platform:** profile, account, notifications, integrations (Garmin/ForeFlight),
  AI assistant, debrief, premium, store.

Each screen has a matching route in `main.dart` and typically a corresponding service.

## 4. Data & persistence
Three local stores are used deliberately:

- **shared_preferences** — the dominant store (~22 files): flags, JWTs (see security note), flashcard
  progress, premium state, chat history, cloud-sync snapshot.
- **sqflite** — relational data: `logbook_service` (FAA logbook entries) and `navdb_service`.
- **Hive** — initialized in `main.dart`; used by `navdb_service` and `cloud_sync_service`.

Remote data comes from free public APIs (Aviation Weather Center, OpenSky, RotatePilot, RSS feeds)
and the optional AmericanGroupLLC backend (auth, AI chat). `cloud_sync_service` ships a same-device
stub behind a swappable `BackendClient` seam — it is not real multi-device sync.

**Security note:** `auth_service` currently stores JWTs in shared_preferences with a TODO to move to
secure storage (Keychain/Keystore). `backend_config.dart` holds only client-public values
(API gateway URL, Supabase anon/publishable key, OAuth client IDs, Firebase project id) — never
server/service-role secrets.

## 5. Navigation & flow
- **Routing:** `MaterialApp.routes` (Navigator 1.0 named routes). `initialRoute` is `/` (`HomeScreen`).
  Navigation uses `Navigator.pushNamed(context, '/route')`, mostly from `AppDrawer` and home cards.
  Note: `go_router` is a declared dependency but is **not** used.
- **Launch sequence** (`main()`): `WidgetsFlutterBinding.ensureInitialized()` → `Hive.initFlutter()`
  → `tz.initializeTimeZones()` → `NotificationService.initialize()` → `AdService().initialize()`
  → `AuthService.instance.init()` (restore session) → lock orientations → set system UI overlay
  → `runApp(PilotEnRouteApp())`.
- **Home:** `HomeScreen` uses a sliver app bar, a bottom navigation index, and the `AppDrawer`; a
  post-frame callback fetches the daily quote, quiz-of-day, and news.

## 6. Models
Models are lightweight Dart classes co-located with their service (no shared `models/` folder),
each with `toJson`/`fromJson` for persistence. Examples: `LogbookEntry` (logbook_service),
`MetarData` (weather_service), `Flashcard` (flashcard_service), `ChatMessage`/`ChatRole` and
`UserRole` (ai_service/auth_service), `PremiumTier`/`PremiumFeature` (premium_service),
`PilotLevel`/`NotificationCategory` (notification_service).

## 7. Theme
Defined in `_buildTheme()` in `main.dart`: Material 3, dark brightness.
- Scaffold background `#0A1628`; primary `#00BCD4` (cyan), secondary `#FFB300` (amber),
  surface `#112240`, error `#F44336`.
- Typography via `google_fonts`: **Orbitron** for display/headline/app-bar/tab labels,
  **Inter** for body/titles/buttons.
- Rounded inputs/cards (12–16px radius), transparent status bar, dark system nav bar.

Brand assets live in `assets/logo/`: `pilot_enroute_icon.svg` (square opaque gradient + ascending
jet/compass glyph) and `pilot_enroute_logo.svg` (icon + "PilotEnRoute" wordmark + tagline). App
icons are generated from `assets/logo/master_1024.png` (opaque, 1024²).

## 8. Services & configuration
See the "Key services" table in `AGENTS.md` for the full list. Configuration surfaces:
- `lib/config/backend_config.dart` — backend base URL, auth endpoints, Supabase/Firebase/OAuth IDs.
- `lib/services/premium_service.dart` — IAP product IDs and premium feature gates.
- `lib/services/ad_service.dart` — AdMob unit IDs (placeholder/test until release).
- `lib/services/ai_service.dart` — Anthropic model + `ANTHROPIC_API_KEY` via `--dart-define`; falls
  back to an honest offline reference mode when no key is present.

## 9. Platform
- **Android** (`android/`): `applicationId` / namespace `com.americangroupllc.pilot_enroute`;
  Kotlin `MainActivity` under `com/americangroupllc/pilot_enroute`; adaptive launcher icons in
  `res/mipmap-*`; permissions for internet, notifications/exact-alarms, location, legacy storage.
  Release build currently signs with the debug keystore (TODO).
- **iOS** (`ios/`): `PRODUCT_BUNDLE_IDENTIFIER` `com.americangroup.pilotenroute` (no underscore —
  matches IAP product IDs and appleClientId); `CFBundleDisplayName` "PilotEnRoute"; custom URL scheme
  `pilotenroute` for OAuth redirect; `AppIcon.appiconset` with a full opaque icon set.
- **Web** (`web/`): PWA build. Separately, `web_marketing/` is a standalone static marketing site.

Platform bundle IDs intentionally differ in spelling and should not be "unified" — the iOS form is
tied to store IAP product IDs and OAuth configuration.

## 10. Testing
`test/` contains widget tests (`widget_test.dart`, `screens/*`, `widgets/*`) and service unit tests
(`services/*` — weather, flashcard, logbook, premium, flight_plan). Run with `flutter test`.
CI (`.github/workflows/`) runs analyze/test and builds. **Always run `flutter pub get` before
analyze/test**: a stale `package_config.json` produces thousands of false "uri_does_not_exist"
errors. A clean analyze reports 0 errors / 0 warnings and ~33 informational lints.

---

## Authentication & Backend (Supabase) — current

The app authenticates against the org's **Supabase** backend.

- **Config**: `lib/services/supabase_config.dart` (`SupabaseConfig`) holds the
  `url`, `anonKey` (publishable), and the shared `qaEmail`/`qaPassword` +
  `devEmail`/`devPassword` test accounts. The publishable key is client-safe.
- **Init**: `main()` calls `await Supabase.initialize(url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey)` inside a `try/catch` **before** `runApp`, so
  a misconfigured/offline start can never block launch.
- **Email/password**: `AuthService.loginEmail()` uses
  `Supabase.instance.client.auth.signInWithPassword(...)`. Supabase persists and
  auto-restores its own session; `AuthService.init()` adopts a live Supabase
  session on startup (it takes precedence over any local/legacy session).
- **One-tap test account**: the login screen's "Use test account" button calls
  `signInWithTestAccount()` → `loginEmail(SupabaseConfig.qaEmail,
  SupabaseConfig.qaPassword)`.
- **Offline fallback (dev/CI)**: on a **network/socket error** (couldn't reach
  Supabase) *and* only when the entered credentials match a `SupabaseConfig`
  QA/Dev test account, `AuthService` falls back to a **persisted local demo
  session** (`shared_preferences`). A genuine Supabase `AuthException` (bad
  credentials, etc.) is returned to the UI and **never** falls back. A networked
  device always uses the real Supabase backend.
- **Sign-out**: `AuthService.signOut()` clears **both** sessions — it calls
  `Supabase...auth.signOut()` and wipes the persisted local demo session (and any
  legacy backend token).
- **Social / phone**: Google/Apple/Facebook (OAuth start URL + WebView) and
  Firebase Phone OTP still go through the AmericanGroupLLC API gateway
  (`lib/config/backend_config.dart`); these paths are unchanged.
