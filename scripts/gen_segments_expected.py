#!/usr/bin/env python3
"""Glyph contours as SEGMENTS, from an independent reader of the same bytes.

The step between the stored points and anything drawable is two rules that the file does not spell
out, and both of them are places to be quietly wrong:

  implied on-curve points   two off-curve points in a row have an on-curve point BETWEEN them that
                            is not stored — it is their midpoint. A reader that does not insert it
                            draws a curve through the wrong place; a reader that inserts it in the
                            wrong half draws one that is nearly right.
  the first point           a contour may START on an off-curve point, in which case the point it
                            starts at is again a midpoint that is not written down — or, if every
                            point is off-curve, the midpoint of the last and the first.

Composites add a third: their components have to be placed, and a component is itself a glyph that
may be composite.

fontTools does all three and is the oracle. Its pen keeps runs of off-curve points in one
`qCurveTo`, which is the same information in a different shape, so this expands them into single
segments — the form a rasteriser actually consumes and the form the Mere side produces directly.
Converting the oracle rather than the subject keeps the two answers independent.

One line per glyph, tokens separated by spaces:

    M x y            start a contour
    L x y            a straight segment
    Q cx cy x y      a quadratic segment with one control point
    Z                close the contour

Needs fontTools. Maintenance command, not a gate — the answers are committed.

  python3 scripts/gen_segments_expected.py test/data/font
"""
import os, sys


def r(v):
    """Half away from zero, which is the one rounding an integer implementation can match exactly.

    Midpoints are the only fractional numbers here and they are always halves, so the tie is not a
    corner case — it is most of them. Python's own `round` breaks ties to even, which an integer
    `(a + b) / 2` cannot reproduce without knowing whether the result is even, so the canonical form
    uses the rule both sides can state in one line.
    """
    import math
    return int(math.floor(v + 0.5)) if v >= 0 else int(math.ceil(v - 0.5))


def expand(value):
    """The pen's calls as single segments, with implied midpoints made explicit."""
    out, cur = [], None
    for op, args in value:
        if op == "moveTo":
            cur = args[0]
            out += ["M", "%d %d" % (r(cur[0]), r(cur[1]))]
        elif op == "lineTo":
            cur = args[0]
            out += ["L", "%d %d" % (r(cur[0]), r(cur[1]))]
        elif op == "qCurveTo":
            pts = list(args)
            if pts[-1] is None:
                # An all-off-curve contour: the pen says so by ending with None, and the start it
                # implied is the midpoint of the last and first control points.
                raise SystemExit("gen_segments_expected: an all-off-curve contour is not in the "
                                 "canonical form here")
            offs, end = pts[:-1], pts[-1]
            for i, c in enumerate(offs):
                if i + 1 < len(offs):
                    nxt = offs[i + 1]
                    mid = ((c[0] + nxt[0]) / 2.0, (c[1] + nxt[1]) / 2.0)
                else:
                    mid = end
                out += ["Q", "%d %d %d %d" % (r(c[0]), r(c[1]), r(mid[0]), r(mid[1]))]
                cur = mid
        elif op == "closePath":
            out += ["Z"]
        elif op == "endPath":
            out += ["Z"]
        else:
            raise SystemExit("gen_segments_expected: unexpected pen op %r" % op)
    return " ".join(out)


def main(data_dir):
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.recordingPen import DecomposingRecordingPen
    except ImportError:
        print("gen_segments_expected: needs fontTools (pip install fonttools)", file=sys.stderr)
        return 1
    path = os.path.join(data_dir, "NotoSans-Regular.ttf")
    f = TTFont(path)
    cmap, gs = f.getBestCmap(), f.getGlyphSet()
    cases = [l.strip() for l in open(os.path.join(data_dir, "outlines.cases")) if l.strip()]
    lines = []
    for cp in cases:
        name = cmap[int(cp)]
        pen = DecomposingRecordingPen(gs)
        gs[name].draw(pen)
        lines.append(expand(pen.value))
    open(os.path.join(data_dir, "segments.expected"), "w").write("\n".join(lines) + "\n")
    print("gen_segments_expected: %d glyphs written" % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
