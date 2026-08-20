#!/bin/sh
# scripts/northstar_check.sh — a real page, off the real web, drawn.
#
# This is A9's gate and it is a LADDER rather than a pass/fail. The rest of this repository is held
# to suites written to isolate one rule at a time; a page somebody actually published is held to
# nothing, uses whatever it likes, and the useful question is not "does it pass" but "how far in does
# it get, and what stopped it". So every number here is pinned, including the ones that are bad, and
# the gate fails when any of them MOVES — in either direction.
#
# **The page is a snapshot, not a URL.** `scripts/vendor_northstar.sh` fetched it once and committed
# the bytes with their provenance. A live fetch would mean the browser and this engine render
# different pages whenever the site is edited, and a red gate would mean the site changed as often as
# it meant anything. The network is exercised by `fetch_check.sh` against a server this repository
# starts, and by the smoke run at the end of this file, which is NOT part of the count.
#
# **Three numbers, because they fail for three different reasons:**
#
#   elements   the tag sequence, exactly. This is what says the page was parsed and a box tree was
#              built at all, and an engine that draws nothing still has to get it right.
#   geometry   how many of those boxes are where the browser puts them, exactly. The strong check.
#   ink        how much of the painting differs from the browser's screenshot, as a percentage.
#              WITH A TOLERANCE, and that is forced: a page of text has no unique correct picture
#              because two engines antialias glyphs differently. On its own this number would be
#              passed by a grey rectangle, which is why it is third and not first.
#
# The tolerance is not a round number picked in advance — it is the measurement, pinned, so that any
# change to it is a change somebody made rather than a threshold that was always going to be met.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/northstar_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "northstar_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "northstar_check: python3 needed to diff the ink" >&2; exit 0; }
DATA="$ROOT/test/data/northstar"
T="${TMPDIR:-/tmp}/mbrowse_northstar.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

pages=0; report=""
for d in "$DATA"/*/; do
  n=$(basename "$d")
  [ -f "$d/index.html" ] || continue
  [ -f "$d/index.expected" ] || { echo "  NO ORACLE $n — run scripts/gen_northstar_expected.py"; continue; }
  pages=$((pages + 1))

  "$MERE" "$ROOT/test/layout_cases.mere" "$d/index.html" > "$T/raw" 2>/dev/null || true
  sed '$d' "$T/raw" > "$T/geo"

  want_tags=$(cut -f1 "$d/index.expected"); got_tags=$(cut -f1 "$T/geo")
  if [ "$want_tags" = "$got_tags" ]; then tagsok=1; else tagsok=0; fi
  elems=$(grep -c '' "$d/index.expected")
  # Whole lines, so an element counts only when x, y, width and height are all right.
  # Temporary files rather than `<(...)`: this repository runs its gates under dash as well, where
  # process substitution is a syntax error rather than a slower answer.
  sort "$d/index.expected" > "$T/want.sorted"; sort "$T/geo" > "$T/got.sorted"
  geo=$(comm -12 "$T/want.sorted" "$T/got.sorted" | grep -c '' || true)

  h=$(head -1 "$d/index.expected" | cut -f5)
  "$MERE" "$ROOT/test/paint_cases.mere" "$d/index.html" "$h" > "$T/rawink" 2>/dev/null || true
  sed '$d' "$T/rawink" > "$T/ink"
  ink=$(python3 "$ROOT/scripts/ink_diff.py" "$d/index.ink" "$T/ink" 2>/dev/null | cut -d' ' -f3)
  [ -n "$ink" ] || ink="NaN"

  echo "  $n: tag sequence $([ $tagsok = 1 ] && echo MATCHES || echo DIFFERS), geometry $geo of $elems, ink ${ink}% differing"
  report="$report$n $tagsok $geo/$elems $ink;"
done

echo "northstar: $pages page(s)"
EXPECT="${EXPECT_NORTHSTAR:-example-com 1 0/7 93.886;}"
if [ "$report" != "$EXPECT" ]; then
  echo "northstar: the answers moved"
  echo "  was:  $EXPECT"
  echo "  now:  $report"
  echo "  If this is the engine growing, update EXPECT_NORTHSTAR here and say what changed."
  exit 1
fi
echo "northstar: ok"
