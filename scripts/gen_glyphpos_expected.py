#!/usr/bin/env python3
"""Where a real browser put each CHARACTER, for the same documents the box gate uses.

The box gate asks where each ELEMENT went. This asks where each character went, which is a different
question with a different failure: a paragraph can be in exactly the right place with the words
inside it in the wrong ones, and every box gate in this repository would call that a pass.

The browser answers it through `Range`: a range around one character has a rect. That is the same
kind of oracle as the box gate's — an independent implementation, asked at vendoring time, committed
— and it is the last measurement before painting, because a painter that puts a glyph where this
says is a painter that puts it where the browser does.

**White space is skipped on both sides.** A space between two words has a rect in the browser and no
glyph in the engine — it is the gap the advance leaves, not something drawn — so including it would
compare two different ideas of what a space is. The positions of everything either side of it still
say whether the advance was right.

One line per character: `codepoint<TAB>x<TAB>y<TAB>w<TAB>h`, rounded to whole pixels, in document
order. Blank for a document with no text.

Needs a browser. Maintenance command, not a gate.

  python3 scripts/gen_glyphpos_expected.py test/data/layout /tmp/work
"""
import os, subprocess, sys

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SKIP = {"head", "style", "script", "meta", "link", "title", "base"}

FONT_CSS = """<style>
@font-face { font-family: MB; src: url("file://%s"); }
* { font-family: MB !important; }
</style>"""

PROBE = r"""<script>
document.fonts.load('16px MB').then(function(){ return document.fonts.ready; }).then(function(){
  var skip = %s;
  var out = [];
  var walk = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT, null);
  var n;
  while ((n = walk.nextNode())) {
    var p = n.parentNode;
    var bad = false;
    for (var e = p; e; e = e.parentNode) {
      if (e.nodeName && skip.indexOf(e.nodeName.toLowerCase()) >= 0) { bad = true; break; }
    }
    if (bad) continue;
    var t = n.nodeValue;
    for (var i = 0; i < t.length; i++) {
      var ch = t[i];
      if (/\s/.test(ch)) continue;
      var r = document.createRange();
      r.setStart(n, i); r.setEnd(n, i + 1);
      var b = r.getBoundingClientRect();
      if (b.width === 0 && b.height === 0) continue;
      out.push([ch.codePointAt(0), Math.round(b.left), Math.round(b.top),
                Math.round(b.width), Math.round(b.height)].join('\t'));
    }
  }
  var pre = document.createElement('pre');
  pre.id = '__mbrowse_glyphs';
  pre.textContent = out.join('\n');
  document.documentElement.appendChild(pre);
});
</script>"""

FLAGS = ["--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--window-size=800,600", "--force-device-scale-factor=1",
         "--allow-file-access-from-files", "--virtual-time-budget=6000", "--dump-dom"]


def positions_for(path, tmp, font):
    import json
    html = open(path, encoding="utf-8", errors="replace").read()
    page = html + FONT_CSS % font + PROBE % json.dumps(sorted(SKIP))
    out_path = os.path.join(tmp, "probe.html")
    open(out_path, "w", encoding="utf-8").write(page)
    got = subprocess.run([CHROME] + FLAGS + ["file://" + out_path],
                         capture_output=True, text=True, timeout=180).stdout
    marker = '<pre id="__mbrowse_glyphs">'
    if marker not in got:
        return None
    body = got.split(marker, 1)[1].split("</pre>", 1)[0]
    for a, b in (("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"')):
        body = body.replace(a, b)
    return body.strip("\n")


def main(data_dir, tmp):
    font = os.path.abspath(os.path.join(data_dir, "..", "font", "NotoSans-Regular.ttf"))
    if not os.path.exists(CHROME):
        print("gen_glyphpos_expected: no browser at the expected path", file=sys.stderr)
        return 1
    names = sorted(n for n in os.listdir(data_dir) if n.endswith(".html"))
    wrote = failed = 0
    for n in names:
        r = positions_for(os.path.join(data_dir, n), tmp, font)
        if r is None:
            print("  NO ANSWER %s" % n)
            failed += 1
            continue
        open(os.path.join(data_dir, n[:-5] + ".glyphs"), "w", encoding="utf-8").write(r + "\n")
        wrote += 1
    print("gen_glyphpos_expected: %d written, %d with no answer" % (wrote, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
