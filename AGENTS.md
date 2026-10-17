# AGENTS.md — PilotEnRoute

AI-oriented map of this repo. Keep dense and accurate. Deeper detail: `docs/DESIGN.md`.
Product spec: `agl-manifest/ai-office/projects/real-apps/specs/PilotEnRoute.md`.

## What
A pilot's logbook that answers one question before each flight: **am I legal for
this flight, and is the live weather inside my own minimums?** Flutter (iOS,
Android). No account; everything is stored on the device.

- **Today (Go Card)**: departure / destination / time, passengers · night · IFR.
  *Legal* comes from the legality engine over the pilot's own logbook and
  profile; *Minimums* compares live aviationweather.gov METAR/TAF (with
  best-runway crosswind) to the pilot's day/night limits. Every check is saved.
- **Logbook**: full entry form, search, filters, month groups, 30/90/365/all
  totals, PDF / Share PDF / Copy as CSV / Paste CSV (own format only).
  Students get **Private pilot progress** (61.109(a)) from the Totals tab.
- **Weather**: METAR/TAF, PIREPs, SIGMETs, G-AIRMETs, winds aloft (AWC only).
- **Kit**: E6B, weight & balance, fuel, flight planner, checklists
  (representative only), documents, airport, FAA charts link. Each tool has
  an (i) "About" sheet (`KitScreen.explanations`).
- **Night window**: with Night on, the Go Card shows the 61.57(b) window from
  on-device sunrise/sunset (`lib/core/minimums/solar.dart`).
- **Settings** (gear on Today): home airport, pilot profile, minimums,
  reminders, Privacy choices (UMP), language, About.

## Run
```bash
flutter pub get                 # REQUIRED first
flutter analyze                 # must be "No issues found!"
flutter test                    # host tests incl. real SQLite via sqflite_common_ffi
flutter build ios --simulator --debug
```
SDK: `/Users/spatchava/agl/.flutter-sdk/bin/flutter` (3.44.x).

## Architecture
`main.dart` loads `SettingsStore` from SharedPreferences, then `PilotEnRouteApp`
provides `SettingsStore`, `LogbookService`, `WeatherService`, `ReminderService`,
`AglLocaleController`, `FlightPlanService`, `AdService`. `RootGate` shows
`OnboardingScreen` until it is finished once, then `AppShell` (4 tabs).
Kit tools are named routes (`onGenerateRoute`) wrapped in `PanelTheme` (dark).

| Path | Role |
|---|---|
| `lib/core/legality/` | Pure-Dart legality engine (61.57(a)/(b)/(c)/(d), 61.56, 61.23(d), BasicMed, 61.87(n), 61.89), calendar-month maths, profile model |
| `lib/core/weather/awc_models.dart` | AWC METAR/TAF/airport decoding (true wind, `"10+"`, clouds, runway alignment) |
| `lib/core/minimums/` | Personal minimums, best-runway crosswind, per-line check, Go verdict + wording, saved check record |
| `lib/core/logbook/` | `LogbookEntry`, search/filter/group/totals, RFC-4180 CSV, form validation |
| `lib/core/legality/private_pilot_progress.dart` | 61.109(a) student progress (pure Dart, eCFR text quoted) |
| `lib/core/minimums/solar.dart` | NOAA sunrise/sunset, 61.57(b) night window |
| `lib/core/reminders/` | Which lapse reminders exist (30 and 7 days before each date) |
| `lib/data/logbook_store.dart` | SQLite schema v2 + v1→v2 migration, memory store for web/tests |
| `lib/services/` | `logbook_service`, `weather_service` (AWC client), `settings_store`, `reminder_service`, `notification_service`, `ad_service`, kit services |
| `lib/screens/` | today, logbook, logbook_entry, weather, kit, airport, settings, profile, minimums, reminders, go_history, onboarding + kit tools |
| `lib/ui/` | `theme.dart` (palette, fonts, `PanelTheme`), `status_tag.dart` (punched-tag chips), `widgets.dart` |
| `assets/fonts/` | Sofia Sans Condensed, Sofia Sans, Fira Mono + OFL licences |
| `assets/logo/` | Tag icon/mark SVG sources and rendered PNGs |
| `test/fixtures/awc/` | Recorded real AWC answers with UTC capture time |

## Data sources
aviationweather.gov data API only (metar, taf, airport, pirep, isigmet, airmet,
windtemp) — keyless; a 5xx is retried once. No Supabase, no account, no other API.

## Where to change X
| Task | Location |
|---|---|
| A currency rule | `lib/core/legality/legality_engine.dart` + `test/core/legality_engine_test.dart` |
| Go Card wording | `lib/core/minimums/go_check.dart`, `minimums_check.dart` |
| Logbook columns | `LogbookEntry` + `v2Columns`/a new migration in `logbook_store.dart` (bump `logbookSchemaVersion`) |
| Theme | `lib/ui/theme.dart` |
| 61.109(a) progress rules | `private_pilot_progress.dart` + `test/core/private_pilot_progress_test.dart` |
| CSV import | `logbookFromCsv` in `logbook_csv.dart` + `test/core/logbook_csv_import_test.dart` |
| Kit "About" text | `KitScreen.explanations` |
| A Kit route | `KitScreen.tools` + `onGenerateRoute`/`RootGate.routes` in `main.dart` |
| AdMob units | `--dart-define=ADMOB_<FORMAT>_<PLATFORM>` (`ad_service.dart`) |

## Gotchas
- Wind direction and runway `alignment` are both TRUE; never mix in the
  magnetic runway number.
- AWC vertical visibility: METAR `vertVis` is hundreds of feet, TAF `vertVis`
  is feet.
- Old v1 logbook rows have no category/class; they do not count toward
  currency until edited, and the Go Card says so.
- No ad on Today, the Go result or the entry form (test: `app_boot_test`).
- Bundle IDs: Android `com.americangroupllc.pilot_enroute`, iOS
  `com.americangroupllc.pilotenroute` — never change.
- `ios/Runner.xcodeproj/project.pbxproj` carries someone else's uncommitted
  reorder; do not commit it.

## Verify and CI
`tools/verify.sh [quick|ios|android|<steps>]` runs analyze, tests, the iOS
simulator build + launch + on-device test, and the Android build + emulator
launch + on-device test, printing one line per step (logs and screenshots in
`build/verify/`). `.github/workflows/ci.yml` runs the same script on GitHub
(needs the `AGL_PACKAGES_TOKEN` secret). `tools/ci_status.sh` prints the latest
CI result in a few lines. Delivery stays in agl-manifest `ship.yml`.
