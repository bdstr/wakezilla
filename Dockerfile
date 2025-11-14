# Multi-stage build for Wakezilla
# Stage 1: Build the frontend and backend
FROM rust:1.91-bookworm AS builder

# Install dependencies required for building
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install wasm32 target for building the frontend
RUN rustup target add wasm32-unknown-unknown

# Install trunk for building the frontend
RUN cargo install trunk --locked

# Set working directory
WORKDIR /build

# Copy the entire project
COPY . .

# Build the frontend
RUN cd frontend && trunk build --release

# Build the backend
RUN cargo build --release

# Stage 2: Create the runtime image
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create directory for data storage
RUN mkdir -p /opt/wakezilla

# Copy the compiled binary from builder
COPY --from=builder /build/target/release/wakezilla /usr/local/bin/wakezilla

# Set working directory
WORKDIR /opt/wakezilla

# Expose ports for proxy-server (3000) and client-server (3001)
EXPOSE 3000 3001

# Set default environment variables
ENV WAKEZILLA__STORAGE__MACHINES_DB_PATH=/opt/wakezilla/machines.json

# Default command runs the proxy server
ENTRYPOINT ["wakezilla"]
CMD ["proxy-server"]
