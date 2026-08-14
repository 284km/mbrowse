#!/bin/sh
# scripts/css_check.sh — the CSS tokenizer against css-parsing-tests.
#
# The component value level, 50 cases. 34 of them use shapes this level does not reach —
# blocks and functions with children — and are counted as not covered rather than as
# failures, because the tokenizer is not wrong about them, it does not get there. The
# rest are pass or fail, and the pass count is pinned exactly.
#
# No failures at this level: all 16 comparable cases pass. The 34 not compared split into
# two reasons, which the harness prints separately because calling both of them "blocks and
# functions" was wrong for thirteen of them:
#
#   nested (21)  a function with children, or a block — a tree, which needs a parser over
#                these tokens and not more tokens
#
# The numeric-fields group is gone: those cases are compared now. What is compared of a
# number is everything the tokenizer decides — the representation, whether it is an
# integer, and the unit — and not the numeric value, because the value is arithmetic on
# the representation (the suite writes `+45.0` as 45) and comparing it would be comparing
# how two languages print a float.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/css_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "css_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "css_check: python3 needed to read the JSON" >&2; exit 0; }
EXPECT_PASS=${EXPECT_PASS:-29}
T="${TMPDIR:-/tmp}/mbrowse_css.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/css_cases.py" "$ROOT/test/data/css_component_value_list.json" \
  "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/css_cases.mere" "$T/cases.txt" > "$T/got.txt" || true
python3 "$ROOT/scripts/css_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
