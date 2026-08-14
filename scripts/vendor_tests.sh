#!/bin/sh
# scripts/vendor_tests.sh — the tree-construction corpus, pinned to a commit.
#
# html5lib-tests moved its tree-construction data to web-platform-tests on
# 2026-06-26 ("Tree construction tests have moved to WPT"), and the obvious paths in
# WPT do not have it in a form a harness can read. The last commit before that move
# still does, so that is where this takes it from — by SHA, not by branch.
#
# Pinning is not a workaround here, it is the correct form: an oracle is a versioned
# dependency, and a corpus that moves under you turns a red build into an
# archaeology problem. The SHA below says exactly what these cases are.
#
# Needs network. Maintenance command, not a gate.
#
#   sh scripts/vendor_tests.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF=9329e64694e7      # html5lib-tests, the commit before tree-construction moved
BASE="https://raw.githubusercontent.com/html5lib/html5lib-tests/$REF/tree-construction"
OUT="$ROOT/test/data"
mkdir -p "$OUT"
for f in tests1 tests2 tests3; do
  curl -sSf --max-time 60 "$BASE/$f.dat" -o "$OUT/tree_$f.dat"
  echo "vendored tree_$f.dat ($(grep -c '^#data' "$OUT/tree_$f.dat") cases)"
done
echo "from html5lib-tests@$REF"
