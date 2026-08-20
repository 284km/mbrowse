#!/bin/sh
# scripts/screen_check.sh — the painter's pixels, on a window, read back and compared.
#
# The last step of A9 and the only one that opens anything. Everything else that looks at the
# drawing compares reference pixels and needs no display: the reftests compare two of our own
# renderings, `imgpaint_check.sh` compares against a browser's screenshot, and the north-star gate
# compares boxes against a browser's rects. So the question left for a window is the one none of
# them asks — **is what a compositor receives what the painter produced.**
#
# **A readback is normally not evidence, and here it is.** "The window's pixels match" would be a
# tautology if `show` wrote the image and `capture` handed the same memory back; this repository
# already recorded that trap for this capability. The capability closes it upstream by POISONING the
# pixel block before asking SDL for it, so a capture that short-circuits comes back as the poison
# rather than as the image.
#
# **The comparison reuses `Paint.render`.** The window's pixels are turned back into an `int Vec`
# and formatted by the same function whose output the reftests compare, rather than by a second
# run-length encoder written here. Two encoders agree until they do not, and the disagreement would
# read as a window bug.
#
# Compiled, not interpreted: `win_open` has no interpreter mock and says so rather than returning a
# plausible handle — the same refusal `now_ms` makes, and the same reason this has to be a binary.
#
# Runs under SDL's `dummy` video driver: a software renderer and a real event queue with no display,
# so it works in CI and does not open a window on your desktop while you are working. Skips when
# SDL2 is absent, the way the optional gates upstream do.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/screen_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "screen_check: no mere — set MERE=..." >&2; exit 1; }
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
command -v "$CC" >/dev/null 2>&1 || { echo "screen_check: no C compiler" >&2; exit 0; }
command -v sdl2-config >/dev/null 2>&1 || {
  echo "screen_check: sdl2-config not found — skipping (this gate is optional)"; exit 0; }
T="${TMPDIR:-/tmp}/mbrowse_screen.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

# The build is the first assertion and it says why when it fails.
"$MERE" -c "$ROOT/test/screen_cases.mere" > "$T/s.c"
if ! $CC -O2 -w -ferror-limit=0 $(sdl2-config --cflags) "$T/s.c" -o "$T/screen" $(sdl2-config --libs) -lm 2> "$T/cc.err"; then
  # Two ways to fail and they need different reports. Counting `error:` lines was the only one this
  # had, and running it with `CC=false` -- the cheapest way to reach a branch that had never been
  # reached -- printed "does not compile, 0 errors" and nothing else. A diagnostic that reports zero
  # of the thing that went wrong is worse than no diagnostic, so the fallback prints what was said.
  # `grep -c` on a file with no matches PRINTS 0 and EXITS 1, so `|| echo 0` appended a second line
  # and `[ "$n" -gt 0 ]` was handed "0\n0". Same family as reading `$?` through a pipe: one
  # expression answering twice. So the value is taken and then validated, never defaulted by `||`.
  n=$(grep -c 'error:' "$T/cc.err" 2>/dev/null || true)
  case "$n" in ''|*[!0-9]*) n=0;; esac
  if [ "$n" -gt 0 ]; then
    echo "screen_check: the window program does not compile — $n errors"
    grep 'error:' "$T/cc.err" | sed 's/.*error: /  /' | sort | uniq -c | sort -rn | head -4
  else
    echo "screen_check: the compiler failed without naming an error — CC=$CC"
    sed -n '1,4p' "$T/cc.err" | sed 's/^/  /'
    [ -s "$T/cc.err" ] || echo "  (it said nothing at all)"
  fi
  exit 1
fi
"$MERE" -c "$ROOT/test/paint_cases.mere" > "$T/p.c"
$CC -O2 -w "$T/p.c" -o "$T/painter" -lm

DOCS="test/data/layout/inlines-002.html
test/data/layout/blocks-011.html
test/data/northstar/example-com/index.html"

# NEITHER side is told how tall the page is. Both derive it from the layout they just ran, by the
# same rule -- the root box's height -- because `paint_cases.mere` falls back to exactly that when no
# height argument is given. The first version of this passed a height read out of the `.expected`
# file to the painter while the window program computed its own, and the two agreed; a gate whose two
# sides read the same number from two places reports the day they stop agreeing as a WINDOW bug.
total=0; pass=0; fail=0
for d in $DOCS; do
  [ -f "$d" ] || continue
  total=$((total + 1))
  SDL_VIDEODRIVER=dummy "$T/screen" "$d" --capture > "$T/win.txt" 2>"$T/win.err" || true
  sed '$d' "$T/win.txt" > "$T/win.rows"
  "$T/painter" "$d" > "$T/p.txt" 2>/dev/null || true
  sed '$d' "$T/p.txt" > "$T/p.rows"
  if [ ! -s "$T/win.rows" ]; then
    fail=$((fail + 1))
    echo "  FAIL $d — the window produced nothing: $(head -1 "$T/win.err" | cut -c1-70)"
  elif cmp -s "$T/win.rows" "$T/p.rows"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  DIFF $d  (window $(grep -c '' "$T/win.rows") rows, painter $(grep -c '' "$T/p.rows"))"
    diff "$T/win.rows" "$T/p.rows" 2>/dev/null | head -3 | cut -c1-100 | sed 's/^/    /'
  fi
done

echo "screen: $pass of $total pages reach the window unchanged"
EXPECT_PASS=${EXPECT_PASS:-3}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "screen_check: expected exactly $EXPECT_PASS, got $pass"
  exit 1
fi
echo "screen_check: ok"
