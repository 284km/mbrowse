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

# 46 -> 54 when the label table upstream became the Standard's full 228; 54 -> 67 when
# the prescan stopped reading `charset=` out of any attribute at all and started
# requiring the two forms the standard names. What fails now is the other direction
# again — declarations that should count and are not found. 67 -> 72 when a tag's end
# stopped being the first `>` and started being its own, and 72 -> 79 when the scan
# stopped stopping at 1024 bytes: the standard says it *may* be aborted there, and
# reading that as *does* loses the declaration on any page whose head opens with a
# long comment. Two left.
EXPECT_PASS=${EXPECT_PASS:-79}

T="${TMPDIR:-/tmp}/mbrowse_enc.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/encoding_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/sniff_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/encoding_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
