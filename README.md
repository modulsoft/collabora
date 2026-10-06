# OpenBP Docs

Collaborative online office editor for [OpenBP](https://openbp.io). Several
people can edit the same text document, spreadsheet or presentation at the
same time, right in the browser.

OpenBP Docs is a rebranded build of **[Collabora Online](https://github.com/CollaboraOnline/online)**
([read-only mirror](https://github.com/CollaboraOnline/online.mirror), developed on
[Gerrit](https://gerrit.collaboraoffice.com)). It is meant to run only as a
browser-based service inside OpenBP. Everything else from upstream (mobile and
desktop apps, packaging, upstream CI, documentation) has been removed.

This is an independent project. It is not affiliated with or endorsed by
Collabora Productivity Ltd. or The Document Foundation.

## Docker image

```sh
docker run -d --name openbp-docs -p 9980:9980 \
  -e "aliasgroup1=https://openbp.example.com:443" \
  ghcr.io/modulsoft/openbp-docs:latest
```

The tags are:

- `latest`: the newest build.
- `<upstream version>`, e.g. `26.04.4-2`: the build of a given upstream release.
- `sha-<commit>`: the build of a given commit in this repository.

The images are published for `linux/amd64` only. Configuration
works exactly as in upstream, through `aliasgroupN`, `extra_params`, `username`,
`password` and so on. See the
[upstream configuration docs](https://sdk.collaboraonline.com/docs/installation/CODE_Docker_image.html).

## How it is built

- **Web UI.** The editor UI (`browser/`) is built from this repository, with the
  OpenBP branding from [`openbp/branding`](openbp/branding).
- **Runtime.** The office engine and the `coolwsd` server come unmodified from
  the official `collabora/code` image of the *same* upstream release. The
  Dockerfile swaps that image's web UI for ours
  ([`openbp/docker`](openbp/docker)).

## Following upstream

| Branch     | Content |
|------------|---------|
| `upstream` | One commit per upstream release tag (`cp-X.Y.Z-N`): a pruned snapshot of that tag, without upstream history. |
| `main`     | `upstream` plus the OpenBP additions. Upstream releases are merged in. |

[`sync-upstream.yml`](.github/workflows/sync-upstream.yml) runs every 6 hours:

1. It imports a new upstream release into `upstream`.
2. It merges that into `main`.
3. It builds, smoke-tests and publishes the image ([`build.yml`](.github/workflows/build.yml)).

If the merge or the build fails, the workflow fails and keeps failing until
someone fixes it by hand.

The OpenBP changes live in new files only (`openbp/`, `.github/`, this README).
No upstream file is edited, so merges should normally be conflict-free.

## License

The source code is under the [Mozilla Public License 2.0](COPYING), like
upstream Collabora Online. Some parts are under other open-source licenses; see
[`browser/LICENSE`](browser/LICENSE) and [`THIRDPARTYLICENSES`](THIRDPARTYLICENSES).

The office engine in the image is Collabora Office (MPL-2.0 / LGPL-3.0+),
taken unchanged from the official upstream image. Its source code is in the
upstream repository at the matching release tag. The tag of the current build
is recorded in [`.upstream-version`](.upstream-version).

"Collabora", "Collabora Online", "Collabora Office" and "LibreOffice" are
trademarks of their respective owners. They are used here only to name the
upstream project.
