#!/bin/sh
# scripts/compiled_check.sh — the engine, compiled, answering what the interpreter answers.
#
# Every other gate here runs interpreted. That is not a detail: it is why this engine went its
# whole life without being compiled once, and why `mere -c` on it produced 29 C errors the first
# time anybody asked — a library that only ever runs interpreted has untested portability and no
# gate is in a position to notice. (Q-18.)
#
# **"It compiles" is the weaker half of what this asks.** A backend can compile and answer
# differently, and that is the interesting failure: the interpreter is the oracle here, the same
# way it is for the language's own cross-backend parity. So the compiled binary is run over a
# sample of documents and its box output is compared to the interpreter's, line for line.
#
# The sample is small on purpose. Compiling the engine takes tens of seconds and the point is a
# tripwire, not coverage — the 228-document corpus is already checked interpreted, and what could
# newly break here is the compilation, which breaks for every document at once or none.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/compiled_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "compiled_check: no mere — set MERE=..." >&2; exit 1; }
command -v clang >/dev/null 2>&1 || { echo "compiled_check: no clang" >&2; exit 0; }
T="${TMPDIR:-/tmp}/mbrowse_compiled.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

# THE BUILD IS THE FIRST ASSERTION, and it says why when it fails rather than just that it did.
"$MERE" -c "$ROOT/test/layout_cases.mere" > "$T/e.c"
if ! clang -O2 -w -ferror-limit=0 "$T/e.c" -lm -o "$T/engine" 2> "$T/cc.err"; then
  echo "compiled_check: the engine does not compile — $(grep -c 'error:' "$T/cc.err" || true) errors"
  grep 'error:' "$T/cc.err" | sed 's/.*error: /  /' | sort | uniq -c | sort -rn | head -4
  exit 1
fi

DOCS="test/data/northstar/example-com/index.html
test/data/layout/inlines-002.html
test/data/layout/blocks-011.html
test/data/img/img-border-box.html"

total=0; pass=0; fail=0
for d in $DOCS; do
  [ -f "$d" ] || continue
  total=$((total + 1))
  "$MERE" "$ROOT/test/layout_cases.mere" "$d" 2>/dev/null | sed '$d' > "$T/interp.txt" || true
  "$T/engine" "$d" 2>/dev/null | sed '$d' > "$T/compiled.txt" || true
  if [ ! -s "$T/interp.txt" ]; then
    echo "  SKIP $d (the interpreter produced nothing to compare against)"
    total=$((total - 1)); continue
  fi
  if cmp -s "$T/interp.txt" "$T/compiled.txt"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  DIFF $d  (interp $(grep -c '' "$T/interp.txt") boxes, compiled $(grep -c '' "$T/compiled.txt"))"
    diff "$T/interp.txt" "$T/compiled.txt" 2>/dev/null | head -4 | sed 's/^/    /'
  fi
done

echo "compiled engine: $pass of $total documents answer what the interpreter answers"
EXPECT_PASS=${EXPECT_PASS:-4}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "compiled_check: expected exactly $EXPECT_PASS, got $pass"
  exit 1
fi
echo "compiled_check: ok"
