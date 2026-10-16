#!/bin/sh
# Captures stable App Store screenshots on the simulators (and the Mac) that
# match each required display size. Content is the bundled snapshot: the UI
# test launches with -NCSnapshot.
#
#   support/appstore/capture_screenshots.sh [out-dir]
#
# out-dir/<device>/01-today.png  (device: iphone-6.9, iphone-6.5, ipad-13, mac, appletv, vision)
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT="${1:-$ROOT/build/appstore/raw}"
mkdir -p "$OUT"
cd "$ROOT"
bash scripts/xcodegen.sh

pick() {
  os="$1"
  shift
  python3 - "$os" "$@" <<'PY'
import json, subprocess, sys
os_name, names = sys.argv[1], sys.argv[2:]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
found = []
for runtime, devices in data["devices"].items():
    if f"SimRuntime.{os_name}-" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable"):
            found.append(device)
found.sort(key=lambda d: d["name"])
for wanted in names:
    for device in found:
        if device["name"] == wanted or device["name"].startswith(wanted + " "):
            print(device["udid"])
            print(device["name"])
            raise SystemExit(0)
print("missing", file=sys.stderr)
raise SystemExit(1)
PY
}

run_tests() {
  device="$1"
  destination="$2"
  screens="$3"
  signing="$4"
  dir="$OUT/$device"
  mkdir -p "$dir"
  log="$ROOT/build/appstore/logs/$device.log"
  mkdir -p "$(dirname "$log")"
  echo "capturing $device ($screens) -> $dir"
  set +e
  NC_SHOT_DIR="$dir" NC_SCREENS="$screens" NC_LANG=en \
    xcodebuild test \
      -project "$ROOT/NordicCrypto.xcodeproj" \
      -scheme NordicCryptoScreenshots \
      -destination "$destination" \
      -only-testing:NordicCryptoScreenshotTests/ScreenshotTests/testCapture \
      -derivedDataPath "$ROOT/build/appstore/DerivedData-$device" \
      $signing \
      >"$log" 2>&1
  code=$?
  set -e
  if [ "$code" -ne 0 ]; then
    echo "xcodebuild failed for $device (log $log)" >&2
    tail -n 40 "$log" >&2 || true
    return 1
  fi
}

fail=0
capture_sim() {
  device="$1"
  os="$2"
  screens="$3"
  shift 3
  if ! info=$(pick "$os" "$@" 2>"$ROOT/build/appstore/logs/$device.sim.txt"); then
    echo "No $os simulator for $device. Install the runtime in Xcode, then re-run." >&2
    cat "$ROOT/build/appstore/logs/$device.sim.txt" >&2 || true
    fail=1
    return
  fi
  id=$(printf '%s\n' "$info" | head -n 1)
  echo "$device: $(printf '%s\n' "$info" | tail -n 1) ($id)"
  xcrun simctl boot "$id" 2>/dev/null || true
  xcrun simctl bootstatus "$id" -b >/dev/null
  if [ "$os" = iOS ]; then
    xcrun simctl ui "$id" appearance dark >/dev/null 2>&1 || true
    xcrun simctl status_bar "$id" override --time "9:41" --batteryState charged --batteryLevel 100 \
      --wifiBars 3 --cellularMode active --cellularBars 4 >/dev/null 2>&1 || true
  fi
  run_tests "$device" "platform=$os Simulator,id=$id" "$screens" "CODE_SIGNING_ALLOWED=NO" || fail=1
  xcrun simctl shutdown "$id" >/dev/null 2>&1 || true
}

mkdir -p "$ROOT/build/appstore/logs"
capture_sim iphone-6.9 iOS "today,story,events,countries,newsletter" \
  "iPhone 17 Pro Max" "iPhone 16 Pro Max" "iPhone 15 Pro Max" "iPhone 14 Pro Max"
capture_sim iphone-6.5 iOS "today,story,events,countries,newsletter" \
  "iPhone 14 Plus" "iPhone 13 Pro Max" "iPhone 11 Pro Max" "iPhone XS Max"
capture_sim ipad-13 iOS "today,story,events,countries,newsletter" \
  "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)" "iPad Pro 13-inch"
capture_sim appletv tvOS "dashboard" \
  "Apple TV 4K (3rd generation)" "Apple TV 4K" "Apple TV"
capture_sim vision visionOS "today,story,events" \
  "Apple Vision Pro"

# The Mac app runs on this machine. Automatic signing uses the team in project.yml.
run_tests mac "platform=macOS" "today,story,events,countries,newsletter" "" || fail=1

if [ "$fail" -ne 0 ]; then
  echo "One or more screenshot captures failed." >&2
  exit 1
fi
echo "raw screenshots in $OUT"
