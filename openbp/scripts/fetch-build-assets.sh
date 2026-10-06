#!/usr/bin/env bash
# Fetch the upstream files the browser build needs but that are not stored in
# this repository (see openbp/snapshot.sparse), at the exact upstream tag
# recorded in .upstream-version:
#
#   engine/   - COKit headers, Langs.conf and the UI/Accelerators .xcu files
#               that unocommands.js / unoshortcuts.ts / l10n maps come from
#   browser/node_shrinkpack/ - vendored npm tarballs for `npm ci --offline`
#
#   fetch-build-assets.sh [<srcdir>]   (default: repository root)
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../upstream.conf
. "$here/upstream.conf"

src=$(cd "${1:-$here/..}" && pwd)
tag=$(sed -n 's/^tag=//p' "$src/.upstream-version")
[ -n "$tag" ] || { echo "no tag in $src/.upstream-version" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
git -C "$tmp" remote add origin "$UPSTREAM_URL"
git -C "$tmp" fetch -q --depth=1 --filter=blob:none origin "refs/tags/$tag:refs/tags/$tag"
git -C "$tmp" sparse-checkout set --cone \
    engine/include \
    engine/distro-configs \
    engine/officecfg/registry/data/org/openoffice/Office \
    engine/vcl/unx/generic/app \
    browser/node_shrinkpack
git -C "$tmp" -c advice.detachedHead=false checkout -q "refs/tags/$tag"

rsync -a --delete "$tmp/engine/" "$src/engine/"
rsync -a --delete "$tmp/browser/node_shrinkpack/" "$src/browser/node_shrinkpack/"

# Keep the fetched trees out of `git status` in a local checkout.
if gitdir=$(git -C "$src" rev-parse --git-dir 2>/dev/null); then
    exclude="$src/$gitdir/info/exclude"
    case "$gitdir" in /*) exclude="$gitdir/info/exclude" ;; esac
    mkdir -p "$(dirname "$exclude")"
    for p in /engine/ /browser/node_shrinkpack/; do
        grep -qxF "$p" "$exclude" 2>/dev/null || echo "$p" >> "$exclude"
    done
fi
echo "Fetched build assets for $tag into $src"
