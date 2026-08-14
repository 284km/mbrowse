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
