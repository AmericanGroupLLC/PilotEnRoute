# AGENTS.md — PilotEnRoute

AI-oriented map of this repo. Keep dense and accurate. Deeper detail: `docs/DESIGN.md`.
Product spec: `agl-manifest/ai-office/projects/real-apps/specs/PilotEnRoute.md`.

## What
A pilot's logbook and private-pilot study app that answers one question before
each flight: **am I legal for this flight, and is the live weather inside my own
minimums?** Flutter (iOS, Android). No account; everything is stored on the
device. Five tabs (Clear Skies design, `pilotenroute-design/`): **Home · Learn ·
Practice · Plan · Logbook**.

- **Home**: legal-today line for the home class (same engine as the Go Card),
  61.109(a) progress for students, practice readiness, last logged flight. No ad.
- **Learn**: FAA library (`content/faa_library.json`), six-pack trainer (PHAK
  ch. 8), airport operations (AIM 2-3, 4-3). Every line carries its cite.
- **Practice**: FAA PAR sample questions, word for word. The FAA publishes no
  answer key; each answer is proved by a quoted FAA source and re-checked
  independently (`content/par_answers.json`, `par_verification.json`).
  Answers are saved in `PracticeStore`; readiness = last 40 answers.
- **Plan**: Go Card, Weather, Charts & plates, Check history tiles + the flight
  bag (Kit tools).
- **Go Card** (`/go`, from Home or Plan): departure / destination / time, passengers · night · IFR.
  *Legal* comes from the legality engine over the pilot's own logbook and
  profile; *Minimums* compares live aviationweather.gov METAR/TAF (with
  best-runway crosswind) to the pilot's day/night limits. Every check is saved.
- **Logbook**: full entry form, search, filters, month groups, 30/90/365/all
  totals, PDF / Share PDF / Copy as CSV / Paste CSV (own format only).
  Students get **Private pilot progress** (61.109(a)) from the Totals tab.
- **Weather**: METAR/TAF, PIREPs, SIGMETs, G-AIRMETs, winds aloft (AWC only).
- **Flight bag** (on Plan): E6B, weight & balance, fuel, flight planner,
  checklists (representative only), documents, airport. Each tool has an (i)
  "About" sheet (`PlanScreen.explanations`).
- **Night window**: with Night on, the Go Card shows the 61.57(b) window from
  on-device sunrise/sunset (`lib/core/minimums/solar.dart`).
- **Settings** (gear on Home and the Go Card): home airport, pilot profile, minimums,
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
`main.dart` loads `SettingsStore` and `PracticeStore` from SharedPreferences, then
`PilotEnRouteApp` provides `SettingsStore`, `LogbookService`, `WeatherService`,
`PracticeStore`, `ReminderService`, `AglLocaleController`, `FlightPlanService`,
`AdService`. `RootGate` shows `OnboardingScreen` until it is finished once, then
`AppShell` (5 tabs, Home first). The Go Card (`/go`) and Weather (`/weather`)
are pushed routes. Kit tools are named routes (`onGenerateRoute`) wrapped in `PanelTheme` (forces the light theme).

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
| `lib/screens/` | home, learn (library, six_pack, airport_ops), practice + quiz, plan (Kit tools), today (Go Card), logbook, logbook_entry, weather, airport, settings, profile, minimums, reminders, go_history, onboarding + kit tools |
| `content/*.json` → `lib/content/*.g.dart` | Sourced Learn/Practice content (FAA doc, edition, URL, sha256). `python3 tools/gen_content.py` regenerates; a test fails if stale |
| `lib/services/practice_store.dart` | The pilot's practice answers, readiness, topic scores, missed questions |
| `lib/ui/instruments.dart` | Flat painters for the six instruments |
| `lib/ui/` | `theme.dart` ("Clear Skies" `Sky` tokens, fonts, `buildSkyTheme`, `PanelTheme`), `status_tag.dart` (status pills), `widgets.dart` (`SkyCard`, `PageTitle`, `NavRowCard`, `IconTile`, `StatTile`, `ProgressStrip`, `SegmentedTabBar`…), `sky_scene.dart` (hero illustration) |
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
| Kit "About" text | `PlanScreen.explanations` |
| A Kit route | `PlanScreen.tools` + `onGenerateRoute`/`RootGate.routes` in `main.dart` |
| Learn / Practice text | `content/*.json` (with its source), then `tools/gen_content.py`; never hand-edit `*.g.dart` |
| A knowledge question | only from an FAA publication, answer proved by a verbatim FAA quote and re-checked; `test/content/sourced_content_test.dart` |
| AdMob units | `--dart-define=ADMOB_<FORMAT>_<PLATFORM>` (`ad_service.dart`) |

## Gotchas
- Wind direction and runway `alignment` are both TRUE; never mix in the
  magnetic runway number.
- AWC vertical visibility: METAR `vertVis` is hundreds of feet, TAF `vertVis`
  is feet.
- Old v1 logbook rows have no category/class; they do not count toward
  currency until edited, and the Go Card says so.
- No ad on Home, the Go Card, the Go result or the entry form (test: `app_boot_test`).
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
