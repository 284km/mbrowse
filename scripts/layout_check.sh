#!/bin/sh
# scripts/layout_check.sh — layout against box geometry from a real browser.
#
# 126 documents from web-platform-tests' CSS 2 normal-flow suite, with expected geometry
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
# was run twice over all 126 documents and the two runs agreed on every byte, with a fixed
# viewport, no scrollbars and no device scaling — all three change the numbers.
#
# The pass count is pinned exactly rather than as a floor: a floor lets a regression hide behind
# a new pass.
#
# Ten of the 126 pass. Text has a height now — a line is `(ascender - descender + lineGap)` scaled,
# 22px for this font at 16px — and words wrap at the containing block's width, measured in font units
# so the comparison never rounds. What is left, in the order it is worth doing:
#
#   font-size        not resolved, so every `em` is 16px and every line 22. Several of these documents
#                    set it, and each one moves every number under it.
#   float            eleven documents use it and it is a layout mode, not a value.
#   position         thirty-five uses, same.
#   anonymous blocks a box with both text and block children is laid out as if it were all inline. The
#                    standard wraps the text in an anonymous block; this does not.
#   kerning          the font gate's four failures. Text is up to 1.5px wider here than in the browser,
#                    which is only visible when a line breaks near its limit.
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
EXPECT_PASS=${EXPECT_PASS:-10}

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
