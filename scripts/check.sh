#!/bin/sh
# scripts/check.sh — everything this repository can be held to, so far.
#
# Needs a built `mere` on PATH, or MERE pointing at one.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "check: no mere — set MERE=/path/to/mere.exe" >&2; exit 1; }
# ONE AT A TIME, AND A PROGRAM THAT DOES NOT RUN IS A FAILURE. These were a single command
# substitution whose output was searched for `MISMATCH`, which asks only "did a running program
# disagree with itself". A program that does not START has no output to disagree with: a type error
# prints to stderr, contributes no MISMATCH, and the list's exit status is the LAST program's — so a
# failure anywhere but the end was invisible.
#
# Measured when this was written: `formatting_check` had not compiled since 2026-08-14 and
# `style_check` since 2026-08-15, four and five days during which this line said ok. Both were the
# tests rotting while the source moved — `elem` gained a field, `Reconstruct.run` gained a parameter
# — which is exactly the drift a unit gate exists to catch and the one shape it could not see.
for t in dom tree sniff nodes formatting aaa style font; do
  if ! out=$("$MERE" "$ROOT/test/${t}_check.mere" 2>&1); then
    echo "$out"; echo "check: test/${t}_check.mere did not run" >&2; exit 1
  fi
  echo "$out"
  case "$out" in *MISMATCH*) echo "check: test/${t}_check.mere failed" >&2; exit 1 ;; esac
done
sh "$ROOT/scripts/css_check.sh"
sh "$ROOT/scripts/tree_check.sh"
sh "$ROOT/scripts/encoding_check.sh"
sh "$ROOT/scripts/font_check.sh"
sh "$ROOT/scripts/glyf_check.sh"
MODE=segments sh "$ROOT/scripts/glyf_check.sh"
MODE=raster sh "$ROOT/scripts/glyf_check.sh"
MODE=text sh "$ROOT/scripts/glyf_check.sh"
MODE=coverage sh "$ROOT/scripts/glyf_check.sh"
# The lists let `questions_check.sh` verify that the documents OPEN_QUESTIONS.md names as failing
# are still failing. Without them it can only check the counts.
QL="${TMPDIR:-/tmp}/mbrowse_layout_list.$$"; RL="${TMPDIR:-/tmp}/mbrowse_reftest_list.$$"
rm -f "$QL" "$RL"; trap 'rm -f "$QL" "$RL"' EXIT
LAYOUT_LIST="$QL" sh "$ROOT/scripts/layout_check.sh"
sh "$ROOT/scripts/img_check.sh"
sh "$ROOT/scripts/imgpaint_check.sh"
sh "$ROOT/scripts/glyphpos_check.sh"
sh "$ROOT/scripts/jpeg_check.sh"
sh "$ROOT/scripts/jpeg_pixels_check.sh"
sh "$ROOT/scripts/fetch_check.sh"
# A real page, off the real web, from a committed snapshot. Every number here is pinned
# including the bad ones — it is a ladder, and the gate fails when a rung MOVES either way.
sh "$ROOT/scripts/northstar_check.sh"
# The engine, compiled, answering what the interpreter answers. Every other gate here runs
# interpreted, which is how this engine went its whole life without being compiled once.
sh "$ROOT/scripts/compiled_check.sh"
# The pixels, on an actual window, read back out of the compositor. Compiled too, because the
# window capability has no interpreter mock. The readback is evidence and not a tautology only
# because the capability poisons the pixel block before asking SDL to fill it. Skips without SDL2.
sh "$ROOT/scripts/screen_check.sh"
# The window is the viewport now, not the document. Held against the document itself: row k of a
# window at `scroll_y` must be row `scroll_y + k`, so there is nothing to be an oracle for.
sh "$ROOT/scripts/scroll_check.sh"
# And the build instructions the README actually contains, extracted from it at run time rather
# than copied here. It named `src/main.mere` for a long time and that file has never existed.
sh "$ROOT/scripts/readme_check.sh"
# The whole sentence at the top of the README, end to end: the committed snapshot served over real
# TLS, fetched through src/main.mere, drawn, read back off the window, and required to equal what the
# same program draws from the same bytes on disk. No oracle -- the two paths are each other's.
sh "$ROOT/scripts/pipeline_check.sh"
# Last, and slowest by a long way: the only gate that draws.
REFTEST_LIST="$RL" sh "$ROOT/scripts/reftest_check.sh"
# After the gates, because it reads their lists: the counts and claims in OPEN_QUESTIONS.md, held to
# the same standard as the code. Everything else here is checked against something; this file was
# not, and Q-6 spent a day 10 pairs and 43 failures out of date as a result.
LAYOUT_LIST="$QL" REFTEST_LIST="$RL" sh "$ROOT/scripts/questions_check.sh"
echo "check: ok"
