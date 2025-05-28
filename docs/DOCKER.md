# Docker Guide for MCP-Jujutsu

This guide provides detailed information about using MCP-Jujutsu with Docker.

## Quick Start

```bash
# Build and run with Docker
docker build -t mcp-jujutsu:latest .
docker run -p 8080:8080 -v $(pwd)/repos:/app/repos mcp-jujutsu:latest

# Or use Docker Compose
docker-compose --profile single up
```

## Docker Images

### Base Image: `mcp-jujutsu:latest`

The main Docker image includes:
- Nim runtime and compiled MCP-Jujutsu binary
- Jujutsu (jj) version control system
- Git for repository compatibility
- Non-root user for security
- Alpine Linux base for small size

### Build Stages

The Dockerfile uses multi-stage build:
1. **Builder stage**: Compiles the Nim application
2. **Runtime stage**: Minimal image with just the binary and dependencies

## Docker Compose Profiles

### Single Repository Mode (`--profile single`)

```yaml
ports: 8080:8080
environment:
  - MCP_JUJUTSU_MODE=single
  - MCP_JUJUTSU_REPO_PATH=/app/repos/single
```

### Multi Repository Mode (`--profile multi`)

```yaml
ports: 8081:8081
environment:
  - MCP_JUJUTSU_MODE=multi
  - MCP_JUJUTSU_REPOS_DIR=/app/repos/multi
  - MCP_JUJUTSU_REPO_CONFIG_PATH=/app/config/repos.json
```

### Development Mode (`--profile dev`)

```yaml
ports: 8082:8082
volumes:
  - ./src:/app/src:rw
  - ./tests:/app/tests:rw
command: nimble run
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_JUJUTSU_MODE` | Server mode: `single` or `multi` | `single` |
| `MCP_JUJUTSU_REPO_PATH` | Repository path (single mode) | `/app/repos` |
| `MCP_JUJUTSU_REPOS_DIR` | Repositories directory (multi mode) | `/app/repos` |
| `MCP_JUJUTSU_HTTP_HOST` | HTTP server bind address | `0.0.0.0` |
| `MCP_JUJUTSU_HTTP_PORT` | HTTP server port | `8080` |
| `MCP_JUJUTSU_LOG_LEVEL` | Log level: debug/info/warn/error | `info` |

## Volume Mounts

### Required Volumes

| Path | Purpose | Mode |
|------|---------|------|
| `/app/repos` | Repository storage | Read/Write |
| `/app/config` | Configuration files | Read/Write |

### Optional Volumes

| Path | Purpose | Mode |
|------|---------|------|
| `/home/mcp/.ssh` | SSH keys for Git | Read-only |
| `/home/mcp/.gitconfig` | Git configuration | Read-only |

## Networking

- Default port: `8080` (configurable)
- Binds to `0.0.0.0` by default (all interfaces)
- Use Docker networks for multi-container setups

## Security Considerations

1. **Non-root user**: Runs as `mcp` user (UID 1000)
2. **Read-only mounts**: SSH keys and Git config mounted read-only
3. **Minimal base image**: Alpine Linux for reduced attack surface
4. **No unnecessary packages**: Only required runtime dependencies

## Building Custom Images

### Build Script

Use the provided build script for convenience:

```bash
# Basic build
./scripts/docker-build.sh

# Build with custom tag
./scripts/docker-build.sh -t v1.0.0

# Build and push to registry
./scripts/docker-build.sh -t latest -p -r docker.io/myuser

# Multi-platform build
./scripts/docker-build.sh --platform linux/amd64,linux/arm64 -t multiarch
```

### Manual Build

```bash
# Standard build
docker build -t mcp-jujutsu:latest .

# Build with build arguments
docker build \
  --build-arg NIM_VERSION=2.0.2 \
  -t mcp-jujutsu:custom .

# Multi-platform build
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t mcp-jujutsu:multiarch .
```

## Docker Compose Override

Create `docker-compose.override.yml` for local customization:

```yaml
version: '3.8'

services:
  mcp-jujutsu-single:
    environment:
      - MCP_JUJUTSU_LOG_LEVEL=debug
    volumes:
      - ~/my-repos:/app/repos:rw
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker logs mcp-jujutsu-single
docker-compose logs -f
```

### Permission issues

Ensure proper ownership:
```bash
# Fix repository permissions
docker exec mcp-jujutsu-single chown -R mcp:mcp /app/repos

# Or run as root (not recommended)
docker run --user root ...
```

### Network connectivity

Test from inside container:
```bash
docker exec mcp-jujutsu-single wget -O- http://localhost:8080/health
```

### Build failures

Clean build:
```bash
docker build --no-cache -t mcp-jujutsu:latest .
```

## Performance Optimization

### Resource Limits

Set in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '1'
      memory: 1G
```

### Caching

- Use Docker BuildKit: `DOCKER_BUILDKIT=1 docker build ...`
- Mount nimble cache: `-v ~/.nimble:/home/mcp/.nimble:ro`

## Integration Examples

### With CI/CD

```yaml
# GitHub Actions
- name: Build MCP-Jujutsu
  run: |
    docker build -t mcp-jujutsu:${{ github.sha }} .
    docker tag mcp-jujutsu:${{ github.sha }} mcp-jujutsu:latest
```

### With Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-jujutsu
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: mcp-jujutsu
        image: mcp-jujutsu:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: repos
          mountPath: /app/repos
```

## Monitoring

### Health Check

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
```

### Metrics

Export Prometheus metrics:
```bash
docker run -p 8080:8080 -p 9090:9090 \
  -e MCP_JUJUTSU_METRICS_ENABLED=true \
  mcp-jujutsu:latest
```