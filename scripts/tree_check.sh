#!/bin/sh
# scripts/tree_check.sh — tree construction against html5lib-tests' corpus.
#
# 189 cases, pinned to the commit before that suite moved (see vendor_tests.sh). 185 pass. The
# pass count is pinned exactly rather than as a floor: a floor lets a regression hide
# behind a new pass.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/tree_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "tree_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "tree_check: python3 needed to read the .dat" >&2; exit 0; }

# The 4 remaining failures, re-derived from the diffs rather than carried forward — a keyword
# bucket over the input once said 51 for something a fix moved 2 of. None are exempted: an
# exemption bucket hides real failures the moment the feature lands.
#
#   4  the adoption agency on `<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I>` and its three
#      longer siblings. Everything about the tree is right except the ORDER of two of the div's
#      children: the emptied `<i>` and the `<p>` are siblings either way, and the suite wants the
#      `<i>` first. Step 14 of the current algorithm inserts the last node "at the appropriate
#      place with the common ancestor as the override target", which is after its last child —
#      giving what is produced here. The suite's own `#errors` lines name `adoption-agency-1.3`,
#      html5lib's numbering for an OLDER version of the algorithm, so this may be the corpus's
#      age rather than a bug. Not guessed at either way: the disagreement is one ordering, it is
#      written down, and the next step is the spec text and not another attempt.
#
EXPECT_PASS=${EXPECT_PASS:-185}

T="${TMPDIR:-/tmp}/mbrowse_tree.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/tree_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/tree_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/tree_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
