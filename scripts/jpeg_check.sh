#!/bin/sh
# scripts/jpeg_check.sh — the baseline JPEG headers against an independent decoder.
#
# 6 files, read by libjpeg through Pillow and by `src/jpeg.mere` from the same bytes: size, component
# count, each component's id / sampling factors / quantisation table, and every table's 64 values.
#
# **Headers before pixels, which is the order the font took and for the same reason.** A wrong header
# produces a PLAUSIBLE picture — the right size in the wrong colours, or the right colours at half the
# resolution — and a gate that only compares pixels cannot say which of the two halves is wrong.
# Everything a header holds has exactly one answer, so this comparison needs no tolerance, and it is
# worth knowing the headers are right before anything harder is attempted.
#
# **The tables are compared in NATURAL order, not the file's.** A JPEG stores a quantisation table
# along the diagonals; every later step wants it in rows. Doing the un-zigzag on the way in makes the
# permutation something this gate can see — and it needs to be seen, because a table read along the
# wrong diagonal still produces a picture, which is the kind of wrong that survives being looked at.
#
# **Six files, and three of them exist because this gate was poisoned and let the poison through.** A
# gate that has only ever passed has not been shown to be a gate. Eight deliberate errors were put into
# `src/jpeg.mere` one at a time; the corpus started at three files and caught four of them:
#
#     width and height swapped                6 of 6 fail   caught from the start
#     quantisation table left in zigzag order  6 of 6 fail   caught from the start
#     component records strided by four        5 of 6 fail   caught from the start
#     the second DQT segment ignored           5 of 6 fail   caught from the start
#     the DQT's table number ignored           5 of 6 fail   caught from the start
#     the two nibbles of the sampling byte swapped   1 of 6  NEEDED flat422
#     every APPn stepped over by sixteen bytes       1 of 6  NEEDED flat422's neighbour, flatexif
#     the DQT precision bit ignored            passes        cannot be reached — see below
#     not stopping at the scan                 passes        cannot be reached — see below
#
# The nibble swap is the ordinary shape of this mistake and the original corpus could not see it,
# because 4:4:4 is 1,1 and 4:2:0 is 2,2 and both are symmetric. 4:2:2 is 2,1 and is not.
#
# The APPn one took two tries and the failed try is the more interesting. A long APP1 full of ZEROES
# did not catch it: this reader scans for the next `FF` rather than trusting lengths absolutely, so it
# resynchronises on the next real marker and a wrong skip costs nothing. It is only fatal when the
# payload has markers of its own — and a camera's EXIF contains a whole JPEG thumbnail, so the reader
# answers with the thumbnail's size and the thumbnail's tables. **A robustness property and a hole in
# the gate are the same fact seen twice**, and the file that shows it had to contain a real JPEG.
#
# **Two of the eight cannot be reached, and saying why is the point.** The precision bit needs a 16-bit
# quantisation table, which requires 12-bit samples, which this libjpeg was not built for — so the
# oracle cannot produce the input that would tell the two readings apart. And a baseline scan is byte-
# stuffed: after SOS the only `FF` pairs that occur are `FF 00` and the restart markers, so no well-
# formed baseline file contains anything after the scan that a header walker would mistake for a
# header. Stopping at SOS matters for damaged input and for progressive JPEG, and neither is in scope.
# Not "we did not check these" — there is no input in this world that would check them.
#
# One more branch is written and unreached: a single DQT segment may carry several tables one after
# another, and libjpeg writes each in its own segment, so the loop that walks them never goes round
# twice. It is kept because a file that does it is legal, and it is recorded because an unreached
# branch is an untested one.
#
# What this does NOT check: the scan. The entropy-coded data, the Huffman decode, dequantisation, the
# IDCT and the upsampler are all downstream of here and are a separate gate with a separate claim.
# `scripts/gen_jpeg_images.py` already makes the images flat-blocked so that gate can be exact when it
# is written; a general image cannot be, because no two IDCTs round alike.
#
# Regenerate the expectations with `python3 scripts/gen_jpeg_expected.py test/data/jpeg` — a
# maintenance command, not part of the gate. The answers are committed.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/jpeg_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "jpeg_check: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/jpeg"

T="${TMPDIR:-/tmp}/mbrowse_jpeg.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

"$MERE" "$ROOT/test/jpeg_cases.mere" "$DATA/headers.cases" > "$T/raw.txt"
sed '$d' "$T/raw.txt" > "$T/got.txt"

total=$(grep -c '' "$DATA/headers.expected")
pass=0; fail=0; shown=0; i=0
while IFS= read -r want; do
  i=$((i + 1))
  got=$(sed -n "${i}p" "$T/got.txt")
  name=$(sed -n "${i}p" "$DATA/headers.cases")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    if [ "$shown" -lt 3 ]; then
      shown=$((shown + 1))
      echo "  FAIL $name"
      echo "    want ${want}" | cut -c1-140
      echo "    got  ${got}" | cut -c1-140
    fi
  fi
done < "$DATA/headers.expected"

echo "jpeg headers: $pass passed, $fail failed, of $total files"
EXPECT_PASS=${EXPECT_PASS:-7}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "jpeg headers: expected exactly $EXPECT_PASS passing, got $pass"
  exit 1
fi
echo "jpeg headers: ok"
