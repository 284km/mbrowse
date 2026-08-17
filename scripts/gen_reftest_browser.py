#!/usr/bin/env python3
"""Which of the vendored reftest pairs the BROWSER itself renders identically.

A reftest needs no oracle for what a page should look like — it asks whether two pages look the same,
and both are ours. It does need one for something else, and this is it: **whether the two files are
actually a pair.** That was assumed, and the assumption was wrong for 33 of the 109.

The reason, measured rather than guessed: 25 of those 33 contain `<![CDATA[` and none of the 76 that
match do. The originals are XHTML — `.xht` — and were vendored as `.html`. In XHTML a CDATA section
inside `<style>` is markup and disappears; in HTML it is stylesheet text, so the first rule of the
reference's stylesheet is eaten and the reference renders differently from the test. A file renamed is
not a file converted.

The other 8 are a different reason and are not guessed at here; they are recorded as differing and the
gate treats them the same way.

So the denominator for `scripts/reftest_check.sh` is 76 and not 109, and the answers are committed
here rather than re-derived, because a gate that launches a browser fails for reasons that have nothing
to do with the code.

  python3 scripts/gen_reftest_browser.py test/data/layout
"""
import os, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_expected as G

FLAGS = ["--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--window-size=800,600", "--force-device-scale-factor=1",
         "--allow-file-access-from-files", "--virtual-time-budget=4000"]


def main(d):
    from PIL import Image
    tmp = tempfile.mkdtemp()
    for n in os.listdir(d):
        if n.endswith(".html"):
            shutil.copy(os.path.join(d, n), os.path.join(tmp, n))
    pairs = [l.split("\t") for l in subprocess.run(
        ["python3", os.path.join(os.path.dirname(__file__), "reftest_pairs.py"), d],
        capture_output=True, text=True).stdout.splitlines() if l.strip()]

    shot = {}
    def png(n):
        if n not in shot:
            p = os.path.join(tmp, n + ".png")
            subprocess.run([G.CHROME] + FLAGS + ["--screenshot=" + p, "file://" + os.path.join(tmp, n)],
                           capture_output=True, timeout=120)
            shot[n] = p if os.path.exists(p) else None
        return shot[n]

    out, same = [], 0
    for a, b in pairs:
        pa, pb = png(a), png(b)
        if not pa or not pb:
            out.append("DIFF\t%s\t%s" % (a, b))
            continue
        ok = (Image.open(pa).convert("RGB").tobytes() == Image.open(pb).convert("RGB").tobytes())
        same += ok
        out.append("%s\t%s\t%s" % ("SAME" if ok else "DIFF", a, b))
    open(os.path.join(d, "reftest.browser"), "w").write("\n".join(out) + "\n")
    print("gen_reftest_browser: %d of %d pairs the browser renders identically" % (same, len(pairs)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
