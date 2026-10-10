# ✈️ PilotEnRoute — Aviation Training Platform

> **Train Smarter. Fly Safer. Go Further.**

PilotEnRoute is a **100% production-ready Flutter aviation platform** targeting iOS, Android, and Web from a single codebase. It combines AI-driven flight simulation, FAA education, drone training, live weather, flight tracking, digital logbook, and smart notifications — all powered by free public APIs with **no server required**.

---

## 📱 Platforms

| Platform | Status | Notes |
|---|---|---|
| **Android** | ✅ Ready | Android 6.0+ (API 23+), Google Play ready |
| **iOS** | ✅ Ready | iOS 14+, App Store ready |
| **Web** | ✅ Ready | PWA, works in all modern browsers |
| **Web Marketing** | ✅ Ready | Static HTML in `web_marketing/` |

---

## 🚀 Features

### Core Modules

| Module | Description |
|---|---|
| 🛩️ **AI Flight Simulator** | Lightweight Flame-powered 2D simulation — 6 aircraft, 7 scenarios, AI autopilot |
| 📚 **FAA Education Hub** | Regulations, AIM, handbooks, study guides for PPL through ATP |
| 🃏 **Flashcards** | Spaced-repetition cards across all FAA knowledge categories |
| 📝 **Exam Tests** | Full FAA written exam simulation with real past-paper questions |
| 🚨 **Emergency Simulator** | Timed, scored emergency procedure training |
| 📓 **Digital Logbook** | FAA-compliant logbook with PDF export |
| 🗺️ **Flight Planner** | ICAO-format flight plan builder with weather integration |
| 🔍 **Flight Tracker** | Real-time tail number tracking via OpenSky Network |
| 🌤️ **Weather** | METAR, TAF, PIREPs, SIGMETs from Aviation Weather Center |
| 🏢 **Airport Lookup** | Full airport data, runways, frequencies via RotatePilot API |
| 📖 **Aviation Glossary** | Complete aviation terminology database |
| 📋 **Smart Checklists** | Aircraft-specific checklists with critical item highlighting |
| 🚁 **Drone Education** | FAA Part 107 complete course, LAANC, Remote ID |
| 🌐 **ICARA** | International student guide: TSA/AFSP, visas, ICAO standards |
| 🏆 **Career Pathways** | Airline, corporate, military paths with salary data |
| ✍️ **Endorsements** | Complete FAA endorsement guide with templates |
| 🔔 **Smart Notifications** | Medical renewals, FAA alerts, TFRs, currency reminders |
| ⌚ **Garmin Integration** | Garmin Connect IQ, ForeFlight, SkyVector deep links |
| 📰 **Aviation News** | Live RSS feed from AOPA, AVweb, FlightGlobal |
| 🤖 **AI Instructor** | Ask aviation questions, get FAA-referenced answers |

---

## 🌐 Public APIs Used (No Server Required)

| API | Data | Auth |
|---|---|---|
| [Aviation Weather Center](https://aviationweather.gov/api/data) | METAR, TAF, PIREPs, SIGMETs | None |
| [OpenSky Network](https://opensky-network.org/api) | Live flights, tail number lookup | None |
| [RotatePilot API](https://rotatepilot.com/api/v1) | ATPL questions, airports, glossary | None |
| [AirportDB](https://airportdb.io) | Airport database | Free key |
| [OpenStreetMap](https://tile.openstreetmap.org) | Map tiles | None |
| [Aviation News RSS](https://www.aopa.org/news-and-media/rss) | News feed | None |
| [ADS-B Exchange](https://www.adsbexchange.com) | Unfiltered ADS-B | Free tier |
| [Garmin Connect IQ](https://developer.garmin.com/connect-iq) | Wearable data | Garmin SDK |

---

## 🏗️ Project Structure

```
pilot_enroute/
├── lib/
│   ├── main.dart                      # App entry, routing, theming, providers
│   ├── screens/
│   │   ├── home_screen.dart           # Dashboard with quick stats
│   │   ├── simulation_screen.dart     # AI Flight Simulator (Flame engine)
│   │   ├── weather_screen.dart        # METAR/TAF/Live Flights/PIREPs
│   │   ├── news_screen.dart           # Aviation News RSS Feed
│   │   ├── quiz_screen.dart           # FAA Knowledge Quiz
│   │   ├── flashcard_screen.dart      # Spaced Repetition Flashcards
│   │   ├── exam_screen.dart           # Full FAA Exam Simulation
│   │   ├── logbook_screen.dart        # Digital Logbook (SQLite)
│   │   ├── flight_plan_screen.dart    # ICAO Flight Plan Builder
│   │   ├── flight_tracker_screen.dart # Tail Number Tracker
│   │   ├── airport_screen.dart        # Airport Lookup
│   │   ├── glossary_screen.dart       # Aviation Glossary
│   │   ├── checklist_screen.dart      # Smart Checklists
│   │   ├── emergency_screen.dart      # Emergency Procedure Simulator
│   │   ├── drone_screen.dart          # Drone / Part 107 Education
│   │   ├── education_screen.dart      # FAA Education Hub
│   │   ├── endorsements_screen.dart   # FAA Endorsements Guide
│   │   ├── career_screen.dart         # Career Pathways & Salary Data
│   │   ├── icara_screen.dart          # International Students (ICARA)
│   │   ├── notifications_screen.dart  # Notification Manager
│   │   ├── garmin_screen.dart         # Garmin & External Integrations
│   │   └── profile_screen.dart        # Pilot Profile & Medical Tracker
│   ├── services/
│   │   ├── aviation_api_service.dart  # RotatePilot API client
│   │   ├── weather_service.dart       # AWC + OpenSky API client
│   │   ├── news_service.dart          # RSS News Feed parser
│   │   ├── notification_service.dart  # Push notification manager
│   │   ├── logbook_service.dart       # SQLite logbook CRUD
│   │   ├── flight_plan_service.dart   # Flight plan builder
│   │   ├── flight_tracker_service.dart# OpenSky tail number tracker
│   │   └── flashcard_service.dart     # Flashcard engine with spaced rep
│   └── widgets/
│       ├── module_card.dart           # Reusable module card widget
│       ├── daily_quote_card.dart      # Daily aviation quote
│       ├── news_ticker.dart           # Scrolling news preview
│       └── app_drawer.dart            # Navigation drawer
├── web_marketing/
│   └── index.html                     # Full marketing landing page
├── android/                           # Android build configuration
├── ios/                               # iOS build configuration
├── web/                               # Flutter Web configuration
└── pubspec.yaml                       # Dependencies
```

---

## 🛠️ Setup & Development

### Prerequisites

- Flutter SDK 3.32+
- Dart 3.8+
- Android Studio (for Android builds)
- Xcode 15+ (for iOS builds, macOS only)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/AmericanGroupLLC/PilotEnRoute.git
cd PilotEnRoute

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run on Chrome (web)
flutter run -d chrome

# Run on iOS Simulator
flutter run -d ios

# Run on Android Emulator
flutter run -d android
```

### Production Builds

```bash
# Android APK (release)
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release

# Web (outputs to build/web/)
flutter build web --release --base-href /PilotEnRoute/
```

---

## 🔔 Notification System

PilotEnRoute uses `flutter_local_notifications` for on-device notifications with timezone support.

**Notification Categories by Pilot Level:**

| Category | Trigger | Pilot Levels |
|---|---|---|
| 🏥 Medical Renewal | 60, 30, 7 days before expiry | All |
| ⚠️ FAA Alerts | TFRs, NOTAMs, ADs | All |
| 🌤️ Weather | SIGMETs, AIRMETs | All |
| 🎯 Daily Quiz | 8:00 AM daily | All |
| ✈️ BFR Reminder | 90 days before due | PPL+ |
| 🎯 IPC Reminder | 90 days before due | IR+ |
| 🔄 Currency | Passenger/night currency | PPL+ |
| 📡 SIGMET | Active SIGMETs in area | IR+ |

---

## 🌍 International Students (ICARA)

The ICARA module provides complete guidance for international flight students:

- **TSA Alien Flight Student Program (AFSP)** — Step-by-step enrollment guide
- **Visa Categories** — M-1 vocational, F-1 academic, B-1/B-2 limitations
- **ICAO Standards** — Annex 1 license requirements and conversions
- **Bilateral Agreements** — BASA countries and reciprocal recognition
- **Country-Specific Guides** — India, China, UAE, UK, Canada, and more
- **Recommended Schools** — FAA-approved flight schools accepting international students

---

## ✈️ Supported Certificate Levels

| Certificate | Knowledge Test | Simulator | Notifications | Logbook |
|---|---|---|---|---|
| Student Pilot | ✅ | ✅ | ✅ | ✅ |
| Private Pilot (PPL) | ✅ | ✅ | ✅ | ✅ |
| Instrument Rating (IR) | ✅ | ✅ | ✅ | ✅ |
| Commercial Pilot (CPL) | ✅ | ✅ | ✅ | ✅ |
| Airline Transport Pilot (ATP) | ✅ | ✅ | ✅ | ✅ |
| Part 107 Remote Pilot | ✅ | ✅ | ✅ | ✅ |
| CFI / CFII | ✅ | — | ✅ | ✅ |

---

## 🔧 Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | 3.32+ |
| Language | Dart | 3.8+ |
| State Management | Provider | 6.1+ |
| Local Database | sqflite | 2.4+ |
| Game Engine | Flame | 1.18+ |
| Maps | flutter_map | 7.0+ |
| Notifications | flutter_local_notifications | 18.0+ |
| HTTP Client | http | 1.2+ |
| Fonts | google_fonts | 6.2+ |
| Charts | fl_chart | 0.69+ |
| PDF Generation | pdf + printing | 3.11+ |
| Local Storage | shared_preferences | 2.5+ |

---

## 🚀 GitHub Actions CI/CD

The repository includes automated workflows:

```yaml
# .github/workflows/flutter.yml
- flutter analyze (every push)
- flutter test (every PR)
- flutter build apk (on release tag)
- flutter build web → GitHub Pages (on main push)
```

---

## 💰 Monetization Setup

### Google AdMob (Replace Test IDs Before Release)
```dart
// lib/services/ad_service.dart
static const String _androidBannerAdUnitId = 'ca-app-pub-XXXXXXXX/XXXXXXXX';
static const String _iosBannerAdUnitId = 'ca-app-pub-XXXXXXXX/XXXXXXXX';
```
```groovy
// android/app/build.gradle
manifestPlaceholders += [admobAppId: "ca-app-pub-XXXXXXXX~XXXXXXXXXX"]
```
```xml
<!-- ios/Runner/Info.plist -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXX~XXXXXXXXXX</string>
```

### In-App Purchases (Set Real Product IDs)
```dart
// lib/services/premium_service.dart
static const String monthlyProductId = 'com.americangroupllc.pilotenroute.premium_monthly';
static const String annualProductId  = 'com.americangroupllc.pilotenroute.premium_annual';
static const String lifetimeProductId = 'com.americangroupllc.pilotenroute.premium_lifetime';
```

---

## 🤖 Android Release Build

```bash
# 1. Generate keystore
keytool -genkey -v -keystore android/pilotenroute.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias pilotenroute

# 2. Copy template and fill in credentials
cp android/key.properties.template android/key.properties
# Edit android/key.properties with your keystore password

# 3. Build release AAB (for Google Play)
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

## 🍎 iOS Release Build (macOS + Xcode Required)

```bash
# 1. Open workspace
open ios/Runner.xcworkspace

# 2. In Xcode: Runner target → Signing & Capabilities
#    Set Team to your Apple Developer account
#    Bundle ID: com.americangroupllc.pilotenroute

# 3. Build for release
flutter build ios --release
# Then in Xcode: Product → Archive → Distribute App
```

## 🌐 Marketing Website Deployment

```bash
# GitHub Pages (automatic via .github/workflows/deploy-website.yml)
# Enable in: Settings → Pages → Source: GitHub Actions
# Live URL: https://www.americangroup.ai/PilotEnRoute/

# Manual: Upload web_marketing/ to any static host (Netlify, Vercel, S3)
```

---

## ✅ Production Submission Checklist

See `store_submission/app_store_metadata.md` for complete App Store & Play Store metadata.

### Before Submitting to App Store / Play Store
- [ ] Replace AdMob test IDs with real production IDs
- [ ] Create IAP products in App Store Connect / Play Console
- [ ] Generate and configure Android release keystore
- [ ] Configure iOS signing certificate and provisioning profile
- [ ] Upload app icon (1024×1024 PNG, no alpha) to App Store Connect
- [ ] Upload screenshots for all required device sizes
- [ ] Upload Feature Graphic (1024×500) to Play Console
- [ ] Set Privacy Policy URL in both stores
- [ ] Complete age rating questionnaire (4+ / Everyone)
- [ ] Enable GitHub Pages for marketing website
- [ ] Update App Store / Play Store links in `web_marketing/index.html`

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m 'feat: add your feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request against `master`

---

## ⚠️ Disclaimer

PilotEnRoute is an **educational and training tool only**. It is **not** certified for actual flight navigation, weather briefing, or operational use. Always consult official FAA-approved sources for actual flight operations.

---

## 📄 License

Proprietary — © 2026 American Group LLC. All rights reserved.

---

## 🔗 Links

- [GitHub Repository](https://github.com/AmericanGroupLLC/PilotEnRoute)
- [Marketing Website](https://www.americangroup.ai/PilotEnRoute)
- [FAA Official](https://www.faa.gov)
- [Aviation Weather Center](https://aviationweather.gov)
- [OpenSky Network](https://opensky-network.org)
- [RotatePilot API](https://rotatepilot.com/developers)

## Test Account (offline demo login)

PilotEnRoute ships with a built-in **offline test account** for reviewers and
QA. It is validated locally by `AuthService` — no backend or network required —
and creates a persisted session that survives app restarts.

| Field    | Value                          |
| -------- | ------------------------------ |
| Email    | `test@americangroup.ai`    |
| Password | `Test1234!`                    |

**How to sign in**

1. Launch the app — the login screen is shown before the main navigation.
2. Tap **"Use test account"** (one tap) — or type the credentials above and tap
   **SIGN IN**.
3. You land on the home dashboard.

You can also tap **"Continue without signing in"** to browse as a guest, or use
the account screen to sign out. Real email/password, social, and phone logins
continue to work against the AmericanGroupLLC backend as before.
