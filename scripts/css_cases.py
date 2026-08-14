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
    """The expected list in the canonical form, or (None, why) when it uses a shape this
    tokenizer cannot produce yet.

    The canonical form is one line per component value, and a tree is its root line
    followed by its children indented two spaces per level:

        B<TAB>value                a bare token
        N<TAB>kind<TAB>fields...   a named one
        K<TAB>()                   a simple block, children indented below
        F<TAB>name                 a function, children indented below

    `why` is what is missing, and it took two rounds of being wrong to get these apart.
    Calling all of it "blocks and functions" hid thirteen numeric cases; calling the rest
    "nested" then hid nine `unicode-range` cases and two hash flags, which are not trees
    at all and not one piece of work with trees. A bucket is a claim about what is left,
    so a bucket that names the wrong thing is a wrong estimate of the work.
    """
    why = set()
    lines = _render_into(expected, 0, [], why)
    if why:
        return (None, ",".join(sorted(why)))
    return ("\n".join(lines), None)


def _render_into(vals, depth, lines, why):
    pad = "  " * depth
    for v in vals:
        if isinstance(v, str):
            lines.append("%sB\t%s" % (pad, esc(v)))
        elif not isinstance(v, list) or not v:
            why.add("other")
        elif v[0] in ("()", "[]", "{}"):
            lines.append("%sK\t%s" % (pad, v[0]))
            _render_into(v[1:], depth + 1, lines, why)
        elif v[0] == "function":
            lines.append("%sF\t%s" % (pad, esc(v[1])))
            _render_into(v[2:], depth + 1, lines, why)
        elif v[0] == "hash":
            # The flag is the tokenizer's answer to "could this be an identifier", which
            # is what tells `#0red` from `#red`, so it is a decision and it is compared.
            lines.append("%sN\thash\t%s\t%s" % (pad, esc(v[1]), v[2]))
        elif v[0] == "unicode-range":
            # Two code points, and both are arithmetic the tokenizer did: `u+1?` means
            # 0x10 through 0x1F, and getting the fill wrong is the whole bug there is.
            lines.append("%sN\tunicode-range\t%d\t%d" % (pad, v[1], v[2]))
        elif v[0] in ("number", "dimension", "percentage"):
            # Everything the tokenizer decides, and not the numeric value. The value is
            # arithmetic on the representation — the suite writes `+45.0` as 45 — so
            # comparing it would be comparing how two languages print a float, which is
            # not what this gate is for. The representation, the integer-or-number
            # decision and the unit are all tokenizer decisions and are all compared.
            if v[0] == "dimension":
                lines.append("%sN\tdimension\t%s\t%s\t%s" % (pad, esc(v[1]), v[3], esc(v[4])))
            else:
                lines.append("%sN\t%s\t%s\t%s" % (pad, v[0], esc(v[1]), v[3]))
        elif len(v) == 2 and isinstance(v[1], str):
            lines.append("%sN\t%s\t%s" % (pad, v[0], esc(v[1])))
        else:
            why.add("other:" + str(v[0]))
    return lines


def _group(text):
    """Lines back into component values: a line at depth zero starts a new one and the
    indented lines under it belong to it."""
    out = []
    for line in (text.split("\n") if text else []):
        if line.startswith("  ") and out:
            out[-1].append(line)
        else:
            out.append([line])
    return out


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
        # A component value is no longer a line — a tree is several — so the lines are
        # grouped back into component values by their indentation before being compared.
        # Reporting "line 14" would name a place inside a tree and not the tree, and the
        # tree is what differs.
        wl, al = _group(w), _group(a)
        first = None
        for k in range(max(len(wl), len(al))):
            wk = wl[k] if k < len(wl) else ["<nothing>"]
            ak = al[k] if k < len(al) else ["<nothing>"]
            if wk != ak:
                first = (k, wk, ak)
                break
        if first is None:
            print("  FAIL (lengths %d vs %d, no differing element)" % (len(wl), len(al)))
        else:
            k, wk, ak = first
            print("  FAIL at component value %d of %d:" % (k + 1, len(wl)))
            for tag, rows in (("want", wk), ("got ", ak)):
                for j, r in enumerate(rows):
                    print("       %s %s" % (tag if j == 0 else "    ", r))
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
