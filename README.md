# MCP-Jujutsu

A Model Context Protocol (MCP) based system for semantically dividing large Jujutsu commits into smaller, more meaningful units with proper commit messages following release-please format.

## Overview

MCP-Jujutsu is an integrated tool that provides:

1. **Semantic analysis** of Jujutsu repository changes
2. **Automatic division** of large commits into semantic units
3. **Multi-repository management** and cross-repo analysis
4. **MCP-compatible client** integration for AI assistants

## Prerequisites

- [Nim](https://nim-lang.org/) 1.6.0 or higher
- [Jujutsu](https://github.com/martinvonz/jj) 0.9.0 or higher
- Git (for repository compatibility)

## Project Structure

```
mcp-jujutsu/
├── src/                    # Source code
│   ├── core/              # Core components
│   │   ├── config/        # Configuration management
│   │   ├── logging/       # Logging utilities
│   │   ├── mcp/           # MCP server implementation
│   │   └── repository/    # Jujutsu repository interface
│   ├── single_repo/       # Single repository mode
│   │   ├── analyzer/      # Semantic analysis
│   │   ├── config/        # Mode-specific config
│   │   ├── mcp/           # Server extensions
│   │   └── tools/         # MCP tool implementations
│   ├── multi_repo/        # Multi-repository mode
│   │   ├── analyzer/      # Cross-repo analysis
│   │   ├── config/        # Multi-repo config
│   │   ├── mcp/           # Hub server extensions
│   │   ├── repository/    # Repository management
│   │   └── tools/         # Multi-repo tools
│   ├── client/            # Client library
│   └── mcp_jujutsu.nim    # Main entry point
├── tests/                 # Test suite
├── examples/              # Example usage
├── docs/                  # Documentation
├── card/                  # MCP card definition
├── scripts/               # Helper scripts
└── mcp_jujutsu.nimble     # Package definition
```

## Features

- **Semantic Analysis**: Analyzes commit content to identify logical boundaries using advanced code pattern recognition
- **Intelligent Commit Division**: Automatically divides large commits into smaller, semantic units with configurable strategies
- **Release-Please Format**: Generates proper commit messages following the release-please convention (feat, fix, docs, etc.)
- **Multi-Repository Support**: Manages multiple repositories with cross-repo dependency analysis
- **MCP Integration**: Full compatibility with Claude Code and other MCP-compatible AI assistants
- **Flexible Division Strategies**: Choose between balanced, semantic, filetype, or directory-based division
- **Confidence Scoring**: Each proposed division includes confidence scores for validation

## Installation

1. **Install Nim** (if not already installed):
```bash
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
```

2. **Install Jujutsu**:
```bash
cargo install jj
```

3. **Clone and build MCP-Jujutsu**:
```bash
git clone https://github.com/jasagiri/mcp-jujutsu.git
cd mcp-jujutsu
nimble install
nimble build
```

## Getting Started

### Quick Start

1. **Start the server**:
```bash
# Single repository mode (default)
./scripts/start-server.sh 8080

# Multi-repository mode
./scripts/start-server.sh 8080 multi
```

2. **Connect with Claude Code**:
```bash
claude-code --mcp-card=/path/to/mcp-jujutsu/card/card.json
```

### Basic Usage Examples

#### Analyzing a Commit Range
```bash
# Using the MCP client
mcp-client call analyzeCommitRange '{"commitRange": "HEAD~5..HEAD"}'
```

#### Proposing Commit Division
```bash
# Propose division with semantic strategy
mcp-client call proposeCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "semantic",
  "commitSize": "balanced",
  "maxCommits": 5
}'
```

#### Automating the Entire Process
```bash
# Automatically analyze and split commits
mcp-client call automateCommitDivision '{
  "commitRange": "HEAD~3..HEAD",
  "strategy": "semantic",
  "dryRun": true,
  "validate": true
}'
```

## Usage Modes

### Single Repository Mode (Default)

Focuses on analyzing and dividing commits within a single repository.

**Available Tools:**
- `analyzeCommitRange` - Analyze changes in a commit range
- `proposeCommitDivision` - Propose semantic division with multiple strategies
- `executeCommitDivision` - Execute a proposed division
- `automateCommitDivision` - Automate the entire process

**Example workflow:**
```nim
import asyncdispatch
import mcp_jujutsu/client/client

proc divideCommits() {.async.} =
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze the commit
  let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
  echo "Files changed: ", analysis.fileCount
  
  # Propose division
  let proposal = await client.proposeCommitDivision(
    commitRange = "HEAD~1..HEAD",
    strategy = "semantic",
    maxCommits = 5
  )
  
  # Execute if confident
  if proposal.confidence > 0.8:
    let result = await client.executeCommitDivision(proposal)
    echo "Created ", result.commitIds.len, " commits"

waitFor divideCommits()
```

### Multi-Repository Mode

Manages multiple repositories with cross-repository dependency analysis.

**Available Tools:**
- `analyzeMultiRepoCommits` - Analyze commits across multiple repositories
- `proposeMultiRepoSplit` - Propose coordinated splits across repos
- `executeMultiRepoSplit` - Execute multi-repo proposal
- `automateMultiRepoSplit` - Automate multi-repo splitting

**Example workflow:**
```nim
proc splitAcrossRepos() {.async.} =
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze changes across repos
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~1..HEAD",
    repositories = @["frontend", "backend", "shared"]
  )
  
  # Check for cross-repo dependencies
  if analysis.hasCrossDependencies:
    echo "Found dependencies between: ", analysis.dependencies
  
  # Propose coordinated split
  let proposal = await client.proposeMultiRepoSplit(
    commitRange = "HEAD~1..HEAD"
  )
  
  # Execute the split
  let result = await client.executeMultiRepoSplit(proposal)
  for repo, commits in result.commitsByRepo:
    echo repo, ": created ", commits.len, " commits"

waitFor splitAcrossRepos()
```

## Division Strategies

MCP-Jujutsu supports multiple strategies for dividing commits:

1. **Balanced** (default): Aims for equally-sized commits
2. **Semantic**: Groups by logical functionality
3. **Filetype**: Groups by file extensions
4. **Directory**: Groups by directory structure

### Strategy Examples

```bash
# Semantic strategy - groups related functionality
mcp-client call proposeCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "semantic"
}'

# Filetype strategy - groups by file type
mcp-client call proposeCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "filetype"
}'

# Directory strategy with few large commits
mcp-client call proposeCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "strategy": "directory",
  "commitSize": "few"
}'
```

## Configuration

### Server Configuration

Create a `config.json` file:
```json
{
  "server": {
    "port": 8080,
    "mode": "single",
    "logLevel": "info"
  },
  "analysis": {
    "minConfidence": 0.7,
    "maxCommits": 10,
    "defaultStrategy": "semantic"
  }
}
```

### Multi-Repository Configuration

For multi-repo mode, create `repos.json`:
```json
{
  "repositories": [
    {
      "name": "frontend",
      "path": "./repos/frontend",
      "dependencies": ["shared"]
    },
    {
      "name": "backend",
      "path": "./repos/backend",
      "dependencies": ["shared"]
    },
    {
      "name": "shared",
      "path": "./repos/shared",
      "dependencies": []
    }
  ]
}
```

## Client Integration

### Nim Client Library

The included client library provides type-safe access to all MCP tools:

```nim
import mcp_jujutsu/client/client

# Create client
let client = newMcpClient("http://localhost:8080/mcp")

# Use typed methods
let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
let proposal = await client.proposeCommitDivision(
  commitRange = "HEAD~1..HEAD",
  strategy = SemanticStrategy,
  commitSize = BalancedSize
)
```

### Direct MCP Integration

For other languages, use the MCP protocol directly:

```python
import requests

# Call MCP tool
response = requests.post("http://localhost:8080/mcp", json={
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "analyzeCommitRange",
        "arguments": {
            "commitRange": "HEAD~1..HEAD"
        }
    },
    "id": 1
})

result = response.json()["result"]
```

## Advanced Usage

### Dry Run Mode

Test division without making changes:
```bash
mcp-client call automateCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "dryRun": true,
  "validate": true
}'
```

### Custom Confidence Thresholds

Set minimum confidence for automatic execution:
```bash
mcp-client call automateCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "minConfidence": 0.9,
  "autoFix": true
}'
```

### Validation and Auto-fix

Validate commit messages and auto-fix issues:
```bash
mcp-client call automateCommitDivision '{
  "commitRange": "HEAD~1..HEAD",
  "validate": true,
  "autoFix": true
}'
```

## License

MIT