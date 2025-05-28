# MCP-Jujutsu Installation Guide

This guide provides detailed instructions for installing and setting up MCP-Jujutsu on various platforms.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Install](#quick-install)
- [Platform-Specific Installation](#platform-specific-installation)
- [Building from Source](#building-from-source)
- [Docker Installation](#docker-installation)
- [Verifying Installation](#verifying-installation)
- [Client Setup](#client-setup)
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

## Client Setup

After installing the MCP-Jujutsu server, you need to configure client applications to connect to it. This section covers setup for various MCP clients.

### Claude Code (Desktop App)

Claude Code is Anthropic's official CLI and desktop application with built-in MCP support.

#### Prerequisites

- Claude Code installed ([Download here](https://claude.ai/code))
- MCP-Jujutsu server running
- Valid MCP card configuration

#### Configuration

1. **Add Server Configuration**

   ```bash
   # Using Claude Code CLI for stdio transport
   claude-code mcp add \
     "mcp-jujutsu" \
     --transport "stdio" \
     --command "./bin/mcp_jujutsu" \
     --args "--stdio" \
     --env "MCP_LOG_LEVEL=info"

   # Alternative: Using absolute path
   claude-code mcp add \
     "mcp-jujutsu" \
     --transport "stdio" \
     --command "/absolute/path/to/mcp-jujutsu/bin/mcp_jujutsu" \
     --args "--stdio"
   ```

2. **Alternative: Manual Configuration**

   Edit Claude Code's configuration file:

   ```json
   {
     "mcpServers": {
       "mcp-jujutsu": {
         "command": "/path/to/mcp-jujutsu/bin/mcp_jujutsu",
         "args": ["--stdio"],
         "env": {
           "MCP_LOG_LEVEL": "info",
           "MCP_MODE": "single"
         }
       }
     }
   }
   ```

3. **Configuration with TOML**

   Create `mcp-jujutsu.toml` in your project directory:

   ```toml
   [general]
   mode = "single"
   server_name = "MCP-Jujutsu"
   log_level = "info"

   [transport]
   stdio = true
   http = false

   [repository]
   path = "."
   ```

   Then configure Claude Code:

   ```bash
   claude-code mcp add \
     "mcp-jujutsu" \
     --transport "stdio" \
     --command "path/to/mcp_jujutsu/bin/mcp_jujutsu" \
     --args "--stdio --config mcp-jujutsu.toml"
   ```

#### Multi-Repository Setup

For projects with multiple repositories:

1. **Create Repository Configuration**

   ```toml
   # repos.toml
   [[repositories]]
   name = "frontend"
   path = "./repos/frontend"
   dependencies = []

   [[repositories]]
   name = "backend"
   path = "./repos/backend"
   dependencies = ["shared-lib"]

   [[repositories]]
   name = "shared-lib"
   path = "./repos/shared-lib"
   dependencies = []
   ```

2. **Configure MCP-Jujutsu for Multi-Repo**

   ```toml
   # mcp-jujutsu.toml
   [general]
   mode = "multi"
   server_name = "MCP-Jujutsu Multi-Repo"

   [repository]
   repos_dir = "./repos"
   config_path = "./repos.toml"
   ```

3. **Update Claude Code Configuration**

   ```bash
   claude-code mcp add \
     "mcp-jujutsu-multi" \
     --transport "stdio" \
     --command "path/to/mcp_jujutsu/bin/mcp_jujutsu" \
     --args "--stdio --mode=multi --config mcp-jujutsu.toml" \
     --env "MCP_MODE=multi"
   ```

### VS Code Extension

If using VS Code with MCP support:

1. **Install MCP Extension**

   ```bash
   code --install-extension anthropic.mcp-client
   ```

2. **Configure in settings.json**

   ```json
   {
     "mcp.servers": {
       "mcp-jujutsu": {
         "command": "/path/to/mcp-jujutsu/bin/mcp_jujutsu",
         "args": ["--stdio"],
         "initializationOptions": {
           "mode": "single",
           "logLevel": "info"
         }
       }
     }
   }
   ```

### Custom MCP Client

For developing your own MCP client:

#### HTTP Transport

```python
import asyncio
import aiohttp
import json

async def mcp_request(method, params=None):
    url = "http://localhost:8080/mcp"
    request_data = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {}
    }

    async with aiohttp.ClientSession() as session:
        async with session.post(url, json=request_data) as response:
            return await response.json()

# Example usage
async def main():
    # Initialize connection
    result = await mcp_request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {
            "name": "my-client",
            "version": "1.0.0"
        }
    })
    print(result)

    # List available tools
    tools = await mcp_request("tools/list")
    print(tools)

    # Analyze commits
    analysis = await mcp_request("tools/call", {
        "name": "analyzeCommitRange",
        "arguments": {
            "commitRange": "@~2..@",
            "repoPath": "/path/to/repo"
        }
    })
    print(analysis)

asyncio.run(main())
```

#### Stdio Transport

```python
import asyncio
import json
import subprocess

class StdioMCPClient:
    def __init__(self, command, args):
        self.process = None
        self.command = command
        self.args = args
        self.request_id = 0

    async def start(self):
        self.process = await asyncio.create_subprocess_exec(
            self.command, *self.args,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

    async def send_request(self, method, params=None):
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }

        request_json = json.dumps(request) + "\n"
        self.process.stdin.write(request_json.encode())
        await self.process.stdin.drain()

        response_line = await self.process.stdout.readline()
        return json.loads(response_line.decode())

# Example usage
async def main():
    client = StdioMCPClient("/path/to/mcp-jujutsu/bin/mcp_jujutsu", ["--stdio"])
    await client.start()

    # Initialize
    await client.send_request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "stdio-client", "version": "1.0.0"}
    })

    # Use tools
    result = await client.send_request("tools/call", {
        "name": "analyzeCommitRange",
        "arguments": {"commitRange": "@~1..@"}
    })
    print(result)

asyncio.run(main())
```

### Client Configuration Options

#### Environment Variables

```bash
# Set global defaults
export MCP_JUJUTSU_MODE=single
export MCP_JUJUTSU_LOG_LEVEL=info
export MCP_JUJUTSU_REPO_PATH=/path/to/repo

# For multi-repo mode
export MCP_JUJUTSU_MODE=multi
export MCP_JUJUTSU_REPOS_DIR=/path/to/repos
export MCP_JUJUTSU_CONFIG_PATH=/path/to/repos.toml
```

#### Client-Specific Settings

**For Claude Code:**

```json
{
  "mcp-jujutsu": {
    "enabled": true,
    "autoStart": true,
    "features": {
      "commitAnalysis": true,
      "semanticDivision": true,
      "multiRepo": false
    },
    "ui": {
      "showProgress": true,
      "autoRefresh": true
    }
  }
}
```

**For VS Code:**

```json
{
  "mcp.jujutsu.enabled": true,
  "mcp.jujutsu.autoAnalyze": true,
  "mcp.jujutsu.showInlineSuggestions": true,
  "mcp.jujutsu.commitMessageFormat": "conventional"
}
```

### Testing Client Connection

1. **Basic Connection Test**

   ```bash
   # Test server is running
   curl -X POST http://localhost:8080/mcp \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "id": 1,
       "method": "initialize",
       "params": {
         "protocolVersion": "2024-11-05",
         "capabilities": {}
       }
     }'
   ```

2. **Tool Availability Test**

   ```bash
   # List available tools
   curl -X POST http://localhost:8080/mcp \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "id": 2,
       "method": "tools/list",
       "params": {}
     }'
   ```

3. **Claude Code Integration Test**

   ```bash
   # Test through Claude Code (if supported)
   claude-code mcp test mcp-jujutsu

   # Or manually test stdio connection
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}' | ./bin/mcp_jujutsu --stdio
   ```

### Troubleshooting Client Setup

#### Common Issues

1. **Connection Refused**
   ```bash
   # Check if server is running
   ps aux | grep mcp_jujutsu
   netstat -an | grep 8080
   ```

2. **Permission Denied**
   ```bash
   # Fix executable permissions
   chmod +x /path/to/mcp-jujutsu/bin/mcp_jujutsu
   ```

3. **Configuration Not Found**
   ```bash
   # Verify config file paths
   ls -la mcp-jujutsu.toml
   ls -la repos.toml
   ```

4. **Protocol Version Mismatch**
   ```bash
   # Check server version
   ./bin/mcp_jujutsu --version

   # Update client to use correct protocol version
   ```

#### Debug Mode

Enable debug logging for troubleshooting:

```bash
# Server side
MCP_LOG_LEVEL=debug ./bin/mcp_jujutsu --stdio

# Client side (Claude Code)
claude-code --verbose mcp test mcp-jujutsu
```

## Initial Setup

### 1. Create Configuration

```bash
# Create config directory
mkdir -p ~/.config/mcp-jujutsu

# Option 1: TOML Configuration (Recommended)
cp mcp-jujutsu.toml.example ~/.config/mcp-jujutsu/config.toml

# Edit TOML configuration
nano ~/.config/mcp-jujutsu/config.toml

# Option 2: JSON Configuration (Legacy)
cp config.example.json ~/.config/mcp-jujutsu/config.json

# Edit JSON configuration
nano ~/.config/mcp-jujutsu/config.json
```

**Example TOML Configuration:**

```toml
[general]
mode = "single"
server_name = "MCP-Jujutsu"
server_port = 8080
log_level = "info"
verbose = false

[transport]
http = true
http_host = "127.0.0.1"
http_port = 8080
stdio = false

[repository]
path = "/path/to/your/repo"
repos_dir = "/path/to/repos"
config_path = "/path/to/repos.toml"

[ai]
endpoint = "https://api.openai.com/v1/chat/completions"
api_key = ""  # Set via environment variable
model = "gpt-4"
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

For Claude Code (see [Client Setup](#client-setup) for detailed instructions):
```bash
# Add to MCP settings
claude-code mcp add \
  "mcp-jujutsu" \
  --transport "stdio" \
  --command "/path/to/mcp-jujutsu/bin/mcp_jujutsu" \
  --args "--stdio"
```

### 4. Set Up Multi-Repository Mode

```bash
# Option 1: TOML Configuration (Recommended)
cat > repos.toml << EOF
[[repositories]]
name = "frontend"
path = "./repos/frontend"
dependencies = []

[[repositories]]
name = "backend"
path = "./repos/backend"
dependencies = ["shared-lib"]

[[repositories]]
name = "shared-lib"
path = "./repos/shared-lib"
dependencies = []

[analysis]
analyze_dependencies = true
semantic_grouping = true
max_dependency_depth = 3
EOF

# Option 2: JSON Configuration (Legacy)
cat > repos.json << EOF
{
  "repositories": [
    {
      "name": "frontend",
      "path": "./repos/frontend",
      "dependencies": []
    },
    {
      "name": "backend",
      "path": "./repos/backend",
      "dependencies": ["shared-lib"]
    },
    {
      "name": "shared-lib",
      "path": "./repos/shared-lib",
      "dependencies": []
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
./bin/mcp_jujutsu --help

# Run with debug logging
MCP_LOG_LEVEL=debug ./bin/mcp_jujutsu --stdio

# Test connection manually
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | ./bin/mcp_jujutsu --stdio
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
