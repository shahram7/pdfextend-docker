# syntax=docker/dockerfile:1.7

# ---------------------------------------------------------------------------
# Build stage: compile the upstream Rust/WASM app and the React frontend.
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM node:22-bookworm-slim AS builder

# Pinned upstream revision and PDFium WASM release. Bump these deliberately:
# changing PDFIUM_LIB_VERSION also requires updating PDFIUM_LIB_SHA256.
ARG PDFEXTEND_REPO=https://github.com/DorianRudolph/pdfextend.git
ARG PDFEXTEND_REF=c53db44affaf5be5accdaccd8f8d5d28bf3de28d
ARG PDFIUM_LIB_VERSION=8046d
ARG PDFIUM_LIB_SHA256=062d10055de90a01120acf307ce16e0022021a32203f4aeae4877750f9a08427

ENV DEBIAN_FRONTEND=noninteractive \
    CARGO_TERM_COLOR=always \
    PATH=/root/.cargo/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain. wasm-pack can add the target itself, but doing it here makes
# the requirement explicit and fails early if the toolchain is broken.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --profile minimal \
    && rustup target add wasm32-unknown-unknown

# Prebuilt wasm-pack is much faster than `cargo install wasm-pack`.
RUN curl -sSf https://rustwasm.github.io/wasm-pack/installer/init.sh | sh

WORKDIR /src
RUN git clone "$PDFEXTEND_REPO" . \
    && git checkout --detach "$PDFEXTEND_REF"

# Build the Rust -> WASM module used by the web worker.
WORKDIR /src/pdfextend-web
RUN --mount=type=cache,target=/root/.cargo/registry \
    --mount=type=cache,target=/root/.cargo/git \
    --mount=type=cache,target=/src/pdfextend-web/target \
    wasm-pack build --release --target no-modules \
    && mkdir -p /src/webapp/public \
    && cp pkg/pdfextend_web.js pkg/pdfextend_web_bg.wasm /src/webapp/public/

# worker.js calls the global PDFiumModule() factory. That factory is provided
# by the paulocoutinhox/pdfium-lib WASM build, NOT by bblanchon/pdfium-binaries.
# The latter exports a classic Emscripten `Module` and causes:
#   Uncaught ReferenceError: PDFiumModule is not defined
WORKDIR /src/webapp/public
RUN curl -fsSL --retry 3 -o /tmp/pdfium-wasm.zip \
      "https://github.com/paulocoutinhox/pdfium-lib/releases/download/${PDFIUM_LIB_VERSION}/wasm.zip" \
    && echo "${PDFIUM_LIB_SHA256}  /tmp/pdfium-wasm.zip" | sha256sum -c - \
    && unzip -p /tmp/pdfium-wasm.zip release/node/pdfium.js   > pdfium.js \
    && unzip -p /tmp/pdfium-wasm.zip release/node/pdfium.wasm > pdfium.wasm \
    && rm /tmp/pdfium-wasm.zip \
    && grep -q 'PDFiumModule' pdfium.js

# Build the React frontend. Vite copies everything in public/ into dist/.
WORKDIR /src/webapp
RUN npm ci --no-audit --no-fund \
    && npm run build

# Fail the image build here, instead of in the browser, if an expected runtime
# asset is missing or the wrong PDFium bundle was downloaded.
RUN test -f dist/index.html \
    && test -f dist/pdfium.js \
    && test -f dist/pdfium.wasm \
    && test -f dist/pdfextend_web.js \
    && test -f dist/pdfextend_web_bg.wasm \
    && grep -q 'PDFiumModule' dist/pdfium.js

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM nginx:alpine

COPY --from=builder /src/webapp/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
