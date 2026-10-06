# Notes for Claude: OpenBP Docs

This repository is public. Never commit secrets, hostnames of private systems or customer data.

## What this is

This repo is a rebranded fork of Collabora Online ("OpenBP Docs"). It ships only as a Docker image
on GHCR, for browser use inside OpenBP. The README describes it for humans.

## Invariants (keep merges conflict-free)

- **Never edit upstream files on `main`.** OpenBP changes go only into new paths: `openbp/`,
  `.github/`, `README.md`, `CLAUDE.md`. Upstream versions of `README.md`, `CLAUDE.md`, `AGENTS.md`
  and `.github/` are pruned from snapshots, so ours never collide.
- **Delete upstream content through `openbp/snapshot.sparse`**, never with `git rm` on main. A
  deletion on main turns into a modify/delete conflict on the next upstream change.
- **`upstream` branch:** commits made only by `openbp/scripts/snapshot-upstream.sh`, one per
  upstream tag. `.upstream-version` exists only there and reaches main through merges.
- **History:** upstream history is deliberately not kept. Main and upstream share history only
  through the vendor-branch merges, so `git merge upstream` is a proper 3-way merge.

## Build model (hybrid)

- **Web UI:** `browser/dist` is built from this repo in `openbp/docker/Dockerfile`, stage
  `builder` (debian:trixie, node 20). The steps are `./autogen.sh`, `./configure`, then
  `make -C browser`. coolwsd itself is not compiled.
- **Runtime:** taken from the official `docker.io/collabora/code:<X.Y.Z.N.1>` for upstream tag
  `cp-X.Y.Z-N`. That image is hardened and has no shell or package manager. The final stage
  bind-mounts a static busybox for a single `RUN` (`openbp/docker/install-dist.sh`), so neither
  busybox (GPL) nor the staging files land in a layer. busybox picks the applet from argv[0],
  so the binary must be named `busybox`.
- **Why not build coolwsd:** since 2026 upstream is a monorepo with `engine/` (LibreOffice core,
  about 1.3 GB). The online C++ build needs a configured engine build tree (gbuild
  `partial_build.mk`, `config_host.mk`, externals). A full engine build takes 3-5 hours on a free
  GitHub runner.
- **Not stored in git, fetched per build** by `openbp/scripts/fetch-build-assets.sh` at the tag
  in `.upstream-version`:
  - `engine/` slice: `include` (COKit headers), `distro-configs/Langs.conf`, `officecfg/.../Office`
    for unocommands/unoshortcuts, and `vcl/unx/generic/app`.
  - `browser/node_shrinkpack`: about 250 MB of npm tarballs for `npm ci --offline`.
- **Stub dirs:** configure.ac and automake need `*.in` and `Makefile.am` files from pruned app
  dirs (android, ios, windows, macos, qt, wasm, fuzzer). The snapshot script restores just those
  files.
- **UNO translations:** the public mirror has no `engine/translations`, so our build has no
  translated UNO command labels. install-dist.sh copies `l10n/uno/*.json` from the official
  image for languages we lack.

## Branding (`openbp/branding`, MPL-2.0, all written from scratch)

- **How it gets in:** `configure --with-app-branding=openbp/branding` copies `branding*` and
  `images/*.svg` into dist. coolwsd injects `branding.css` and `branding.js` into every page.
- **branding.js** sets `brandProductName` and friends. It runs after global.js and before the
  deferred bundle.js, so it also forces welcome, feedback and update notices off. The CODE
  binaries are built with ENABLE_WELCOME_MESSAGE, which cannot be disabled via config.
- **branding.css** overrides the colours (`--color-primary*`, Writer `--doc-type`), the logos and
  the spinner. It also hides Help → Forum, Report an issue and Send Feedback; notebookbar ids
  have numeric suffixes such as `forum352`.
- **install-dist.sh** patches `/etc/coolwsd/coolwsd.xml`:
  - adds `product_name` (shown in /hosting/capabilities)
  - sets `fetch_update_check=0` (no phoning home)
  - sets `use_integration_theme=false`
- **Never copy Collabora's own branding files.** The `branding.*` and logos in the official image
  are "All Rights Reserved". Dropping the whole official dist removes them.
- **Colours:** OpenBP blue `#0094FF` (text variant `#0077CC`) and dark `#303030`. The logo
  geometry comes from `openbp-landing/src/app/logo.png`.

## Testing locally

```sh
openbp/scripts/fetch-build-assets.sh
docker build -f openbp/docker/Dockerfile \
  --build-arg BASE_IMAGE=$(openbp/scripts/upstream-tags.sh base-image $(sed -n 's/^tag=//p' .upstream-version)) \
  -t openbp-docs:test .
openbp/test/smoke.sh openbp-docs:test
# Manual check: WOPI test host plus container on the host network
docker run -d --name obp --network host -e aliasgroup1=http://127.0.0.1:8090 \
  -e "extra_params=--o:ssl.enable=false" openbp-docs:test
python3 openbp/test/wopi-host.py <dir-with-documents>   # open http://127.0.0.1:8090/
```

Headless screenshots work with Playwright (`chromium.launch`, POST the form from the index page).

## Gotchas seen

- `set -o pipefail` with `| head` or `| grep -q` gives exit code 141 (SIGPIPE). Capture output
  into a variable first.
- Release tags look like `cp-26.04.4-2`. Ignore `cp-*-HEAD`, `coda-*` and `helm-*`. The official
  image `26.04.4.2.1` appears a day or so after the tag; the sync waits for it.
- GitHub disables scheduled workflows after 60 days without repository activity. Re-enable
  `Sync upstream` in the Actions tab if that happens.
