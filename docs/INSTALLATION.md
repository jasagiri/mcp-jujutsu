# MCP-Jujutsu Installation Guide

This guide provides detailed instructions for installing and setting up MCP-Jujutsu on various platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Install](#quick-install)
- [Platform-Specific Installation](#platform-specific-installation)
- [Building from Source](#building-from-source)
- [Docker Installation](#docker-installation)
- [Verifying Installation](#verifying-installation)
- [Initial Setup](#initial-setup)
- [Troubleshooting](#troubleshooting)
- [Upgrading](#upgrading)

## Prerequisites

Before installing MCP-Jujutsu, ensure you have the following:

### Required Software

| Software | Minimum Version | Recommended Version | Notes |
|----------|----------------|-------------------|--------|
| Nim | 1.6.0 | 2.0.0+ | Programming language |
| Jujutsu | 0.9.0 | Latest | Version control system |
| Git | 2.25.0 | Latest | For repository compatibility |
| GCC/Clang | - | Latest | C compiler for Nim |

### System Requirements

- **OS**: Linux, macOS, Windows (WSL2 recommended)
- **RAM**: 2GB minimum, 4GB recommended
- **Disk**: 500MB for installation, 2GB+ for cache
- **Network**: Required for MCP client connections

## Quick Install

### One-Line Installation (Linux/macOS)

```bash
curl -sSL https://raw.githubusercontent.com/jasagiri/mcp-jujutsu/main/install.sh | sh
```

### Manual Quick Install

```bash
# 1. Install Nim
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
source ~/.nimble/bin/activate

# 2. Install Jujutsu
cargo install jj

# 3. Clone and build MCP-Jujutsu
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install
nimble build
```

## Platform-Specific Installation

### Linux

#### Ubuntu/Debian

```bash
# Install system dependencies
sudo apt update
sudo apt install -y build-essential git curl

# Install Rust (for Jujutsu)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Nim using choosenim
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
echo 'export PATH=$HOME/.nimble/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Install Jujutsu
cargo install jj

# Clone and build MCP-Jujutsu
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install -y
nimble build -d:release
```

#### Fedora/RHEL/CentOS

```bash
# Install system dependencies
sudo dnf install -y gcc git curl

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Nim
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
echo 'export PATH=$HOME/.nimble/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Continue with Jujutsu and MCP-Jujutsu installation as above
```

#### Arch Linux

```bash
# Install from AUR (if available)
yay -S nim jujutsu-git

# Or manual installation
sudo pacman -S base-devel git curl
# Follow general Linux instructions above
```

### macOS

#### Using Homebrew

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install nim rust git

# Install Jujutsu
cargo install jj

# Clone and build MCP-Jujutsu
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install -y
nimble build -d:release
```

#### Manual Installation

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Nim
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
echo 'export PATH=$HOME/.nimble/bin:$PATH' >> ~/.zshrc
source ~/.zshrc

# Continue with installation
```

### Windows

#### Using WSL2 (Recommended)

```bash
# Install WSL2
wsl --install

# Inside WSL2, follow Linux installation instructions
```

#### Native Windows

```powershell
# Install Scoop package manager
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install dependencies
scoop install git nim rust

# Install Jujutsu
cargo install jj

# Clone and build
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install -y
nimble build -d:release
```

## Building from Source

### Development Build

```bash
# Clone repository
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu

# Install dependencies
nimble install -y

# Build debug version
nimble build

# Run tests
nimble test
```

### Release Build

```bash
# Build optimized release version
nimble build -d:release

# Build with specific features
nimble build -d:release -d:ssl -d:multithreading

# Build static binary
nimble build -d:release --passL:"-static"
```

### Custom Build Options

```bash
# Build with custom optimization
nim c -d:release \
      -d:danger \
      --opt:speed \
      --passC:"-march=native" \
      src/mcp_jujutsu.nim

# Build with debugging symbols
nim c -d:release \
      --debugger:native \
      --lineDir:on \
      src/mcp_jujutsu.nim
```

## Docker Installation

### Using Pre-built Image

```bash
# Pull the image
docker pull ghcr.io/jasagiri/mcp-jujutsu:latest

# Run the container
docker run -d \
  --name mcp-jujutsu \
  -p 8080:8080 \
  -v $(pwd)/repos:/repos \
  ghcr.io/jasagiri/mcp-jujutsu:latest
```

### Building Docker Image

Create a `Dockerfile`:

```dockerfile
FROM nimlang/nim:2.0.0-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git gcc musl-dev

# Install Rust and Jujutsu
RUN apk add --no-cache cargo
RUN cargo install jj

# Copy source
WORKDIR /app
COPY . .

# Build application
RUN nimble install -y
RUN nimble build -d:release

# Runtime image
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache git

# Copy binaries
COPY --from=builder /root/.cargo/bin/jj /usr/local/bin/
COPY --from=builder /app/mcp_jujutsu /usr/local/bin/

# Create non-root user
RUN adduser -D -h /home/mcp mcp
USER mcp
WORKDIR /home/mcp

# Expose port
EXPOSE 8080

# Run server
CMD ["mcp_jujutsu", "server", "--port", "8080"]
```

Build and run:

```bash
docker build -t mcp-jujutsu .
docker run -d -p 8080:8080 -v $(pwd)/repos:/home/mcp/repos mcp-jujutsu
```

### Docker Compose

```yaml
version: '3.8'

services:
  mcp-jujutsu:
    image: ghcr.io/jasagiri/mcp-jujutsu:latest
    ports:
      - "8080:8080"
    volumes:
      - ./repos:/repos
      - ./config.json:/app/config.json
    environment:
      - MCP_MODE=multi
      - MCP_LOG_LEVEL=info
    restart: unless-stopped
```

## Verifying Installation

### Check Versions

```bash
# Check Nim
nim --version
# Expected: Nim Compiler Version 2.0.0 or higher

# Check Jujutsu
jj --version
# Expected: jj 0.9.0 or higher

# Check MCP-Jujutsu
./mcp_jujutsu --version
# Expected: mcp-jujutsu 0.1.0 or higher
```

### Run Basic Tests

```bash
# Test single repository mode
./mcp_jujutsu test-connection

# Test multi-repository mode
./mcp_jujutsu test-connection --mode multi

# Run built-in diagnostics
./mcp_jujutsu diagnose
```

### Test Server

```bash
# Start server
./scripts/start-server.sh 8080

# In another terminal, test connection
curl http://localhost:8080/health
# Expected: {"status":"healthy","version":"0.1.0"}
```

## Initial Setup

### 1. Create Configuration

```bash
# Create config directory
mkdir -p ~/.config/mcp-jujutsu

# Copy default configuration
cp config.example.json ~/.config/mcp-jujutsu/config.json

# Edit configuration
nano ~/.config/mcp-jujutsu/config.json
```

### 2. Initialize Repository

```bash
# For existing Git repository
cd /path/to/your/repo
jj init --git-repo .

# For new repository
mkdir my-project
cd my-project
jj init
```

### 3. Configure MCP Client

For Claude Code:
```bash
# Add to MCP settings
claude-code config add-server \
  --name mcp-jujutsu \
  --url http://localhost:8080/mcp \
  --card /path/to/mcp-jujutsu/card/card.json
```

### 4. Set Up Multi-Repository Mode

```bash
# Create repository configuration
cat > repos.json << EOF
{
  "repositories": [
    {
      "name": "frontend",
      "path": "./repos/frontend"
    },
    {
      "name": "backend",
      "path": "./repos/backend"
    }
  ]
}
EOF

# Start in multi-repo mode
./scripts/start-server.sh 8080 multi
```

## Troubleshooting

### Common Issues

#### 1. Nim Installation Fails

```bash
# Manual Nim installation
git clone https://github.com/nim-lang/Nim.git
cd Nim
sh build_all.sh
export PATH=$PWD/bin:$PATH
```

#### 2. Jujutsu Command Not Found

```bash
# Add cargo bin to PATH
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Build Errors

```bash
# Clear Nimble cache
nimble refresh
rm -rf ~/.nimble/pkgs

# Reinstall dependencies
nimble install -y --depsOnly
```

#### 4. Server Won't Start

```bash
# Check port availability
lsof -i :8080

# Check logs
tail -f logs/mcp-jujutsu.log

# Run with debug logging
MCP_LOG_LEVEL=debug ./mcp_jujutsu server
```

#### 5. Permission Errors

```bash
# Fix permissions
chmod +x scripts/start-server.sh
chmod +x mcp_jujutsu

# For system-wide installation
sudo cp mcp_jujutsu /usr/local/bin/
```

### Debug Mode

```bash
# Enable verbose logging
export MCP_LOG_LEVEL=debug
export MCP_LOG_FORMAT=pretty

# Run with debugging
./mcp_jujutsu server --debug --verbose
```

### Getting Help

```bash
# Built-in help
./mcp_jujutsu --help
./mcp_jujutsu server --help

# Run diagnostics
./mcp_jujutsu diagnose --verbose

# Check system compatibility
./mcp_jujutsu check-system
```

## Upgrading

### Upgrade from Source

```bash
cd mcp-jujutsu
git pull origin main
nimble install -y
nimble build -d:release
```

### Upgrade Dependencies

```bash
# Upgrade Nim
choosenim update stable

# Upgrade Jujutsu
cargo install --force jj

# Upgrade Nimble packages
nimble refresh
nimble install -y
```

### Migration Guide

When upgrading between major versions:

1. **Backup Configuration**
   ```bash
   cp config.json config.json.backup
   cp repos.json repos.json.backup
   ```

2. **Check Breaking Changes**
   ```bash
   # View changelog
   cat CHANGELOG.md | grep -A 10 "BREAKING"
   ```

3. **Update Configuration**
   ```bash
   # Use migration tool
   ./mcp_jujutsu migrate-config config.json.backup
   ```

4. **Test Before Production**
   ```bash
   # Run in test mode
   ./mcp_jujutsu server --test --config config.json.new
   ```

### Rollback Procedure

```bash
# If upgrade fails, rollback
git checkout v0.1.0  # Previous version
nimble build -d:release

# Restore configuration
cp config.json.backup config.json
```