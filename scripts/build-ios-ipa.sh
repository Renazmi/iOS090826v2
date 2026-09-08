#!/usr/bin/env bash
# Build TrackIT iOS .ipa for App Store / TestFlight — run on macOS with Xcode + CocoaPods.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must be run on a Mac with Xcode installed."
  exit 1
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

echo "==> Disable Swift Package Manager (CocoaPods + Firebase)"
flutter config --no-enable-swift-package-manager

echo "==> Flutter pub get"
flutter pub get

echo "==> CocoaPods"
cd ios
pod install --repo-update
cd ..

echo "==> flutter build ipa (app-store)"
echo "    Version comes from pubspec.yaml (currently 1.0.1+19)"
flutter build ipa --release --export-options-plist="$ROOT/ios/ExportOptions.plist"

OUT="$ROOT/build/ios/ipa"
mkdir -p "$REPO/releases"
shopt -s nullglob
for ipa in "$OUT"/*.ipa; do
  cp -f "$ipa" "$REPO/releases/TrackIT.ipa"
  echo "Copied $(basename "$ipa") to releases/TrackIT.ipa"
done

echo ""
echo "Done. IPA output:"
ls -la "$OUT"/*.ipa 2>/dev/null || ls -la "$OUT" || true
echo ""
echo "Open ios/Runner.xcworkspace in Xcode (not .xcodeproj)."
echo "Signing & Capabilities → Team → your Apple Developer team."
echo "Bundle ID: com.trackit.trackitMobile"
echo "Upload with Transporter, Xcode Organizer, or App Store Connect."
