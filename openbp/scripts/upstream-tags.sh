#!/usr/bin/env bash
# Helpers around upstream release tags.
#
#   upstream-tags.sh list              all release tags, oldest first
#   upstream-tags.sh base-image <tag>  official image for <tag>
#                                      (cp-26.04.4-2 -> docker.io/collabora/code:26.04.4.2.1)
#   upstream-tags.sh version <tag>     our image version for <tag> (cp-26.04.4-2 -> 26.04.4-2)
#   upstream-tags.sh newer <a> <b>     exit 0 if tag <a> is newer than tag <b>
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../upstream.conf
. "$here/upstream.conf"

check_tag() {
    [[ $1 =~ $UPSTREAM_TAG_REGEX ]] || { echo "not a release tag: $1" >&2; exit 2; }
}

case "${1:-}" in
list)
    git ls-remote --tags --refs "$UPSTREAM_URL" 'cp-*' |
        sed 's#.*refs/tags/##' | grep -E "$UPSTREAM_TAG_REGEX" | sort -V
    ;;
base-image)
    check_tag "$2"
    v=${2#cp-}
    echo "$BASE_IMAGE:${v%-*}.${v##*-}.1"
    ;;
version)
    check_tag "$2"
    echo "${2#cp-}"
    ;;
newer)
    check_tag "$2"; check_tag "$3"
    [ "$2" != "$3" ] && [ "$(printf '%s\n%s\n' "$2" "$3" | sort -V | tail -1)" = "$2" ]
    ;;
*)
    sed -n '2,10p' "$0" >&2
    exit 2
    ;;
esac
