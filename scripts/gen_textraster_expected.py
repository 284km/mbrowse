#!/usr/bin/env python3
"""A whole STRING rastered, from the independent reader.

This is the first thing that uses the metrics and the outlines together, and that is what it is for.
Each of them has been checked on its own — advances against a browser's `measureText`, outlines
against fontTools — and neither check can see the join between them: a reader with the right widths
and the right shapes still draws nonsense if it advances by the wrong one, or advances before
drawing instead of after.

**No kerned pairs.** The strings below are chosen so that the advance between every two glyphs is
just `hmtx`, because that is the part this oracle can state without reimplementing GPOS. Kerning is
already gated on its own, against a browser, in `font_check.sh` — asking one gate to check two
things is how a gate ends up unable to say which of them broke.

The grid and the inside test are the raster gate's: `PX` to the em, pixel centres, nonzero winding.

  python3 scripts/gen_textraster_expected.py test/data/font
"""
import os, sys

PX, H, DESC = 16, 22, 5

STRINGS = [
    "nn",      # the same glyph twice: the advance is the whole of the distance between them
    "oo",      # two round shapes, where an advance one pixel out is obvious
    "in",      # different widths
    "HH",      #
    "lo",      # a narrow glyph before a wide one
    "no on",   # a space, which has an advance and no outline
]


def main(data_dir):
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.pointInsidePen import PointInsidePen
    except ImportError:
        print("gen_textraster_expected: needs fontTools", file=sys.stderr)
        return 1
    f = TTFont(os.path.join(data_dir, "NotoSans-Regular.ttf"))
    gs, cmap, hmtx = f.getGlyphSet(), f.getBestCmap(), f["hmtx"]
    upem = f["head"].unitsPerEm
    lines = []
    for s in STRINGS:
        # Where each glyph sits, in font units, by advance alone.
        placed, pen_x = [], 0
        for ch in s:
            name = cmap[ord(ch)]
            placed.append((name, pen_x))
            pen_x += hmtx[name][0]
        w = int(pen_x * PX / upem) + 2
        rows = []
        for row in range(H):
            y = (H - 1 - row - DESC + 0.5) * upem / PX
            out = []
            for col in range(w):
                x = (col + 0.5) * upem / PX
                hit = False
                for name, ox in placed:
                    p = PointInsidePen(gs, (x - ox, y))
                    gs[name].draw(p)
                    if p.getResult():
                        hit = True
                        break
                out.append("#" if hit else ".")
            rows.append("".join(out))
        lines.append("/".join(rows))
    open(os.path.join(data_dir, "textraster.cases"), "w").write("\n".join(STRINGS) + "\n")
    open(os.path.join(data_dir, "textraster.expected"), "w").write("\n".join(lines) + "\n")
    print("gen_textraster_expected: %d strings at %d px/em" % (len(lines), PX))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
