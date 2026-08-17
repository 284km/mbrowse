#!/bin/sh
# scripts/reftest_check.sh — a test document and its reference, painted, compared.
#
# 76 pairs, taken from the `<link rel="match">` the WPT documents carry: the suite's authors said
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
# **The denominator is 76, not 109, and finding that out was the whole of settling what the failures
# were.** A reftest needs no oracle for what a page should look like. It does need one for something
# else, and that had been assumed: whether the two files are a PAIR. `test/data/layout/reftest.browser`
# is the browser asked directly, and it renders 33 of the 109 differently itself.
#
# The reason is measured, not guessed: 25 of those 33 contain `<![CDATA[` and none of the 76 that match
# do. The originals are XHTML and were vendored as `.html`. In XHTML a CDATA section inside `<style>`
# is markup and vanishes; in HTML it is stylesheet text, so the first rule of the reference's
# stylesheet is eaten and the reference stops being a reference. **A file renamed is not a file
# converted.** The other 8 have some other cause and are not guessed at.
#
# So the earlier note here — that the failures were probably layout failures seen from the other side —
# was wrong, and it was wrong in the way a guess is: three had been looked at and 45 had not. The
# cross-reference is `scripts/reftest_why.py` and it needs `REFTEST_LIST=path` from this gate and
# `LAYOUT_LIST=path` from the layout gate; both write a list instead of a number.
#
# **61 of 76 pass.**
#
# The history is worth keeping because it is the same lesson three times over. 61 once the denominator
# was corrected. 66 once the painter walked the box list in CSS 2.1 Appendix E's order instead of
# document order. Then 57, when inline boxes were given the background and border they had never had —
# not a step backwards: an inline box SPLIT by a block child is several fragments and its border belongs
# to them severally, so drawing it correctly in the simple case is what made the split case visible.
# Then 61 again, with a box per fragment carrying its own share of the border.
#
# The four numbers are the same lesson from four sides. **Two pages that both omit something agree about
# it perfectly**, so every correct addition to the painter costs pairs before it gains them.
#
# **The 19 that fail:**
#
#     5   have a side that already fails the layout gate — a layout failure seen from the other side,
#         and nothing more to say about them here.
#     0   are painting order any more. That was six, and Appendix E's order fixed five of them; the
#         sixth was not paint order at all — an inline box's `background: green` painted NOTHING,
#         because the inline box was built with no background, no border and the block-level layer. A
#         missing feature that looked exactly like a wrong order, because only one of the two
#         overlapping boxes was ever drawn.
#    10   are BORDER FRAGMENTS, still. `block-in-inline-empty-*` and `block-in-inline-insert-012` to `-016`
#         compare two references that say
#         the same rendering two ways: one `display: inline` box containing block children, and the
#         same thing written out already split, with `border-right: none` on the first piece and
#         `border-left: none` on the last. An inline box broken by a block child becomes several
#         fragments and the border is divided among them — the left edge on the first, the right on the
#         last, none in between. This draws one border around one box.
#
# **Both of those only became visible because borders started being drawn.** Two pages that both omit
# a border agree about it perfectly. See Q-14 and Q-15.
#
# **It is slow: about an hour for the 76 pairs**, because painting asks the outline whether it
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

# Only the pairs the BROWSER renders identically. See `test/data/layout/reftest.browser` and the
# note above: 33 of the 109 are not pairs at all.
grep '^SAME' "$DATA/reftest.browser" | cut -f2,3 > "$T/pairs.txt"

total=0; pass=0; fail=0; shown=0
while IFS='	' read -r a b; do
  [ -n "$a" ] || continue
  total=$((total + 1))
  # Both at the SAME height — the taller of the two root boxes — because a page painted at its own
  # height has already discarded any ink below it, and an inline box taller than its line puts ink
  # there. Padding the shorter list with white afterwards cannot put back what was never drawn.
  ha=$(head -1 "$DATA/${a%.html}.expected" 2>/dev/null | cut -f5); hb=$(head -1 "$DATA/${b%.html}.expected" 2>/dev/null | cut -f5)
  ph=${ha:-1}; [ "${hb:-1}" -gt "$ph" ] 2>/dev/null && ph=$hb
  "$MERE" "$ROOT/test/paint_cases.mere" "$DATA/$a" "$ph" > "$T/a.txt" 2>/dev/null || true
  "$MERE" "$ROOT/test/paint_cases.mere" "$DATA/$b" "$ph" > "$T/b.txt" 2>/dev/null || true
  sed '$d' "$T/a.txt" > "$T/a2.txt"; sed '$d' "$T/b.txt" > "$T/b2.txt"
  # A reftest compares a VIEWPORT, not a document. Two pages a suite calls identical can lay out to
  # different total heights — the browser reports 216 and 136 for one of these pairs and still renders
  # them the same — so the shorter list is padded with white rows rather than the taller one truncated.
  # Painting the taller height directly was tried and is six times the work for the same answer.
  ra=$(grep -c '' "$T/a2.txt"); rb=$(grep -c '' "$T/b2.txt")
  n=$ra; [ "$rb" -gt "$n" ] && n=$rb
  i=$ra; while [ "$i" -lt "$n" ]; do echo "800xffffff" >> "$T/a2.txt"; i=$((i + 1)); done
  i=$rb; while [ "$i" -lt "$n" ]; do echo "800xffffff" >> "$T/b2.txt"; i=$((i + 1)); done
  if cmp -s "$T/a2.txt" "$T/b2.txt"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    [ -n "$REFTEST_LIST" ] && echo "$a	$b" >> "$REFTEST_LIST"
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
