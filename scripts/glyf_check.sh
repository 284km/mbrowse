#!/bin/sh
# scripts/glyf_check.sh — glyph outlines against an independent reader of the same bytes.
#
# 13 glyphs, each chosen for one thing that can be read wrongly on its own: one contour and several,
# a contour that closes through an off-curve point, a composite built from two others, and a glyph
# with no contours at all — which is a real answer and not a failure.
#
# The oracle is fontTools, and the comparison is EXACT because both sides answer with the raw stored
# points: the coordinates as the file holds them, before any curve is flattened or any component
# placed. Comparing flattened shapes would compare two flattenings and agree about nothing.
#
# Why that matters more here than for the widths gate: a width is one number and a wrong reader tends
# to produce an obviously wrong one. An outline is hundreds of numbers, and a reader with the flag
# bits slightly wrong produces a shape that is ALMOST right — which looks like a font hint rather
# than like a bug.
#
# The three things this gate exists to catch, all of which produce a drawable wrong answer:
#
#   the repeat flag       one flag byte can stand for a run of points, so the flag array is shorter
#                         in the file than the number of points. Reading one byte per point walks
#                         off the end of it and into the coordinates.
#   the short-delta sign  an x delta stored in one byte is UNSIGNED, and its sign lives in a
#                         different flag bit. The same bit means "unchanged" when the delta is absent.
#   composite arg widths  the arguments are one byte or two by a flag, and a transform may follow
#                         that must be stepped over even though nothing reads it. Misjudge one
#                         component's size and every component after it is garbage.
#
# **The expected values are committed.** `gen_glyf_expected.py` needs fontTools; a gate that needs a
# Python package fails for reasons that have nothing to do with the code.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/glyf_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "glyf_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/font"
[ -f "$DATA/NotoSans-Regular.ttf" ] || { echo "glyf_check: no font — run scripts/vendor_font.sh" >&2; exit 1; }
[ -f "$DATA/outlines.expected" ] || { echo "glyf_check: no expectations — run gen_glyf_expected.py" >&2; exit 1; }

T="${TMPDIR:-/tmp}/mbrowse_glyf.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"
"$MERE" "$ROOT/test/glyf_cases.mere" "$DATA/outlines.cases" > "$T/raw.txt"
# The program's own exit value is the last line and is not an outline.
sed '$d' "$T/raw.txt" > "$T/got.txt"

want=$(grep -c '' "$DATA/outlines.expected")
got=$(grep -c '' "$T/got.txt")
if [ "$want" != "$got" ]; then
  echo "glyf: $got outlines for $want glyphs — the runner and the corpus disagree on how many"
  exit 1
fi

pass=0; fail=0; shown=0; i=1
while [ "$i" -le "$want" ]; do
  w=$(sed -n "${i}p" "$DATA/outlines.expected")
  g=$(sed -n "${i}p" "$T/got.txt")
  if [ "$w" = "$g" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      cp=$(sed -n "${i}p" "$DATA/outlines.cases")
      echo "  FAIL code point $cp"
      echo "    want: $(echo "$w" | cut -c1-100)"
      echo "    got:  $(echo "$g" | cut -c1-100)"
    fi
  fi
  i=$((i + 1))
done

echo "glyf_outlines: $pass passed, $fail failed, of $want glyphs"
EXPECT_PASS=${EXPECT_PASS:-13}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "glyf_outlines: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the reader growing"
  exit 1
fi
echo "glyf_outlines: ok"
