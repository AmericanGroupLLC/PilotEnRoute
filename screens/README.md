# Screens — PilotEnRoute

Store screenshots live here, one directory per required size. Capture them
from the app itself rather than a mockup, so what a user sees in the store is
what they get.

```
screens/
  iphone-6.7/     1290x2796   required by Apple
  iphone-6.1/     1179x2556
  ipad-12.9/      2048x2732   only if the app supports iPad
  android-phone/  1080x1920   required by Google
  feature-graphic/ 1024x500   required by Google
```

## Capturing

```sh
flutter build ios --simulator --debug
xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <UDID> com.americangroup.pilotenroute
xcrun simctl io <UDID> screenshot screens/iphone-6.7/01-home.png
```

Name them in the order they should appear: `01-`, `02-`, and so on. Apple shows
the first three without scrolling, so lead with what the app is for.
