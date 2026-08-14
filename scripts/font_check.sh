#!/bin/sh
# scripts/font_check.sh — the TrueType metrics reader against a browser's own measurement.
#
# 29 strings, measured by `canvas.measureText` over the same font file this reads, in units of 1/100
# pixel at 16px. That oracle was chosen for two reasons: it already draws text correctly, and it reads
# the same bytes. A metrics reader checked against a table somebody typed has been checked against
# somebody typing.
#
# The strings separate the things that can each be wrong alone — one glyph, a repeated glyph, a space,
# digits, punctuation, an accented character that is two bytes of UTF-8, and a hundred-character run
# where rounding once and rounding per glyph diverge.
#
# All 29 pass. The four that used to fail were kerning, which was established by measurement rather than
# argument: asking the same browser for the same strings with `font-kerning: none` returned exactly the
# numbers this produced. Kerning is now read from GPOS — this font ships no `kern` table — and the four
# came back without touching anything else, which is what a diagnosis that was right looks like.
#
# The `kern` feature here also names a type 8 chained-context lookup, which is skipped. That is
# contextual kerning, and skipping it is a smaller error than guessing at it; it costs nothing on these
# 29 strings and the count would say if it started to.
#
# The header values and the line height are checked separately by `test/font_check.mere`, by hand,
# because a wrong read of them produces something plausible: `descender` read unsigned is 65243
# instead of -293, and the line height that follows is about a thousand pixels.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/font_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "font_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/font"
[ -f "$DATA/NotoSans-Regular.ttf" ] || { echo "font_check: no font — run scripts/vendor_font.sh" >&2; exit 1; }

T="${TMPDIR:-/tmp}/mbrowse_font.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT

# Run from the repository root so the font path inside the runner resolves.
cd "$ROOT"
"$MERE" "$ROOT/test/font_cases.mere" "$DATA/widths.cases" > "$T/raw.txt"
# The program's own exit value is the last line and is not a width.
sed '$d' "$T/raw.txt" > "$T/got.txt"

want=$(grep -c '' "$DATA/widths.expected")
got=$(grep -c '' "$T/got.txt")
if [ "$want" != "$got" ]; then
  echo "font: $got widths for $want strings — the runner and the corpus disagree on how many"
  exit 1
fi

pass=0; fail=0; shown=0
i=1
while [ "$i" -le "$want" ]; do
  w=$(sed -n "${i}p" "$DATA/widths.expected")
  g=$(sed -n "${i}p" "$T/got.txt")
  if [ "$w" = "$g" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 5 ]; then
      shown=$((shown + 1))
      s=$(sed -n "${i}p" "$DATA/widths.cases")
      echo "  FAIL $s: want $w, got $g (hundredths of a pixel)"
    fi
  fi
  i=$((i + 1))
done

echo "font_widths: $pass passed, $fail failed, of $want strings"
EXPECT_PASS=${EXPECT_PASS:-29}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "font_widths: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the reader growing"
  exit 1
fi
echo "font_widths: ok"
