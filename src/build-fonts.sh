#!/bin/bash
# build-fonts.sh -- regenerate the self-hosted font subsets in fonts/ and rewrite the
# @font-face block inside index.html and og.html (between the FONTS:BEGIN/FONTS:END markers).
#
#   *** THE SUBSET COVERS ONLY THE CHARACTERS THAT ARE ON THE PAGE RIGHT NOW. ***
#   Re-run this script whenever the copy changes -- any new character (a new caption, a new
#   tag, a new sentence in the letter, a new button label) has no glyph until you do, and the
#   browser will silently fall back to a system font for it.
#
# The character set is read out of index.html and og.html by chars.py: every text node and
# every text-bearing attribute (data-say, data-cap, alt, aria-label, the <title>), plus ASCII
# printable, the digits, the CJK punctuation the page uses, and · — ↓ → ✕.
#
# Upstream faces come from the Google Fonts CSS API, requested with a modern Chrome
# User-Agent so the URLs are woff2. For Noto Sans SC that API hands a modern browser ~100
# unicode-range slices per weight, which cannot be fed to pyftsubset as one font, so the
# request carries &text= and Google returns a single woff2 for our characters; pyftsubset
# then does the final pass (features, flavor) on it. Inter and IBM Plex Mono go the same way
# for consistency.
#
# Needs: curl, python3 with fontTools + brotli (pyftsubset on PATH).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
WORK="$HERE/.fontwork"
UP="$WORK/upstream"
rm -rf "$WORK"; mkdir -p "$UP" fonts

SRC=(index.html)
[ -f og.html ] && SRC+=(og.html)

# ---- 1. the character set -------------------------------------------------
python3 -I "$HERE/chars.py" --unicodes "${SRC[@]}" > "$WORK/unicodes.txt"
python3 -I "$HERE/chars.py" --text     "${SRC[@]}" > "$WORK/text.txt"
echo "characters on the page: $(python3 -I -c "import io;print(len(io.open('$WORK/text.txt',encoding='utf-8').read().rstrip(chr(10))))")"

# ---- 2. the faces we actually use ----------------------------------------
# Confirmed against index.html: the sans stack is asked for at 400 (body default),
# 500 (.brand, .said, .btn, .block h3) and 600 (h1, .why h2, .reasons li h3);
# the mono stack at 400 (.srcs, .bridge, .cap, .ver, .sign, figcaption) and 500
# (.brand, .block h3). No other weight, no italic -- so nothing else is fetched.
FACES=(
  "Inter|400|inter-400"
  "Inter|500|inter-500"
  "Inter|600|inter-600"
  "Noto Sans SC|400|noto-sans-sc-400"
  "Noto Sans SC|500|noto-sans-sc-500"
  "Noto Sans SC|600|noto-sans-sc-600"
  "IBM Plex Mono|400|ibm-plex-mono-400"
  "IBM Plex Mono|500|ibm-plex-mono-500"
)

rm -f fonts/*.woff2
CSS="$WORK/faces.css"
: > "$CSS"

for face in "${FACES[@]}"; do
  IFS='|' read -r family weight slug <<< "$face"
  curl -fsS -A "$UA" --get \
    --data-urlencode "family=${family}:wght@${weight}" \
    --data-urlencode "text@$WORK/text.txt" \
    --data "display=swap" \
    'https://fonts.googleapis.com/css2' -o "$WORK/$slug.css"
  url="$(grep -o 'https://fonts.gstatic.com/[^)]*' "$WORK/$slug.css" | head -1)"
  [ -n "$url" ] || { echo "no woff2 url for $family $weight" >&2; exit 1; }
  curl -fsS -A "$UA" "$url" -o "$UP/$slug.woff2"

  pyftsubset "$UP/$slug.woff2" \
    --unicodes-file="$WORK/unicodes.txt" \
    --layout-features=+tnum \
    --flavor=woff2 \
    --output-file="fonts/$slug.woff2"

  bytes=$(wc -c < "fonts/$slug.woff2" | tr -d ' ')
  glyphs=$(python3 -I -c "from fontTools.ttLib import TTFont;print(TTFont('fonts/$slug.woff2')['maxp'].numGlyphs)")
  printf '@font-face{font-family:"%s";font-style:normal;font-weight:%s;font-display:swap;src:url("fonts/%s.woff2") format("woff2")}\n' \
    "$family" "$weight" "$slug" >> "$CSS"
  printf '  %-22s %6s bytes  %4s glyphs\n' "$slug.woff2" "$bytes" "$glyphs"
done

# ---- 3. rewrite the @font-face block in place ----------------------------
for f in "${SRC[@]}"; do
  python3 -I - "$f" "$CSS" <<'PY'
import io, sys
page, cssfile = sys.argv[1], sys.argv[2]
s = io.open(page, encoding='utf-8').read()
css = io.open(cssfile, encoding='utf-8').read().strip('\n')
B, E = '/* FONTS:BEGIN */', '/* FONTS:END */'
i, j = s.find(B), s.find(E)
if i < 0 or j < 0:
    sys.exit('%s: FONTS:BEGIN / FONTS:END markers missing' % page)
io.open(page, 'w', encoding='utf-8').write(s[:i + len(B)] + '\n' + css + '\n' + s[j:])
print('  @font-face block written into', page)
PY
done

total=$(cat fonts/*.woff2 | wc -c | tr -d ' ')
echo "fonts/ total: $total bytes ($(python3 -I -c "print('%.1f' % ($total/1024))") KB) in $(ls fonts/*.woff2 | wc -l | tr -d ' ') files"
rm -rf "$WORK"
