#!/usr/bin/env bash
# First-time iOS setup on a Mac — run from anywhere.
# Opens Xcode on the CocoaPods workspace (required for Simulator, device, TestFlight).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Run this script on the MacBook, not on Windows."
  exit 1
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

echo "==> Flutter doctor"
flutter doctor -v || true

echo "==> Disable Swift Package Manager (this app uses CocoaPods + Firebase)"
flutter config --no-enable-swift-package-manager

echo "==> flutter pub get"
flutter pub get

echo "==> CocoaPods"
cd ios
pod install
cd ..

echo ""
echo "Opening ios/Runner.xcworkspace in Xcode..."
echo "Signing & Capabilities → Team → your Apple Developer team"
echo "Bundle ID must stay: com.trackit.trackitMobile"
open ios/Runner.xcworkspace
