#!/usr/bin/env python3
"""Box geometry for the `<img>` documents, from the same browser as the layout corpus.

**A separate corpus, deliberately.** These could have gone in `test/data/layout`, and putting them
there would have meant re-running `gen_layout_expected.py` over all 228 documents — regenerating the
answers a pinned gate is currently being held to, with whatever browser happens to be installed today.
A gate must not have its subject regenerated as a side effect of adding to it. So the images get their
own directory, their own expectations and their own count, and the layout gate is untouched.

The measuring is `gen_layout_expected.boxes_for`, so the two corpora are read the same way. Two things
had to be arranged around it, and both were found by the numbers coming back WRONG AND PLAUSIBLE:

**The browser has to be able to fetch the images.** `boxes_for` writes an instrumented copy of the
document into a scratch directory, so `src="../jpeg/detail.jpg"` pointed at nothing; the images are
copied to the matching place beside it. Without that every image measured 16x16 — Chrome's broken
image placeholder — which is a perfectly ordinary-looking box, the same for every file, and says
nothing about layout at all.

**And the probe has to wait for them.** The layout probe waits on `document.fonts.ready`, which says
nothing about images; one that fires first measures the placeholder for the same reason. This one
waits on the fonts and every image together. Same failure, two independent causes — a size that is
plausible is not evidence that anything was loaded.

  python3 scripts/gen_img_expected.py test/data/img
"""
import os, shutil, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_expected as G

# The layout probe with an extra wait: the fonts AND every image. `complete` covers an image that was
# already in the cache; `onerror` is resolved rather than rejected because a document whose image is
# deliberately missing is one of the cases being measured.
IMG_PROBE = r"""<script>
Promise.all([document.fonts.ready].concat([].map.call(document.images, function (im) {
  return im.complete ? Promise.resolve()
                     : new Promise(function (res) { im.onload = res; im.onerror = res; });
}))).then(function () {
""" + G.PROBE.split("document.fonts.ready.then(function(){", 1)[1].replace("</script>", "") + """
</script>"""


def main(d):
    font = os.path.abspath(os.path.join(d, "..", "font", "NotoSans-Regular.ttf"))
    if not os.path.exists(font):
        print("gen_img_expected: no font — run scripts/vendor_font.sh", file=sys.stderr)
        return 1
    if not os.path.exists(G.CHROME):
        print("gen_img_expected: no browser at the expected path", file=sys.stderr)
        return 1
    tmp = tempfile.mkdtemp()
    # `../jpeg/x.jpg` from a document in `tmp` means `dirname(tmp)/jpeg/x.jpg`.
    for sub, ext in (("jpeg", ".jpg"), ("font", ".ttf")):
        beside = os.path.join(os.path.dirname(tmp), sub)
        os.makedirs(beside, exist_ok=True)
        for n in os.listdir(os.path.join(d, "..", sub)):
            if n.endswith(ext):
                shutil.copy(os.path.join(d, "..", sub, n), os.path.join(beside, n))
    names = sorted(n for n in os.listdir(d) if n.endswith(".html"))
    wrote = failed = 0
    for n in names:
        b = G.boxes_for(os.path.join(d, n), tmp, font, IMG_PROBE)
        if b is None:
            print("  NO ANSWER %s" % n)
            failed += 1
            continue
        open(os.path.join(d, n[:-5] + ".expected"), "w", encoding="utf-8").write(b + "\n")
        wrote += 1
    print("gen_img_expected: %d written, %d with no answer" % (wrote, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
