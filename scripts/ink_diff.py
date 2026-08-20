#!/usr/bin/env python3
"""How far apart two paintings are, in pixels.

Both files are run-length rows — `count x rrggbb` — which is what the painter writes and what
`gen_northstar_expected.py` converts a screenshot into. Prints one line:

    <differing pixels> <total pixels> <percent> <rows-a> <rows-b>

**A count and not a verdict.** The threshold belongs to whoever is asking: a reftest wants zero, an
image at natural size wants zero, and a page with text cannot have zero because two engines
antialias glyphs differently. Putting the number here and the tolerance in the caller keeps this
usable by all three, and keeps a tolerance from quietly becoming part of the measurement.

A pixel counts as differing when any channel differs by more than `--near` (default 0, meaning exact).
Near-miss antialiasing on the same glyph in the same place differs by a little; a glyph in the wrong
place differs by a lot, and so does a missing one. Being able to separate those is the point of the
option — a single percentage cannot say which of the two it is made of.

Rows the two do not share are counted as fully differing, so a short painting cannot score well by
being short.

  python3 scripts/ink_diff.py a.ink b.ink [--near N] [--width 800]
"""
import sys


def expand(path, width):
    rows = []
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        px = []
        for run in line.split(" "):
            n, _, c = run.partition("x")
            px.extend([int(c, 16)] * int(n))
        # A row that does not add up to the width is not silently padded: the format is exact and a
        # short row means the writer disagreed about the viewport, which is not a pixel difference.
        if len(px) != width:
            raise SystemExit("ink_diff: %s has a row of %d pixels, expected %d" % (path, len(px), width))
        rows.append(px)
    return rows


def main(argv):
    near, width = 0, 800
    files = []
    i = 0
    while i < len(argv):
        if argv[i] == "--near":
            near = int(argv[i + 1]); i += 2
        elif argv[i] == "--width":
            width = int(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1
    a, b = expand(files[0], width), expand(files[1], width)
    rows = max(len(a), len(b))
    diff = 0
    for y in range(rows):
        if y >= len(a) or y >= len(b):
            diff += width
            continue
        ra, rb = a[y], b[y]
        for x in range(width):
            p, q = ra[x], rb[x]
            if p == q:
                continue
            if near and max(abs((p >> 16 & 255) - (q >> 16 & 255)),
                            abs((p >> 8 & 255) - (q >> 8 & 255)),
                            abs((p & 255) - (q & 255))) <= near:
                continue
            diff += 1
    total = rows * width
    print("%d %d %.3f %d %d" % (diff, total, 100.0 * diff / total if total else 0.0, len(a), len(b)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
