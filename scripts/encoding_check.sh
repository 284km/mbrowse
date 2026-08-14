#!/bin/sh
# scripts/encoding_check.sh — encoding sniffing against html5lib-tests' encoding suite.
#
# A normative corpus, which the hand-written cases in test/sniff_check.mere are not.
# The pass count is pinned exactly rather than as a floor: a floor lets a regression
# hide behind a new pass.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/encoding_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "encoding_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "encoding_check: python3 needed to read the .dat" >&2; exit 0; }

# That gap is closed upstream (the label table is the Standard's full 228 now), which
# moved this from 46 to 54. What fails now is the other direction: the prescan finds a
# declaration the suite says should not count — a `charset` that is not in a meta
# element, or one past the first 1024 bytes. The scanner is too willing, not too
# blind, which is a different fix.
EXPECT_PASS=${EXPECT_PASS:-54}

T="${TMPDIR:-/tmp}/mbrowse_enc.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/encoding_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/sniff_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/encoding_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
