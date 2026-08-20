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

# The window and the canvas it composites. `contrib/raster` is the canvas type and the polygon
# fill; `contrib/window` is SDL. Only the last step of the pipeline needs them -- everything that
# checks the drawing compares reference pixels and opens nothing.
mkdir -p "$ROOT/.mere_modules/mere-raster" "$ROOT/.mere_modules/mere-window"
for f in canvas.mere path.mere; do
  cp "$MERE_SRC/contrib/raster/$f" "$ROOT/.mere_modules/mere-raster/$f"
  echo "vendored mere-raster/$f"
done
cp "$MERE_SRC/contrib/window/window.mere" "$ROOT/.mere_modules/mere-window/window.mere"
echo "vendored mere-window/window.mere"

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
for pkg in ("mere-html", "mere-encoding", "mere-url", "mere-raster", "mere-window"):
    d = os.path.join(root, ".mere_modules", pkg)
    for f in os.listdir(d):
        p = os.path.join(d, f); s = open(p).read()
        # Two forms, and a rewriter that skips what it does not recognise is how a vendored module
        # comes to import a path that does not resolve -- found twice: `ipv6.mere`, because the
        # pattern was `[a-z_]+` and could not see a digit, and `../raster/canvas.mere`, because it
        # could not see a directory. So both forms are handled AND anything left over is an error
        # here rather than a failure at the module's first use.
        #   "sibling.mere"          -> "<pkg>/sibling.mere"
        #   "../other/file.mere"    -> "mere-other/file.mere"
        s2 = re.sub(r'import "(?!mere-)([a-z0-9_]+\.mere)"', r'import "%s/\1"' % pkg, s)
        s2 = re.sub(r'import "\.\./([a-z0-9_]+)/([a-z0-9_]+\.mere)"',
                    r'import "mere-\1/\2"', s2)
        # AT THE START OF A LINE, because `import "contrib/encoding/decode.mere"` also appears
        # inside a usage comment and is not an import. The first version of this check read every
        # occurrence and stopped the vendoring over a code sample.
        left = [m for m in re.findall(r'(?m)^import "([^"]+)"', s2) if not m.startswith("mere-")]
        if left:
            raise SystemExit("vendor: %s/%s imports %s, which nothing rewrote -- "
                             "the vendored copy would not resolve it"
                             % (pkg, f, ", ".join(left)))
        if s2 != s:
            open(p, "w").write(s2)
            print("rewired " + pkg + "/" + f)
REWIRE
