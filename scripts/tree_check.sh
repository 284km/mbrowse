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

# The 13 remaining failures, grouped by what each one needs rather than by the tags it
# mentions — a keyword bucket over the input once said 51 for something a fix moved 2 of.
# None are exempted: an exemption bucket hides real failures the moment the feature lands.
#
#   4  the adoption agency on `<DIV> abc <B> def <I> ghi <P> jkl </B> mno </I>` and its three
#      longer siblings. Tracing the CURRENT algorithm by hand on this input gives a tree with
#      the cloned `<i>` containing the `<p>`; the suite wants them as siblings. Its own
#      `#errors` lines name `adoption-agency-1.3`, which is html5lib's numbering for an OLDER
#      version of the algorithm, so the disagreement may be the corpus's age rather than a bug
#      here. Not guessed at either way — the trace is written down, the question is open, and
#      the next step is the spec text and not another attempt.
#   4  the agency inside a table: `<a><table><a></table><p>` and friends. Step 15 inserts into
#      the common ancestor "at the appropriate place for inserting a node", which means FOSTER
#      PARENTING when that ancestor is a table, tbody, tfoot, thead or tr. The agency does a
#      plain reparent, and the foster logic it needs lives in the builder rather than in the
#      agency, so this is a refactor and not a line.
#   2  text that should merge across an agency rewrite (`<b><table><td></b><i></table>X`) and a
#      comment that should not follow the body (`...you</body><!--do-->`).
#   1  a `<marquee>` scope marker one level out.
#   2  `<script> <!-- </script> --> </script>` and the tokenizer's script-data escape states,
#      which are the html5lib tokenizer files this repository has not vendored.
#
EXPECT_PASS=${EXPECT_PASS:-176}

T="${TMPDIR:-/tmp}/mbrowse_tree.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
python3 "$ROOT/scripts/tree_cases.py" "$ROOT/test/data" "$T/cases.txt" "$T/meta.txt"
"$MERE" "$ROOT/test/tree_cases.mere" "$T/cases.txt" > "$T/got.txt"
python3 "$ROOT/scripts/tree_cases.py" --compare "$T/got.txt" "$T/meta.txt" "$EXPECT_PASS"
