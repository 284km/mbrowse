#!/bin/sh
# scripts/jpeg_pixels_check.sh — decoded JPEG pixels against libjpeg's, exactly.
#
# 7 files, every pixel, no tolerance. That the comparison can be exact at all is a property of the
# images: a JPEG's inverse DCT is an approximation and the standard requires only that two decoders
# agree within one, but a block of a single colour has nothing in it but the DC coefficient, and the
# inverse transform of that is the coefficient spread flat. libjpeg takes exactly that shortcut and so
# does `src/jpeg.mere`, so here the two agree to the bit and a tolerance would only hide a real error
# behind a difference of method.
#
# What that covers: the marker walk, the Huffman decode, dequantisation, the DC predictor across a
# whole scan, restart markers, the MCU interleave of three components, and the colour conversion.
# What it does not: the AC path beyond its end-of-block symbol, and the IDCT. See Q-10.
#
# **4:2:0 and 4:2:2 are here too, and the claim they carry is narrower.** The decoder has to invent the
# chroma samples the encoder threw away, and the standard does not say how; two correct decoders
# legitimately differ within one chroma sample of a chroma edge. So this part of the comparison is
# against libjpeg's triangle filter specifically — its weights, its rounding, its edge handling — and
# the honest statement of what passes is "the same as libjpeg", not "right". That is the widest claim
# there is anything to check, and it is worth checking: the alternative, repeating the nearest sample,
# is what leaves visible blocks at every chroma edge, and it misses 64 of the 231 lines.
#
# **Ten deliberate errors, eight caught.** A gate that has only passed has not been shown to be a gate:
#
#     the stuffed zero after a literal FF not skipped   99 of 231
#     blocks within an MCU taken column-first          198 of 231
#     restart markers not consumed                     198 of 231
#     nearest-neighbour instead of the triangle filter 167 of 231
#     the two quarter positions rounded the same way   215 of 231
#     the DC divided by eight without rounding         215 of 231
#     the vertical weights made 1:1 instead of 3:1     229 of 231
#     the nearer row taken on the wrong side           229 of 231
#     the empty-length sentinel in maxcode removed     231 of 231  — no answer can change; see below
#     the first and last column special cases removed  231 of 231  — no answer can change; see below
#
# The last two are not holes, and finding that out is why they were tried. Clamping the neighbour
# lookup at a row's edge already makes the general interpolation formula reduce to the edge value, so
# libjpeg's special cases are three rules where there is one; they have been deleted. And the
# empty-length sentinel cannot be reached on a well-formed stream by an invariant of canonical Huffman
# codes, so it is kept for corrupt input and not because any file here needs it.
#
# Two of the numbers are worth reading twice. The DC rounding took a file at quality 1 to catch,
# because at every other quality setting the quantised DC times its quantiser lands exactly on a
# multiple of eight for all 256 grey levels, and rounding and flooring agree. And 229 of 231 is what a
# real error looks like when the corpus barely touches it — the vertical weights only matter at a
# horizontal chroma edge, and there are two of those.
#
# The `ac=` on each header line is the number of non-zero AC coefficients the scan contained. It is
# zero for all four and the expectations say so, so the day a corpus image stops being flat this gate
# says which file and by how much, instead of the picture quietly changing underneath the claim above.
#
# Regenerate with `python3 scripts/gen_jpeg_pixels_expected.py test/data/jpeg`. Maintenance, not a
# gate — the answers are committed.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/jpeg_pixels_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "jpeg_pixels_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/jpeg"

T="${TMPDIR:-/tmp}/mbrowse_jpegpx.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

"$MERE" "$ROOT/test/jpeg_pixels_cases.mere" "$DATA/pixels.cases" > "$T/raw.txt" 2>/dev/null
sed '$d' "$T/raw.txt" > "$T/got.txt"

total=$(grep -c '' "$DATA/pixels.expected")
bad=$(diff "$T/got.txt" "$DATA/pixels.expected" 2>/dev/null | grep -c '^<' || true)
same=$((total - bad))
[ "$bad" -gt 0 ] && diff "$T/got.txt" "$DATA/pixels.expected" 2>/dev/null | head -6 | cut -c1-120 | sed 's/^/  /'

echo "jpeg pixels: $same of $total lines match"
EXPECT_LINES=${EXPECT_LINES:-231}
if [ "$same" -ne "$EXPECT_LINES" ] || [ "$total" -ne "$EXPECT_LINES" ]; then
  echo "jpeg pixels: expected all $EXPECT_LINES lines to match"
  exit 1
fi
echo "jpeg pixels: ok"
