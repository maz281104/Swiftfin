#!/bin/sh
set -eu

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SOURCE="$ROOT/Shared/Markhor/Assets/markhor-app-icon.png"

if [ ! -f "$SOURCE" ]; then
  echo "error: Markhor source icon not found: $SOURCE"
  exit 1
fi

TMP_DIR="${DERIVED_FILE_DIR:-/tmp}/markhor-branding"
mkdir -p "$TMP_DIR"

square_icon() {
  SIZE="$1"
  OUTPUT="$2"
  mkdir -p "$(dirname "$OUTPUT")"
  /usr/bin/sips -s format png -z "$SIZE" "$SIZE" "$SOURCE" --out "$OUTPUT" >/dev/null
}

padded_icon() {
  WIDTH="$1"
  HEIGHT="$2"
  LOGO_SIZE="$3"
  OUTPUT="$4"
  TEMP="$TMP_DIR/logo-${WIDTH}x${HEIGHT}.png"

  mkdir -p "$(dirname "$OUTPUT")"
  /usr/bin/sips -s format png -z "$LOGO_SIZE" "$LOGO_SIZE" "$SOURCE" --out "$TEMP" >/dev/null
  /usr/bin/sips --padToHeightWidth "$HEIGHT" "$WIDTH" --padColor 07130E "$TEMP" --out "$OUTPUT" >/dev/null
}

# iOS / iPadOS App Store icon
square_icon 1024 "$ROOT/Swiftfin/Resources/Assets.xcassets/AppIcons/Primary/AppIcon-primary-primary.appiconset/AppIcon-primary-primary.png"

# tvOS layered app icons
square_icon 216 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/216.png"
square_icon 432 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Webp.net-resizeimage-2.png"
square_icon 512 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/512.png"

padded_icon 400 240 190 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/400x240-back.png"
padded_icon 800 480 380 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Webp.net-resizeimage.png"
padded_icon 1280 768 610 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/1280x768-back.png"

# tvOS Top Shelf assets (1x + 2x variants)
padded_icon 1920 720 520 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image.imageset/top shelf.png"
padded_icon 1920 720 520 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image.imageset/top shelf-1.png"
padded_icon 3840 1440 1040 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image.imageset/Untitled-1.png"
padded_icon 3840 1440 1040 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image.imageset/Untitled-2.png"

padded_icon 2320 720 520 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image Wide.imageset/top shelf.png"
padded_icon 2320 720 520 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image Wide.imageset/top shelf-1.png"
padded_icon 4640 1440 1040 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image Wide.imageset/Untitled-1.png"
padded_icon 4640 1440 1040 "$ROOT/Swiftfin tvOS/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/Top Shelf Image Wide.imageset/Untitled-2.png"

echo "Markhor Apple branding assets generated."
