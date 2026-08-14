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
    """The expected list in the canonical form, or (None, why) when it uses a shape the
    tokenizer's output cannot be compared against yet.

    There are two reasons, and calling both of them "blocks and functions" was wrong:

      nested          a function with children, or a block — a tree, which needs a
                      parser over the tokens and not more tokens
      numeric-fields  a number, dimension or percentage, which the suite writes with
                      five fields — kind, representation, value, integer-or-number, and
                      the unit — where this emits two

    The second is not a shape the tokenizer cannot reach. It is a shape it does reach
    and does not say enough about, which is a different and smaller piece of work, and
    counting the two together hid thirteen cases behind a label that did not fit them.
    """
    lines = []
    for v in expected:
        if isinstance(v, str):
            lines.append("B\t%s" % esc(v))
        elif isinstance(v, list) and len(v) == 2 and isinstance(v[1], str):
            lines.append("N\t%s\t%s" % (v[0], esc(v[1])))
        elif isinstance(v, list) and v and v[0] in ("number", "dimension", "percentage"):
            # Everything the tokenizer decides, and not the numeric value. The value is
            # arithmetic on the representation — the suite writes `+45.0` as 45 — so
            # comparing it would be comparing how two languages print a float, which is
            # not what this gate is for. The representation, the integer-or-number
            # decision and the unit are all tokenizer decisions and are all compared.
            if v[0] == "dimension":
                lines.append("N\tdimension\t%s\t%s\t%s" % (esc(v[1]), v[3], esc(v[4])))
            else:
                lines.append("N\t%s\t%s\t%s" % (v[0], esc(v[1]), v[3]))
        else:
            return (None, "nested")
    return ("\n".join(lines), None)

if sys.argv[1] == "--compare":
    got, meta, expect = sys.argv[2], sys.argv[3], int(sys.argv[4])
    blocks, cur = {}, None
    for line in open(got, encoding="utf-8").read().split("\n"):
        if line.startswith("##"): cur = int(line[2:]); blocks[cur] = []
        elif cur is not None: blocks[cur].append(line)
    rows = [l.split("\t", 1) for l in open(meta, encoding="utf-8").read().split("\n") if l]
    p = f = sk = 0; bad = []; by_why = {}
    for i, (kind, want) in enumerate(rows):
        a = "\n".join(blocks.get(i, [])).strip("\n")
        if a.endswith("\n0"): a = a[:-2]
        elif a == "0": a = ""
        if kind.startswith("skip"):
            sk += 1
            by_why[kind[5:]] = by_why.get(kind[5:], 0) + 1
            continue
        w = want.replace("\\N", "\n")
        if a == w: p += 1
        else:
            f += 1
            if len(bad) < 5: bad.append((w, a))
    print("css_tokens: %d passed, %d failed, %d not compared, of %d"
          % (p, f, sk, len(rows)))
    for w in sorted(by_why):
        print("  not compared: %-16s %d" % (w, by_why[w]))
    for w, a in bad:
        # Element-wise, not the whole line. These cases pack dozens of inputs into one,
        # so a joined diff says "something in here" and leaves the reader to align two
        # long strings by eye — which is how a case can sit one detail from passing
        # without anyone knowing which detail.
        wl, al = w.split("\n") if w else [], a.split("\n") if a else []
        first = None
        for k in range(max(len(wl), len(al))):
            wk = wl[k] if k < len(wl) else "<nothing>"
            ak = al[k] if k < len(al) else "<nothing>"
            if wk != ak:
                first = (k, wk, ak)
                break
        if first is None:
            print("  FAIL (lengths %d vs %d, no differing element)" % (len(wl), len(al)))
        else:
            k, wk, ak = first
            print("  FAIL at component value %d of %d:" % (k + 1, len(wl)))
            print("       want: %s" % wk)
            print("       got:  %s" % ak)
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
        r, why = render(exp)
        if r is None: mf.write("skip-%s\t\n" % why)
        else: mf.write("ok\t%s\n" % r.replace("\n", "\\N"))
print("css_tokens: %d cases" % (len(data) // 2))
