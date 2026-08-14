#!/bin/sh
# scripts/vendor_font.sh — the one font both sides of the layout gate use.
#
# The layout expectations could not be met without this and the reason is worth stating. A line of
# text is as tall as the font says it is, so the browser's numbers were the metrics of whatever
# font it happened to default to — on this machine a system font that cannot be redistributed and
# whose exact metrics nothing here can read. Comparing against them would be comparing against a
# file that is not in the repository.
#
# So the generator injects this font into every document, and both sides measure with it. That does
# change what the WPT documents test — they no longer exercise the reader's default font — and it
# is the right trade: a comparison against a font nobody has is not a comparison.
#
# Noto Sans Regular, hinted TTF, SIL Open Font License 1.1, pinned by commit. It has `glyf`
# outlines rather than CFF, which is what the plan for this repository picked and what the metrics
# reader here understands.
#
# Needs network. Maintenance command, not a gate.
#
#   sh scripts/vendor_font.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF=c971829a87e7920f960e7277c3dafd9bedd3c601   # googlefonts/noto-fonts, 2022-06-07
BASE="https://raw.githubusercontent.com/googlefonts/noto-fonts/$REF"
OUT="$ROOT/test/data/font"

command -v curl >/dev/null 2>&1 || { echo "vendor_font: needs curl" >&2; exit 1; }
mkdir -p "$OUT"
curl -fsSL --max-time 120 "$BASE/hinted/ttf/NotoSans/NotoSans-Regular.ttf" \
  -o "$OUT/NotoSans-Regular.ttf"
curl -fsSL --max-time 60 "$BASE/LICENSE" -o "$OUT/NotoSans-LICENSE.txt"
echo "vendor_font: $(wc -c < "$OUT/NotoSans-Regular.ttf") bytes"
