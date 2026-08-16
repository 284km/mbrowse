#!/usr/bin/env python3
"""Which pixel centres are inside each glyph, decided by an independent implementation.

Rasterising is where a font stops being data and becomes ink, and it is the first thing in this
repository with no exact oracle available: two rasterisers antialias differently, so comparing
grey levels compares their coverage heuristics and not the shape. Asking a weaker question of a
stronger oracle is the way out —

    is this pixel's CENTRE inside the outline, by the nonzero winding rule?

— which is a mathematical question with one answer. fontTools' `PointInsidePen` answers it by
solving the curves, so the comparison is exact and neither side is allowed a tolerance.

What it does not check: coverage, antialiasing, hinting, and anything about a pixel that the
outline only clips a corner of. Those are the next question and they need a different oracle. What
it does check is the whole of the shape: a winding rule applied the wrong way round, a contour
walked backwards, a curve solved on the wrong interval, a component placed at the wrong offset —
every one of those moves pixel centres.

The grid is fixed so the two sides raster the same window: `PX` pixels to the em, `W` columns
starting at the glyph origin, `H` rows of which `DESC` are below the baseline. A pixel's centre in
font units is therefore

    x = (col + 0.5) * upem / PX
    y = (H - 1 - row - DESC + 0.5) * upem / PX

One line per glyph, rows joined by `/`, a pixel that is inside written `#` and one that is not `.`.

Needs fontTools. Maintenance command, not a gate — the answers are committed.

  python3 scripts/gen_raster_expected.py test/data/font
"""
import os, sys

PX, W, H, DESC = 24, 30, 32, 6


def main(data_dir):
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.pointInsidePen import PointInsidePen
    except ImportError:
        print("gen_raster_expected: needs fontTools (pip install fonttools)", file=sys.stderr)
        return 1
    f = TTFont(os.path.join(data_dir, "NotoSans-Regular.ttf"))
    gs, cmap = f.getGlyphSet(), f.getBestCmap()
    upem = f["head"].unitsPerEm
    cases = [l.strip() for l in open(os.path.join(data_dir, "outlines.cases")) if l.strip()]
    lines = []
    for cp in cases:
        name = cmap[int(cp)]
        rows = []
        for row in range(H):
            y = (H - 1 - row - DESC + 0.5) * upem / PX
            out = []
            for col in range(W):
                x = (col + 0.5) * upem / PX
                pen = PointInsidePen(gs, (x, y))
                gs[name].draw(pen)
                out.append("#" if pen.getResult() else ".")
            rows.append("".join(out))
        lines.append("/".join(rows))
    open(os.path.join(data_dir, "raster.expected"), "w").write("\n".join(lines) + "\n")
    print("gen_raster_expected: %d glyphs at %d px/em, %dx%d" % (len(lines), PX, W, H))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
