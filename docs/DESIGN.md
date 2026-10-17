# PilotEnRoute — design

## Product
One job, end to end: log each flight with what 14 CFR part 61 counts; before
the next flight, see on one card whether you are legal for it and whether the
live weather at your airport is inside your own personal minimums — each item
with its number, its limit and the date it lapses. Ground tool only; nothing
here is for use in flight. No account: logbook, profile, minimums and check
history live on the device.

Since 2026-10-17 (founder's Clear Skies design, `pilotenroute-design/`) it is
also a private-pilot study app: five tabs, **Home · Learn · Practice · Plan ·
Logbook**. Home is first; the Go Card (`/go`) opens from Home and Plan.

## Learn and Practice content
Content is data with provenance, not prose in widgets: `content/*.json`
records each FAA document (number, edition, URL, sha256 of the file read) and
every line's page/paragraph; `tools/gen_content.py` compiles it to
`lib/content/*.g.dart` (offline, testable). `test/content/sourced_content_test.dart`
fails if the Dart is stale, a line has no cite, or anything says "safe".

- Six-pack trainer: PHAK FAA-H-8083-25C ch. 8; generic dials
  (`lib/ui/instruments.dart`), the POH/AFM gives real speeds.
- Airport operations: AIM 2-3 and 4-3 (Change 3, 7/9/2026). The 45° entry is
  shown only in an AIM figure we did not check, so it is not drawn.
- FAA library: 13 documents checked HTTP 200 on 2026-10-17; opened in the
  browser/PDF reader, not stored.
- Knowledge test: the FAA's PAR sample questions (8/10/2021), word for word.
  The FAA publishes no answer key, so an answer ships only if a verbatim FAA
  quote decides it and an independent re-check agrees. Questions that need a
  testing-supplement figure are left out (16 + 2 with inline images).
  `PracticeStore` keeps the pilot's answers; readiness is the correct rate
  over the last 40 (shown from 10), with the 70% pass mark and an 85–90%
  practice aim stated, and no claim that it predicts the test.

## Layers
| Layer | Contents | Rule |
|---|---|---|
| `lib/core/` | legality engine, AWC decoding, minimums/Go verdict, logbook query/CSV/validation, reminder plan | Pure Dart, no Flutter import, dates injected — all unit-tested |
| `lib/data/` | SQLite schema and migrations, in-memory store | `sqflite` only |
| `lib/services/` | `ChangeNotifier`s the UI watches; the AWC HTTP client; notification plugin seams | Thin |
| `lib/screens/`, `lib/ui/` | Widgets, theme | No business rules |

## Legality engine (`lib/core/legality/legality_engine.dart`)
Inputs: entries, `PilotProfile`, `PlannedFlight` (date, category/class,
tailwheel, passengers, night, IFR). Output: one `RuleStatus` per rule with
state, `validThrough` / `lapsedOn`, summary, shortfall, notes and cite.

| Rule | Computation |
|---|---|
| 61.57(a) | 3 T/O + 3 landings (day + night) on or after F−90 days, same category/class; tailwheel flight counts full stops in tailwheel only |
| 61.57(b) | 3 night T/O + 3 night full-stop landings, same window and class |
| 61.57(c)/(d) | each task in month T good through end of T+6; current-month tasks count; grace to end of 6 calendar months after the lapse month, then IPC; IPC entry resets; tasks after the grace window do not restore currency |
| 61.56 | latest of profile date, entries flagged flight review or practical test; through end of the 24th calendar month; 61.56(g) student exemption |
| 61.23(d) | the full table for first/second/third class × privileges × under-40/40+ (age unknown → shorter duration, stated) |
| 61.23(c)(3) | BasicMed: CMEC 48 and course 24 calendar months; third-class privileges only |
| 61.87(n), 61.89(a)(1) | student solo endorsement 90 days; no passengers |

Not checked (stated on the card): type ratings, other endorsements, simulator
credit rules, 61.57(e), BasicMed operating limits.

## Student progress (`lib/core/legality/private_pilot_progress.dart`)
61.109(a) (private pilot, airplane single-engine), regulation text quoted from
eCFR in the file. 40 h of flight time from every entry; the 20 h of
instruction, 10 h of solo and every sub-item count ASEL and ASES only (the
61.107(b)(1) areas of operation). XC, night and instrument time is credited
as training up to the dual time of a dual-only entry, and as solo up to the
solo time of a solo-only entry; an entry logging both is not split and is
counted on screen. (4) is dual since the 1st of the second calendar month
before this one. (2)(i), (5)(ii), (5)(iii) need distances or tower status the
logbook does not store: shown "not tracked", never met. Shown to students only,
from the Logbook Totals tab.

## Night window (`lib/core/minimums/solar.dart`)
NOAA General Solar Position equations on the device (zenith 90.833°), within
2 min of US Naval Observatory times at the mid-latitude airports tested. The
series drifts at high latitude, so above 66° no window is shown. With *Night*
on, the Go Card's Legal section shows the 61.57(b) window (1 h after sunset to
1 h before the next sunrise) at the checked airport's AWC lat/lon, in Zulu and
device time; an early-morning departure gets the previous evening's window.
Under 2 h of darkness, or no sunset/sunrise, it says so instead of showing
times.

## Minimums (`lib/core/minimums/`)
Ceiling = lowest BKN/OVC/OVX base (none reported ≠ 0). Visibility handles
`"10+"`/`"6+"`/fractions. Crosswind: every runway end from AWC true
`alignment`, smallest steady crosswind wins (ties → more headwind); gust
component compared with the limit; VRB = full crosswind; calm = 0. TAF: every
group overlapping departure ±1 h. Stale: METAR older than 90 min. Near =
within 80 % of a limit. Wording never says "safe"; every result carries "Your
decision, not the app's. Check an official briefing (1800wxbrief.com) before
flight."

## Persistence
- `pilot_logbook.db` schema v2: `logbook_entries` (v1 columns + category_class,
  tailwheel, route, solo_time, day_full_stop_landings, holding, tracking,
  flight_review, ipc, practical_test, night_flight) and `go_checks`.
  v1 rows are kept with honest defaults (no category/class).
- "Paste CSV" (`logbookFromCsv`) reads back the app's own "Copy as CSV" text:
  every export column must be present (any order), rows are validated like the
  entry form (category/class may be empty for v1 rows), a row with the wrong
  field count is refused, and a row identical to a flight already logged is
  skipped once per existing copy. Hours are exported in tenths, finer values
  exactly, so the round trip is lossless. Other logbooks' layouts are refused, not
  guessed.
- SharedPreferences: profile, minimums, home airport, reminder switches,
  onboarding flag, documents metadata, scheduled reminder ids.

## Reminders
`lapseItemsFrom` evaluates a generic flight today (home class, passengers at
night, IFR if rated) and takes each valid rule's `validThrough`; documents add
their expiry. Reminders at 09:00 local 30 and 7 days before; stable ids
(`reminderId`); `ReminderService` reschedules on any logbook/profile/document
change and cancels the previous ids first.

## Identity — "Clear Skies"
- Light: sky canvas `#F2F7FB`, white cards `#FFFFFF`, navy ink `#0E2235`,
  muted `#5D7083`, deep-teal primary `#0A7887` (white text 5.2:1), icon
  tiles `#E8F1F8` / `#1D4E78`. Status: go `#1C7F46`, caution `#9A5E00`,
  stop `#C0343A`, each with a soft tint (`goSoft`, `cautionSoft`,
  `stopSoft`). Every text colour is ≥ 4.5:1 on cards and canvas (tested).
  Dark: canvas `#0B1621`, cards `#132331`, ink `#E6EEF5`, teal `#4CC3D0`.
  Hand-built `ColorScheme` (`skyLightScheme` / `skyDarkScheme`), tokens in
  `Sky` (`lib/ui/theme.dart`).
- Shape: 16 px cards (`Sky.radius`), 12 px inputs and tiles (`radiusM`),
  22 px hero panels and sheets (`radiusL`), pill chips, pill nav indicator,
  14 px buttons (52 px tall primary). Cards carry a hairline border and a
  soft two-layer shadow (`Sky.shadow`).
- Building blocks (`lib/ui/widgets.dart`): `SkyCard` (`PlacardCard` is
  kept as an alias), `PageTitle` (large title + caption in the app bar),
  `SectionHeader` (sentence case), `IconTile`, `NavRowCard` (tile + title +
  caption + chevron), `StatTile`, `ProgressStrip`, `SegmentedTabBar` (a
  TabBar on a rounded track — the theme's tab indicator is a teal pill),
  `NoticeLine`, `MonoBlock`.
- Hero illustration: `SkyScene` (`lib/ui/sky_scene.dart`) — a flat,
  layered CustomPainter scene of a high-wing trainer over hills and a lake.
  No photos, no network, no gradients. Mood follows the planned flight:
  `night` when Night is on, `overcast` when the result is outside minimums.
- Status pills (`StatusTag`): soft tinted capsule, icon + word in the tone
  colour; neutral states are outlined. Every status = word + icon + colour.
- Kit tools render on the light theme (`PanelTheme` forces light so their
  fixed tints stay legible in dark mode).
- Fonts bundled: Sofia Sans (titles 800, headings 700, body), Sofia Sans
  Condensed (instrument read-outs in the Kit tools), Fira Mono (METAR/TAF,
  times, hours, ICAO). All SIL OFL 1.1.
- Flight-category colours keep their meaning: VFR green, MVFR blue, IFR
  red, LIFR magenta.
- Icon/mark: `assets/logo/pilot_enroute_icon.svg` and
  `pilot_enroute_mark.svg`, rendered with
  `rsvg-convert -w 1024 -h 1024 <svg> -o <png>`, then resized with PIL to
  every iOS AppIcon size and Android mipmap.

## Ads
AdMob banner only, behind UMP consent: one in-list slot in Logbook (after the
5th row) and one in Weather. Never on Home, the Go Card, the Go result or the
entry form.

## Testing
`test/core` (engine, decoding, minimums, logbook depth, 61.109(a) progress,
solar vs USNO, CSV import), `test/data` (real
SQLite migration), `test/services`, `test/screens` (Go Card with recorded AWC
fixtures and a fake HTTP client, entry form, logbook, onboarding, settings),
`test/foldable_layout_test.dart` (every screen at fold geometries and 1.6×
text), `test/ui/theme_test.dart`, `test/services/honest_entry_points_test.dart`
(scope/grep checks), `test/content` (sourced content), `test/screens/clear_skies_screens_test.dart`
and `practice_quiz_test.dart` (Home, Plan, Learn, Practice).
