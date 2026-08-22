#!/bin/sh
# scripts/scroll_check.sh — a window onto a document, checked against the document.
#
# Until Q-19 was closed the viewport height was read by three unit conversions in `style.mere` and by
# no layout or paint decision anywhere, so a page 1202 pixels tall opened a window 1202 pixels tall
# on a viewport that is 513. `Paint.viewport` is the window, and this is how it is held to its claim.
#
# **The document is the oracle.** The claim is exactly "row k of a window at `scroll_y` is row
# `scroll_y + k` of the document", and the document is right there to ask, so there is no reference
# image and none is needed. Everything a slice can get wrong is an off-by-one, and an off-by-one
# against the thing itself is the one kind of defect this shape cannot miss.
#
# **One driver launch per document.** The first version asked one question per launch — ten launches
# per document, each re-doing layout from scratch — and ran ninety minutes without finishing its
# first document. A gate whose subject is a slicing function spent 90% of its budget re-deriving the
# thing being sliced, and a gate that takes two hours is a gate nobody runs. The driver now paints
# once and prints every section; this gate re-splits the output and does all the judging. The
# driver's `#SLICE n` headers are CLAIMS, and the expected offsets are recomputed here from `#DIMS`:
# a driver that quietly chose easier offsets would otherwise be testing something else under the
# right names.
#
# Four properties, and the first is the one that makes the rest mean something:
#
#   1. IDENTITY — a window as tall as the document IS the document. If this fails, every other
#      comparison below is between two wrong things and might well agree.
#   2. ALIGNMENT — a window of H rows at offset S equals rows S+1..S+H of the document, at offset 0,
#      an odd offset, and the last legal one.
#   3. CLAMPING — an offset past the end gives the LAST window, a negative one the first. Checked
#      twice over: the offset the code chose AND the pixels it produced.
#   4. SHORT DOCUMENTS — a viewport taller than the document gives the document, never padding.
#
# Usage:  MERE=/path/to/mere.exe sh scripts/scroll_check.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERE="${MERE:-mere}"
command -v "$MERE" >/dev/null 2>&1 || { echo "scroll_check: no mere — set MERE=..." >&2; exit 1; }
CC="${CC:-clang}"; command -v "$CC" >/dev/null 2>&1 || CC=cc
command -v "$CC" >/dev/null 2>&1 || { echo "scroll_check: no C compiler — skipping (optional)"; exit 0; }
T="${TMPDIR:-/tmp}/mbrowse_scroll.$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cd "$ROOT"

# COMPILED, and that is a measured decision, not a preference: interpreted, one tall document did
# not finish in ten minutes, because `Paint.render` builds ~3M pixels of run-length text per
# document and string-building is what the interpreter is worst at. Compiled it is 0.09s. The
# driver imports `paint.mere` directly (never `screen.mere`) precisely so this build needs no SDL.
"$MERE" -c "$ROOT/test/scroll_cases.mere" > "$T/d.c"
$CC -O2 -w "$T/d.c" -o "$T/driver" -lm

# Documents TALLER than the viewport, which is the only place most of this is observable, plus one
# shorter one so property 4 is exercised rather than assumed. Named rather than discovered, so a
# corpus change that removes one is a failure here and not a silent skip.
TALL="test/data/layout/inline-block-002.html
test/data/layout/inline-block-003.html
test/data/layout/inline-block-004.html
test/data/layout/inline-block-005.html"
SHORT="test/data/northstar/example-com/index.html"

total=0; pass=0; fail=0
ok()  { total=$((total + 1)); pass=$((pass + 1)); }
bad() { total=$((total + 1)); fail=$((fail + 1)); echo "  FAIL $1"; }

for d in $TALL $SHORT; do
  [ -f "$d" ] || { bad "$d is not in the corpus any more"; continue; }
  "$T/driver" "$d" > "$T/all" 2>"$T/err" || {
    bad "$d: the driver died: $(head -1 "$T/err" | cut -c1-70)"; continue; }

  # Split on the `#` markers: each section to its own file, CLAMP lines to one list.
  rm -f "$T"/sec_* "$T/clamps"; : > "$T/clamps"
  # Three marker shapes, and the first version conflated two of them: `#DIMS w h vp` CARRIES its
  # values on the marker line, `#SLICE n` NAMES a section by its argument -- one rule for both
  # turned DIMS into a section called DIMS_800 holding nothing, and every document failed with
  # "no #DIMS section" on the gate's first compiled run.
  awk -v dir="$T" '
    /^#DIMS /   { print $2, $3, $4 > (dir "/sec_DIMS"); name = ""; next }
    /^#CLAMP /  { print $2, $3 >> (dir "/clamps"); next }
    /^#/        { name = substr($1, 2); if ($2 != "") name = name "_" $2
                  out = dir "/sec_" name; printf "" > out; next }
    name != ""  { print >> (dir "/sec_" name) }
  ' "$T/all"

  dims=$(cat "$T/sec_DIMS" 2>/dev/null || true)
  doc=$(echo "$dims" | cut -d' ' -f2); vp=$(echo "$dims" | cut -d' ' -f3)
  case "$vp" in ''|*[!0-9]*) bad "$d: no viewport in #DIMS"; continue;; esac
  case "$doc" in ''|*[!0-9]*) bad "$d: no #DIMS section"; continue;; esac
  full_rows=$(awk 'END{print NR}' "$T/sec_FULL")
  if [ "$full_rows" -ne "$doc" ]; then
    bad "$d: painted $full_rows rows but the layout says $doc"; continue
  fi

  # 1. IDENTITY.
  if cmp -s "$T/sec_IDENTITY" "$T/sec_FULL"; then ok
  else bad "$d: a window as tall as the document is not the document"; fi

  if [ "$doc" -le "$vp" ]; then
    # 4. SHORT DOCUMENT.
    if cmp -s "$T/sec_SHORT" "$T/sec_FULL"; then ok
    else bad "$d: a $vp-row viewport onto a $doc-row document is not the document"; fi
    printf '  %-46s %4s rows, under the %s viewport\n' "$d" "$doc" "$vp"
    continue
  fi

  # 2. ALIGNMENT — at offsets THIS GATE derives, not offsets the driver picked.
  last=$((doc - vp))
  for s in 0 37 "$last"; do
    if [ ! -f "$T/sec_SLICE_$s" ]; then
      bad "$d: the driver printed no slice for offset $s"; continue
    fi
    sed -n "$((s + 1)),$((s + vp))p" "$T/sec_FULL" > "$T/want"
    if cmp -s "$T/sec_SLICE_$s" "$T/want"; then ok
    else
      bad "$d: the window at $s is not rows $((s + 1))..$((s + vp)) of the document"
      diff "$T/sec_SLICE_$s" "$T/want" 2>/dev/null | head -2 | cut -c1-90 | sed 's/^/      /'
    fi
  done

  # 3. CLAMPING — the chosen offset, then the pixels.
  over_got=$(awk -v k=$((doc + 1000)) '$1 == k {print $2}' "$T/clamps")
  under_got=$(awk '$1 == "-5" {print $2}' "$T/clamps")
  if [ "$over_got" = "$last" ]; then ok
  else bad "$d: scroll $((doc + 1000)) clamped to '$over_got', wanted $last"; fi
  sed -n "$((last + 1)),$((last + vp))p" "$T/sec_FULL" > "$T/want"
  if cmp -s "$T/sec_OVER" "$T/want"; then ok
  else bad "$d: the over-scrolled window is not the last window"; fi
  if [ "$under_got" = "0" ]; then ok
  else bad "$d: scroll -5 clamped to '$under_got', wanted 0"; fi
  sed -n "1,${vp}p" "$T/sec_FULL" > "$T/want"
  if cmp -s "$T/sec_UNDER" "$T/want"; then ok
  else bad "$d: the under-scrolled window is not the first window"; fi

  printf '  %-46s %4s rows, %s windows of %s\n' "$d" "$doc" "$((last + 1))" "$vp"
done

echo "scroll: $pass of $total properties hold"
# Arithmetic, not taste: each of the 4 tall documents contributes 8 (1 identity + 3 alignments +
# 2 clamp offsets + 2 clamp pixel checks) and the 1 short document contributes 2 (identity +
# not-padded), so 4*8 + 2 = 34. The first version pinned 30 because 30 was a guess, and the gate's
# own first run reported "34 and 0" as a failure. A pin nobody can recompute is a pin nobody will
# dare to change.
EXPECT=${EXPECT:-34}
if [ "$pass" -ne "$EXPECT" ] || [ "$fail" -ne 0 ]; then
  echo "scroll_check: expected $EXPECT passing and 0 failing, got $pass and $fail"
  exit 1
fi
echo "scroll_check: ok"
