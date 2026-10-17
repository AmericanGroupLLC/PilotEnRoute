#!/usr/bin/env bash
# One command for every check on PilotEnRoute: analyze, host tests, the iOS
# simulator build + launch + on-device test, and the Android build + emulator
# launch + on-device test. The same script runs on this Mac and in GitHub
# Actions (.github/workflows/ci.yml), so a green CI run means what a green
# local run means.
#
# Output is short on purpose: one PASS/FAIL line per step, plus the last lines
# of a failing step's log. Full logs, screenshots and a summary live in
# build/verify/ (summary.md, summary.json, <step>.log, *.png).
#
# Usage:
#   tools/verify.sh                  # all steps
#   tools/verify.sh quick            # pub, analyze, test
#   tools/verify.sh ios              # ios-build, ios-launch, ios-drive
#   tools/verify.sh android          # android-build, android-launch, android-drive
#   tools/verify.sh analyze test     # any list of steps or groups
#
# Environment (all optional):
#   FLUTTER          flutter binary (default: ~/agl/.flutter-sdk, then PATH)
#   IOS_SIM_UDID     simulator to use (default: newest iPhone Pro Max, else iPhone)
#   ANDROID_SERIAL   adb device (default: the first one attached)
#   ANDROID_AVD      AVD to boot headless when no device is attached
#   VERIFY_OFFLINE   true = skip the live-weather step of the on-device test.
#                    Default: true for Android off CI (the emulator on the AGL
#                    Mac has no internet), false elsewhere.
#   TAIL_LINES       log lines shown for a failing step (default 25)
set -uo pipefail
# With pipefail, `cmd | grep -q` fails when grep exits early and cmd gets
# SIGPIPE; read the whole stream instead (`grep … >/dev/null`).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
OUT="$ROOT/build/verify"
mkdir -p "$OUT"
TAIL_LINES="${TAIL_LINES:-25}"
IOS_BUNDLE="com.americangroupllc.pilotenroute"
# The prod flavor's debug build installs under this id (applicationIdSuffix).
ANDROID_PKG="com.americangroupllc.pilotenroute.debug"
ANDROID_FLAVOR="prod"

# On the AGL Mac only the workspace SDK is writable (the sandbox blocks
# ~/flutter-sdk), so it wins over PATH; CI has no ~/agl and uses PATH.
if [ -n "${FLUTTER:-}" ]; then :;
elif [ -x "$HOME/agl/.flutter-sdk/bin/flutter" ]; then FLUTTER="$HOME/agl/.flutter-sdk/bin/flutter";
elif command -v flutter >/dev/null 2>&1; then FLUTTER="$(command -v flutter)";
else echo "flutter not found (set FLUTTER)"; exit 2; fi

# Gradle on the AGL Mac: the JVM needs IPv4 and the proxy as system properties
# (see agl-manifest/scripts/build_release.py). Derived from HTTPS_PROXY.
if [ -z "${JAVA_TOOL_OPTIONS:-}" ] && [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then
  p="${HTTPS_PROXY:-${https_proxy:-}}"; p="${p#*://}"; p="${p%%/*}"
  host="${p%%:*}"; port="${p##*:}"
  export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true -Dhttp.proxyHost=$host -Dhttp.proxyPort=$port -Dhttps.proxyHost=$host -Dhttps.proxyPort=$port"
fi

RESULTS=()   # "name|PASS|seconds|note"
FAILED=0

record() { RESULTS+=("$1|$2|$3|${4:-}"); }

# step <name> <function>: runs the function with output to <name>.log.
step() {
  local name="$1" fn="$2" start end secs log="$OUT/$1.log"
  start=$(date +%s)
  if "$fn" >"$log" 2>&1; then
    end=$(date +%s); secs=$((end - start))
    record "$name" PASS "$secs" "$(note_for "$name")"
    printf 'PASS %-15s %4ss %s\n' "$name" "$secs" "$(note_for "$name")"
  else
    end=$(date +%s); secs=$((end - start)); FAILED=1
    record "$name" FAIL "$secs" "log: build/verify/$name.log"
    printf 'FAIL %-15s %4ss log: build/verify/%s.log\n' "$name" "$secs" "$name"
    grep -v -E 'Picked up JAVA_TOOL_OPTIONS|^\s*$' "$log" | tail -n "$TAIL_LINES" | sed 's/^/     | /'
  fi
}

# A short fact from a step's log for the summary line.
note_for() {
  local log="$OUT/$1.log"
  case "$1" in
    analyze) grep -E 'No issues found|issues? found' "$log" | tail -1 ;;
    test) grep -oE '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (All tests passed!|Some tests failed\.)' "$log" | tail -1 ;;
    ios-build|android-build) grep -oE 'Built build/[^ ]+' "$log" | tail -1 ;;
    ios-launch|android-launch) grep -E '^launched' "$log" | tail -1 ;;
    ios-drive|android-drive) echo "$(grep -c '\[verify\] captured' "$log") screenshots" ;;
  esac
}

# ── steps ────────────────────────────────────────────────────────────────

s_pub() { "$FLUTTER" pub get; }

s_analyze() { "$FLUTTER" analyze --no-fatal-infos; }

s_test() { "$FLUTTER" test; }

ios_udid() {
  if [ -n "${IOS_SIM_UDID:-}" ]; then echo "$IOS_SIM_UDID"; return; fi
  xcrun simctl list devices available -j | python3 -I -c '
import json, re, sys
devs = json.load(sys.stdin)["devices"]
best = None
for rt, items in devs.items():
    m = re.search(r"iOS-(\d+)-(\d+)", rt)
    if not m:
        continue
    ver = (int(m[1]), int(m[2]))
    for d in items:
        if not d["name"].startswith("iPhone"):
            continue
        key = (ver, "Pro Max" in d["name"], d["name"])
        if best is None or key > best[0]:
            best = (key, d["udid"])
print(best[1] if best else "")'
}

ios_boot() {
  local u="$1"
  xcrun simctl boot "$u" 2>/dev/null || true
  xcrun simctl bootstatus "$u" -b >/dev/null
}

s_ios_build() { "$FLUTTER" build ios --simulator --debug; }

s_ios_launch() {
  local u; u="$(ios_udid)"; [ -n "$u" ] || { echo "no iPhone simulator"; return 1; }
  echo "simulator $u"
  ios_boot "$u"
  xcrun simctl install "$u" build/ios/iphonesimulator/Runner.app
  xcrun simctl launch "$u" "$IOS_BUNDLE"
  sleep 12
  xcrun simctl io "$u" screenshot "$OUT/ios-launch.png"
  # Still running 12 s after launch = no crash on start (the 2.1(a) failure).
  if xcrun simctl spawn "$u" launchctl list | grep "UIKitApplication:$IOS_BUNDLE" >/dev/null; then
    echo "launched and still running after 12 s"
  else
    echo "app is not running 12 s after launch"; return 1
  fi
}

s_ios_drive() {
  local u; u="$(ios_udid)"; ios_boot "$u"
  local offline="${VERIFY_OFFLINE:-false}"
  "$FLUTTER" drive --driver=test_driver/verify_driver.dart \
    --target=integration_test/should_features_test.dart \
    --dart-define=SCREENSHOT=true --dart-define=VERIFY_OFFLINE="$offline" -d "$u"
  local rc=$?
  mkdir -p "$OUT/ios"; cp build/verify_screenshots/*.png "$OUT/ios/" 2>/dev/null
  return $rc
}

android_serial() {
  if [ -n "${ANDROID_SERIAL:-}" ]; then echo "$ANDROID_SERIAL"; return; fi
  adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

android_ensure_device() {
  local s; s="$(android_serial)"
  if [ -z "$s" ] && [ -n "${ANDROID_AVD:-}" ]; then
    # First SDK that exists: ANDROID_HOME can point at a missing folder.
    local emu="" d
    for d in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
      if [ -n "$d" ] && [ -x "$d/emulator/emulator" ]; then emu="$d/emulator/emulator"; break; fi
    done
    [ -n "$emu" ] || { echo "no Android emulator binary found" >&2; return 0; }
    "$emu" -avd "$ANDROID_AVD" -no-window -no-audio -no-boot-anim -no-snapshot-save \
      >"$OUT/emulator.log" 2>&1 &
    for _ in $(seq 1 72); do
      s="$(android_serial)"
      [ -n "$s" ] && [ "$(adb -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
      sleep 5
    done
  fi
  echo "$s"
}

s_android_build() {
  "$FLUTTER" build apk --debug --flavor "$ANDROID_FLAVOR"
  local rc=$?
  [ -n "${CI:-}" ] || pkill -f '[G]radleDaemon' || true   # memory on the Mac
  return $rc
}

s_android_launch() {
  local s; s="$(android_ensure_device)"; [ -n "$s" ] || { echo "no Android device (set ANDROID_AVD)"; return 1; }
  echo "device $s"
  adb -s "$s" install -r "build/app/outputs/flutter-apk/app-$ANDROID_FLAVOR-debug.apk"
  local act; act="$(adb -s "$s" shell cmd package resolve-activity --brief "$ANDROID_PKG" | tail -1 | tr -d '\r')"
  adb -s "$s" logcat -c
  adb -s "$s" shell am start -W -n "$act"
  sleep 12
  adb -s "$s" exec-out screencap -p >"$OUT/android-launch.png"
  if adb -s "$s" logcat -d | grep 'FATAL EXCEPTION' >/dev/null; then
    adb -s "$s" logcat -d | grep -A20 'FATAL EXCEPTION'; return 1
  fi
  if [ -n "$(adb -s "$s" shell pidof "$ANDROID_PKG" | tr -d '\r')" ]; then
    echo "launched and still running after 12 s"
  else
    echo "app is not running 12 s after launch"; return 1
  fi
}

s_android_drive() {
  local s; s="$(android_ensure_device)"; [ -n "$s" ] || { echo "no Android device"; return 1; }
  local offline="${VERIFY_OFFLINE:-}"
  if [ -z "$offline" ]; then if [ -n "${CI:-}" ]; then offline=false; else offline=true; fi; fi
  echo "VERIFY_OFFLINE=$offline"
  "$FLUTTER" drive --flavor "$ANDROID_FLAVOR" --driver=test_driver/verify_driver.dart \
    --target=integration_test/should_features_test.dart \
    --dart-define=SCREENSHOT=true --dart-define=VERIFY_OFFLINE="$offline" -d "$s"
  local rc=$?
  mkdir -p "$OUT/android"; cp build/verify_screenshots/*.png "$OUT/android/" 2>/dev/null
  return $rc
}

# ── plan ─────────────────────────────────────────────────────────────────

expand() {
  case "$1" in
    all) echo pub analyze test ios-build ios-launch ios-drive android-build android-launch android-drive ;;
    quick) echo pub analyze test ;;
    ios) echo ios-build ios-launch ios-drive ;;
    android) echo android-build android-launch android-drive ;;
    pub|analyze|test|ios-build|ios-launch|ios-drive|android-build|android-launch|android-drive) echo "$1" ;;
    *) echo "unknown step: $1" >&2; exit 2 ;;
  esac
}

PLAN=()
[ $# -eq 0 ] && set -- all
for a in "$@"; do for s in $(expand "$a"); do PLAN+=("$s"); done; done

echo "PilotEnRoute verify · $(git rev-parse --short HEAD)$(git diff --quiet || echo '+dirty') · $("$FLUTTER" --version 2>/dev/null | head -1)"
for s in "${PLAN[@]}"; do
  # A failed build makes its launch/drive steps meaningless; skip them.
  case "$s" in
    ios-launch|ios-drive)
      if printf '%s\n' "${RESULTS[@]:-}" | grep '^ios-build|FAIL' >/dev/null; then
        record "$s" SKIP 0 "ios-build failed"; printf 'SKIP %-15s       ios-build failed\n' "$s"; continue; fi ;;
    android-launch|android-drive)
      if printf '%s\n' "${RESULTS[@]:-}" | grep '^android-build|FAIL' >/dev/null; then
        record "$s" SKIP 0 "android-build failed"; printf 'SKIP %-15s       android-build failed\n' "$s"; continue; fi ;;
  esac
  step "$s" "s_${s//-/_}"
done

# ── summary ──────────────────────────────────────────────────────────────
{
  echo "## PilotEnRoute verify"
  echo
  echo "Commit \`$(git rev-parse --short HEAD)\`, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "| Step | Result | Time | Note |"
  echo "|---|---|---|---|"
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r n st t note <<<"$r"
    echo "| $n | $st | ${t}s | $note |"
  done
} >"$OUT/summary.md"
python3 -I - "$OUT/summary.json" "${RESULTS[@]}" <<'PY'
import json, sys
out, rows = sys.argv[1], sys.argv[2:]
steps = []
for r in rows:
    n, st, t, note = (r.split("|", 3) + [""] * 4)[:4]
    steps.append({"step": n, "result": st, "seconds": int(t or 0), "note": note})
json.dump({"ok": all(s["result"] != "FAIL" for s in steps), "steps": steps},
          open(out, "w"), indent=2)
PY
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$OUT/summary.md" >>"$GITHUB_STEP_SUMMARY"
echo "summary: build/verify/summary.md"
exit $FAILED
