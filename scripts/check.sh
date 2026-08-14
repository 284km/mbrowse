#!/bin/sh
# scripts/check.sh — everything this repository can be held to, so far.
#
# Needs a built `mere` on PATH, or MERE pointing at one.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "check: no mere — set MERE=/path/to/mere.exe" >&2; exit 1; }
out=$("$MERE" "$ROOT/test/dom_check.mere"; "$MERE" "$ROOT/test/tree_check.mere"; "$MERE" "$ROOT/test/sniff_check.mere")
echo "$out"
echo "$out" | grep -q MISMATCH && { echo "check: failed" >&2; exit 1; }
sh "$ROOT/scripts/tree_check.sh"
sh "$ROOT/scripts/encoding_check.sh"
echo "check: ok"
