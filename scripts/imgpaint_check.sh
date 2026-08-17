#!/bin/sh
# scripts/imgpaint_check.sh — the painted page against the browser's own screenshot.
#
# **The only gate here that compares DRAWING against something that is not us.** Every other painting
# check in this repository is a reftest — two of our own renderings, compared to each other — and that
# is not a choice, it is what is available: two engines antialias differently, so a page with text in
# it has no unique correct picture and nothing to compare against exactly.
#
# An image at its natural size antialiases nothing. Its pixels are the file's pixels, put where layout
# said. That was measured before this gate was built: Chrome's screenshot of an `<img>` and the decoded
# JPEG differ in 0 of 1536 pixels. So for these documents there IS a right answer, and it can be had
# from a browser.
#
# What that buys is the question the reftests cannot ask — **did the ink land where the box said, and
# is it the right ink** — settled against an outside party. A reftest can only say two pages disagree.
#
# The corpus is a subset of `test/data/img` and the exclusions are the limits, not laziness: documents
# with TEXT (glyph antialiasing has no unique answer) and documents that SCALE the image (resampling
# has no unique answer either — see Q-12). What is left is placement and colour.
#
# **8 of the 12, and the four that fail are two known things, both pinned rather than excluded.**
#
#   img-border, img-border-box-auto   borders are not painted at all. Not an image problem — no box in
#                                     this engine draws a border — and fixing it changes what the 109
#                                     reftests look like too. Q-13.
#   img-missing, img-not-an-image     the browser draws its broken-image icon and this does not. That
#                                     is a user-agent decoration, not a rule: the standard leaves it
#                                     open and other browsers show alt text or nothing. Its SIZE is
#                                     taken, because the size moves everything else on the page; its
#                                     picture is not, because it moves nothing.
#
# They stay in the corpus and the count is pinned so that painting a border or an icon makes this gate
# fail and say so, rather than a quietly excluded document never being looked at again.
#
# **The picture goes in the CONTENT box, not the box the gate reports.** `getBoundingClientRect` gives
# the border box, so every expectation in `test/data/img/*.expected` is a border box — and the picture
# sits inside the padding and the border. Painting it at the element's own rectangle is invisible until
# something has padding, and then it is forty rows wrong. Layout emits an ANONYMOUS box for the
# picture, which is what CSS calls a box with no element behind it, and the box-sequence gate filters
# on exactly that: a box with no tag is not an element.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/imgpaint_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "imgpaint_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/img"
T="${TMPDIR:-/tmp}/mbrowse_imgpaint.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

total=0; pass=0; shown=0
for e in "$DATA"/*.ink; do
  n=$(basename "$e" .ink)
  total=$((total + 1))
  "$MERE" "$ROOT/test/paint_cases.mere" "$DATA/$n.html" > "$T/raw.txt" 2>/dev/null || true
  sed '$d' "$T/raw.txt" > "$T/got.txt"
  if cmp -s "$T/got.txt" "$e"; then
    pass=$((pass + 1))
  elif [ "$shown" -lt 3 ]; then
    shown=$((shown + 1))
    ra=$(grep -c '' "$T/got.txt"); rb=$(grep -c '' "$e")
    echo "  FAIL $n  (${ra} rows vs ${rb})"
    diff "$T/got.txt" "$e" 2>/dev/null | head -4 | cut -c1-110 | sed 's/^/    /'
  fi
done

echo "image ink: $pass of $total documents"
EXPECT=${EXPECT:-8}
if [ "$pass" -ne "$EXPECT" ]; then
  echo "image ink: expected exactly $EXPECT"
  exit 1
fi
echo "image ink: ok"
