#!/usr/bin/env python3
"""How much of each pixel a glyph covers, by counting subsamples.

The previous gate asks whether a pixel's CENTRE is inside, which is a yes-or-no with one answer.
Coverage is the next question and it does not have one: the exact answer is the area of the
intersection between a pixel square and the outline, and no two rasterisers approximate that the
same way — so an oracle that reports its own approximation is reporting an opinion.

So the thing implemented here is not "area, approximated". It is **N x N subsample coverage**, which
is a rule with exactly one answer:

    divide the pixel into N x N equal cells, ask of each cell's CENTRE whether it is inside, and
    report how many said yes.

That is a real antialiasing method and not a stand-in for a better one, and calling it by its name
is the difference between a gate that checks what was built and a gate that excuses it. Its error
against true area is bounded by the outline length crossing the pixel and shrinks as N grows; it is
NOT the same number, and this gate does not claim it is.

N = 4, so a pixel is 0 to 16 and is written as one character: `0`-`9` then `a`-`g`.

  python3 scripts/gen_coverage_expected.py test/data/font
"""
import os, sys

PX, W, H, DESC, N = 16, 20, 22, 5, 4
DIGITS = "0123456789abcdefg"


def main(data_dir):
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.pointInsidePen import PointInsidePen
    except ImportError:
        print("gen_coverage_expected: needs fontTools", file=sys.stderr)
        return 1
    f = TTFont(os.path.join(data_dir, "NotoSans-Regular.ttf"))
    gs, cmap = f.getGlyphSet(), f.getBestCmap()
    upem = f["head"].unitsPerEm
    cases = [l.strip() for l in open(os.path.join(data_dir, "coverage.cases")) if l.strip()]
    lines = []
    for cp in cases:
        name = cmap[int(cp)]
        rows = []
        for row in range(H):
            out = []
            for col in range(W):
                hits = 0
                for j in range(N):
                    y = (H - 1 - row - DESC + (j + 0.5) / N) * upem / PX
                    for i in range(N):
                        x = (col + (i + 0.5) / N) * upem / PX
                        p = PointInsidePen(gs, (x, y))
                        gs[name].draw(p)
                        if p.getResult():
                            hits += 1
                out.append(DIGITS[hits])
            rows.append("".join(out))
        lines.append("/".join(rows))
    open(os.path.join(data_dir, "coverage.expected"), "w").write("\n".join(lines) + "\n")
    print("gen_coverage_expected: %d glyphs at %d px/em, %dx%d, %dx%d subsamples"
          % (len(lines), PX, W, H, N, N))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
