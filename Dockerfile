# Multi-stage build for wakezilla
# Stage 1: Builder stage with Rust and dependencies
FROM rust:1.83 AS builder

# Set working directory
WORKDIR /usr/src/wakezilla

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set trunk version
ARG TRUNK_VERSION=0.21.14

# Install wasm target and download prebuilt trunk binary
RUN set -eux; \
    rustup toolchain install nightly --allow-downgrade; \
    rustup target add wasm32-unknown-unknown; \
    curl -fSL -o /tmp/trunk.tar.gz "https://github.com/trunk-rs/trunk/releases/download/v${TRUNK_VERSION}/trunk-x86_64-unknown-linux-gnu.tar.gz"; \
    # Fail early if the download is unexpectedly small (likely HTML error page)
    test "$(stat -c %s /tmp/trunk.tar.gz)" -ge 1024 || (echo "trunk download too small — showing contents:" && cat /tmp/trunk.tar.gz && false); \
    tar -xzf /tmp/trunk.tar.gz -C /tmp; \
    mv /tmp/trunk /usr/local/bin/trunk; \
    chmod +x /usr/local/bin/trunk; \
    rm /tmp/trunk.tar.gz; \
    trunk --version

# Copy project files
COPY . .

# Build the project (frontend and backend)
RUN make install

# Stage 2: Runtime stage with minimal dependencies
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built binary from builder stage
COPY --from=builder /usr/local/bin/wakezilla /usr/local/bin/wakezilla

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/wakezilla"]

# Default command (can be overridden)
CMD ["--help"]
