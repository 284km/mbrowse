#!/bin/sh
# scripts/img_check.sh — the box an image gets, against a browser's own rects.
#
# 21 documents covering what a replaced element's box depends on: the intrinsic size in the file, a
# width or a height attribute alone, both, CSS overriding the attribute, a percentage width, borders
# and padding and margins around it, `box-sizing` with and without a stated size, an image wider than
# its container, images on a line with text, display:block, a src that points at nothing, a src that
# points at a file that is not an image, and no src at all.
#
# **A replaced element is the one box whose size does not come from its content.** There is no text to
# measure and no children to stack; the number is in the file. Everything else here follows from that
# and from one rule that has no analogue anywhere else in CSS: when the page states exactly ONE of the
# two dimensions, the other is not the intrinsic value, it is the stated one scaled by the intrinsic
# RATIO. An image told to be twice as wide becomes twice as tall without being told to.
#
# **Fifteen deliberate errors, fifteen caught — but only after five documents were added.** Four
# poisons went straight through the first corpus, and each one was an input that was missing rather
# than a poison that was harmless:
#
#     the image put on the baseline instead of above it     1 of 21 survive
#     the base directory dropped from the src               6 of 21
#     a hidden inline no longer skipped on the line        12 of 21  (sequence 12 too)
#     the intrinsic ratio ignored                          15 of 21
#     `box-sizing` overridden to content-box always        17 of 21
#     a broken image given 0 by 0                          17 of 21
#     a missing src treated as a broken image              17 of 21
#     "is there a line" asked as "did the cursor move"     17 of 21
#     a block-level image left unsized                     17 of 21
#     `box-sizing` respected even for an intrinsic size    19 of 21  — NEEDED img-border-box-auto
#     a percentage width left unresolved                   19 of 21  — NEEDED img-pct-width
#     the JPEG magic number not checked                    19 of 21  — NEEDED img-not-an-image
#
# The last three each needed a document with a shape nothing else had: an image whose `box-sizing` is
# stated but whose size is not, a width in percent, and a `src` that names a file that exists and is
# not an image. Without them the code was passing on inputs it had never been given.
#
# One poison was removed rather than fixed. `..` used to be folded out of the joined path; breaking
# the fold changed no answer, because the filesystem resolves `a/../b` itself and nothing here reports
# the joined path to anyone. It was a second implementation of something already implemented.
#
# **20 of 21 geometries, and the one that fails is `max-width`, which is not implemented at all.** It
# is not an image property — it applies to every box — and adding it means adding it to the cascade,
# which is a change to the 228 documents next door and not to this. The document stays, and the count
# is pinned at 20 so that implementing it makes this gate fail and say so.
#
# **A separate corpus from `test/data/layout`, deliberately.** Adding these there would mean re-running
# the generator over all 228 documents to add one, regenerating the answers a pinned gate is currently
# held to, against whatever browser is installed today. A gate must not have its subject regenerated
# as a side effect of being added to.
#
# Two numbers, as everywhere else here: the box SEQUENCE and the GEOMETRY. They fail for different
# reasons — a missing box is a question about which elements generate boxes, a wrong rectangle is a
# question about arithmetic — and one number cannot say which happened. The sequence caught something
# the geometry could not have: a `<style>` in the body was being laid out as a line of text, because
# the LINE path had never learned about `display: none`. No document in the layout corpus puts a hidden
# inline beside a visible one, so nothing had ever asked.
#
# Regenerate with `python3 scripts/gen_img_expected.py test/data/img`. Maintenance, not a gate.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/img_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "img_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/img"
T="${TMPDIR:-/tmp}/mbrowse_img.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

total=0; seq_ok=0; geo_ok=0; shown=0
for h in "$DATA"/*.html; do
  n=$(basename "$h" .html)
  e="$DATA/$n.expected"
  [ -f "$e" ] || continue
  total=$((total + 1))
  "$MERE" "$ROOT/test/layout_cases.mere" "$h" > "$T/raw.txt" 2>/dev/null || true
  sed '$d' "$T/raw.txt" > "$T/got.txt"
  cut -f1 "$T/got.txt" > "$T/gs.txt"; cut -f1 "$e" > "$T/es.txt"
  if cmp -s "$T/gs.txt" "$T/es.txt"; then seq_ok=$((seq_ok + 1)); fi
  if cmp -s "$T/got.txt" "$e"; then
    geo_ok=$((geo_ok + 1))
  elif [ "$shown" -lt 4 ]; then
    shown=$((shown + 1))
    echo "  FAIL $n"
    diff "$T/got.txt" "$e" 2>/dev/null | head -4 | sed 's/^/    /'
  fi
done

echo "img boxes: sequence $seq_ok of $total, geometry $geo_ok of $total"
EXPECT_SEQ=${EXPECT_SEQ:-21}
EXPECT_GEO=${EXPECT_GEO:-20}
if [ "$seq_ok" -ne "$EXPECT_SEQ" ] || [ "$geo_ok" -ne "$EXPECT_GEO" ]; then
  echo "img boxes: expected sequence $EXPECT_SEQ and geometry $EXPECT_GEO"
  exit 1
fi
echo "img boxes: ok"
