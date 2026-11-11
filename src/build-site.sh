#!/bin/bash
# build-site.sh -- turn the artifact source (index.html, which has no <!doctype>/<html>/
# <head>/<body> because the artifact platform injects them) into a deployable static site
# in ../site/.
#
# The split is purely positional: everything up to and including the FIRST </style> is head
# material, everything after it is body material. That is the artifact source's contract --
# <title>, <meta>, <style> first, then markup, then the scripts -- so nothing has to be
# parsed or rewritten and index.html stays the single source of truth.
#
# The deploy-only head tags (description, Open Graph, Twitter card, canonical, favicons,
# font preloads) live in this script, not in the artifact source: an artifact is served from
# a different origin under a different path, where absolute og:/canonical URLs and the font
# preload paths would be wrong.
#
# Needs: bash + coreutils only. Run it twice and the output is byte-identical.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$(cd "$HERE/.." && pwd)/site"
SRC="$HERE/index.html"

# ---- the split point: end of the first </style> --------------------------
off="$(LC_ALL=C grep -abo -m1 '</style>' "$SRC" | head -1 | cut -d: -f1)"
[ -n "$off" ] || { echo "build-site.sh: no </style> in $SRC" >&2; exit 1; }
end=$(( off + 8 ))   # 8 = length of "</style>"

rm -rf "$SITE"
mkdir -p "$SITE"

# ---- index.html ----------------------------------------------------------
{
  printf '<!doctype html>\n'
  printf '<html lang="zh-CN">\n'
  printf '<head>\n'
  printf '<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
  head -c "$end" "$SRC"
  printf '\n'
  cat <<'HEAD'
<meta name="description" content="装在你电脑上的学术写作工具：把你的材料和数据，写成能交出去的 Word 或 LaTeX 稿。免费，开源，不需要注册。">
<link rel="canonical" href="https://xept.pages.dev/">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Xept">
<meta property="og:title" content="Xept — 伴你写作">
<meta property="og:description" content="装在你电脑上的学术写作工具：把你的材料和数据，写成能交出去的 Word 或 LaTeX 稿。免费，开源，不需要注册。">
<meta property="og:url" content="https://xept.pages.dev/">
<meta property="og:image" content="https://xept.pages.dev/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Xept — 伴你写作">
<meta name="twitter:description" content="装在你电脑上的学术写作工具：把你的材料和数据，写成能交出去的 Word 或 LaTeX 稿。免费，开源，不需要注册。">
<meta name="twitter:image" content="https://xept.pages.dev/og.png">
<link rel="icon" href="favicon.svg" type="image/svg+xml">
<link rel="icon" href="icon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="preload" as="font" type="font/woff2" crossorigin href="fonts/noto-sans-sc-600.woff2">
<link rel="preload" as="font" type="font/woff2" crossorigin href="fonts/ibm-plex-mono-500.woff2">
HEAD
  printf '</head>\n'
  printf '<body>\n'
  tail -c "+$(( end + 1 ))" "$SRC"
  printf '</body>\n</html>\n'
} > "$SITE/index.html"

# ---- everything the page loads ------------------------------------------
cp -R "$HERE/assets" "$SITE/assets"
cp -R "$HERE/fonts"  "$SITE/fonts"
cp "$HERE/og.png" "$HERE/favicon.svg" "$HERE/icon-180.png" "$HERE/icon-32.png" "$SITE/"

# ---- what we wrote -------------------------------------------------------
echo "wrote $SITE"
( cd "$SITE" && find . -type f | LC_ALL=C sort | while read -r f; do
    printf '  %9s  %s\n' "$(wc -c < "$f" | tr -d ' ')" "${f#./}"
  done )
total=$( cd "$SITE" && find . -type f -exec cat {} + | wc -c | tr -d ' ' )
files=$( cd "$SITE" && find . -type f | wc -l | tr -d ' ' )
echo "  ---------"
echo "  $files files, $total bytes total"
