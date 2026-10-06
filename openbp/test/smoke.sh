#!/usr/bin/env bash
# Smoke-test an OpenBP Docs image: start it, wait for coolwsd, check that the
# OpenBP web UI and branding are what gets served.
#
#   smoke.sh <image>
set -euo pipefail

image=${1:?usage: $0 <image>}
name=openbp-docs-smoke-$$
port=9980

cleanup() {
    status=$?
    if [ $status -ne 0 ]; then
        echo "---- container log (tail) ----"
        docker logs "$name" 2>&1 | tail -50 || true
    fi
    docker rm -f "$name" >/dev/null 2>&1 || true
    exit $status
}
trap cleanup EXIT

docker run -d --name "$name" -p "$port:9980" \
    -e "extra_params=--o:ssl.enable=false" "$image" >/dev/null

base=http://127.0.0.1:$port
for _ in $(seq 1 90); do
    curl -sf "$base/hosting/capabilities" >/dev/null && break
    sleep 2
done

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

caps=$(curl -sf "$base/hosting/capabilities") || fail "coolwsd did not come up"
echo "capabilities: $caps"
grep -q '"productName":"OpenBP Docs"' <<<"$caps" || fail "productName is not OpenBP Docs"

discovery=$(curl -sf "$base/hosting/discovery") || fail "no discovery"
urlsrc=$(grep -m1 -o 'urlsrc="[^"]*cool.html?' <<<"$discovery" || true)
urlsrc=${urlsrc#urlsrc=\"}
[ -n "$urlsrc" ] || fail "no cool.html urlsrc in discovery"
root=${urlsrc%cool.html?}
root=${root/https:/http:}

page=$(curl -sf "${urlsrc}WOPISrc=http%3A%2F%2F127.0.0.1%2Fwopi%2Ffiles%2Fx") || fail "cool.html not served"
grep -q 'branding.js' <<<"$page" || fail "cool.html does not load branding.js"
grep -q 'branding.css' <<<"$page" || fail "cool.html does not load branding.css"

js=$(curl -sf "${root}branding.js") || fail "branding.js not served"
grep -q "OpenBP Docs" <<<"$js" || fail "branding.js is not the OpenBP one"
css=$(curl -sf "${root}branding.css") || fail "branding.css not served"
grep -q "openbp-logo.svg" <<<"$css" || fail "branding.css is not the OpenBP one"
curl -sf -o /dev/null "${root}images/openbp-logo.svg" || fail "OpenBP logo missing"
curl -sf -o /dev/null "${root}bundle.js" || fail "bundle.js missing"
if curl -sf -o /dev/null "${root}nextcloud/branding.css"; then
    fail "integration theme still present"
fi

echo "SMOKE OK: $image"
