#!/bin/sh
# scripts/layout_check.sh — layout against box geometry from a real browser.
#
# 228 documents from web-platform-tests' CSS 2 normal-flow suite, with expected geometry
# committed next to each one. Both halves come from somewhere other than here: the documents
# were chosen by the people who wrote the specification, and the numbers were produced by an
# independent implementation.
#
# **Why not reftests.** The plan for this layer said WPT reftests, and reftests are the wrong
# gate to start with: a reftest compares two of YOUR OWN renderings, so an engine that draws
# nothing passes every one of them. That is the same trap as a window readback that hands back
# the pixels just written — it took poisoning the buffer to notice that one. Geometry from
# another engine cannot be passed by drawing nothing, because the numbers are specific.
# Reftests are still worth running later, for what they check that geometry does not: colour,
# stacking, and where the ink actually lands.
#
# **The expected values are committed, not generated here.** `gen_layout_expected.py` needs a
# browser; a gate that launches one fails for reasons that have nothing to do with the code. It
# has been run three times now over the whole corpus — twice at 126 documents and once at 228 —
# and every run agreed with the last on every byte of the documents they had in common, with a
# fixed viewport, no scrollbars and no device scaling. All three of those change the numbers.
#
# The pass count is pinned exactly rather than as a floor: a floor lets a regression hide behind
# a new pass.
#
# **What widening the corpus was for.** It went from 126 to 228 by adding the `inline-`,
# `inlines-` and `blocks-` families, and the reason to do it before finishing the last five
# failures is in the numbers it produced. At 126 documents exactly one used `display:
# inline-block`, so laying an inline-block out as if it were block-level cost one document and
# the comment in `src/layout.mere` saying it was wrong looked like a note for later. At 228 it
# is 32 of the 53 failures — the single largest thing missing — and it was the same defect the
# whole time. A corpus does not only tell you whether you are right. It tells you what to do
# next, and it is the only thing here that can.
#
# The taxonomy, re-derived from the failures at 204 of 228 with all 228 box sequences right. **It is re-derived every time and
# never carried forward**, because it has been wrong four times: it once named `font-size`,
# which not one document sets; then floats, which were a tenth of it; then anonymous boxes; then
# floats beside each other, which was really a formatting context dodging one.
#
#    6  a `<table>` sized wrong, all six of them documents whose table carries `height="200"` or
#       `valign="bottom"` — PRESENTATIONAL ATTRIBUTES, which are not mapped to style at all. The
#       cascade never sees them. That is a whole missing layer and not a layout bug.
#    4  the block-in-inline split, where a fragment wants to be taller than its line.
#   10  the rest, one or two documents each.
#
# **A note on how long this takes.** The engine is superlinear in the number of sibling INLINE elements:
# 40 spans in a paragraph take 1.5 seconds and 80 take 17. `inlines-004` has 130 of them and is the
# slowest document in the corpus by a long way. This was measured, and measured again against an
# earlier commit — 40 spans cost 1542ms then and 1594ms now — so it is not something the recent work
# introduced, and it has not been chased. A wall-clock number from this script is not evidence on its
# own: a run that took 2.5 hours and one that took 9 minutes were the same code on the same corpus,
# with a load average of 21 and of 1.
#
# **Both sides measure with the same font, and they have to.** The expectations were first taken with
# whatever font the browser defaulted to — on that machine a system font that cannot be
# redistributed and that nothing here can read — so the 18px line in them was a number from a file
# not in the repository. `scripts/vendor_font.sh` brings in Noto Sans Regular under the OFL, pinned
# by commit, and the generator injects it into every document and waits for
# `document.fonts.ready` before measuring. That waiting is the difference between measuring the
# vendored font and measuring the fallback, and a probe that fires early gets plausible numbers from
# the wrong file without saying so.
#
# It does change what the WPT documents test: they no longer exercise a reader's default font. That
# is the right trade, because a comparison against a font nobody has is not a comparison.
#
# So the next slice is the font's metrics, and after it this number should move a long way at once.
# What is NOT missing, and would have been the guess: the box model, the cascade, and collapsing.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/layout_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "layout_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/layout"
EXPECT_PASS=${EXPECT_PASS:-204}

T="${TMPDIR:-/tmp}/mbrowse_layout.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT

total=0; pass=0; fail=0; shape=0; shown=0
for f in "$DATA"/*.html; do
  exp="${f%.html}.expected"
  [ -f "$exp" ] || continue
  total=$((total + 1))
  "$MERE" "$ROOT/test/layout_cases.mere" "$f" > "$T/got.txt" 2>/dev/null || true
  # The program's own exit value is the last line of its output, and it is not a box.
  sed '$d' "$T/got.txt" > "$T/boxes.txt"
  # Two numbers, because they fail for different reasons and one of them is already right.
  # The box SEQUENCE — which elements generate boxes and in what order — is the parser and the
  # box tree; the GEOMETRY is layout. Reporting only the second would hide a broken parse behind
  # a missing property, and reporting only the first would call a blank page a success.
  cut -f1 "$exp" > "$T/want_tags.txt"
  cut -f1 "$T/boxes.txt" > "$T/got_tags.txt"
  if cmp -s "$T/want_tags.txt" "$T/got_tags.txt"; then shape=$((shape + 1)); fi
  if diff -q "$exp" "$T/boxes.txt" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      echo "  FAIL $(basename "$f")"
      diff "$exp" "$T/boxes.txt" 2>/dev/null | head -6 | sed 's/^/    /'
    fi
  fi
done

echo "layout: $pass passed, $fail failed, of $total documents"
echo "layout: $shape of $total have the right box sequence (the parser and the box tree)"
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "layout: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the engine growing"
  exit 1
fi
echo "layout: ok"
