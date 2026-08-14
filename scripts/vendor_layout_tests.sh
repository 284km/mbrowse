#!/bin/sh
# scripts/vendor_layout_tests.sh — layout test documents, from WPT, pinned to a commit.
#
# The inputs are web-platform-tests' CSS 2 normal-flow reftests. They are the right shape for
# a geometry gate and it is worth saying why: each one is a whole document with its CSS
# inline, no external stylesheet, no image, no script. So they can be laid out from the file
# alone, and they were chosen by the people who wrote the specification rather than by whoever
# is writing the layout engine.
#
# **They are renamed to `.html` on the way in.** The originals are `.xht`, which browsers hand
# to their XML parser, and this repository has an HTML parser. Renaming makes both sides parse
# the same document by the same rules — the self-closing `<link ... />` syntax in them is
# accepted by the HTML parser, so nothing is lost. Comparing an XML parse against an HTML
# parse would be measuring the wrong difference.
#
# Files that reference anything outside themselves are dropped rather than vendored broken: a
# document whose layout depends on a stylesheet that is not here has no correct answer.
#
# Pinned by SHA, not by branch. An oracle is a versioned dependency, and a corpus that moves
# under you turns a red build into an archaeology problem.
#
# Needs network. Maintenance command, not a gate. The expectations come from
# `gen_layout_expected.sh`, which needs a browser and is also not a gate.
#
#   sh scripts/vendor_layout_tests.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF=4832db47614f      # web-platform-tests, 2026-07-27
BASE="https://raw.githubusercontent.com/web-platform-tests/wpt/$REF/css/CSS2/normal-flow"
API="https://api.github.com/repos/web-platform-tests/wpt/contents/css/CSS2/normal-flow?ref=$REF"
OUT="$ROOT/test/data/layout"

command -v curl >/dev/null 2>&1 || { echo "vendor_layout_tests: needs curl" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "vendor_layout_tests: needs python3" >&2; exit 1; }

mkdir -p "$OUT"
T="${TMPDIR:-/tmp}/mbrowse_vendor_layout.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT

curl -fsSL --max-time 60 "$API" > "$T/list.json"

# The listing, the fetch and the filter are all one python program. A shell loop over two
# hundred names either assembles a command line too long for xargs or spawns two hundred
# processes, and neither is the interesting part of this script.
python3 "$ROOT/scripts/vendor_layout_tests.py" "$T/list.json" "$BASE" "$T" "$OUT"
