# syntax=docker/dockerfile:1
#
# Vim Dojo in a box: pinned Neovim + this repo's plugin, nothing else.
# Build context is the repo root (see compose.yaml).

ARG DEBIAN_TAG=trixie-slim

# ---------------------------------------------------------------------------
# Stage 1: download and verify Neovim
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_TAG} AS fetch

# Set by BuildKit: amd64 on most PCs, arm64 on Apple Silicon.
ARG TARGETARCH

# Keep in sync with .github/workflows/ci.yml (AGENTS.md rule 4).
ARG NVIM_VERSION=v0.12.5
ARG NVIM_SHA256_AMD64=bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875
ARG NVIM_SHA256_ARM64=1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
      amd64) asset=nvim-linux-x86_64; sum="$NVIM_SHA256_AMD64" ;; \
      arm64) asset=nvim-linux-arm64;  sum="$NVIM_SHA256_ARM64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/nvim.tar.gz \
      "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${asset}.tar.gz"; \
    echo "${sum}  /tmp/nvim.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/nvim; \
    tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1

# ---------------------------------------------------------------------------
# Stage 2: runtime
# ---------------------------------------------------------------------------
FROM debian:${DEBIAN_TAG}

ENV LANG=C.UTF-8 \
    TERM=xterm-256color

COPY --from=fetch /opt/nvim /opt/nvim

ARG PLUGIN_DIR=/opt/nvim-plugins/pack/dojo/opt/vim-dojo
COPY plugin ${PLUGIN_DIR}/plugin
COPY lua ${PLUGIN_DIR}/lua
COPY tests ${PLUGIN_DIR}/tests

# Unprivileged user. ~/.local is created up front so the data volume starts
# out owned by the user.
RUN ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim \
 && useradd --create-home --uid 1000 trainee \
 && mkdir -p /home/trainee/.config/nvim \
             /home/trainee/.cache \
             /home/trainee/.local/share/nvim/dojo \
             /home/trainee/.local/state/nvim \
 && chown -R trainee:trainee /home/trainee

COPY docker/init.lua /home/trainee/.config/nvim/init.lua

USER trainee
WORKDIR /home/trainee

ENTRYPOINT ["nvim"]
CMD ["-c", "Dojo"]
