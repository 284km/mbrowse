#!/usr/bin/env python3
"""html5lib-tests' tree-construction .dat -> cases, and compare.

A block is `#data`, the source, `#errors`, then `#document` and the expected tree in
the indented form src/dom.mere serializes to. Cases with `#document-fragment` are the
fragment parsing algorithm, which is a different entry point, and are counted as
skipped rather than failed.
"""
import sys, os

def esc(s):
    out = []
    for ch in s:
        if ch == "\\": out.append("\\\\")
        elif ch == "\t": out.append("\\t")
        elif ch == "\n": out.append("\\n")
        elif ch == "\r": out.append("\\r")
        elif ord(ch) < 0x20 or ord(ch) == 0x7F: out.append("\\x%02x" % ord(ch))
        else: out.append(ch)
    return "".join(out)

def collect(d):
    cases = []
    for name in sorted(os.listdir(d)):
        if not name.startswith("tree_") or not name.endswith(".dat"): continue
        text = open(os.path.join(d, name), encoding="utf-8").read()
        for block in text.split("\n#data\n"):
            block = block.lstrip("#data\n") if block.startswith("#data\n") else block
            if "#document" not in block: continue
            data = block.split("\n#errors")[0]
            doc = block.split("\n#document\n", 1)
            if len(doc) < 2: continue
            tree = doc[1].rstrip("\n")
            skip = "fragment" if "#document-fragment" in block else None
            # The suite writes each line as `| ` plus two spaces per level; ours is
            # two spaces per level with no bar, and it does not print the implied
            # <html> wrapper differently. Convert rather than change the serializer:
            # the bar is the suite's, the indentation is the tree's.
            lines = []
            for l in tree.split("\n"):
                if not l.startswith("| "): 
                    lines = None; break
                lines.append(l[2:])
            if lines is None: continue
            cases.append((name, data, "\n".join(lines), skip))
    return cases

if sys.argv[1] == "--compare":
    got = open(sys.argv[2], encoding="utf-8").read()
    meta = open(sys.argv[3], encoding="utf-8").read()
    expect = int(sys.argv[4])
    blocks = {}
    cur = None
    for line in got.split("\n"):
        if line.startswith("##"): cur = int(line[2:]); blocks[cur] = []
        elif cur is not None: blocks[cur].append(line)
    rows = [l.split("\t", 2) for l in meta.split("\n") if l]
    p = f = 0; sk = 0; bad = []
    for i, (skip, fname, want) in enumerate(rows):
        a = "\n".join(blocks.get(i, [])).strip("\n")
        if a.endswith("\n0"): a = a[:-2]
        elif a == "0": a = ""
        w = want.replace("\\n", "\n")
        if skip: sk += 1; continue
        if a == w: p += 1
        else:
            f += 1
            if len(bad) < 5: bad.append((fname, w, a))
    print("tree_construction: %d passed, %d failed, %d skipped (fragment), of %d"
          % (p, f, sk, len(rows)))
    for fname, w, a in bad:
        print("  FAIL %s\n    want: %s\n    got:  %s" % (fname, w.replace("\n"," | "), a.replace("\n"," | ")))
    if p != expect:
        print("tree_construction: expected exactly %d passing, got %d — raise "
              "EXPECT_PASS if this is the builder growing" % (expect, p))
        sys.exit(1)
    print("tree_construction: ok")
    sys.exit(0)

d, cases_path, meta_path = sys.argv[1], sys.argv[2], sys.argv[3]
cases = collect(d)
with open(cases_path, "w", encoding="utf-8") as cf, open(meta_path, "w", encoding="utf-8") as mf:
    for name, data, tree, skip in cases:
        cf.write(esc(data) + "\n")
        mf.write("%s\t%s\t%s\n" % (skip or "", name, tree.replace("\n", "\\n")))
print("tree_construction: %d cases from %s" % (len(cases), d))
