FROM node:20-slim AS webapp-builder

# Install dependencies needed for building web + wasm
RUN apt update && apt install -y \
    git curl wget unzip build-essential pkg-config libssl-dev

# Install Rust & wasm-pack
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install wasm-pack

# Clone pdfextend and do web build preparation
RUN git clone https://github.com/DorianRudolph/pdfextend.git /src
WORKDIR /src/pdfextend-web

# Build web WASM/js
RUN wasm-pack build --target no-modules \
 && mkdir -p ../webapp/public \
 && cp -r pkg/* ../webapp/public

# Download pdfium.js + wasm from pdfium.js repo (prebuilt)
WORKDIR /src
RUN wget -qO pdfium-js.zip https://github.com/Jaewoook/pdfium.js/archive/refs/heads/main.zip \
    && unzip pdfium-js.zip \
    && cp pdfium.js-main/dist/pdfium.js pdfium.js-main/dist/pdfium.wasm /src/webapp/public

# Build frontend
WORKDIR /src/webapp
RUN npm install && npm run build

# Final image
FROM nginx:alpine
COPY --from=webapp-builder /src/webapp/dist /usr/share/nginx/html
