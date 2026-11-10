#!/usr/bin/env python3
"""Every character the page can put on screen -- used by build-fonts.sh to subset.

Reads the rendered text of the given HTML files: all text nodes (skipping <style> and
<script>), plus the text-bearing attributes (data-say, data-cap, alt, aria-label, title),
plus the <title> element. index.html is an artifact source (no <head>/<body>), so for it
everything before the first </style> is treated as head material and only its <title>
counts.

Then adds, unconditionally: ASCII printable, the digits, the CJK punctuation the page
uses, and the glyphs the CSS/markup draw on their own -- · — ↓ → ✕.

    chars.py --unicodes a.html b.html   ->  U+0020,U+0021,...   (for pyftsubset)
    chars.py --text     a.html b.html   ->  the characters themselves (for &text=)
"""
import sys, re, io
from html.parser import HTMLParser

TEXT_ATTRS = {'data-say', 'data-cap', 'alt', 'aria-label', 'title'}
SKIP_TAGS = {'style', 'script'}

# drawn by the page itself rather than sitting in a text node we can see as content:
# the · separators, the em dash in the signature and the title, the ↓ hints, the ✕ close
ALWAYS = set('·—↓→✕')
# the CJK punctuation this copy uses, spelled out so a future edit that adds one of these
# is covered even before the copy lands
ALWAYS |= set('，。、：；？！「」（）《》“”‘’…～·【】〈〉')
ALWAYS |= set(chr(c) for c in range(0x20, 0x7f))   # ASCII printable, digits included


class Collect(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in SKIP_TAGS:
            self.skip += 1
        for k, v in attrs:
            if k in TEXT_ATTRS and v:
                self.out.append(v)

    def handle_startendtag(self, tag, attrs):
        for k, v in attrs:
            if k in TEXT_ATTRS and v:
                self.out.append(v)

    def handle_endtag(self, tag):
        if tag in SKIP_TAGS and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data)


def rendered_text(path):
    src = io.open(path, encoding='utf-8').read()
    pre = ''
    if '<!doctype' not in src[:200].lower() and '<html' not in src[:200].lower():
        # artifact source: head material is everything up to and including the first </style>
        cut = src.find('</style>')
        if cut >= 0:
            head, src = src[:cut], src[cut + len('</style>'):]
            m = re.search(r'<title>(.*?)</title>', head, re.S)
            if m:
                pre = m.group(1)
    p = Collect()
    p.feed(src)
    return pre + ''.join(p.out)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ('--unicodes', '--text'):
        sys.exit(__doc__)
    mode, paths = sys.argv[1], sys.argv[2:]
    chars = set(ALWAYS)
    for path in paths:
        chars |= set(rendered_text(path))
    # keep printable characters and the plain space; drop control chars, NBSP, ZWSP, etc.
    chars = {c for c in chars if c == ' ' or (c.isprintable() and not c.isspace())}
    chars.discard('​')
    chars.discard('﻿')
    ordered = sorted(chars)
    if mode == '--unicodes':
        sys.stdout.write(','.join('U+%04X' % ord(c) for c in ordered) + '\n')
    else:
        # no trailing newline: this goes straight into the &text= query parameter
        sys.stdout.write(''.join(ordered))


if __name__ == '__main__':
    main()
