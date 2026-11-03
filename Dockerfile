# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the builder image
#     E.g.: docker.io/hexpm/elixir:1.20.4-erlang-29.1.2-debian-trixie-20261027-slim
#   - https://hub.docker.com/_/debian/tags?name=trixie-20261027-slim - for the runner image
#     E.g.: docker.io/debian:trixie-20261027-slim
#
# Find builder and runner images on Docker Hub or on Hex's Build Server (Bob).
# We recommend using Bob's Web UI to find recent tags:
#
#   - https://bob.hex.pm/docker?repo=hexpm/elixir&os=debian&sort=elixir_version,erlang_version,os_version
#
# We suggest using the same Debian version for both the builder and runner images.
#
# We suggest Debian/Ubuntu instead of Alpine to avoid production compatibility issues
# (such as DNS resolution failures, and dynamically linked NIFs/precompiled binaries).
#
# For finding packages in Debian, search on https://packages.debian.org/.
ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.1.2
ARG DEBIAN_VERSION=trixie-20261027-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

# --------------- typst image start ---------------
FROM debian:bookworm-slim AS typst
ARG TYPST_VERSION=0.15.1
# SHA-256 of each release file for the version above (the "digest" shown on the GitHub release page).
# Update all three together; .github/workflows/ci.yml checks that the version and amd64 hash agree.
ARG TYPST_SHA256_AMD64=a6d077d0a95eed5a2eba715b2dae06be954f624ccbf85758a03f389ded33118c
ARG TYPST_SHA256_ARM64=5aa8d74a3d906e60ea12a66ac2f37f8eef1b14cbad7182a745e393a10c23dcee
ARG TARGETARCH
RUN apt-get update -y && apt-get install -y --no-install-recommends curl xz-utils ca-certificates \
  && case "$TARGETARCH" in \
       amd64) TYPST_TARGET=x86_64-unknown-linux-musl; TYPST_SHA256="$TYPST_SHA256_AMD64" ;; \
       arm64) TYPST_TARGET=aarch64-unknown-linux-musl; TYPST_SHA256="$TYPST_SHA256_ARM64" ;; \
       *) echo "unsupported arch $TARGETARCH" && exit 1 ;; \
     esac \
  && curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${TYPST_TARGET}.tar.xz" -o /tmp/typst.tar.xz \
  && echo "${TYPST_SHA256}  /tmp/typst.tar.xz" | sha256sum -c - \
  && tar -xJf /tmp/typst.tar.xz -C /tmp \
  && mv "/tmp/typst-${TYPST_TARGET}/typst" /usr/local/bin/typst \
  && /usr/local/bin/typst --version
# --------------- typst image end ---------------

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies with typst
RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git nodejs npm && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

# Compile the release
RUN mix compile

COPY assets assets

# compile assets
# npm ci installs exactly what assets/package-lock.json says (and fails if it is out of date)
RUN npm ci --prefix assets
RUN mix assets.setup

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates qpdf curl \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

COPY --from=typst /usr/local/bin/typst /usr/local/bin/typst

WORKDIR "/app"
RUN chown nobody /app \
  && mkdir -p /data/uploads && chown -R nobody /data

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/quickslips ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["sh", "-c", "/app/bin/migrate && /app/bin/server"]
