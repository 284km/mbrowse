#!/usr/bin/env python3
"""html5lib-tests' encoding suite -> cases, and compare.

The .dat format is blocks separated by blank lines: `#data` then the bytes of the
page, `#encoding` then the encoding it should be taken as. The bytes are the point
— a case is about what a sequence of bytes says about itself — so they are passed
through escaped rather than as text.
"""
import sys, os

def esc(bs):
    out = []
    for b in bs:
        if b == 0x5C: out.append("\\\\")
        elif b == 0x09: out.append("\\t")
        elif b == 0x0A: out.append("\\n")
        elif b == 0x0D: out.append("\\r")
        elif b < 0x20 or b >= 0x7F: out.append("\\x%02x" % b)
        else: out.append(chr(b))
    return "".join(out)

def collect(d):
    cases = []
    for name in sorted(os.listdir(d)):
        if not name.endswith(".dat"): continue
        raw = open(os.path.join(d, name), "rb").read()
        for block in raw.split(b"\n\n"):
            if not block.strip(): continue
            if not block.startswith(b"#data\n"): continue
            rest = block[len(b"#data\n"):]
            i = rest.find(b"\n#encoding\n")
            if i < 0: continue
            data = rest[:i]
            enc = rest[i + len(b"\n#encoding\n"):].strip().decode("ascii", "replace")
            cases.append((name, data, enc.lower()))
    return cases

if sys.argv[1] == "--compare":
    got = [l for l in open(sys.argv[2], encoding="utf-8").read().split("\n")]
    meta = [l.split("\t") for l in open(sys.argv[3], encoding="utf-8").read().split("\n") if l]
    expect = int(sys.argv[4])
    p = f = 0; bad = []
    for i, (fname, want) in enumerate(meta):
        a = got[i].strip() if i < len(got) else ""
        if a == want: p += 1
        else:
            f += 1
            if len(bad) < 8: bad.append((fname, want, a))
    print("encoding_sniff: %d passed, %d failed, of %d cases" % (p, f, p + f))
    for fname, want, a in bad:
        print("  FAIL %s: want %s got %s" % (fname, want, a))
    if p != expect:
        print("encoding_sniff: expected exactly %d passing, got %d — raise EXPECT_PASS "
              "in the harness if this is the sniffer growing" % (expect, p))
        sys.exit(1)
    print("encoding_sniff: ok")
    sys.exit(0)

data_dir, cases_path, meta_path = sys.argv[1], sys.argv[2], sys.argv[3]
cases = collect(data_dir)
with open(cases_path, "w", encoding="utf-8") as cf, open(meta_path, "w", encoding="utf-8") as mf:
    for fname, data, enc in cases:
        cf.write(esc(data) + "\n")
        mf.write("%s\t%s\n" % (fname, enc))
print("encoding_sniff: %d cases from %s" % (len(cases), data_dir))
