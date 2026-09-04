#!/bin/sh
# Package the approved raster artwork into macOS icon resolutions.
set -eu
cd "$(dirname "$0")/.."
icon_work=$(mktemp -d)
mkdir "$icon_work/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/Brand/app-icon.png --out "$icon_work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/Brand/app-icon.png --out "$icon_work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_work/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Built Resources/AppIcon.icns from Resources/Brand/app-icon.png"
