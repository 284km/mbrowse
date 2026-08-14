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

# Most of what fails is one thing: the vendored label table lists only the encodings
# it can decode, so a page declaring iso-8859-2 reads as undeclared. Sniffing needs a
# label table that is complete whether or not a decoder exists for each entry — the
# same gap `utf-16` was, and larger.
EXPECT_PASS=${EXPECT_PASS:-46}

T="${TMPDIR:-/tmp}/mbrowse_enc.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/encoding_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/sniff_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/encoding_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
