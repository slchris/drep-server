# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build the derper binary
# ============================================
# Note: These defaults are overridden by Makefile/CI which auto-detect
# the Tailscale version from Headscale's go.mod for compatibility
# Go version must match the requirement in Tailscale's go.mod
ARG GO_VERSION=1.25
ARG TAILSCALE_VERSION=v1.94.1
# TARGETARCH is automatically set by Docker BuildKit for multi-platform builds
ARG TARGETARCH

FROM golang:${GO_VERSION}-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /build

# Clone specific version for reproducible builds
ARG TAILSCALE_VERSION
RUN git clone --depth 1 --branch ${TAILSCALE_VERSION} https://github.com/tailscale/tailscale.git

WORKDIR /build/tailscale

# Build with optimizations
# TARGETARCH is injected by BuildKit (amd64, arm64, arm)
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -X tailscale.com/version.longStamp=${TAILSCALE_VERSION}" \
    -trimpath \
    -o /derper \
    ./cmd/derper/

# ============================================
# Stage 2: Create minimal runtime image
# ============================================
FROM alpine:3.20

LABEL maintainer="Chris <chris@lesscrowds.org>"
LABEL org.opencontainers.image.title="DERP Server"
LABEL org.opencontainers.image.description="Tailscale/Headscale DERP relay server"
LABEL org.opencontainers.image.source="https://github.com/slchris/derp-server"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata curl

# Create non-root user for security
RUN addgroup -g 1000 derper && \
    adduser -u 1000 -G derper -s /sbin/nologin -D derper

# Environment variables with sensible defaults
ENV DERP_DOMAIN=example.com \
    DERP_CERT_MODE=letsencrypt \
    DERP_CERT_DIR=/app/certs \
    DERP_ADDR=:443 \
    DERP_STUN=true \
    DERP_HTTP_PORT=80 \
    DERP_STUN_PORT=3478 \
    DERP_VERIFY_CLIENTS=false \
    DERP_VERIFY_CLIENT_URL= \
    DERP_VERIFY_CLIENT_URL_FAILOPEN=true \
    TZ=UTC

WORKDIR /app

# Copy binary from builder
COPY --from=builder /derper /app/derper

# Create certificate directory
RUN mkdir -p /app/certs && \
    chown -R derper:derper /app

# Expose ports
EXPOSE 443 80 3478/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:${DERP_HTTP_PORT}/ || exit 1

# Run as non-root user (commented out - may need root for port 443)
# USER derper

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Use JSON form with entrypoint for proper signal handling
ENTRYPOINT ["/app/entrypoint.sh"]
