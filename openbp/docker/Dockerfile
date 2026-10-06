# syntax=docker/dockerfile:1
# OpenBP Docs image.
#
# Stage `builder` compiles the web UI (browser/dist) from this repository with
# the OpenBP branding. The final stage starts from the official image of the
# *same* upstream release (office engine + coolwsd, hardened, no shell) and
# swaps its web UI for ours. busybox, the script and the new dist are only
# bind-mounted into that RUN step, so none of them ends up in an image layer.
#
# Build from the repository root after openbp/scripts/fetch-build-assets.sh:
#
#   docker build -f openbp/docker/Dockerfile \
#       --build-arg BASE_IMAGE=docker.io/collabora/code:26.04.4.2.1 .

ARG BASE_IMAGE

# The web UI is architecture independent: build it once, natively.
FROM --platform=$BUILDPLATFORM debian:trixie-slim AS builder
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
        autoconf automake libtool m4 make g++ pkg-config git ca-certificates \
        python3 python3-lxml python3-polib nodejs npm \
        libpoco-dev libcap-dev libpam0g-dev libzstd-dev libpng-dev libssl-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
# configure probes the server dependencies as well; only browser/ is built.
RUN ./autogen.sh && \
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
        --disable-tests --disable-werror \
        --with-lokit-path=/src/engine/include \
        --with-lo-path=/opt/collaboraoffice \
        --with-vendor="OpenBP" \
        --with-app-name="OpenBP Docs" \
        --with-app-branding=/src/openbp/branding && \
    make -C browser -j"$(nproc)"

FROM docker.io/library/busybox:1.37-musl AS busybox

FROM ${BASE_IMAGE}
USER root
COPY openbp/branding/favicon.ico /usr/share/coolwsd/favicon.ico
RUN --mount=type=bind,from=busybox,source=/bin/busybox,target=/tmp/openbp/busybox \
    --mount=type=bind,from=builder,source=/src/browser/dist,target=/tmp/openbp/dist \
    --mount=type=bind,source=openbp/docker/install-dist.sh,target=/tmp/openbp/install-dist.sh \
    ["/tmp/openbp/busybox", "sh", "/tmp/openbp/install-dist.sh"]
USER 1001
LABEL org.opencontainers.image.title="OpenBP Docs" \
      org.opencontainers.image.description="Collaborative online office editor for OpenBP, based on Collabora Online" \
      org.opencontainers.image.licenses="MPL-2.0" \
      author="OpenBP" \
      description="OpenBP Docs: collaborative online office editor for OpenBP, based on Collabora Online." \
      release.notes="" \
      commit.history.core=""
