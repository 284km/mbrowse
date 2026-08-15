#!/usr/bin/env python3
"""Fetch and filter the WPT layout documents. Driven by vendor_layout_tests.sh."""
import json, os, re, sys
from concurrent.futures import ThreadPoolExecutor
from urllib.request import urlopen

listing, base, tmp, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

# The selection is a set of prefixes and it is deliberate: taking all 905 would vendor
# documents about features nothing here implements, and a corpus full of documents that
# cannot be right is not a measurement, it is a backlog. Widen the set when the engine
# widens — which is what `inline-`/`inlines-` are: the block families came first because
# blocks came first, and inline layout is where every remaining failure lives, so it is
# where more documents buy the most.
#
# The `-` matters. `block-` does not match `blocks-`, which is why both are named.
PREFIXES = ("block-", "blocks-", "inline-", "inlines-")

names = [f["name"] for f in json.load(open(listing))
         if f["name"].startswith(PREFIXES) and f["name"].endswith(".xht")]
print("vendor_layout_tests: %d candidates" % len(names))


def get(n):
    try:
        with urlopen(base + "/" + n, timeout=60) as r:
            open(os.path.join(tmp, n), "wb").write(r.read())
        return None
    except Exception as e:
        return "%s: %s" % (n, e)


with ThreadPoolExecutor(max_workers=8) as ex:
    for miss in [m for m in ex.map(get, names) if m]:
        print("  MISS %s" % miss)

# Anything that reaches outside the file has no correct answer here. The `rel` links these
# documents carry — author, reviewer, help, match — load nothing, so they stay.
external = re.compile(
    r"<img|<iframe|<object|<embed|<script|<video|<audio|url\s*\(|"
    r"<link[^>]*rel\s*=\s*[\"']?stylesheet", re.I)

kept = dropped = 0
for name in sorted(os.listdir(tmp)):
    if not name.endswith(".xht"):
        continue
    text = open(os.path.join(tmp, name), encoding="utf-8", errors="replace").read()
    if external.search(text):
        dropped += 1
        continue
    open(os.path.join(out, name[:-4] + ".html"), "w", encoding="utf-8").write(text)
    kept += 1
print("vendor_layout_tests: %d vendored, %d dropped for reaching outside themselves"
      % (kept, dropped))
