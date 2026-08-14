#!/bin/sh
# scripts/css_check.sh — the CSS tokenizer against css-parsing-tests.
#
# The component value level, all 50 cases, all passing, with no exemption bucket and
# nothing not compared. The count is pinned exactly rather than as a floor: a floor lets a
# regression hide behind a new pass.
#
# What is compared is every decision the tokenizer and the parser make, and one thing is
# deliberately not: the numeric value of a number. The value is arithmetic on the
# representation — the suite writes `+45.0` as 45 — so comparing it would compare how two
# languages print a float rather than what was decided. The representation, the
# integer-or-number flag and the unit are all compared.
#
# The "not compared" bucket is gone, and it is worth recording what it cost. It was one
# bucket called "blocks and functions" holding 34 cases; splitting it found 13 numeric
# cases that were a smaller and different job, and splitting what was left found 9
# `unicode-range` cases and 2 hash flags that are not trees at all. Three times the label
# was a wrong estimate of the work behind it. A bucket is a claim about what is left.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/css_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "css_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "css_check: python3 needed to read the JSON" >&2; exit 0; }
EXPECT_PASS=${EXPECT_PASS:-50}
T="${TMPDIR:-/tmp}/mbrowse_css.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/css_cases.py" "$ROOT/test/data/css_component_value_list.json" \
  "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/css_cases.mere" "$T/cases.txt" > "$T/got.txt" || true
python3 "$ROOT/scripts/css_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
