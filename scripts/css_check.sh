#!/bin/sh
# scripts/css_check.sh — the CSS tokenizer against css-parsing-tests.
#
# The component value level, 50 cases. 34 of them use shapes this level does not reach —
# blocks and functions with children — and are counted as not covered rather than as
# failures, because the tokenizer is not wrong about them, it does not get there. The
# rest are pass or fail, and the pass count is pinned exactly.
#
# What the remaining failures need. The escape case is down to one difference: after six
# hex digits the escape ends whether or not a whitespace follows, so `\000030red` is the
# identifier `0red` and this splits it in two. The rest are url(), and the numeric edges.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/css_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "css_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "css_check: python3 needed to read the JSON" >&2; exit 0; }
EXPECT_PASS=${EXPECT_PASS:-13}
T="${TMPDIR:-/tmp}/mbrowse_css.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/css_cases.py" "$ROOT/test/data/css_component_value_list.json" \
  "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/css_cases.mere" "$T/cases.txt" > "$T/got.txt" || true
python3 "$ROOT/scripts/css_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
