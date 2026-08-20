#!/bin/sh
# scripts/readme_check.sh — run the build instructions the README actually contains.
#
# The `## Building` section named `src/main.mere` for a long time and that file has never existed.
# Nobody noticed because nobody ran it: a build command in a README is a claim about the repository
# with none of the excuses a stale count has, since the thing it describes is one command away.
#
# So this extracts the fenced block under `## Building` FROM README.md at run time and executes it.
# Not a copy of it — a copy is a paraphrase, and a paraphrase tests the paraphrase. If someone edits
# the README, this runs what they wrote; if they write something that does not work, this is red.
#
# The block is run the way a reader would run it: from the repository root, with `mere` found on
# PATH under that name rather than through the `$MERE` this script was handed. A shim directory
# supplies it, so the commands need no rewriting and the block stays copy-pasteable.
#
# Skips without SDL2, because the block links against it.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/readme_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "readme_check: no mere — set MERE=..." >&2; exit 1; }
MERE_ABS="$(command -v "$MERE")"
command -v sdl2-config >/dev/null 2>&1 || {
  echo "readme_check: sdl2-config not found — skipping (this gate is optional)"; exit 0; }

T="${TMPDIR:-/tmp}/mbrowse_readme.$$"; mkdir -p "$T/bin"; trap 'rm -rf "$T"' EXIT
ln -sf "$MERE_ABS" "$T/bin/mere"

# Everything between the first ``` after `## Building` and the ``` that closes it.
awk '/^## Building/{s=1} s&&/^```/{n++; next} s&&n==1{print} n==2{exit}' "$ROOT/README.md" > "$T/block.sh"
# NOT `lines=$(grep -c '' ...)`: on an empty file `grep -c` PRINTS 0 and EXITS 1, and under `set -e`
# a failing command substitution in an assignment kills the script -- so deleting the build block
# made this gate die with an exit status and NOT ONE BYTE of output, which is the worst way for a
# check to fail. It was the poison that found it, which is the entire reason for poisoning.
lines=$(awk 'END{print NR}' "$T/block.sh")
if [ "$lines" -eq 0 ]; then
  echo "readme_check: found no build block under '## Building' in README.md"
  echo "  A README that gives no way to build is not a passing state for this gate."
  exit 1
fi
echo "readme_check: running the $lines lines the README gives"
sed 's/^/  | /' "$T/block.sh"

# The block writes `mbrowse.c` and `mbrowse` into the working directory. Both are gitignored, and
# it runs in a scratch directory anyway; the `cd` is what makes the relative paths in the block
# resolve, which is also what a reader has when they follow the instructions.
cd "$T"
ln -sf "$ROOT/test" test
if PATH="$T/bin:$PATH" sh -e "$T/block.sh" > "$T/out" 2>"$T/err"; then
  echo "readme_check: ok — the block builds and runs"
else
  echo "readme_check: the README's own build block FAILED"
  sed -n '1,6p' "$T/err" | sed 's/^/  /'
  sed -n '1,3p' "$T/out" | sed 's/^/  out: /'
  exit 1
fi
