#!/bin/sh
# scripts/vendor_css_tests.sh — the CSS syntax corpus, pinned to a commit.
#
# css-parsing-tests is to CSS what html5lib-tests is to HTML: the JSON suite the
# implementations are measured against, at every level from component values up to a
# whole stylesheet. It is the gate, and it is being vendored **before** any parser is
# written — the sniffing work in this repository went 43 to 81 against a normative
# corpus while alternating between too permissive and too blind, and without one there
# was no way to know which side it was out on. CSS fails the same way.
#
# Pinned by SHA, and the repository moved once already (SimonSapin -> CourtBouillon),
# which is the second corpus in this project to move under a URL that then 404s.
#
# Needs network. Maintenance command, not a gate.
#
#   sh scripts/vendor_css_tests.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF=203ce36bffd617db7f118c551e32794561fb273d
BASE="https://raw.githubusercontent.com/CourtBouillon/css-parsing-tests/$REF"
OUT="$ROOT/test/data"
mkdir -p "$OUT"
for f in component_value_list declaration_list one_declaration one_rule rule_list stylesheet; do
  curl -sSf --max-time 60 "$BASE/$f.json" -o "$OUT/css_$f.json"
  echo "vendored css_$f.json"
done
echo "from css-parsing-tests@$REF"
