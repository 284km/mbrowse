#!/bin/sh
# scripts/glyphpos_check.sh — where each CHARACTER went, against a real browser's own answer.
#
# The box gate asks where each ELEMENT went. This asks where each character went, and they are
# different questions with different failures: a paragraph can be in exactly the right place with the
# words inside it in the wrong ones, and every box gate here would call that a pass. Layout computed
# these positions on every line it laid out and had no way to say them.
#
# The oracle is `Range.getBoundingClientRect` over the same 228 documents, taken once at vendoring
# time and committed — the same shape of oracle as the box gate's, asked a smaller question.
#
# **White space is skipped on both sides.** A space between two words has a rect in the browser and no
# glyph here: it is the gap an advance leaves, not something drawn. Comparing them would compare two
# ideas of what a space is; the characters either side of it still say whether the advance was right.
#
# **What this gate can see that no other one can.** Kerning reaches geometry here for the first time.
# A kern belongs BETWEEN two glyphs and moves the second, so the pen before a character has taken it
# into account and the width of the characters before it has not — one kern of difference, and every
# character after a kerned pair sits a pixel right of where it belongs. The widths gate cannot see it:
# it measures whole strings, and the ends of a string are in the right place however the middle is
# distributed.
#
# The pass count is pinned exactly rather than as a floor: a floor lets a regression hide behind a new
# pass.
#
# **112 of 228, against 218 for the boxes.** That gap is the whole reason this exists: 106 documents
# have every element box exactly where the browser puts it and at least one character somewhere else.
#
# What the failures are, derived from the diffs rather than guessed:
#
#   LIGATURES. The browser substitutes `fi` with one glyph through GSUB, so its two characters share
#   a rect and divide it differently. Nothing here does GSUB. This is a missing feature and not a
#   wrong number — the pair still occupies the same total width.
#
#   single-pixel drift along a long line, which is the same sub-pixel accumulation the box gate's
#   last four failures are, seen one character at a time instead of once at the end of a span.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/glyphpos_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "glyphpos_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/layout"

T="${TMPDIR:-/tmp}/mbrowse_glyphpos.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

total=0; pass=0; fail=0; shown=0
for f in "$DATA"/*.html; do
  exp="${f%.html}.glyphs"
  [ -f "$exp" ] || continue
  total=$((total + 1))
  "$MERE" "$ROOT/test/glyphpos_cases.mere" "$f" > "$T/raw.txt" 2>/dev/null || true
  # The program's own exit value is the last line and is not a glyph.
  sed '$d' "$T/raw.txt" > "$T/got.txt"
  if diff -q "$exp" "$T/got.txt" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      echo "  FAIL $(basename "$f")"
      diff "$exp" "$T/got.txt" 2>/dev/null | head -6 | sed 's/^/    /'
    fi
  fi
done

echo "glyph_positions: $pass passed, $fail failed, of $total documents"
EXPECT_PASS=${EXPECT_PASS:-112}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "glyph_positions: expected exactly $EXPECT_PASS passing, got $pass — raise EXPECT_PASS if this is the engine growing"
  exit 1
fi
echo "glyph_positions: ok"
