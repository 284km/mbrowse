#!/usr/bin/env python3
"""What the image documents LOOK like, from the browser's own screenshot.

**This is the first independent oracle for painting in this repository, and it exists because of one
measured fact**: Chrome's screenshot of an `<img>` at its natural size is pixel-identical to the
decoded JPEG — checked, 0 of 1536 pixels different. Everywhere else, drawing has no exact oracle
because two engines antialias differently, which is why the reftests compare two of our own renderings
instead. An image at natural size antialiases nothing: the pixels are the file's pixels, in the place
layout put them.

So this gate asks a question the reftests cannot: **did the ink land where the box said, and is it the
right ink** — against something that is not us.

The limits are the reason for the corpus being a subset. Documents with TEXT are excluded, because
glyph antialiasing is exactly the thing with no unique answer. Documents that SCALE the image are
excluded, because resampling is another. What is left is the question actually being asked here, which
is placement and colour.

Rows are run-length — `count x rrggbb` — the format the painter already writes.

Needs Pillow and Chrome. Maintenance command, not a gate — the answers are committed.

  python3 scripts/gen_imgpaint_expected.py test/data/img
"""
import os, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_expected as G

# Text or a scaled image; see above.
SKIP = {"img-inline-flow", "img-width-attr", "img-height-attr", "img-both-attrs",
        "img-css-width", "img-css-both", "img-pct-width", "img-max-width",
        "img-border-box"}


def rows(im, w, h):
    px = im.load()
    out = []
    for y in range(h):
        runs, cur, n = [], None, 0
        for x in range(w):
            p = px[x, y]
            c = (p[0] << 16) | (p[1] << 8) | p[2]
            if c == cur:
                n += 1
            else:
                if cur is not None:
                    runs.append("%dx%06x" % (n, cur))
                cur, n = c, 1
        runs.append("%dx%06x" % (n, cur))
        out.append(" ".join(runs))
    return out


def main(d):
    from PIL import Image
    tmp = tempfile.mkdtemp()
    for sub, ext in (("jpeg", ".jpg"), ("font", ".ttf")):
        beside = os.path.join(os.path.dirname(tmp), sub)
        os.makedirs(beside, exist_ok=True)
        for n in os.listdir(os.path.join(d, "..", sub)):
            if n.endswith(ext):
                shutil.copy(os.path.join(d, "..", sub, n), os.path.join(beside, n))

    names = sorted(n for n in os.listdir(d) if n.endswith(".html") and n[:-5] not in SKIP)
    kept = []
    for n in names:
        exp = os.path.join(d, n[:-5] + ".expected")
        if not os.path.exists(exp):
            continue
        # The page is as tall as the root box, which is what the painter draws and what makes two
        # documents of different heights different pictures rather than one cropped to the other.
        h = int(open(exp).readline().split("\t")[4])
        wrapped = os.path.join(tmp, n)
        shutil.copy(os.path.join(d, n), wrapped)
        shot = os.path.join(tmp, n + ".png")
        subprocess.run([G.CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
                        "--window-size=800,%d" % max(h, 1), "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=6000",
                        "--screenshot=" + shot, "file://" + wrapped],
                       capture_output=True, timeout=120)
        if not os.path.exists(shot):
            print("  NO SHOT %s" % n)
            continue
        im = Image.open(shot).convert("RGB")
        open(os.path.join(d, n[:-5] + ".ink"), "w").write("\n".join(rows(im, 800, max(h, 1))) + "\n")
        kept.append(n)
    print("gen_imgpaint_expected: %d screenshots" % len(kept))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
