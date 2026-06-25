# Tailscale/Headscale DERP Server

[![Build and Push](https://github.com/slchris/derp-server/actions/workflows/build.yml/badge.svg)](https://github.com/slchris/derp-server/actions/workflows/build.yml)
[![Docker Image](https://img.shields.io/badge/docker-ghcr.io%2Fslchris%2Fderp--server-blue)](https://github.com/slchris/derp-server/pkgs/container/derp-server)

A lightweight Docker image for deploying [Tailscale DERP](https://tailscale.com/kb/1118/custom-derp-servers/) relay servers.

## Features

- **Multi-architecture support**: `linux/amd64`, `linux/arm64`, and `linux/arm/v7` (Raspberry Pi, Hetzner ARM VPS, etc.)
- **Security-focused**: Based on Alpine Linux with minimal attack surface
- **Health checks**: Built-in health monitoring for orchestration
- **Small image size**: Optimized multi-stage build
- **Auto-synced with Headscale**: Automatically uses the same Tailscale version as [Headscale](https://github.com/juanfont/headscale) for guaranteed compatibility
- **Weekly updates**: GitHub Actions checks for new versions every week

## Quick Start

### Prerequisites

- Domain with DNS record pointing to your server
- SSL certificate (Let's Encrypt or custom)
- Docker installed

### Option 1: Using Docker Compose (Recommended)

1. Download the compose file:
```bash
curl -O https://raw.githubusercontent.com/slchris/derp-server/main/docker-compose.yml
```

2. Edit the configuration:
```bash
# Update DERP_DOMAIN and certificate paths
vi docker-compose.yml
```

3. Start the server:
```bash
docker-compose up -d
```

### Option 2: Using Docker Run

#### Step 1: Generate SSL Certificate

Using certbot:
```bash
docker run -it --rm --name certbot \
  -p 80:80 \
  -v "/etc/letsencrypt:/etc/letsencrypt" \
  -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
  certbot/certbot certonly --standalone -d your-domain.com
```

#### Step 2: Deploy DERP Server

```bash
docker run -d --restart always \
  --name derper \
  -p 443:443 \
  -p 80:80 \
  -p 3478:3478/udp \
  -v /etc/letsencrypt/live/your-domain.com/fullchain.pem:/app/certs/your-domain.com.crt:ro \
  -v /etc/letsencrypt/live/your-domain.com/privkey.pem:/app/certs/your-domain.com.key:ro \
  -e DERP_CERT_MODE=manual \
  -e DERP_DOMAIN=your-domain.com \
  ghcr.io/slchris/derp-server:latest
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `DERP_DOMAIN` | `example.com` | Your DERP server's domain name |
| `DERP_CERT_MODE` | `letsencrypt` | Certificate mode: `manual`, `letsencrypt` |
| `DERP_CERT_DIR` | `/app/certs` | Directory for SSL certificates |
| `DERP_ADDR` | `:443` | HTTPS listen address |
| `DERP_HTTP_PORT` | `80` | HTTP port (for Let's Encrypt or health checks) |
| `DERP_STUN` | `true` | Enable STUN server |
| `DERP_STUN_PORT` | `3478` | STUN server port |
| `DERP_VERIFY_CLIENTS` | `false` | Verify client connections |
| `DERP_VERIFY_CLIENT_URL` |   | Define endpoint for client verification |
| `DERP_VERIFY_CLIENT_URL_FAILOPEN` | `true` | Define if clients should be admitted if the verification endpoint can't be reached |
| `TZ` | `UTC` | Timezone |

### Certificate Modes

- **`manual`**: Provide your own certificates (mount to `/app/certs/{domain}.crt` and `/app/certs/{domain}.key`)
- **`letsencrypt`**: Automatic certificate management via Let's Encrypt

### DERP client verification

- **`DERP_VERIFY_CLIENTS`** controls wether clients should be verified against a tailscale
  instance running locally (see [here](https://github.com/tailscale/tailscale/blob/main/cmd/derper/README.md#guide-to-running-cmdderper))
- **`DERP_VERIFY_CLIENT_URL`** controls wether clients should be validated against an admission endpoint.
  This is mostly useful in self-hosted scenarios where you don't use the Tailscale control plane.
  - Setting the URL enables HTTP(S) based validation, setting `DERP_VERIFY_CLIENTS` is not required
  - The admission endpoint provided by e.g. headscale lives in `/verify` of your control plane, so e.g. `https://headscale.example.com/verify` 
- **`DERP_VERIFY_CLIENT_URL_FAILOPEN`** controls wether clients should be admitted if the
  endpoint is unreachable, i.e. if verification should 'fail open'.

## Integration

### With Headscale

1. Create DERP configuration:
```bash
cat > /etc/headscale/derp.yaml << 'EOF'
regions:
  900:
    regionid: 900
    regioncode: custom
    regionname: My DERP Server
    nodes:
      - name: 900a
        regionid: 900
        hostname: your-domain.com
        stunport: 3478
        derpport: 443
EOF
```

2. Update Headscale configuration (`/etc/headscale/config.yaml`):
```yaml
derp:
  # Disable default DERP servers (optional)
  # urls: []
  
  # Use your custom DERP server
  paths:
    - /etc/headscale/derp.yaml
  
  auto_update_enabled: true
  update_frequency: 24h
```

3. Restart Headscale:
```bash
systemctl restart headscale
```

### With Tailscale (Self-hosted Coordination)

Add to your ACL policy:
```json
{
  "derpMap": {
    "Regions": {
      "900": {
        "RegionID": 900,
        "RegionCode": "custom",
        "Nodes": [{
          "Name": "900a",
          "RegionID": 900,
          "HostName": "your-domain.com"
        }]
      }
    }
  }
}
```

## Building Locally

```bash
# Clone the repository
git clone https://github.com/slchris/derp-server.git
cd derp-server

# Check the auto-detected Tailscale version from Headscale
make detect-version

# Build for local testing
make build-local

# Build multi-platform image
make build

# Push to registry
make push

# View all options
make help
```

## Version Synchronization

This project automatically syncs with Headscale's Tailscale version to ensure compatibility:

1. **GitHub Actions** checks Headscale's `go.mod` weekly and rebuilds if the version changes
2. **Makefile** fetches the version dynamically when building locally
3. **Image tags** include the Tailscale version (e.g., `tailscale-v1.94.1`)

You can also manually trigger a build with a specific version:
```bash
# In GitHub Actions - use workflow_dispatch with custom version
# Locally - override the version:
docker build --build-arg TAILSCALE_VERSION=v1.90.0 -t derp-server .
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 443 | TCP | HTTPS DERP relay |
| 80 | TCP | HTTP (health checks / Let's Encrypt) |
| 3478 | UDP | STUN server |

## Health Checks

The container includes a built-in health check that queries the HTTP endpoint. You can monitor it with:

```bash
docker inspect --format='{{.State.Health.Status}}' derper
```

## Troubleshooting

### Check logs
```bash
docker logs derper
```

### Verify DERP connectivity
```bash
# From a machine with tailscale installed
tailscale netcheck
```

### Test STUN
```bash
# Using stunclient
stunclient your-domain.com 3478
```

## License

This project packages the official [Tailscale DERP server](https://github.com/tailscale/tailscale), which is licensed under the BSD 3-Clause License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
