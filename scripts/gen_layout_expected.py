#!/usr/bin/env python3
"""Box geometry for each layout document, taken from a real browser.

The oracle for layout cannot be a reftest on its own. A reftest compares two of YOUR OWN
renderings, so an engine that draws nothing passes every one of them — the same trap as a
window readback that hands back what was just written. Geometry from an independent
implementation cannot be passed by drawing nothing: the numbers are specific.

The browser is asked once, at vendoring time, and its answers are committed. A gate that
launches a browser fails for reasons that have nothing to do with the code.

The canonical form is one line per element in document order:

    tag<TAB>x<TAB>y<TAB>width<TAB>height

Rounded to whole pixels. Sub-pixel layout is a real difference between engines and comparing
it would compare rounding policy rather than layout; a whole pixel is the unit the reference
images are compared in anyway.

Elements that generate no box are skipped — head, style, script, meta, link, title — because
whether they appear in a box tree is not a layout question, and the injected measuring script
is one of them.
"""
import json, os, subprocess, sys

CHROME = ("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
SKIP = {"head", "style", "script", "meta", "link", "title", "base"}

# The measuring script, and the font both sides will use.
#
# **The font is injected and the probe waits for it.** A line of text is as tall as the font says,
# so without this the numbers are the metrics of whatever the browser defaulted to — here a system
# font that cannot be redistributed and that nothing in this repository can read. That does change
# what the WPT documents test, and it is the right trade: a comparison against a font nobody has is
# not a comparison.
#
# Waiting on `document.fonts.ready` is not caution, it is the difference between measuring the
# vendored font and measuring the fallback. A probe that fires first gets plausible numbers from
# the wrong file and says nothing about it.
FONT_CSS = """<style>
@font-face { font-family: MB; src: url("file://%s"); }
* { font-family: MB !important; }
</style>"""

# Raw, so that `\t` and `\n` reach the browser as the two characters JavaScript needs. Written as a
# normal string once, the `\n` became a real newline and cut the JS string literal in half — the
# probe raised a syntax error, produced nothing, and the generator reported "no answer" for all 126
# documents without saying why.
PROBE = r"""<script>document.fonts.ready.then(function(){
var out=[];
var all=document.querySelectorAll('*');
for (var i=0;i<all.length;i++){
  var e=all[i], t=e.tagName.toLowerCase();
  if (t==='head'||t==='style'||t==='script'||t==='meta'||t==='link'||t==='title'||t==='base')
    continue;
  var r=e.getBoundingClientRect();
  out.push([t,Math.round(r.x),Math.round(r.y),Math.round(r.width),Math.round(r.height)]
           .join('\t'));
}
var pre=document.createElement('pre');
pre.id='__mbrowse_boxes';
pre.textContent=out.join('\n');
document.documentElement.appendChild(pre);
});</script>"""

# A fixed viewport, no scrollbars, no device scaling. All three change the numbers, and a gate
# whose expected values depend on the window the browser happened to open is not a gate.
FLAGS = ["--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--window-size=800,600", "--force-device-scale-factor=1",
         "--allow-file-access-from-files",
         "--virtual-time-budget=6000", "--dump-dom"]


def boxes_for(path, tmp, font, probe=None):
    """`probe` overrides the measuring script. The layout corpus passes nothing and gets PROBE; the
    image corpus needs one that also waits for the images, because a probe that fires first measures
    the broken-image placeholder and returns a number that looks exactly like an answer."""
    text = open(path, encoding="utf-8", errors="replace").read()
    # Appended after the document, so it cannot change what it measures. Measuring happens
    # before the element is inserted in any case, but a probe that is also part of the input
    # is a probe worth being careful with.
    wrapped = os.path.join(tmp, os.path.basename(path))
    # Both appended AFTER the document, never before it. A `<style>` in front of the doctype makes
    # the doctype stray, which puts the browser in quirks mode and changes numbers that have nothing
    # to do with fonts — the first attempt did that and the paragraph margins stopped collapsing.
    # Where a stylesheet sits does not change which elements it applies to.
    open(wrapped, "w", encoding="utf-8").write(
        text + "\n" + (FONT_CSS % font) + "\n" + (probe or PROBE) + "\n")
    got = subprocess.run([CHROME] + FLAGS + ["file://" + wrapped],
                         capture_output=True, text=True, timeout=120).stdout
    marker = '<pre id="__mbrowse_boxes">'
    if marker not in got:
        return None
    body = got.split(marker, 1)[1].split("</pre>", 1)[0]
    # --dump-dom serialises the text content, so the entities it introduced come back out.
    for a, b in (("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"')):
        body = body.replace(a, b)
    return body.strip("\n")


def main(data_dir, tmp):
    font = os.path.abspath(os.path.join(data_dir, "..", "font", "NotoSans-Regular.ttf"))
    if not os.path.exists(font):
        print("gen_layout_expected: no font — run scripts/vendor_font.sh", file=sys.stderr)
        return 1
    if not os.path.exists(CHROME):
        print("gen_layout_expected: no browser at the expected path", file=sys.stderr)
        return 1
    names = sorted(n for n in os.listdir(data_dir) if n.endswith(".html"))
    wrote = failed = 0
    for n in names:
        b = boxes_for(os.path.join(data_dir, n), tmp, font)
        if b is None:
            print("  NO ANSWER %s" % n)
            failed += 1
            continue
        open(os.path.join(data_dir, n[:-5] + ".expected"), "w", encoding="utf-8").write(b + "\n")
        wrote += 1
    print("gen_layout_expected: %d written, %d with no answer" % (wrote, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
