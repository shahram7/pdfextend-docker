FROM node:20-slim AS webapp-builder

# Install dependencies needed for both web and PDFium
RUN apt update && apt install -y \
    git curl wget build-essential pkg-config libssl-dev \
    python3 python3-pip clang cmake ninja-build

# Install Rust & wasm-pack
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install wasm-pack

# Clone pdfextend and do web build preparation
RUN git clone https://github.com/DorianRudolph/pdfextend.git /src
WORKDIR /src/pdfextend-web

# Build web WASM/js
RUN wasm-pack build --target no-modules \
 && cp -r pkg/* ../webapp/public

# Download pdfium.js + wasm from pdfium.js repo
WORKDIR /src
RUN wget -qO pdfium-js.zip https://github.com/Jaewoook/pdfium.js/archive/refs/heads/main.zip \
    && unzip pdfium-js.zip \
    && cp pdfium.js-main/dist/pdfium.js pdfium.js-main/dist/pdfium.wasm /src/webapp/public || true

# Install build deps (Ubuntu Debian)
RUN ./build/install-build-deps.sh

# Generate build files with GN
RUN gn gen out/Release

# Build all PDFium libraries / js interface (if exists)
RUN ninja -C out/Release pdfium_all

# After build, find the output binary (e.g. pdfium.js or libpdfium.so) and copy to webapp/public
RUN cp out/Release/path/to/pdfium.js /src/webapp/public || true

# Build frontend
WORKDIR /src/webapp
RUN npm install && npm run build

# Final image
FROM nginx:alpine
COPY --from=webapp-builder /src/webapp/dist /usr/share/nginx/html
