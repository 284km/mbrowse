#!/bin/sh
# scripts/northstar_measure.sh — how long a real page takes, and how much memory it costs.
#
# **A report, not a gate, and that is deliberate.** Q-7 in `OPEN_QUESTIONS.md` records the reason
# from experience: the same code over the same corpus has taken nine minutes and two and a half hours
# in one sitting, at load averages of 1 and of 21. A wall-clock number with a threshold on it is a
# flake waiting for a busy machine, so nothing here fails — it prints, and the numbers are read by a
# person who knows what else was running.
#
# What makes it worth having anyway is that it is IN THE REPOSITORY. A measurement that exists only
# in somebody's terminal is not a measurement: the next person cannot reproduce it, and the version
# of the engine it described is not recoverable. This is the harness, committed, so a number can be
# taken again on purpose.
#
# **Compiled, not interpreted.** `now_ms` has no interpreter mock — it says so rather than returning
# a plausible zero — and A9's question is about the binary somebody would run. Every gate here runs
# interpreted, so this is the only place the pipeline is measured as native code.
#
# **Peak RSS is quantised and the report says so.** The region allocator grows by doubling, so the
# high-water mark lands on a power of two and a real improvement of a few per cent moves it by
# nothing at all. Read it for the order of magnitude; for anything finer, count allocated bytes.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/northstar_measure.sh [page-name ...]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "northstar_measure: no mere — set MERE=..." >&2; exit 1; }
DATA="$ROOT/test/data/northstar"
T="${TMPDIR:-/tmp}/mbrowse_measure.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

# THE BUILD IS PART OF THE REPORT. `mere -c` exits 0 and writes C that does not compile — see Q-18 —
# and a measurement script that swallowed that would print a table for a program that was never
# built, or a table from a stale binary, and either reads as a result.
"$MERE" -c "$ROOT/test/measure_cases.mere" > "$T/m.c"
if ! clang -O2 -ferror-limit=0 "$T/m.c" -lm -o "$T/m" 2> "$T/cc.err"; then
  n=$(grep -c 'error:' "$T/cc.err" || true)
  echo "northstar_measure: the generated C does not compile — $n errors. See Q-18."
  grep 'error:' "$T/cc.err" | sed 's/.*error: /  /' | sort | uniq -c | sort -rn | head -4
  # Single quotes: inside double quotes a backtick is command substitution, and the first version of
  # this line ran `now_ms` as a program and printed the message with a hole in it.
  echo '  No timings: now_ms has no interpreter mock, so there is nothing to measure until this builds.'
  exit 1
fi

pages="$*"
[ -n "$pages" ] || pages=$(cd "$DATA" && ls -d */ 2>/dev/null | tr -d /)

echo "page                 stage                 ms"
for n in $pages; do
  page="$DATA/$n/index.html"
  [ -f "$page" ] || { echo "  no such snapshot: $n" >&2; continue; }
  # `/usr/bin/time -l` for the high-water mark; the stage table comes from the program itself,
  # because a wrapper timing a stage measures the wrapper.
  /usr/bin/time -l "$T/m" "$page" > "$T/out" 2> "$T/rss" || true
  while IFS='	' read -r k v; do
    case "$k" in
      bytes|boxes|rows|ink-chars) ;;
      *) printf '%-20s %-20s %s\n' "$n" "$k" "$v" ;;
    esac
  done < "$T/out"
  rss=$(grep -i 'maximum resident' "$T/rss" | tr -dc '0-9' || true)
  [ -n "$rss" ] && printf '%-20s %-20s %s MiB (quantised — see the header)\n' "$n" "peak RSS" "$((rss / 1048576))"
  sizes=$(grep -E '^(bytes|boxes|rows|ink-chars)	' "$T/out" | tr '\t' '=' | tr '\n' ' ')
  printf '%-20s %-20s %s\n' "$n" "sizes" "$sizes"
done
