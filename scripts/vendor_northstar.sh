#!/bin/sh
# scripts/vendor_northstar.sh — take a real page off the web, once, and commit it.
#
# A9 is "fetch a real page over HTTPS and draw it". The fetching is gated separately and against
# curl; what is left is whether the drawing is right, and that needs an oracle — a browser rendering
# the SAME page. A live URL cannot give that: the page changes between the two renderings, and then
# a red gate means the site was edited as often as it means anything. It is the same reason
# `fetch_check.sh` serves its corpus itself.
#
# So the page is snapshotted here and the bytes are committed. Both the browser and this engine are
# then handed the same file, and the network is exercised by a smoke run rather than by the gate.
#
# **curl takes the snapshot, not `src/fetch.mere`.** The two are held to each other elsewhere, and a
# vendoring tool that uses the subject to fetch the input its own oracle will read is a shape worth
# not having: if both were wrong in the same way, the snapshot would be wrong and nothing would say
# so. curl is also what a checkout has before it has built anything.
#
# PROVENANCE records the URL, when it was taken and the SHA-256, because a snapshot with no date is
# a page from an unknown year and a snapshot with no digest cannot be told from an edited one.
#
# Usage:
#   sh scripts/vendor_northstar.sh <name> <url>
#   sh scripts/vendor_northstar.sh example-com https://example.com/
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:-}"
url="${2:-}"
[ -n "$name" ] && [ -n "$url" ] || { echo "usage: sh scripts/vendor_northstar.sh <name> <url>" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "vendor_northstar: curl needed" >&2; exit 1; }

d="$ROOT/test/data/northstar/$name"
mkdir -p "$d"

# `identity`, because what is committed has to be the bytes the parser sees. A gzip-encoded snapshot
# would be a file this repository cannot read and the browser can, which is a difference in the
# INPUT masquerading as a difference in the engine.
curl -sS --fail --max-time 60 -H 'Accept-Encoding: identity' -A 'mbrowse/vendor' \
     "$url" -o "$d/index.html"

sha=$(shasum -a 256 "$d/index.html" | cut -d' ' -f1)
{
  echo "url:      $url"
  echo "fetched:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "sha256:   $sha"
  echo "bytes:    $(wc -c < "$d/index.html" | tr -d ' ')"
} > "$d/PROVENANCE"

echo "vendored $name:"
sed 's/^/  /' "$d/PROVENANCE"
