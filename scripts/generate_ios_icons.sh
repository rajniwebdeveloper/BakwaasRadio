#!/usr/bin/env bash
# Generate iOS app icons from assets/logo.png using macOS `sips`.
# Place this file at the project root and run:
# chmod +x scripts/generate_ios_icons.sh
# ./scripts/generate_ios_icons.sh

SRC="assets/logo.png"
DST_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$DST_DIR"

# Helper: generate a square icon of WxH
gen() {
  local H=$1
  local W=$2
  local OUT=$3
  if [ ! -f "$SRC" ]; then
    echo "Source image $SRC not found. Add your icon source at $SRC or edit this script." >&2
    exit 1
  fi
  sips -z $H $W "$SRC" --out "$DST_DIR/$OUT"
}

# iPhone
gen 120 120 "Icon-App-60x60@2x.png"
gen 180 180 "Icon-App-60x60@3x.png"

# iPad
gen 152 152 "Icon-App-76x76@2x.png"
gen 76 76 "Icon-App-76x76@1x.png"

# iPad Pro
gen 167 167 "Icon-App-83.5x83.5@2x.png"

# Small icons
gen 40 40 "Icon-App-40x40@2x.png"
gen 60 60 "Icon-App-40x40@3x.png"

# Notification / settings / spotlight sizes (optional)
gen 40 40 "Icon-App-20x20@2x.png"
gen 60 60 "Icon-App-20x20@3x.png"

# App Store marketing icon
gen 1024 1024 "Icon-App-1024x1024@1x.png"

echo "Generated icons in $DST_DIR. Open Xcode -> Runner -> Assets.xcassets to verify."
