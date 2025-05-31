# MCP-Jujutsu

MCP server for Jujutsu VCS with semantic commit analysis and division.

## Documentation

All documentation is located in the `docs/` directory:

- [README](docs/README.md) - Detailed project documentation
- [QUICK_START](docs/QUICK_START.md) - Getting started guide
- [INSTALLATION](docs/INSTALLATION.md) - Installation instructions
- [CONFIGURATION](docs/CONFIGURATION.md) - Configuration guide
- [API_REFERENCE](docs/API_REFERENCE.md) - API documentation
- [DIFF_FORMATS](docs/DIFF_FORMATS.md) - Diff format options and templates

## Quick Start

```bash
# Install dependencies
nimble install

# Build the project
nimble build

# Run tests
nimble test

# Start the server
nimble run

# Start with TOML configuration
cp mcp-jujutsu.toml.example mcp-jujutsu.toml
# Edit mcp-jujutsu.toml as needed
nimble run
```

## Configuration

MCP-Jujutsu supports both TOML and JSON configuration formats. TOML is the default and recommended format.

Configuration files are searched in the following order:
1. `mcp-jujutsu.toml` (current directory)
2. `.mcp-jujutsu.toml` (current directory)
3. `config.toml` (current directory)
4. `~/.config/mcp-jujutsu/config.toml`
5. JSON equivalents of the above

See `mcp-jujutsu.toml.example` for a complete example configuration.

## Client Setup

To use MCP-Jujutsu with AI clients:

### Claude Code
```bash
# Add server configuration for stdio transport
claude-code mcp add \
  "mcp-jujutsu" \
  --transport "stdio" \
  --command "path/to/mcp_jujutsu" \
  --args "--stdio"

# Alternative: Using absolute path to binary
claude-code mcp add \
  "mcp-jujutsu" \
  --transport "stdio" \
  --command "/path/to/mcp-jujutsu/bin/mcp_jujutsu" \
  --args "--stdio"
```

### Custom Clients
```bash
# HTTP endpoint (default mode) - start server first
./bin/mcp_jujutsu --port=8080 &
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'

# Stdio transport (for direct pipe communication)
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | ./bin/mcp_jujutsu --stdio

# Multi-repo mode with custom config
./bin/mcp_jujutsu --mode=multi --config=repos.toml --stdio

# SSE transport (Server-Sent Events)
./bin/mcp_jujutsu --sse --port=8080
```

### Server Health Monitoring
```bash
# Health check endpoint
curl http://localhost:8080/health

# Server status and capabilities
curl http://localhost:8080/status

# Server information and available endpoints
curl http://localhost:8080/
```

### Testing Connection
```bash
# Test if server binary works
./bin/mcp_jujutsu --version

# Test stdio connection
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | ./bin/mcp_jujutsu --stdio

# Test HTTP connection
./bin/mcp_jujutsu --port=8080 &
sleep 2
curl http://localhost:8080/mcp -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

For detailed client setup instructions, see [docs/INSTALLATION.md#client-setup](docs/INSTALLATION.md#client-setup).

## Project Structure

- `src/` - Source code
- `tests/` - Test files
- `docs/` - Documentation
- `scripts/` - Build and utility scripts
- `examples/` - Usage examples
- `build/` - Build artifacts (not tracked in git)

## License

See LICENSE file for details.