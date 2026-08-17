#!/bin/sh
# scripts/check.sh — everything this repository can be held to, so far.
#
# Needs a built `mere` on PATH, or MERE pointing at one.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "check: no mere — set MERE=/path/to/mere.exe" >&2; exit 1; }
out=$("$MERE" "$ROOT/test/dom_check.mere"; "$MERE" "$ROOT/test/tree_check.mere"; "$MERE" "$ROOT/test/sniff_check.mere"; "$MERE" "$ROOT/test/nodes_check.mere"; "$MERE" "$ROOT/test/formatting_check.mere"; "$MERE" "$ROOT/test/aaa_check.mere"; "$MERE" "$ROOT/test/style_check.mere"; "$MERE" "$ROOT/test/font_check.mere")
echo "$out"
echo "$out" | grep -q MISMATCH && { echo "check: failed" >&2; exit 1; }
sh "$ROOT/scripts/css_check.sh"
sh "$ROOT/scripts/tree_check.sh"
sh "$ROOT/scripts/encoding_check.sh"
sh "$ROOT/scripts/font_check.sh"
sh "$ROOT/scripts/glyf_check.sh"
MODE=segments sh "$ROOT/scripts/glyf_check.sh"
MODE=raster sh "$ROOT/scripts/glyf_check.sh"
MODE=text sh "$ROOT/scripts/glyf_check.sh"
MODE=coverage sh "$ROOT/scripts/glyf_check.sh"
sh "$ROOT/scripts/layout_check.sh"
sh "$ROOT/scripts/glyphpos_check.sh"
sh "$ROOT/scripts/jpeg_check.sh"
# Last, and slowest by a long way: the only gate that draws.
sh "$ROOT/scripts/reftest_check.sh"
echo "check: ok"
