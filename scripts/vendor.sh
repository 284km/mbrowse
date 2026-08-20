#!/bin/sh
# scripts/vendor.sh — copy the Mere libraries this browser needs into .mere_modules.
#
# Mere resolves `import "<package>/<module>.mere"` by walking up to the nearest
# .mere_modules/, so a dependency is a vendored copy rather than a path. The copies
# are committed: a checkout should build without first fetching anything, and the
# version that was built against should be visible in the history rather than
# implied by whatever was on the machine.
#
# Point MERE_SRC at a checkout of the Mere repository (github.com/merelang/mere).
#
# Usage:
#   MERE_SRC=/path/to/mere sh scripts/vendor.sh

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "$MERE_SRC" ] || { echo "vendor: set MERE_SRC to a checkout of the Mere repository" >&2; exit 1; }
[ -d "$MERE_SRC/contrib/html" ] || { echo "vendor: $MERE_SRC does not look like it" >&2; exit 1; }

mkdir -p "$ROOT/.mere_modules/mere-html"
for f in tokenizer.mere entities.mere; do
  cp "$MERE_SRC/contrib/html/$f" "$ROOT/.mere_modules/mere-html/$f"
  echo "vendored mere-html/$f"
done

mkdir -p "$ROOT/.mere_modules/mere-encoding"
for f in decode.mere labels.mere jis.mere jis_index.mere; do
  cp "$MERE_SRC/contrib/encoding/$f" "$ROOT/.mere_modules/mere-encoding/$f"
  echo "vendored mere-encoding/$f"
done

# A fetch needs to know what a URL means, and a page's links need resolving against it. Both are
# the URL Standard's answers rather than string surgery, and there is an implementation of it
# already held to the WPT suite where it lives — writing a second one here would be a second thing
# to be wrong, with no oracle attached.
mkdir -p "$ROOT/.mere_modules/mere-url"
for f in host.mere path.mere percent.mere ipv6.mere; do
  cp "$MERE_SRC/contrib/url/$f" "$ROOT/.mere_modules/mere-url/$f"
  echo "vendored mere-url/$f"
done

# Imports inside a vendored module name the package, not a sibling file. Done in
# python because the obvious `sed -E` for it is one of the places BSD and GNU differ.
python3 - "$ROOT" <<'REWIRE'
import os, re, sys
root = sys.argv[1]
for pkg in ("mere-html", "mere-encoding", "mere-url"):
    d = os.path.join(root, ".mere_modules", pkg)
    for f in os.listdir(d):
        p = os.path.join(d, f); s = open(p).read()
        # [a-z0-9_], not [a-z_]: `ipv6.mere` is the only sibling with a digit in it and it was the
        # only one this rewrote nothing for, so the vendored copy imported a path that does not
        # resolve. A rewriter that silently skips what it does not recognise leaves a module that
        # fails at its first use rather than here.
        s2 = re.sub(r'import "(?!mere-)([a-z0-9_]+\.mere)"', r'import "%s/\1"' % pkg, s)
        if s2 != s:
            open(p, "w").write(s2)
            print("rewired " + pkg + "/" + f)
REWIRE
