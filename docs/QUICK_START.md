# MCP-Jujutsu Quick Start Guide

Get up and running with MCP-Jujutsu in 5 minutes.

## Prerequisites

- Nim 1.6.0+
- Jujutsu 0.9.0+
- Git 2.25.0+

## Installation

```bash
# Install dependencies
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
cargo install jj

# Clone and build
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install
nimble build
```

## Basic Usage

### 1. Start the Server

```bash
./scripts/start-server.sh 8080
```

### 2. Analyze a Commit

```bash
# Using curl
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "analyzeCommitRange",
      "arguments": {
        "commitRange": "HEAD~1..HEAD"
      }
    },
    "id": 1
  }'
```

### 3. Propose Commit Division

```bash
# Automatic division with dry run
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "automateCommitDivision",
      "arguments": {
        "commitRange": "HEAD~1..HEAD",
        "strategy": "semantic",
        "dryRun": true
      }
    },
    "id": 2
  }'
```

## Using with Claude Code

1. Add to your MCP settings:
```json
{
  "mcpServers": {
    "mcp-jujutsu": {
      "command": "/path/to/mcp-jujutsu/mcp_jujutsu",
      "args": ["server", "--port", "8080"]
    }
  }
}
```

2. Or use the card:
```bash
claude-code --mcp-card=/path/to/mcp-jujutsu/card/card.json
```

## Common Commands

### Single Repository Mode

```bash
# Analyze recent commits
mcp-client call analyzeCommitRange '{"commitRange": "HEAD~5..HEAD"}'

# Propose semantic division
mcp-client call proposeCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "semantic"
}'

# Execute division
mcp-client call automateCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "semantic",
  "dryRun": false
}'
```

### Multi-Repository Mode

```bash
# Start in multi-repo mode
./scripts/start-server.sh 8080 multi

# Analyze across repos
mcp-client call analyzeMultiRepoCommits '{
  "commitRange": "HEAD~1..HEAD"
}'

# Coordinated split
mcp-client call automateMultiRepoSplit '{
  "commitRange": "HEAD~1..HEAD"
}'
```

## Division Strategies

- **balanced**: Equal-sized commits (default)
- **semantic**: Group by functionality
- **filetype**: Group by file extension
- **directory**: Group by directory structure

## Configuration

Create `config.json`:
```json
{
  "server": {
    "port": 8080,
    "mode": "single"
  },
  "analysis": {
    "defaultStrategy": "semantic",
    "minConfidence": 0.7,
    "maxCommits": 10
  }
}
```

## Troubleshooting

### Server won't start
```bash
# Check port
lsof -i :8080

# Check logs
tail -f logs/mcp-jujutsu.log
```

### Jujutsu not found
```bash
# Add to PATH
export PATH="$HOME/.cargo/bin:$PATH"
```

### Analysis fails
```bash
# Verify jj is initialized
jj status

# Check repository
jj log -r HEAD
```

## Next Steps

- Read the [full documentation](../README.md)
- Check out [examples](../examples/)
- Review [API reference](./API_REFERENCE.md)
- Configure [advanced settings](./CONFIGURATION.md)

## Getting Help

- GitHub Issues: https://github.com/jasagiri/mcp-jujutsu/issues
- Documentation: [docs/](.)
- Examples: [examples/](../examples/)