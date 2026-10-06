#!/usr/bin/env bash
# Replace the contents of <worktree> with a pruned snapshot of upstream <tag>.
#
#   snapshot-upstream.sh <tag> <worktree>
#
# Only the paths selected by openbp/snapshot.sparse are copied, so the engine
# sources, mobile/desktop apps, upstream CI and other unused parts never enter
# our repository. <worktree> is expected to be a checkout of the `upstream`
# branch; the caller commits the result. The tag and commit are recorded in
# <worktree>/.upstream-version.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../upstream.conf
. "$here/upstream.conf"

tag=${1:?usage: $0 <tag> <worktree>}
dest=$(cd "${2:?usage: $0 <tag> <worktree>}" && pwd)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git -C "$tmp" init -q
git -C "$tmp" remote add origin "$UPSTREAM_URL"
git -C "$tmp" fetch -q --depth=1 --filter=blob:none origin "refs/tags/$tag:refs/tags/$tag"
git -C "$tmp" sparse-checkout set --no-cone --stdin < "$here/snapshot.sparse"
git -C "$tmp" -c advice.detachedHead=false checkout -q "refs/tags/$tag"
commit=$(git -C "$tmp" rev-parse HEAD)

# The app directories are pruned, but configure.ac/automake still require their
# build templates (also inside AM_CONDITIONALs that are never true for us).
# Restore just those so ./autogen.sh works without touching configure.ac.
stub_dirs="android ios windows macos qt wasm fuzzer"
# shellcheck disable=SC2086
git -C "$tmp" ls-tree -r --name-only HEAD -- $stub_dirs |
    grep -E '(\.in|/Makefile\.am)$' |
    while IFS= read -r f; do
        mkdir -p "$tmp/$(dirname "$f")"
        git -C "$tmp" show "HEAD:$f" > "$tmp/$f"
    done

rsync -a --delete --exclude=/.git "$tmp/" "$dest/"
printf 'tag=%s\ncommit=%s\n' "$tag" "$commit" > "$dest/.upstream-version"
echo "Snapshot of $tag ($commit) written to $dest"
