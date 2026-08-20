#!/bin/sh
# scripts/fetch_check.sh — the bytes this browser gets off a socket, against the bytes curl gets.
#
# Everything else in this repository starts from a file on disk. A9 starts from a URL, and this is
# the gate on the piece in between: connect, verify the certificate, ask, and read until the peer is
# done.
#
# **The oracle is curl and the server is ours**, which is the only way this is reproducible. Fetching
# a live page compares against a moving target — a red run would mean "the page changed" as often as
# it means anything, and a green run on a machine with no network would mean nothing. So
# `scripts/fetch_server.py` serves a fixed corpus over real TLS from a certificate it generates, and
# both sides are pointed at the same port. No network, and a real handshake.
#
# **Five bodies, and each is here because something plausible fails on exactly one of them:**
#
#   small.html    the case almost anything passes
#   nul.bin       zero bytes in the body — `mem_to_str` stops at the first one, so this separates
#                 reading the arena as bytes from reading it as a string. Without it the whole
#                 `bytes` argument in `src/fetch.mere` is unchecked.
#   big.bin       200 KB, more than one 64 KB read. A client that reads once returns a prefix, and
#                 on loopback a small body arrives whole in one read and hides that.
#   chunked.html  no Content-Length, and one chunk's size line carries an extension.
#   slow.bin      written in two halves with a pause between. Small enough to fit one read and still
#                 requiring two, so a looping reader and a single-shot one differ here on size alone.
#   sjis.html     Shift_JIS, declared. Compared TWICE and for different reasons: as bytes, like the
#                 rest, and as the text it decodes to. The pipeline now sniffs and decodes every
#                 document it reads, and every other body in this repository is ASCII — so this is
#                 the only input that can tell a right encoding decision from a wrong one.
#
# **The comparison is on bytes, not on a decoded string**, so the subject writes its body to stdout
# through `print_bytes` and the two files are compared with `cmp`. A diff of text would agree about
# `nul.bin` while disagreeing about everything that matters.
#
# TLS is the native backend's one opt-in external dependency: declaring `tcp_starttls_verified` is
# what makes `mere -c` emit the OpenSSL runtime, so this build line has `-lssl -lcrypto` and no other
# gate here does.
#
# Usage:
#   MERE=/path/to/mere.exe sh scripts/fetch_check.sh
#   SSL_PREFIX=/opt/homebrew/opt/openssl@3 ...   (default: `brew --prefix openssl@3`, then /usr/local)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "fetch_check: no mere — set MERE=..." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "fetch_check: python3 needed for the server" >&2; exit 0; }
command -v curl    >/dev/null 2>&1 || { echo "fetch_check: curl needed as the oracle" >&2; exit 0; }
command -v openssl >/dev/null 2>&1 || { echo "fetch_check: openssl needed for the certificate" >&2; exit 0; }
cd "$ROOT"

SSL_PREFIX="${SSL_PREFIX:-$(brew --prefix openssl@3 2>/dev/null || echo /usr/local)}"
[ -f "$SSL_PREFIX/include/openssl/ssl.h" ] || {
  echo "fetch_check: no OpenSSL headers under $SSL_PREFIX — set SSL_PREFIX" >&2; exit 0; }

T="${TMPDIR:-/tmp}/mbrowse_fetch.$$"; mkdir -p "$T"
SRVPID=""
cleanup() { [ -n "$SRVPID" ] && kill "$SRVPID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT INT TERM

# --- build ---------------------------------------------------------------------
"$MERE" -c "$ROOT/test/fetch_cases.mere" > "$T/fetch.c"
clang -O2 "$T/fetch.c" -I"$SSL_PREFIX/include" -L"$SSL_PREFIX/lib" -lssl -lcrypto -lm -o "$T/fetch"

# --- server --------------------------------------------------------------------
# The gate reads the server's first line rather than sleeping: a fixed sleep is a flake on a loaded
# machine and a delay on an idle one. The read is bounded, because a gate that hangs reports nothing
# and spends the whole budget doing it.
mkfifo "$T/ready"
python3 "$ROOT/scripts/fetch_server.py" > "$T/ready" 2>"$T/srv.err" &
SRVPID=$!
LINE=""
i=0
while [ -z "$LINE" ] && [ "$i" -lt 100 ]; do
  LINE=$(dd if="$T/ready" bs=1024 count=1 2>/dev/null | head -1) || true
  i=$((i + 1))
done
[ -n "$LINE" ] || { echo "fetch_check: the server never announced a port"; cat "$T/srv.err" >&2; exit 1; }
PORT=$(echo "$LINE" | cut -d' ' -f1)
CA=$(echo "$LINE" | cut -d' ' -f2)
# 127.0.0.1 AND NOT `localhost`, which is not a preference. `localhost` resolves to `::1` first on
# this platform, and mere's `tcp_connect` takes the FIRST address `getaddrinfo` returns and gives up
# if it cannot reach it — it never walks `ai_next`. curl falls through to the IPv4 address and
# connects; this does not. The certificate carries both `DNS:localhost` and `IP:127.0.0.1` so that
# either spelling verifies, and the difference is purely the connect.
#
# The `localhost` spelling is kept below as an assertion about what happens TODAY, so that fixing it
# upstream makes this gate fail and say the assertion is stale rather than leaving a note that has
# quietly become false. See Q-16.
BASE="https://127.0.0.1:$PORT"

total=0; pass=0; fail=0
check() {  # $1 = path
  total=$((total + 1))
  curl -s --cacert "$CA" --max-time 20 "$BASE/$1" > "$T/want.bin" || true
  rm -f "$T/got.bin"
  "$T/fetch" "$BASE/$1" "$CA" "$T/got.bin" >/dev/null 2>"$T/got.err" || true
  [ -f "$T/got.bin" ] || : > "$T/got.bin"
  if cmp -s "$T/want.bin" "$T/got.bin"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "  FAIL $1  (curl $(wc -c < "$T/want.bin" | tr -d ' ') bytes, mbrowse $(wc -c < "$T/got.bin" | tr -d ' '))"
    head -c 120 "$T/got.err" | sed 's/^/    /'
  fi
}

for f in small.html nul.bin big.bin chunked.html slow.bin sjis.html; do check "$f"; done

# THE BYTES ARE NOT THE POINT FOR THIS ONE. Everything above compares what came off the socket; this
# compares what the document SAYS, which is the step the pipeline now takes and the corpus otherwise
# never exercises — every other body here is ASCII and decodes to itself whatever the encoding
# decision was.
#
# The oracle is python's own Shift_JIS decoder, and the subject is the same sniff-and-decode a
# document off disk goes through. Two independent implementations of one standard's table, compared
# on a document that is mojibake under the default and invalid under UTF-8.
total=$((total + 1))
rm -f "$T/text.txt"
# `head -1`, because mere prints a program's own result value after it runs — the same extra line
# that made four of the byte comparisons above off by exactly two until the body moved to a file.
enc=$("$T/fetch" "$BASE/sjis.html" "$CA" "$T/text.txt" text 2>"$T/text.err" | head -1 || true)
curl -s --cacert "$CA" --max-time 20 "$BASE/sjis.html" > "$T/sjis.bin" || true
python3 -c 'import sys; sys.stdout.write(open(sys.argv[1],"rb").read().decode("shift_jis"))' \
  "$T/sjis.bin" > "$T/text.want" 2>/dev/null || true
if [ "$enc" = "shift_jis" ] && cmp -s "$T/text.want" "$T/text.txt"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  # WHICH HALF WAS WRONG, because "did it refuse" and "did it say what was wrong" are different
  # questions and this one has two ways to fail. Poisoning the decode to ignore the sniffed answer
  # printed `sniffed shift_jis, wanted shift_jis` — a message about the half that was right.
  if [ "$enc" != "shift_jis" ]; then
    echo "  FAIL sjis.html — SNIFFED '$enc', wanted shift_jis (the declaration was not read)"
  else
    echo "  FAIL sjis.html — sniffed shift_jis and DECODED it as something else"
  fi
  diff "$T/text.want" "$T/text.txt" 2>/dev/null | head -4 | cut -c1-100 | sed 's/^/    /'
  head -c 120 "$T/text.err" | sed 's/^/    /'
fi

# A certificate this does not trust must be REFUSED, not fetched. Without this the gate says nothing
# about verification: `tcp_starttls` and `tcp_starttls_verified` pass every case above identically,
# so "the certificate is checked" would be a claim with no check under it.
total=$((total + 1))
if "$T/fetch" "$BASE/small.html" "" "" > "$T/sys.bin" 2>&1 && [ -s "$T/sys.bin" ] \
   && ! grep -q '^ERR' "$T/sys.bin"; then
  fail=$((fail + 1))
  echo "  FAIL verification — the system trust store accepted a certificate it has never seen"
else
  pass=$((pass + 1))
fi

# DOCUMENTED GAP, asserted rather than described. When `tcp_connect` learns to walk the address
# list, this stops failing and the gate says so.
total=$((total + 1))
if "$T/fetch" "https://localhost:$PORT/small.html" "$CA" "" 2>&1 | grep -q '^ERR connect failed'; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  echo "  STALE GAP — a name whose first address is unreachable now connects. tcp_connect walks the"
  echo "              address list; remove this case and Q-16, and drop the 127.0.0.1 note above."
fi

echo "fetch: $pass passed, $fail failed, of $total"
EXPECT_PASS=${EXPECT_PASS:-9}
if [ "$pass" -ne "$EXPECT_PASS" ]; then
  echo "fetch: expected exactly $EXPECT_PASS passing, got $pass"
  exit 1
fi
echo "fetch: ok"
