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
# **Three modes over the same 13 glyphs**, because there are three answers and they fail for different
# reasons. `MODE=points` compares the RAW stored points; `MODE=segments` compares what they become
# once the two unwritten rules are applied and composites are placed; `MODE=raster` compares which
# pixel CENTRES those segments enclose. A reader can get the points right and the segments wrong, and
# the segments right and the winding backwards.
#
# **Rasterising has no exact oracle** — two rasterisers antialias differently, so comparing grey
# levels compares their coverage heuristics and not the shape. The way out is to ask a weaker question
# of a stronger oracle: *is this pixel's centre inside, by the nonzero winding rule* has one answer,
# fontTools solves the curves to give it, and neither side is allowed a tolerance.
#
# What that does NOT check: coverage, antialiasing, hinting, and any pixel the outline only clips a
# corner of. Those need a different oracle and are not here. What it does check is the whole of the
# shape — a winding rule applied the wrong way round, a contour walked backwards, a curve solved on
# the wrong interval, a component at the wrong offset all move pixel centres.
#
# **What poisoning it showed.** Each of these was broken on purpose and the gate was re-run:
#
#   truncate the midpoint instead of rounding half away from zero   11 of 13 red
#   drop a component's offset                                        2 of 13 red
#   forget to shift a component's contour ends                       2 of 13 red
#   ignore that a contour can START on an off-curve point            NOTHING red
#
# and in `raster`:
#
#   count every crossing as +1, which is the even-odd rule                  12 of 13 red
#   take `t` on the closed interval, counting each join twice                1 of 13 red
#   take only one root of the quadratic                                     11 of 13 red
#
# `MODE=text` is the fourth, and it is the only one that uses the metrics and the outlines TOGETHER.
# Each has been checked alone — the advances against a browser, the outlines against fontTools — and
# neither check can see the join: a reader with the right widths and the right shapes still draws
# nonsense if it advances by the wrong one, or advances before drawing instead of after. Its strings
# have no kerned pairs in them, because kerning has its own gate and a gate asked to check two things
# cannot say which of them broke.
#
# `MODE=coverage` is the fifth and the only one that is not a yes-or-no. Coverage has an exact answer
# — the area of the intersection between a pixel square and the outline — and no two rasterisers
# approximate it the same way, so an oracle reporting its own approximation would be reporting an
# opinion. What is implemented and what is gated is therefore N x N SUBSAMPLE COVERAGE, which is a
# real antialiasing method with exactly one answer, and it is called by its name: its error against
# true area shrinks as N grows and is never zero. Naming it "area" would make this gate an excuse.
#
# The last one is the finding. **No glyph in this font starts a contour on an off-curve point** — not
# one of its 3,748, checked directly — so this corpus cannot see that rule at all, and the branch that
# implements it is written but NOT verified by anything here. It is kept because the format allows it
# and another font will use it; it is named here because a branch nothing can exercise is not a branch
# anything has checked, and the count above would otherwise be read as covering it.
#
# What would verify it: a second font that uses the construction, or a synthesised one. Neither is
# here.
#
# Usage:  MERE=/path/to/mere.exe [MODE=points|segments] sh scripts/glyf_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "glyf_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/font"
[ -f "$DATA/NotoSans-Regular.ttf" ] || { echo "glyf_check: no font — run scripts/vendor_font.sh" >&2; exit 1; }
[ -f "$DATA/outlines.expected" ] || { echo "glyf_check: no expectations — run gen_glyf_expected.py" >&2; exit 1; }

T="${TMPDIR:-/tmp}/mbrowse_glyf.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"
MODE="${MODE:-points}"
EXP="$DATA/outlines.expected"
[ "$MODE" = "segments" ] && EXP="$DATA/segments.expected"
[ "$MODE" = "raster" ] && EXP="$DATA/raster.expected"
# The text mode is a different corpus — strings, not glyphs — and a different runner.
CASES="$DATA/outlines.cases"; RUNNER="$ROOT/test/glyf_cases.mere"
if [ "$MODE" = "text" ]; then
  CASES="$DATA/textraster.cases"; EXP="$DATA/textraster.expected"
  RUNNER="$ROOT/test/textraster_cases.mere"
fi
if [ "$MODE" = "coverage" ]; then
  CASES="$DATA/coverage.cases"; EXP="$DATA/coverage.expected"
  RUNNER="$ROOT/test/coverage_cases.mere"
fi
"$MERE" "$RUNNER" "$CASES" "$MODE" > "$T/raw.txt"
# The program's own exit value is the last line and is not an outline.
sed '$d' "$T/raw.txt" > "$T/got.txt"

want=$(grep -c '' "$EXP")
got=$(grep -c '' "$T/got.txt")
if [ "$want" != "$got" ]; then
  echo "glyf: $got outlines for $want glyphs — the runner and the corpus disagree on how many"
  exit 1
fi

pass=0; fail=0; shown=0; i=1
while [ "$i" -le "$want" ]; do
  w=$(sed -n "${i}p" "$EXP")
  g=$(sed -n "${i}p" "$T/got.txt")
  if [ "$w" = "$g" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      cp=$(sed -n "${i}p" "$CASES")
      echo "  FAIL code point $cp"
      echo "    want: $(echo "$w" | cut -c1-100)"
      echo "    got:  $(echo "$g" | cut -c1-100)"
    fi
  fi
  i=$((i + 1))
done

echo "glyf_$MODE: $pass passed, $fail failed, of $want glyphs"
EXPECT_PASS=${EXPECT_PASS:-13}
[ "$MODE" = "text" ] && EXPECT_PASS="${EXPECT_PASS_TEXT:-6}"
[ "$MODE" = "coverage" ] && EXPECT_PASS="${EXPECT_PASS_COV:-6}"
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "glyf_$MODE: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the reader growing"
  exit 1
fi
echo "glyf_$MODE: ok"
