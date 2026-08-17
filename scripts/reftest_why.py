#!/usr/bin/env python3
"""Cross-reference the failing reftest pairs against the failing layout documents.

A reftest says two pages disagree and cannot say which one is wrong — that is the whole shape of the
gate, and it is why this is a separate question rather than a better error message. The other gates
CAN say: `scripts/layout_check.sh` compares each document against a browser's own rects.

So the question this answers is: **of the pairs that disagree, how many have a side that is already
known to be laid out wrongly?** Those need no further explanation — they are a layout failure seen
from the other side. What is left over is the interesting set: pairs where both sides match the
browser's geometry and the pages still do not look the same. That can only be colour, paint order, or
ink landing outside the box it was measured for — the three things geometry cannot see.

Writing this down was prompted by a commit message that claimed the 48 failures were "accounted for"
by layout failures when three had been looked at. This is the cheap way to actually settle it.

  MERE=... REFTEST_LIST=/tmp/rf.txt sh scripts/reftest_check.sh     # ~90 minutes
  MERE=... LAYOUT_LIST=/tmp/lf.txt sh scripts/layout_check.sh
  python3 scripts/reftest_why.py /tmp/rf.txt /tmp/lf.txt
"""
import os, sys


def main(ref_path, lay_path):
    if not os.path.exists(ref_path) or not os.path.exists(lay_path):
        print("reftest_why: need both lists; see the header for how to make them", file=sys.stderr)
        return 1
    pairs = [l.rstrip("\n").split("\t") for l in open(ref_path) if l.strip()]
    bad = {l.strip() for l in open(lay_path) if l.strip()}

    explained, unexplained = [], []
    for p in pairs:
        if len(p) != 2:
            continue
        a, b = p
        hits = [n for n in (a, b) if n in bad]
        (explained if hits else unexplained).append((a, b, hits))

    print("failing pairs:            %d" % len(pairs))
    print("  a side already fails layout: %d" % len(explained))
    print("  both sides match the browser: %d" % len(unexplained))
    print()
    if unexplained:
        print("The ones geometry cannot explain — colour, paint order, or ink outside its box:")
        for a, b, _ in unexplained:
            print("  %s  vs  %s" % (a, b))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
