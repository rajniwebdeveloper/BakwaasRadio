#!/usr/bin/env bash
# Generate iOS, macOS and Android icons from `assets/logo.png` using macOS `sips`.
# Usage:
#   chmod +x scripts/generate_all_icons.sh
#   ./scripts/generate_all_icons.sh

set -euo pipefail

SRC="assets/logo.png"

if [ ! -f "$SRC" ]; then
  echo "Source image $SRC not found. Add your icon source at $SRC." >&2
  exit 1
fi

echo "Using source: $SRC"

# iOS AppIcon destination
IOS_DST="ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_DST"

gen() {
  local W=$1
  local H=$2
  local OUT=$3
  sips -z $H $W "$SRC" --out "$IOS_DST/$OUT" >/dev/null
}

echo "Generating iOS icons..."
gen 120 120 "Icon-App-60x60@2x.png"
gen 180 180 "Icon-App-60x60@3x.png"
gen 152 152 "Icon-App-76x76@2x.png"
gen 76 76 "Icon-App-76x76@1x.png"
gen 167 167 "Icon-App-83.5x83.5@2x.png"
gen 40 40 "Icon-App-40x40@2x.png"
gen 60 60 "Icon-App-40x40@3x.png"
gen 40 40 "Icon-App-20x20@2x.png"
gen 60 60 "Icon-App-20x20@3x.png"
gen 1024 1024 "Icon-App-1024x1024@1x.png"

echo "iOS icons generated at $IOS_DST"

# macOS AppIcon
MAC_DST="macos/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$MAC_DST"

echo "Generating macOS icons..."
# Sizes: 16,32,64,128,256,512,1024 (we'll name per Contents.json expected names)
sips -z 16 16 "$SRC" --out "$MAC_DST/app_icon_16.png" >/dev/null
sips -z 32 32 "$SRC" --out "$MAC_DST/app_icon_32.png" >/dev/null
sips -z 64 64 "$SRC" --out "$MAC_DST/app_icon_64.png" >/dev/null
sips -z 128 128 "$SRC" --out "$MAC_DST/app_icon_128.png" >/dev/null
sips -z 256 256 "$SRC" --out "$MAC_DST/app_icon_256.png" >/dev/null
sips -z 512 512 "$SRC" --out "$MAC_DST/app_icon_512.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$MAC_DST/app_icon_1024.png" >/dev/null

echo "macOS icons generated at $MAC_DST"


# Android mipmap icons (associative arrays not available on older macOS bash)
ANDROID_RES="android/app/src/main/res"
echo "Generating Android mipmap icons..."
pairs=( \
  "mipmap-mdpi:48" \
  "mipmap-hdpi:72" \
  "mipmap-xhdpi:96" \
  "mipmap-xxhdpi:144" \
  "mipmap-xxxhdpi:192" \
)
for p in "${pairs[@]}"; do
  dir="${p%%:*}"
  size="${p##*:}"
  target="$ANDROID_RES/$dir"
  mkdir -p "$target"
  sips -z "$size" "$size" "$SRC" --out "$target/ic_launcher.png" >/dev/null
done

echo "Android mipmap icons generated in $ANDROID_RES/mipmap-*"

echo "All icons generated. Verify in Xcode (iOS/macOS) and Android Studio (Android)."
