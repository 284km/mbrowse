#!/usr/bin/env python3
"""The reftest pairs the WPT documents name themselves, as `test<TAB>reference` lines.

The suite's authors said which two files must look the same, in a `<link rel="match">`. Reading it
rather than pairing by filename matters: several tests point at a shared reference, and one document
is both a test and somebody else's reference.

Pairs whose reference is not vendored here are dropped — silently would be wrong, so the count of
each is printed to stderr.
"""
import os, re, sys

d = sys.argv[1]
found = dropped = 0
for n in sorted(os.listdir(d)):
    if not n.endswith(".html"):
        continue
    s = open(os.path.join(d, n), encoding="utf-8", errors="replace").read()
    m = re.search(r'<link[^>]*rel\s*=\s*["\']?match["\']?[^>]*href\s*=\s*["\']([^"\']+)', s, re.I)
    if not m:
        m = re.search(r'<link[^>]*href\s*=\s*["\']([^"\']+)["\'][^>]*rel\s*=\s*["\']?match', s, re.I)
    if not m:
        continue
    ref = re.sub(r"\.(xht|xhtml|htm)$", ".html", os.path.basename(m.group(1)))
    if not ref.endswith(".html"):
        ref += ".html"
    if os.path.exists(os.path.join(d, ref)):
        print("%s\t%s" % (n, ref))
        found += 1
    else:
        dropped += 1
print("reftest_pairs: %d pairs, %d dropped for a reference that is not vendored"
      % (found, dropped), file=sys.stderr)
