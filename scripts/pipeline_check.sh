#!/bin/sh
# scripts/pipeline_check.sh — the whole sentence, end to end, with no oracle.
#
# "Fetch a page over HTTPS, parse it, lay it out, and draw it in a window." Each of those four steps
# had a gate before `src/main.mere` existed and no program chained them, so nothing measured the
# chain. This does: it serves this repository's committed snapshot of a real page over real TLS,
# fetches it through the program, draws it, reads the WINDOW back — and requires the result to be
# identical to what the same program draws from the same bytes sitting on disk.
#
# **The two paths are each other's oracle.** There is no reference image here and none is needed. A
# URL and a path differ only in where the bytes came from; everything after that is one code path.
# So any disagreement is in the fetch, the decode, or something that depends on which of the two it
# was — and those are exactly the bugs no other gate here can see, because every other gate reads
# from disk.
#
# What it does NOT prove is that the picture is right. `reftest_check.sh`, `imgpaint_check.sh` and
# `northstar_check.sh` are the gates that answer that, two of them against a browser. This one
# answers a different question and the two must not be confused: a pipeline that is wrong in the
# same way twice passes here, which is precisely why the other gates exist.
#
# Prerequisites: mere, a C compiler, SDL2, OpenSSL, python3. Skips without any of them, the way the
# other optional gates upstream do.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/pipeline_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "pipeline_check: no mere — set MERE=..." >&2; exit 1; }
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
for t in "$CC" python3 sdl2-config; do
  command -v "$t" >/dev/null 2>&1 || {
    echo "pipeline_check: $t not found — skipping (this gate is optional)"; exit 0; }
done
SSL_PREFIX="${SSL_PREFIX:-$(brew --prefix openssl@3 2>/dev/null || echo /usr/local)}"
[ -f "$SSL_PREFIX/include/openssl/ssl.h" ] || {
  echo "pipeline_check: no OpenSSL headers under $SSL_PREFIX — skipping (this gate is optional)"; exit 0; }
command -v openssl >/dev/null 2>&1 || {
  echo "pipeline_check: openssl needed for the certificate — skipping"; exit 0; }

T="${TMPDIR:-/tmp}/mbrowse_pipeline.$$"; mkdir -p "$T"
# The trap must not CHANGE the answer. `wait` on the server we just killed made its status the
# script's status, so a passing gate exited 143 and `check.sh`, which runs under `set -e`, would have
# read the pass as a failure. So the status is saved first and exited with explicitly.
cleanup() {
  st=$?
  [ -n "${SRVPID:-}" ] && { kill "$SRVPID" 2>/dev/null || true; wait "$SRVPID" 2>/dev/null || true; }
  rm -rf "$T"
  exit "$st"
}
trap cleanup EXIT
cd "$ROOT"

# --- the program, compiled ------------------------------------------------------
# The same build the README gives, plus the TLS libraries. If this stops compiling the gate says so
# here rather than reporting a picture mismatch, which is a different bug wearing the same clothes.
"$MERE" -c "$ROOT/src/main.mere" > "$T/mbrowse.c"
if ! $CC -O2 -w -ferror-limit=0 "$T/mbrowse.c" -o "$T/mbrowse" \
     $(sdl2-config --cflags) $(sdl2-config --libs) \
     -I"$SSL_PREFIX/include" -L"$SSL_PREFIX/lib" -lssl -lcrypto -lm 2>"$T/cc.err"; then
  n=$(grep -c 'error:' "$T/cc.err" 2>/dev/null || true)
  case "$n" in ''|*[!0-9]*) n=0;; esac
  if [ "$n" -gt 0 ]; then
    echo "pipeline_check: src/main.mere does not compile — $n errors"
    grep 'error:' "$T/cc.err" | sed 's/.*error: /  /' | sort | uniq -c | sort -rn | head -4
  else
    echo "pipeline_check: the compiler failed without naming an error — CC=$CC"
    sed -n '1,4p' "$T/cc.err" | sed 's/^/  /'
    [ -s "$T/cc.err" ] || echo "  (it said nothing at all)"
  fi
  exit 1
fi

# --- the server ----------------------------------------------------------------
# Reads the server's announce line rather than sleeping, and bounds the read: a fixed sleep is a
# flake on a loaded machine, and a gate that hangs reports nothing while spending the whole budget.
mkfifo "$T/ready"
python3 "$ROOT/scripts/fetch_server.py" > "$T/ready" 2>"$T/srv.err" &
SRVPID=$!
LINE=""; i=0
while [ -z "$LINE" ] && [ "$i" -lt 100 ]; do
  LINE=$(dd if="$T/ready" bs=1024 count=1 2>/dev/null | head -1) || true
  i=$((i + 1))
done
[ -n "$LINE" ] || { echo "pipeline_check: the server never announced a port"; cat "$T/srv.err" >&2; exit 1; }
PORT=$(echo "$LINE" | cut -d' ' -f1)
CA=$(echo "$LINE" | cut -d' ' -f2)
# 127.0.0.1 and not `localhost`: `tcp_connect` takes the first address getaddrinfo returns and does
# not walk `ai_next`, and `localhost` resolves to ::1 first here. See Q-16.
URL="https://127.0.0.1:$PORT/example-com.html"
FILE="test/data/northstar/example-com/index.html"

# --- the two paths -------------------------------------------------------------
run() {  # $1 = target, $2 = output file
  # NO `sed '$d'` here, and the first version had one -- copied from `screen_check.sh`, where the
  # driver's final value IS printed by the runtime and has to be stripped. `src/main.mere` calls
  # `exit`, so nothing follows the picture and that `sed` was deleting the LAST ROW OF IT. Both
  # paths lost the same row, so they still compared equal: the row-count pin below is the only
  # reason this was found, on the gate's first run.
  SDL_VIDEODRIVER=dummy "$T/mbrowse" "$1" --ca "$CA" --capture > "$2" 2>"$2.err" || true
}
run "$URL"  "$T/net"
run "$FILE" "$T/disk"

net_rows=$(awk 'END{print NR}' "$T/net")
disk_rows=$(awk 'END{print NR}' "$T/disk")
echo "pipeline: fetched $net_rows rows over TLS, drew $disk_rows from disk"

fail=0
if [ "$disk_rows" -eq 0 ]; then
  echo "  FAIL the disk path drew nothing: $(head -1 "$T/disk.err" | cut -c1-70)"; fail=1
fi
if [ "$net_rows" -eq 0 ]; then
  echo "  FAIL the network path drew nothing: $(head -1 "$T/net.err" | cut -c1-70)"; fail=1
fi
if [ "$fail" -eq 0 ] && ! cmp -s "$T/net" "$T/disk"; then
  echo "  FAIL the two paths drew different pictures"
  diff "$T/net" "$T/disk" 2>/dev/null | head -4 | cut -c1-100 | sed 's/^/    /'
  fail=1
fi

# A picture of nothing would compare equal to a picture of nothing, so the row count is pinned too:
# the height comes from the layout of a real page and is the same number the north-star gate uses.
EXPECT_ROWS=${EXPECT_ROWS:-285}
if [ "$fail" -eq 0 ] && [ "$disk_rows" -ne "$EXPECT_ROWS" ]; then
  echo "  FAIL expected $EXPECT_ROWS rows, both paths drew $disk_rows"
  echo "        (a blank page agrees with a blank page — this is what stops that passing)"
  fail=1
fi

[ "$fail" -eq 0 ] || { echo "pipeline_check: failed"; exit 1; }
echo "pipeline_check: ok — HTTPS and disk draw the same $EXPECT_ROWS rows"
