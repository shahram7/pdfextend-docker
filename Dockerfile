FROM node:20-slim AS webapp-builder

RUN apt update && apt install -y git curl wget build-essential pkg-config libssl-dev

# Install Rust and wasm-pack
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install wasm-pack

# Clone upstream repo
RUN git clone https://github.com/DorianRudolph/pdfextend.git /src
WORKDIR /src/pdfextend-web

# Build wasm
RUN wasm-pack build --target no-modules \
 && cp pkg/pdfextend_web.js ../webapp/public \
 && cp pkg/pdfextend_web_bg.wasm ../webapp/public

# Build frontend
WORKDIR /src/webapp
RUN npm install && npm run build

# Final image
FROM nginx:alpine
COPY --from=webapp-builder /src/webapp/dist /usr/share/nginx/html
