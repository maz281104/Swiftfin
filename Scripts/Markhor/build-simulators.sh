#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

sh "$ROOT/Scripts/Markhor/GenerateMarkhorAssets.sh"

echo "=== Building Markhor IPTV for iOS/iPadOS Simulator ==="
xcodebuild \
  -project "$ROOT/Swiftfin.xcodeproj" \
  -scheme "Swiftfin" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo ""
echo "=== Building Markhor IPTV for tvOS Simulator ==="
xcodebuild \
  -project "$ROOT/Swiftfin.xcodeproj" \
  -scheme "Swiftfin tvOS" \
  -configuration Debug \
  -destination "generic/platform=tvOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo ""
echo "Both Markhor IPTV simulator builds completed successfully."
