#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Keep DerivedData outside the repository so the project's SwiftFormat build
# phase does not recursively scan Swift Package checkouts inside DerivedData.
BUILD_ROOT="${RUNNER_TEMP:-/tmp}/markhor-ios-device"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
PACKAGE_ROOT="$BUILD_ROOT/package"
ARTIFACT_DIR="$ROOT/artifacts"
IPA_PATH="$ARTIFACT_DIR/Markhor-IPTV-iPadOS-unsigned.ipa"

rm -rf "$BUILD_ROOT"
mkdir -p "$PACKAGE_ROOT/Payload" "$ARTIFACT_DIR"
rm -f "$IPA_PATH"

sh "$ROOT/Scripts/Markhor/GenerateMarkhorAssets.sh"

echo "=== Building Markhor IPTV for physical iPhone/iPad (unsigned) ==="
xcodebuild \
  -project "$ROOT/Swiftfin.xcodeproj" \
  -scheme "Swiftfin" \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Debug-iphoneos"
APP_PATH="$(find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.app' -print | head -n 1)"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "ERROR: No iOS .app bundle found in $PRODUCTS_DIR"
  exit 1
fi

echo "Packaging: $APP_PATH"
ditto "$APP_PATH" "$PACKAGE_ROOT/Payload/$(basename "$APP_PATH")"

(
  cd "$PACKAGE_ROOT"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

echo ""
echo "Unsigned IPA created:"
ls -lh "$IPA_PATH"
echo ""
echo "This IPA is intentionally unsigned so it can be re-signed/sideloaded for a physical iPad."
