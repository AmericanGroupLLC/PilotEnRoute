# Pending — PilotEnRoute

Generated from the state of this repository, not a generic
checklist. Regenerate after significant changes.

## Blockers — cannot ship

- [ ] **No Firebase config.** `google-services.json` and `GoogleService-Info.plist` are both absent, so Crashlytics, Analytics and FCM are all inert. Download them from the `americangroupllc-5bdfc` console.

## High

- [ ] Crashlytics not wired — a crash in the wild is invisible.
- [ ] AdMob is using Google's **test** app id — it serves test ads and earns nothing. Replace with this app's real id.

## Medium

- [ ] No release tags. Tag each store submission `v<version>+<build>` so a crash report can be traced to a build.

## Needs someone with console access

These cannot be resolved from the repository:

- [ ] Firebase config files for this app
- [ ] Real AdMob app and ad-unit ids
- [ ] App Store Connect and Play Console app records
- [ ] A privacy-policy URL that resolves
- [ ] Store screenshots and icon

Portfolio-wide status: [`AmericanGroupLLC-Backend/docs/CREDENTIALS_STATUS.md`](https://github.com/AmericanGroupLLC/AmericanGroupLLC-Backend/blob/dev/docs/CREDENTIALS_STATUS.md)
