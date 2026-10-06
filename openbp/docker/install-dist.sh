# Run by openbp/docker/Dockerfile with a bind-mounted busybox:
#   /tmp/openbp/busybox sh /tmp/openbp/install-dist.sh
# Replaces the official web UI with ours (bind-mounted at /tmp/openbp/dist).
set -eu
bb=/tmp/openbp/busybox
dist=/usr/share/coolwsd/browser/dist
new=/tmp/openbp/dist

# The translated UNO command labels (l10n/uno/*.json) are generated from the
# engine translations, which the public mirror does not carry. Reuse the ones
# from the official build of the same release for languages we lack.
old=/tmp/openbp-old-dist
$bb mv "$dist" "$old"
$bb cp -a "$new" "$dist"
$bb mkdir -p "$dist/l10n/uno"
for f in "$old"/l10n/uno/*.json; do
    [ -e "$f" ] || continue
    name=$($bb basename "$f")
    [ -s "$dist/l10n/uno/$name" ] || $bb cp "$f" "$dist/l10n/uno/$name"
done

# Drop the rest of the official web UI: this also removes Collabora's own
# branding files and the integration themes (e.g. dist/nextcloud).
$bb rm -rf "$old"
$bb chown -R 0:0 "$dist"

# Server defaults:
# - no periodic version check against Collabora's update server,
# - integration themes off (there is only the OpenBP one),
# - product name reported by /hosting/capabilities.
conf=/etc/coolwsd/coolwsd.xml
owner=$($bb stat -c %u:%g "$conf")
$bb sed -i \
    -e 's|\(<fetch_update_check [^>]*>\)[0-9]*<|\10<|' \
    -e 's|\(<use_integration_theme [^>]*>\)true<|\1false<|' \
    -e 's|^\(\s*<config>\)\s*$|\1\n    <product_name desc="Product name reported to integrations" type="string" default="OpenBP Docs">OpenBP Docs</product_name>|' \
    "$conf"
$bb chown "$owner" "$conf"
$bb grep -q '<product_name ' "$conf"
$bb grep -q '<fetch_update_check [^>]*>0<' "$conf"

