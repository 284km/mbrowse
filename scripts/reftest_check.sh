#!/bin/sh
# scripts/reftest_check.sh — a test document and its reference, painted, compared.
#
# 109 pairs, taken from the `<link rel="match">` the WPT documents carry: the suite's authors said
# which two files must look the same, and both of each pair are already vendored here.
#
# **This gate has no oracle and does not need one.** Every other gate here asks "is this right" and
# answers it with something written by somebody else. This one asks "do these two pages look the
# same", and both sides of that are ours — so there is nothing to commit as an expectation and
# nothing to regenerate when the engine changes. Both are drawn at gate time and diffed.
#
# **Which is exactly why it could not come first.** An engine that draws nothing passes every reftest;
# that is the trap the window capability hit, where a readback handed back the pixels just written.
# The geometry has been independently checked against a browser for a long time now — 218 of 228 box
# geometries, 112 of 228 character positions — so a page that comes out blank would already be
# failing elsewhere, and this gate is free to check the three things geometry cannot: colour, what is
# painted over what, and whether the ink lands inside the box that was measured for it.
#
# The comparison is exact. Two renderings of the same content by the same engine have no reason to
# differ by a pixel, so a tolerance here would only hide a real difference.
#
# A page is painted as run-length rows — `count x rrggbb` — rather than as an image. The format has to
# be exact and diffable and does not have to be a picture, and a page is mostly one colour per row: a
# PPM of decimal triples is two megabytes where this is a few kilobytes, and a failing line names the
# row and the run, which is where to look.
#
# **61 of 109 pass**, and the failures are the layout ones seen from the other side: a test and its
# reference that lay out to different heights are two different pictures, and the box gate's own ten
# failures plus the character gate's ligatures account for the shape of it. A reftest cannot say WHICH
# number is wrong — that is what the other gates are for — it says that two pages disagree.
#
# **It is slow: about ninety minutes for the 109 pairs**, because painting asks the outline whether it
# covers each pixel of each glyph's box and there are 218 pages of them. That is the honest cost of
# the only gate here that draws, and it is not in the quick path — `check.sh` runs it last and it is
# the one to skip when iterating.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/reftest_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "reftest_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "reftest_check: python3 needed to read the pairs" >&2; exit 0; }
DATA="$ROOT/test/data/layout"

T="${TMPDIR:-/tmp}/mbrowse_reftest.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

python3 "$ROOT/scripts/reftest_pairs.py" "$DATA" > "$T/pairs.txt"

total=0; pass=0; fail=0; shown=0
while IFS='	' read -r a b; do
  [ -n "$a" ] || continue
  total=$((total + 1))
  "$MERE" "$ROOT/test/paint_cases.mere" "$DATA/$a" > "$T/a.txt" 2>/dev/null || true
  "$MERE" "$ROOT/test/paint_cases.mere" "$DATA/$b" > "$T/b.txt" 2>/dev/null || true
  sed '$d' "$T/a.txt" > "$T/a2.txt"; sed '$d' "$T/b.txt" > "$T/b2.txt"
  if cmp -s "$T/a2.txt" "$T/b2.txt"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      ra=$(grep -c '' "$T/a2.txt"); rb=$(grep -c '' "$T/b2.txt")
      echo "  FAIL $a vs $b  (${ra} rows vs ${rb})"
      diff "$T/a2.txt" "$T/b2.txt" 2>/dev/null | head -4 | cut -c1-110 | sed 's/^/    /'
    fi
  fi
done < "$T/pairs.txt"

echo "reftests: $pass passed, $fail failed, of $total pairs"
EXPECT_PASS=${EXPECT_PASS:-61}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "reftests: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the painter growing"
  exit 1
fi
echo "reftests: ok"
