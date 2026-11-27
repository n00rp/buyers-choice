#!/bin/bash
# Tar skärmbilder av appen i simulatorn. Används av .github/workflows/ios.yml.
# Användning: scripts/screenshots.sh <simulator-id> <sökväg till BuyersChoice.app> <utkatalog>
set -euo pipefail
SIM="$1"; APP="$2"; OUT="$3"
BUNDLE=se.buyerschoice.app
mkdir -p "$OUT"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b
xcrun simctl status_bar "$SIM" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl privacy "$SIM" grant location "$BUNDLE" || true

shot() { # namn, väntetid, launch-argument …
  local name="$1" wait="$2"; shift 2
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$SIM" "$BUNDLE" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null
  echo "Skärmbild: $name"
}

shot 01-start 12
shot 02-rapport 12 -uiOpen "Linnégatan 20"
shot 03-plan 10 -uiOpen "Linnégatan 20" -uiSection fastighet
shot 04-miljo 10 -uiOpen "Linnégatan 20" -uiSection miljo
shot 05-omradet 10 -uiOpen "Linnégatan 20" -uiSection omradet
shot 06-service 10 -uiOpen "Linnégatan 20" -uiSection service
shot 07-fragor 10 -uiOpen "Linnégatan 20" -uiSection fragor
shot 08-partille 12 -uiOpen "Partille:Fröjas backe 10"
