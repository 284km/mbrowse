#!/usr/bin/env python3
"""Text widths for a set of strings, measured by a real browser with the vendored font.

The oracle for a metrics reader has to be something that already draws text correctly, and it has to
read the same file. `canvas.measureText` does both: it is the browser's own shaping and advance sum
over `test/data/font/NotoSans-Regular.ttf`, and it answers in fractional pixels, so the comparison is
against what layout will actually use rather than against a table somebody typed.

The strings are chosen to separate the things that can each be wrong on their own:

  a single glyph            the cmap lookup and one advance
  a repeated glyph          whether the sum is a sum
  a space                   an advance that is easy to forget is one
  digits and punctuation    a different cmap segment
  accented Latin            a two-byte character, so the UTF-8 decode as well as the lookup
  a long run                where rounding once versus per glyph diverges

Two files, the same way every other corpus here is split: `widths.cases` is one escaped string per
line and `widths.expected` is one integer per line, the width in units of 1/100 pixel at 16px. An
integer, because comparing floats printed by two languages compares their printing rather than their
arithmetic.

Needs a browser. Maintenance command, not a gate.

  python3 scripts/gen_font_expected.py test/data/font /tmp/work
"""
import os, subprocess, sys

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

STRINGS = [
    "M", "i", "W", " ", "0", "9", ".", ",", "-", "/",
    "MM", "MMMM", "iiii", "  ", "a b",
    "Filler Text", "Test passes if there are 3 lines of \"Filler Text\".",
    "The quick brown fox jumps over the lazy dog",
    "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "0123456789", "!\"#$%&'()*+,-./:;<=>?@[]^_`{|}~",
    "é", "éé", "café", "über",
    "—", "‘quoted’",
    "x" * 100,
]

PAGE = r"""<!DOCTYPE html><html><head><style>
@font-face { font-family: MB; src: url("file://%s"); }
</style></head><body><script>
document.fonts.load('16px MB').then(function(){
  return document.fonts.ready;
}).then(function(){
  var c = document.createElement('canvas').getContext('2d');
  c.font = '16px MB';
  var strs = %s;
  var out = [];
  for (var i = 0; i < strs.length; i++) {
    var w = c.measureText(strs[i]).width;
    out.push(Math.round(w * 100));
  }
  var pre = document.createElement('pre');
  pre.id = '__mbrowse_widths';
  pre.textContent = out.join('\n');
  document.documentElement.appendChild(pre);
});
</script></body></html>"""

FLAGS = ["--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--window-size=800,600", "--force-device-scale-factor=1",
         "--allow-file-access-from-files", "--virtual-time-budget=6000", "--dump-dom"]


def main(data_dir, tmp):
    font = os.path.abspath(os.path.join(data_dir, "NotoSans-Regular.ttf"))
    if not os.path.exists(font):
        print("gen_font_expected: no font — run scripts/vendor_font.sh", file=sys.stderr)
        return 1
    import json
    page = os.path.join(tmp, "measure.html")
    open(page, "w", encoding="utf-8").write(PAGE % (font, json.dumps(STRINGS)))
    got = subprocess.run([CHROME] + FLAGS + ["file://" + page],
                         capture_output=True, text=True, timeout=180).stdout
    marker = '<pre id="__mbrowse_widths">'
    if marker not in got:
        print("gen_font_expected: the browser produced no answer", file=sys.stderr)
        return 1
    body = got.split(marker, 1)[1].split("</pre>", 1)[0]
    for a, b in (("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"')):
        body = body.replace(a, b)
    lines = [l for l in body.strip("\n").split("\n") if l]
    if len(lines) != len(STRINGS):
        print("gen_font_expected: %d answers for %d strings" % (len(lines), len(STRINGS)),
              file=sys.stderr)
        return 1
    def esc(x):
        return (x.replace("\\", "\\\\").replace("\t", "\\t")
                 .replace("\n", "\\n").replace("\r", "\\r"))
    open(os.path.join(data_dir, "widths.cases"), "w", encoding="utf-8").write(
        "\n".join(esc(x) for x in STRINGS) + "\n")
    open(os.path.join(data_dir, "widths.expected"), "w", encoding="utf-8").write(
        "\n".join(lines) + "\n")
    print("gen_font_expected: %d widths written" % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
