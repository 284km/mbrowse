#!/usr/bin/env python3
"""What a real page looks like, from a browser, for the snapshots under `test/data/northstar`.

Two answers per page, and they are not the same kind of answer:

  <name>.expected  box geometry — `tag<TAB>x<TAB>y<TAB>w<TAB>h`, one line per element. EXACT. An
                   independent implementation's numbers, and an engine that draws nothing cannot
                   pass them.

  <name>.ink       the screenshot, as the run-length rows the painter already writes. COMPARED WITH
                   A TOLERANCE, and that is forced rather than chosen: a real page is mostly text,
                   two engines antialias glyphs differently, and there is no unique correct picture.
                   `imgpaint_check.sh` can compare exactly only because an image at its natural size
                   antialiases nothing.

So the geometry is the real check and the ink is the one that says the page is not blank. A gate
with only the tolerance would pass a grey rectangle; a gate with only the geometry would pass an
engine that computes boxes and never draws them. Neither alone is the question A9 asks.

**The vendored font is injected, as it is for the layout corpus.** A page names fonts the machine may
not have, and comparing against whatever the browser fell back to is comparing against a file this
repository cannot read. It changes what the page looks like, and it is the only way the two sides are
looking at the same thing.

Maintenance command, not a gate — a gate that launches a browser fails for reasons that have nothing
to do with the code. The answers are committed.

  python3 scripts/gen_northstar_expected.py test/data/northstar
"""
import os, subprocess, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_expected as G
import gen_imgpaint_expected as I

VIEWPORT_W = 800


def main(root):
    from PIL import Image
    font = os.path.abspath(os.path.join(root, "..", "font", "NotoSans-Regular.ttf"))
    if not os.path.exists(font):
        print("gen_northstar_expected: no font — run scripts/vendor_font.sh", file=sys.stderr)
        return 1
    if not os.path.exists(G.CHROME):
        print("gen_northstar_expected: no browser at the expected path", file=sys.stderr)
        return 1

    tmp = tempfile.mkdtemp()
    names = sorted(n for n in os.listdir(root) if os.path.isdir(os.path.join(root, n)))
    wrote = failed = 0
    for n in names:
        page = os.path.join(root, n, "index.html")
        if not os.path.exists(page):
            continue
        b = G.boxes_for(page, tmp, font)
        if b is None:
            print("  NO ANSWER %s" % n)
            failed += 1
            continue
        open(os.path.join(root, n, "index.expected"), "w", encoding="utf-8").write(b + "\n")

        # As tall as the root box, which is what the painter draws. Taking a fixed viewport height
        # instead would compare a page against a crop of itself.
        h = max(int(b.split("\n")[0].split("\t")[4]), 1)
        wrapped = os.path.join(tmp, n + ".html")
        text = open(page, encoding="utf-8", errors="replace").read()
        open(wrapped, "w", encoding="utf-8").write(text + "\n" + (G.FONT_CSS % font) + "\n")
        shot = os.path.join(tmp, n + ".png")
        subprocess.run([G.CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
                        "--window-size=%d,%d" % (VIEWPORT_W, h), "--force-device-scale-factor=1",
                        "--allow-file-access-from-files", "--virtual-time-budget=6000",
                        "--screenshot=" + shot, "file://" + wrapped],
                       capture_output=True, timeout=180)
        if not os.path.exists(shot):
            print("  NO SHOT %s" % n)
            failed += 1
            continue
        im = Image.open(shot).convert("RGB")
        open(os.path.join(root, n, "index.ink"), "w").write(
            "\n".join(I.rows(im, VIEWPORT_W, h)) + "\n")
        print("  %s: %d elements, %d rows" % (n, b.count("\n") + 1, h))
        wrote += 1
    print("gen_northstar_expected: %d written, %d with no answer" % (wrote, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
