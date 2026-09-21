#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "Markhor IPTV Apple bootstrap"
echo "Repository: $ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: Xcode command line tools are not available."
  echo "Install Xcode from the Mac App Store, launch it once, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Xcode:"
xcodebuild -version

if command -v brew >/dev/null 2>&1; then
  echo "Installing required build tools..."
  brew list swiftgen >/dev/null 2>&1 || brew install swiftgen
  brew list swiftformat >/dev/null 2>&1 || brew install swiftformat
else
  echo "WARNING: Homebrew is not installed."
  echo "SwiftGen and SwiftFormat are required by the Xcode build phases."
  echo "Install Homebrew from https://brew.sh and rerun this script."
  exit 1
fi

echo "Generating Markhor branding assets..."
sh "$ROOT/Scripts/Markhor/GenerateMarkhorAssets.sh"

echo "Resolving Swift packages..."
xcodebuild \
  -resolvePackageDependencies \
  -project "$ROOT/Swiftfin.xcodeproj"

echo ""
echo "Bootstrap complete."
echo "Available shared schemes:"
xcodebuild -project "$ROOT/Swiftfin.xcodeproj" -list
echo ""
echo "Next:"
echo "  Open Swiftfin.xcodeproj in Xcode"
echo "  Select scheme 'Swiftfin' for iPhone/iPad Simulator"
echo "  Select scheme 'Swiftfin tvOS' for Apple TV Simulator"
