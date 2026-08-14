#!/usr/bin/env python3
"""css-parsing-tests' component value list -> cases, and compare.

The suite's array alternates input and expected. A component value is either a bare
string, for a token that is only itself, or a two-element array naming it — both shapes
in the same list, which is why the canonical form here keeps them apart:

    B<TAB>value        a bare token
    N<TAB>kind<TAB>value   a named one

src/css_tokens.mere renders exactly this.
"""
import json, sys

def esc(s):
    out = []
    for ch in s:
        if ch == "\\": out.append("\\\\")
        elif ch == "\t": out.append("\\t")
        elif ch == "\n": out.append("\\n")
        elif ch == "\r": out.append("\\r")
        else: out.append(ch)
    return "".join(out)

def esc_in(s):
    out = []
    for ch in s:
        if ch == "\\": out.append("\\\\")
        elif ch == "\t": out.append("\\t")
        elif ch == "\n": out.append("\\n")
        elif ch == "\r": out.append("\\r")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F: out.append("\\x%02x" % ord(ch))
        else: out.append(ch)
    return "".join(out)

def render(expected):
    """The expected list in the canonical form, or None when it uses a shape this
    level does not implement — blocks, functions with children, url(). Those are
    counted as not-covered rather than as failures, because the tokenizer is not
    wrong about them, it does not reach them."""
    lines = []
    for v in expected:
        if isinstance(v, str):
            lines.append("B\t%s" % esc(v))
        elif isinstance(v, list) and len(v) == 2 and isinstance(v[1], str):
            lines.append("N\t%s\t%s" % (v[0], esc(v[1])))
        else:
            return None
    return "\n".join(lines)

if sys.argv[1] == "--compare":
    got, meta, expect = sys.argv[2], sys.argv[3], int(sys.argv[4])
    blocks, cur = {}, None
    for line in open(got, encoding="utf-8").read().split("\n"):
        if line.startswith("##"): cur = int(line[2:]); blocks[cur] = []
        elif cur is not None: blocks[cur].append(line)
    rows = [l.split("\t", 1) for l in open(meta, encoding="utf-8").read().split("\n") if l]
    p = f = sk = 0; bad = []
    for i, (kind, want) in enumerate(rows):
        a = "\n".join(blocks.get(i, [])).strip("\n")
        if a.endswith("\n0"): a = a[:-2]
        elif a == "0": a = ""
        if kind == "skip": sk += 1; continue
        w = want.replace("\\N", "\n")
        if a == w: p += 1
        else:
            f += 1
            if len(bad) < 5: bad.append((w, a))
    print("css_tokens: %d passed, %d failed, %d not covered (blocks and functions), of %d"
          % (p, f, sk, len(rows)))
    for w, a in bad:
        print("  FAIL want: %s" % w.replace("\n", " | "))
        print("       got:  %s" % a.replace("\n", " | "))
    if p != expect:
        print("css_tokens: expected exactly %d passing, got %d — raise EXPECT_PASS if this "
              "is the tokenizer growing" % (expect, p))
        sys.exit(1)
    print("css_tokens: ok")
    sys.exit(0)

data = json.load(open(sys.argv[1], encoding="utf-8"))
with open(sys.argv[2], "w", encoding="utf-8") as cf, open(sys.argv[3], "w", encoding="utf-8") as mf:
    for i in range(0, len(data), 2):
        src, exp = data[i], data[i + 1]
        cf.write(esc_in(src) + "\n")
        r = render(exp)
        if r is None: mf.write("skip\t\n")
        else: mf.write("ok\t%s\n" % r.replace("\n", "\\N"))
print("css_tokens: %d cases" % (len(data) // 2))
