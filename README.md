# PilotEnRoute

**Am I legal for this flight, and is today inside my own minimums?**

PilotEnRoute is a pilot's logbook that answers both on one card. Log each
flight with what the regulations count — day and night takeoffs and full-stop
landings, approaches, holds, course tracking, night, instrument and
cross-country time. Before the next flight, the **Go Card** works out your
passenger currency (day and night), IFR currency, flight review and medical
from your own entries and dates, shows the date each one lapses and what you
need to fix it, and compares the latest METAR and TAF from the Aviation
Weather Center with your own day/night personal minimums, including the
crosswind on the best runway.

No account. Your logbook stays on your phone.

PilotEnRoute is a ground planning and record-keeping tool. It is not approved
for navigation and does not replace an official weather briefing, your
POH/AFM or your instructor. Every go/no-go decision is yours.

## Features
Five tabs: Home · Learn · Practice · Plan · Logbook.

- **Home** — legal-today line, student progress, practice readiness, last
  flight; settings behind the gear.
- **Learn** — FAA library (PHAK, Airplane Flying Handbook, AIM, ACS, weather
  and more, opened from faa.gov), six-pack trainer (PHAK chapter 8) and
  airport operations (AIM), every line cited.
- **Practice** — the FAA's Private Pilot sample questions, each answer shown in
  the quoted FAA text; your score per topic and a review of missed questions.
- **Go Card** (from Home or Plan) — legality per flight (passengers, night, IFR) under
  14 CFR 61.57, 61.56, 61.23 (incl. BasicMed) and 61.87/61.89 for students;
  live METAR/TAF vs. your minimums; best-runway crosswind from true runway
  alignment; stale/offline/no-station states; every check saved to history;
  "Log this flight".
- **Logbook** — full entry form, edit, swipe-delete with undo, "Log again",
  search, filters, month groups, 30/90/365-day and all-time totals, PDF,
  Share PDF, Copy as CSV, and Paste CSV to bring an exported logbook back
  (from this app's own export only).
- **Student progress** — for student pilots, hours against 14 CFR 61.109(a)
  from the logbook; items the logbook cannot show are marked "not tracked".
- **Night window** — with Night on, the Go Card shows when the 61.57(b) night
  period starts and ends at the airport, worked out on the phone.
- **Weather** — METAR, TAF, PIREPs, SIGMETs, G-AIRMETs, winds aloft.
- **Plan / flight bag** — E6B, weight & balance, fuel, flight planner, checklists
  (representative only), documents with expiry dates, airport details, FAA
  charts link; each with a short "About" explanation.
- **Reminders** — 30 and 7 days before anything lapses.

## Data
- Aviation Weather Center data API (aviationweather.gov, NOAA) — keyless.
- Everything else is on the device (SQLite + SharedPreferences).
- Ads: Google AdMob banners in Logbook and Weather, after UMP consent where
  required.

## Develop
```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug
```
Map of the code: `AGENTS.md`. Design: `docs/DESIGN.md`.

## Licences
Fonts: Sofia Sans, Sofia Sans Condensed, Fira Mono — SIL Open Font License
1.1 (`assets/fonts/OFL-*.txt`).
