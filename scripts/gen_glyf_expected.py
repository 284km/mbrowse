#!/usr/bin/env python3
"""Glyph outlines, read out of the same font file by an independent implementation.

The oracle for an outline reader has to be something that reads the same bytes and was written by
somebody else. fontTools is both: it is the reference implementation the format's own community
uses, and it answers with the RAW points — the coordinates as they are stored, before any curve is
flattened or any transform applied — so the comparison is exact rather than approximate.

That matters more here than for the widths gate. A width is one number and a wrong reader tends to
produce an obviously wrong one; an outline is hundreds of numbers and a reader that has the flag
bits slightly wrong produces a shape that is *almost* right, which looks like a font hint and not
like a bug.

The canonical form is one line per glyph:

    S <nContours> | <endPt> ... | <x> <y> <onCurve> ...        a simple glyph
    C | <gid> <dx> <dy> ...                                    a composite glyph
    E                                                          a glyph with no contours

Composites carry offsets only. A component with a scale or a 2x2 transform is not in this corpus
and is not in the format below; `gen` fails loudly rather than dropping it, because a dropped
component is a glyph that is subtly wrong and passes.

Needs fontTools. Maintenance command, not a gate — the answers are committed.

  python3 scripts/gen_glyf_expected.py test/data/font
"""
import os, sys

# One glyph for each thing that can be read wrongly on its own.
CASES = [
    ("M", "one contour, all on-curve corners and a few control points"),
    ("i", "two contours — the dot is its own, and a reader that stops at the first loses it"),
    ("o", "two contours, one inside the other, both mostly off-curve"),
    ("O", "the same at a larger size, where the repeat flag is likelier"),
    ("e", "a contour that closes back through an off-curve point"),
    ("W", "many corners"),
    ("8", "two counters"),
    ("é", "a COMPOSITE: two components with an offset"),
    ("ü", "a composite whose accent sits at a different offset"),
    ("—", "four points, all on-curve, the simplest shape in the font"),
    (" ", "a glyph with NO contours, which is a real answer and not a failure"),
    (".", "one small contour"),
    ("@", "the most contours of anything here"),
]


def main(data_dir):
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        print("gen_glyf_expected: needs fontTools (pip install fonttools)", file=sys.stderr)
        return 1
    path = os.path.join(data_dir, "NotoSans-Regular.ttf")
    if not os.path.exists(path):
        print("gen_glyf_expected: no font — run scripts/vendor_font.sh", file=sys.stderr)
        return 1
    f = TTFont(path)
    glyf, cmap, order = f["glyf"], f.getBestCmap(), f.getGlyphOrder()
    gid_of = {n: i for i, n in enumerate(order)}

    cases, lines = [], []
    for ch, _why in CASES:
        cp = ord(ch)
        if cp not in cmap:
            print("gen_glyf_expected: %r is not in the font" % ch, file=sys.stderr)
            return 1
        gid = gid_of[cmap[cp]]
        g = glyf[cmap[cp]]
        cases.append(str(cp))
        if g.isComposite():
            parts = []
            for c in g.components:
                if getattr(c, "transform", None) not in (None, [[1, 0], [0, 1]]):
                    print("gen_glyf_expected: %r has a transformed component, which the "
                          "format here cannot say" % ch, file=sys.stderr)
                    return 1
                parts.append("%d %d %d" % (gid_of[c.glyphName], c.x, c.y))
            lines.append("C | " + " ".join(parts))
        elif g.numberOfContours == 0:
            lines.append("E")
        else:
            pts = " ".join("%d %d %d" % (p[0], p[1], fl & 1)
                           for p, fl in zip(g.coordinates, g.flags))
            lines.append("S %d | %s | %s"
                         % (g.numberOfContours,
                            " ".join(str(e) for e in g.endPtsOfContours), pts))

    open(os.path.join(data_dir, "outlines.cases"), "w").write("\n".join(cases) + "\n")
    open(os.path.join(data_dir, "outlines.expected"), "w").write("\n".join(lines) + "\n")
    print("gen_glyf_expected: %d outlines written" % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
