#!/bin/sh
# scripts/tree_check.sh — tree construction against html5lib-tests' corpus.
#
# 189 cases, pinned to the commit before that suite moved (see vendor_tests.sh). The
# pass count is pinned exactly rather than as a floor: a floor lets a regression hide
# behind a new pass.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/tree_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "tree_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "tree_check: python3 needed to read the .dat" >&2; exit 0; }

# What the 106 failures are, in order of how many: cases whose content starts in a
# non-Data tokenizer state (the builder cannot ask for one yet — `Tree.build` takes a
# token list, and by then the choice is made), the table insertion modes, foreign
# content, and the adoption agency algorithm. None of them are counted as anything
# but failures: an exemption bucket hides real failures the moment the feature lands.
EXPECT_PASS=${EXPECT_PASS:-83}

T="${TMPDIR:-/tmp}/mbrowse_tree.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/tree_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/tree_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/tree_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
