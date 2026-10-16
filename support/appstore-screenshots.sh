#!/bin/sh
# App Store screenshots from a booted simulator (Debug build: uses -NCScreen/-NCOpen/-NCFreeze).
# The GitHub workflow uses support/appstore/capture_screenshots.sh instead (it passes -NCSnapshot).
# Usage: support/appstore-screenshots.sh <platform: iphone|ipad|tv|vision> <sim-id> <path/to/Nordic Crypto.app> <out-dir> [lang]
set -e
KIND="$1"; SIM="$2"; APP="$3"; OUT="$4"; LANG_CODE="${5:-en}"
mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
if [ "$KIND" = iphone ] || [ "$KIND" = ipad ]; then
  xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularMode active --cellularBars 4 2>/dev/null || true
fi
xcrun simctl install "$SIM" "$APP"

shot() {
  name="$1"; shift
  xcrun simctl terminate "$SIM" no.cryptonordic.tv 2>/dev/null || true
  sleep 2
  xcrun simctl launch "$SIM" no.cryptonordic.tv -AppleLanguages "($LANG_CODE)" "$@" >/dev/null
  sleep 9
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "$OUT/$name.png"
}

case "$KIND" in
  tv)
    shot 01-dashboard -NCFreeze
    xcrun simctl terminate "$SIM" no.cryptonordic.tv 2>/dev/null || true
    sleep 2
    xcrun simctl launch "$SIM" no.cryptonordic.tv -AppleLanguages "($LANG_CODE)" >/dev/null
    sleep 40   # let the modules rotate to other pages
    xcrun simctl io "$SIM" screenshot "$OUT/02-dashboard.png" >/dev/null 2>&1
    echo "$OUT/02-dashboard.png"
    ;;
  vision)
    shot 01-today -NCScreen today
    shot 02-story -NCOpen story
    shot 03-events -NCScreen events
    ;;
  *)
    shot 01-today -NCScreen today
    shot 02-story -NCOpen story
    shot 03-events -NCScreen events
    shot 04-countries -NCScreen countries
    shot 05-newsletter -NCScreen newsletter
    ;;
esac
