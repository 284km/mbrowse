#!/bin/sh
# scripts/questions_check.sh — hold OPEN_QUESTIONS.md to the same standard as the code.
#
# Every count in this repository is checked except the ones written in prose. `reftest_check.sh`
# pins `EXPECT_PASS` and fails if reality moves; `OPEN_QUESTIONS.md` said "61 pass" of "109 pairs"
# with "48 failures" for a day after the gate was pinned at 71 of 76, and nothing said so. A number
# written twice needs the second copy derived from the first or compared against it, and this is the
# comparison.
#
# There are two ways a question stops being true and they need different checks:
#
#   - Its NUMBERS drift, because the gate moved and the prose did not.
#   - Its SYMPTOM goes away, because somebody fixed it without closing the entry. `mere` grew the
#     same check after four of its questions turned out to have been fixed for several slices.
#
# So an entry may carry any of three lines, and this runs them:
#
#   - **Number:** `71` = `<command printing the current value>`
#         The literal must equal what the command prints. BOTH directions are a failure: a count
#         that is too low is as stale as one that is too high, and only one of them looks like
#         progress.
#
#   - **Reproduces when:** `<command>`
#         Exit 0 while the symptom is still present. A non-zero exit is a RETIRE candidate — the
#         thing the entry describes no longer happens.
#
#         The command reads its input as `$IN` and never names a path itself. That is what lets the
#         poison below run the SAME text.
#
#   - **Over:** `test/data/img/*.html`
#   - **Poisoned by adding:** `<the text of a file that HAS the symptom>`
#         Both required. A reproduction check answers "still open" when it finds nothing, and
#         finding nothing is also what a BROKEN check does — so the reassuring answer is the one a
#         vacuous check gives. This gate was poisoned five ways when it was written and caught four;
#         the one it missed was exactly that, a search term changed to something that appears
#         nowhere, reported as "still open, 13 checks held".
#
#         So the gate runs the reproduction expression TWICE: once with `$IN` as `Over`, where it
#         must succeed, and once with `$IN` as a copy of `Over` plus one file holding the added
#         text, where it must fail. The first version of this had the poison as its own command,
#         which meant the expression was written twice and poisoning one copy left the other to
#         report the gate healthy — the same defect, one level up.
#
#   - **Documents:** `a.html` `b.html` … in `LAYOUT_LIST`
#         Every document named must still be in that gate's failing list. Checked only when the
#         list is supplied, because producing one means running the slow gate; `check.sh` has them
#         in hand and passes them through. A document that has started passing is a RETIRE
#         candidate for the entry that claims it fails.
#
# An entry with none of the three is counted and named, so the hole is visible rather than absent.
# That number going up is the finding, the same way `mere`'s is.
#
# A CLOSED entry is skipped for `Reproduces when` — a closed question SHOULD stop reproducing — but
# its numbers are still checked, because a closed entry's counts are read as history and history
# that quietly changes is worse than history that is wrong.
#
# Usage:
#   MERE=/path/to/mere.exe sh scripts/questions_check.sh
#   LAYOUT_LIST=… REFTEST_LIST=… GLYPHPOS_LIST=… sh scripts/questions_check.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/OPEN_QUESTIONS.md"
cd "$ROOT"
[ -f "$DOC" ] || { echo "questions_check: no OPEN_QUESTIONS.md" >&2; exit 2; }

stale=0; retire=0; ok=0; unchecked=0; missing_list=0; names=""
r_cmd=""; r_over=""; r_add=""

# The three checks, each run for one entry. `q` is the entry's name, used in every message.
check_number() {  # $1 literal, $2 command
  got=$(eval "$2" 2>/dev/null | tr -d ' \n')
  if [ -z "$got" ]; then
    echo "  BROKEN   $q — the command for \`$1\` printed nothing: $2"
    stale=$((stale + 1))
  elif [ "$got" != "$1" ]; then
    echo "  STALE    $q — says $1, the repository says $got   ($2)"
    stale=$((stale + 1))
  else
    ok=$((ok + 1))
  fi
}

# Everything runs in a subshell: a command in the document may legitimately end in `exit`, and this
# gate reading its own report is not something to find out about later.
#
# An entry's three lines are collected and run together at the end of the entry, because the
# reproduction cannot be judged until the poison is known — a reproduction that succeeds and a
# poison that also succeeds is a check that cannot fail, and only the pair says so.
run_entry() {  # uses r_cmd, r_over, r_add
  [ -n "$r_cmd" ] || return 0
  if [ -z "$r_over" ] || [ -z "$r_add" ]; then
    echo "  UNPOISONED $q — a Reproduces line needs Over and Poisoned-by-adding, or it has never been shown to fail"
    stale=$((stale + 1)); return 0
  fi
  if ( IN="$r_over"; eval "$r_cmd" ) >/dev/null 2>&1; then
    ok=$((ok + 1))
  else
    echo "  RETIRE?  $q — the symptom does not reproduce   ($r_cmd  over  $r_over)"
    retire=$((retire + 1)); return 0
  fi
  d=$(mktemp -d) || return 0
  ( eval "cp $r_over \"$d/\"" ) >/dev/null 2>&1
  printf '%s\n' "$r_add" > "$d/zz-poison.html"
  if ( IN="$d/*"; eval "$r_cmd" ) >/dev/null 2>&1; then
    echo "  VACUOUS  $q — the same expression still says 'reproduces' over input that HAS the symptom"
    stale=$((stale + 1))
  else
    ok=$((ok + 1))
  fi
  rm -rf "$d"
}

check_documents() {  # $1 docs, $2 list variable name
  eval "list=\${$2:-}"
  if [ -z "$list" ] || [ ! -f "$list" ]; then
    missing_list=$((missing_list + 1))
    return 0
  fi
  for d in $1; do
    if grep -qF "$d" "$list"; then
      ok=$((ok + 1))
    else
      echo "  RETIRE?  $q — $d is no longer failing in $2"
      retire=$((retire + 1))
    fi
  done
}

q=""; closed=0; seen=0

flush() {
  [ -n "$q" ] || return 0
  run_entry; r_cmd=""; r_over=""; r_add=""
  # A CLOSED entry owes no reproduction — it SHOULD have stopped reproducing — so it is not a hole.
  # Its numbers are still checked above, because a closed entry is read as history and history that
  # quietly changes is worse than history that is wrong.
  [ "$seen" -eq 0 ] && [ "$closed" -eq 0 ] && { unchecked=$((unchecked + 1)); names="$names $q"; }
  q=""; seen=0; closed=0
}

# Read the document, splitting at each question. `line` keeps its backticks, so the fields are taken
# by expansion rather than by sed — an expression that has to escape backticks is a second place to
# be wrong about what the line says.
while IFS= read -r line; do
  case "$line" in
    "## Q-"*)
      flush
      # By expansion, not by sed: the titles contain an em dash, and whether sed can match one
      # depends on the locale of whoever runs this. A gate that reads a name differently on two
      # machines names the wrong question in its own report.
      q=${line#\#\# }; q=${q%% *}; q=${q%.}
      case "$line" in *CLOSED*) closed=1 ;; *) closed=0 ;; esac
      ;;
    *"**Number:**"*)
      [ -n "$q" ] || continue
      seen=1
      rest=${line#*\`}; lit=${rest%%\`*}
      rest=${rest#*= \`}; cmd=${rest%\`*}
      check_number "$lit" "$cmd"
      ;;
    *"**Reproduces when:**"*)
      [ -n "$q" ] || continue
      seen=1
      [ "$closed" -eq 1 ] && continue
      rest=${line#*\`}; r_cmd=${rest%\`*}
      ;;
    *"**Over:**"*)
      [ -n "$q" ] || continue
      rest=${line#*\`}; r_over=${rest%\`*}
      ;;
    *"**Poisoned by adding:**"*)
      [ -n "$q" ] || continue
      rest=${line#*\`}; r_add=${rest%\`*}
      ;;
    *"**Documents:**"*)
      [ -n "$q" ] || continue
      seen=1
      docs=$(printf '%s' "$line" | sed 's/.*\*\*Documents:\*\* //; s/ in `[A-Z_]*`.*//; s/`//g; s/,/ /g')
      var=$(printf '%s' "$line" | sed 's/.* in `\([A-Z_]*\)`.*/\1/')
      check_documents "$docs" "$var"
      ;;
  esac
done < "$DOC"
flush

echo "open questions: $ok checks held, $stale stale, $retire retire candidates, $unchecked not machine-checkable"
[ "$unchecked" -gt 0 ] && echo "  (nothing to run for:$names )"
[ "$missing_list" -gt 0 ] && echo "  ($missing_list document lists were not supplied — run through check.sh to include them)"
if [ "$stale" -gt 0 ] || [ "$retire" -gt 0 ]; then
  echo "questions_check: failed"
  exit 1
fi
echo "questions_check: ok"
