# PilotEnRoute — design

## Product
One job, end to end: log each flight with what 14 CFR part 61 counts; before
the next flight, see on one card whether you are legal for it and whether the
live weather at your airport is inside your own personal minimums — each item
with its number, its limit and the date it lapses. Ground tool only; nothing
here is for use in flight. No account: logbook, profile, minimums and check
history live on the device.

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
- SharedPreferences: profile, minimums, home airport, reminder switches,
  onboarding flag, documents metadata, scheduled reminder ids.

## Reminders
`lapseItemsFrom` evaluates a generic flight today (home class, passengers at
night, IFR if rated) and takes each valid rule's `validThrough`; documents add
their expiry. Reminders at 09:00 local 30 and 7 days before; stable ids
(`reminderId`); `ReminderService` reschedules on any logbook/profile/document
change and cancels the previous ids first.

## Identity — "Remove Before Flight" placard
- Light: placard white `#F7F7F4`, panel black `#1B1D1F`, RBF red `#C1121F`
  (primary), panel grey `#3A3F44`, go green `#2B8A3E`, caution amber `#E09F00`.
  Dark: `#15181B` / `#ECEDEE` / `#FF5A5F`. Hand-built `ColorScheme`.
- Kit tools always render on the dark instrument panel (`PanelTheme`).
- Fonts bundled: Sofia Sans Condensed (headings, tabs, result), Sofia Sans
  (body), Fira Mono (METAR/TAF, times, hours, ICAO). All SIL OFL 1.1, from
  github.com/lettersoup/Sofia-Sans and github.com/google/fonts (ofl/firamono).
- 6 px radius, punched-tag status chips (`TagPainter`), ruled ledger rows, no
  gradients. Every status = word + icon + colour.
- Flight-category colours keep their meaning: VFR green, MVFR blue, IFR red,
  LIFR magenta.
- Icon/mark: `assets/logo/pilot_enroute_icon.svg` (tag on panel black) and
  `pilot_enroute_mark.svg` (tag alone). Rendered with
  `rsvg-convert -w 1024 -h 1024 <svg> -o <png>`, then resized with PIL to every
  iOS AppIcon size (RGB, no alpha) and Android mipmap (adaptive foreground at
  66/108 of the canvas). Launch: placard white + mark on both platforms.

## Ads
AdMob banner only, behind UMP consent: one in-list slot in Logbook (after the
5th row) and one in Weather. Never on Today, the Go result or the entry form.

## Testing
`test/core` (engine, decoding, minimums, logbook depth), `test/data` (real
SQLite migration), `test/services`, `test/screens` (Go Card with recorded AWC
fixtures and a fake HTTP client, entry form, logbook, onboarding, settings),
`test/foldable_layout_test.dart` (every screen at fold geometries and 1.6×
text), `test/ui/theme_test.dart`, `test/services/honest_entry_points_test.dart`
(scope/grep checks).
