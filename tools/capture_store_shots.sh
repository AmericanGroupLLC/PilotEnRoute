#!/usr/bin/env bash
# =====================================================================
#  PilotEnRoute - store screenshot capture
# =====================================================================
#  Google Play blocks a release without >= 2 phone screenshots; the App
#  Store needs at least one 6.9" set. Both must come from a real render,
#  so this script needs macOS + Xcode; it cannot run on Linux/CI images
#  without a simulator.
#
#      ./tools/capture_store_shots.sh
#
#  Output (fastlane naming = upload order):
#      fastlane/screenshots/en-US/{1..N}_<screen>.png          (Apple)
#      fastlane/metadata/android/en-US/images/phoneScreenshots/ (Play, mirrored)
# =====================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"   # 6.9" - 1320 x 2868
IOS_SHOTS="$ROOT/fastlane/screenshots/en-US"
PLAY_SHOTS="$ROOT/fastlane/metadata/android/en-US/images/phoneScreenshots"

command -v xcrun >/dev/null || {
  echo "xcrun not found - this script requires macOS with Xcode." >&2; exit 1; }

mkdir -p "$IOS_SHOTS" "$PLAY_SHOTS"

UDID=$(xcrun simctl list devices available \
  | grep -F "$SIM_NAME (" | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[[ -n "$UDID" ]] || { echo "No available simulator named '$SIM_NAME'" >&2; exit 1; }
echo "Simulator: $SIM_NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

flutter build ios --simulator --debug --flavor prod
APP=$(find "$ROOT/build/ios/iphonesimulator" -maxdepth 1 -name '*.app' | head -1)
[[ -n "$APP" ]] || { echo "No .app built" >&2; exit 1; }
xcrun simctl install "$UDID" "$APP"

# Screens to capture, in store upload order. Deep links come from the app's
# router; adjust if the routes change.
SHOTS=("/education|ground-school" "/exam|exam" "/e6b|e6b" "/logbook|logbook" "/weather|weather")

i=1
for entry in "${SHOTS[@]}"; do
  route="${entry%%|*}"; label="${entry##*|}"
  echo "  [$i] $label  ($route)"
  xcrun simctl terminate "$UDID" "com.americangroupllc.pilotenroute" 2>/dev/null || true
  xcrun simctl launch "$UDID" "com.americangroupllc.pilotenroute" -route "$route" >/dev/null
  sleep 4
  out="$IOS_SHOTS/${i}_${label}.png"
  xcrun simctl io "$UDID" screenshot --type=png "$out"
  cp "$out" "$PLAY_SHOTS/${i}_${label}.png"
  i=$((i+1))
done

echo "Captured $((i-1)) screenshots into:"
echo "  $IOS_SHOTS"
echo "  $PLAY_SHOTS"
