# ============================================
# DERP Server Docker Image Build
# ============================================
# Automatically syncs with Headscale's Tailscale version

# Configuration
IMAGE_NAME := derp-server
REGISTRY := ghcr.io/slchris
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
# Go version must match the requirement in Tailscale's go.mod
GO_VERSION := 1.25
PLATFORMS := linux/amd64,linux/arm64,linux/arm/v7

# Auto-detect Tailscale version from Headscale (with fallback)
HEADSCALE_GO_MOD_URL := https://raw.githubusercontent.com/juanfont/headscale/main/go.mod
TAILSCALE_VERSION := $(shell curl -sL $(HEADSCALE_GO_MOD_URL) 2>/dev/null | grep -E "^\s*tailscale\.com\s+v" | head -1 | awk '{print $$2}' || echo "v1.76.1")

# Full image names
LOCAL_IMAGE := $(IMAGE_NAME):$(VERSION)
REGISTRY_IMAGE := $(REGISTRY)/$(IMAGE_NAME)

# Build arguments
BUILD_ARGS := --build-arg GO_VERSION=$(GO_VERSION) \
              --build-arg TAILSCALE_VERSION=$(TAILSCALE_VERSION)

.PHONY: help build push build-local test clean version info detect-version

# Default target
help:
	@echo "DERP Server Docker Image Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make build          - Build multi-platform image locally"
	@echo "  make push           - Build and push to GitHub Container Registry"
	@echo "  make build-local    - Build for current platform only"
	@echo "  make test           - Run local container for testing"
	@echo "  make clean          - Remove local images"
	@echo "  make version        - Show current version"
	@echo "  make info           - Show build configuration"
	@echo "  make detect-version - Show auto-detected Tailscale version from Headscale"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION=$(VERSION)"
	@echo "  TAILSCALE_VERSION=$(TAILSCALE_VERSION) (auto-detected from Headscale)"

# Detect and display Tailscale version from Headscale
detect-version:
	@echo "Fetching Tailscale version from Headscale..."
	@echo "Headscale uses: $(TAILSCALE_VERSION)"

# Build multi-platform image locally
build:
	docker buildx build \
		--platform $(PLATFORMS) \
		$(BUILD_ARGS) \
		-t $(LOCAL_IMAGE) \
		-t $(IMAGE_NAME):latest \
		. --load

# Build for current platform only (faster for development)
build-local:
	docker build \
		$(BUILD_ARGS) \
		-t $(LOCAL_IMAGE) \
		-t $(IMAGE_NAME):latest \
		.

# Build and push to registry
push:
	docker buildx build \
		--platform $(PLATFORMS) \
		$(BUILD_ARGS) \
		-t $(REGISTRY_IMAGE):$(VERSION) \
		-t $(REGISTRY_IMAGE):latest \
		. --push

# Run local container for testing
test: build-local
	@echo "Starting DERP server for testing..."
	@echo "Press Ctrl+C to stop"
	docker run --rm -it \
		--name derper-test \
		-p 8443:443 \
		-p 3478:3478/udp \
		-e DERP_DOMAIN=localhost \
		-e DERP_CERT_MODE=manual \
		$(LOCAL_IMAGE)

# Remove local images
clean:
	-docker rmi $(LOCAL_IMAGE) 2>/dev/null
	-docker rmi $(IMAGE_NAME):latest 2>/dev/null
	-docker rmi $(REGISTRY_IMAGE):$(VERSION) 2>/dev/null
	-docker rmi $(REGISTRY_IMAGE):latest 2>/dev/null
	@echo "Cleaned up local images"

# Show version
version:
	@echo $(VERSION)

# Show build info
info:
	@echo "Build Configuration:"
	@echo "  Image Name:         $(IMAGE_NAME)"
	@echo "  Registry:           $(REGISTRY)"
	@echo "  Version:            $(VERSION)"
	@echo "  Tailscale Version:  $(TAILSCALE_VERSION)"
	@echo "  Go Version:         $(GO_VERSION)"
	@echo "  Platforms:          $(PLATFORMS)"
