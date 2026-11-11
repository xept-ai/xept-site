#!/bin/bash
# build-assets.sh <file.pdf> <page> <slug>
#
# Renders one page of a PDF into the two sizes the wall needs:
#   assets/<slug>.jpg      760px tall  -- the thumbnail the wall scrolls
#   assets/lg/<slug>.jpg  1700px tall  -- what the lightbox loads when a sheet is clicked
#
# The caption is not automatic: add the sheet to STRINGS.zh.wall / STRINGS.en.wall in
# index.html by hand (file name, intrinsic width, caption), then run build-site.sh.
#
# Needs: pdftoppm (brew install poppler) and sips (macOS).
set -euo pipefail
[ $# -eq 3 ] || { echo "usage: build-assets.sh <file.pdf> <page> <slug>" >&2; exit 1; }
PDF="$1"; PAGE="$2"; SLUG="$3"
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$HERE/assets/lg"
# 1400px wide is about 170dpi for A4: enough for both sizes below
pdftoppm -png -r 150 -scale-to-x 1400 -scale-to-y -1 -f "$PAGE" -l "$PAGE" "$PDF" "$TMP/p"
SRC="$(ls "$TMP"/p*.png | head -1)"
sips -s format jpeg -s formatOptions 82 -Z 760  "$SRC" --out "$HERE/assets/$SLUG.jpg"    >/dev/null
sips -s format jpeg -s formatOptions 78 -Z 1700 "$SRC" --out "$HERE/assets/lg/$SLUG.jpg" >/dev/null
w=$(sips -g pixelWidth "$HERE/assets/$SLUG.jpg" | awk '/pixelWidth/{print $2}')
echo "assets/$SLUG.jpg  ${w}×760  $(wc -c < "$HERE/assets/$SLUG.jpg" | tr -d ' ')B"
echo "assets/lg/$SLUG.jpg  $(sips -g pixelWidth "$HERE/assets/lg/$SLUG.jpg" | awk '/pixelWidth/{print $2}')×1700  $(wc -c < "$HERE/assets/lg/$SLUG.jpg" | tr -d ' ')B"
echo "→ 在 index.html 的 STRINGS.zh.wall / STRINGS.en.wall 里加一行：{ f: \"$SLUG.jpg\", w: $w, c: \"说明文字\" }"
