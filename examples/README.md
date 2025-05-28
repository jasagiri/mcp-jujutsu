# MCP-Jujutsu Examples

This directory contains comprehensive examples demonstrating various use cases for MCP-Jujutsu, from basic commit analysis to advanced multi-repository workflows.

## Quick Start

```bash
# 1. Start the MCP server
nimble run                    # Single repo mode
nimble run -- --hub          # Multi-repo mode

# 2. Run the quickstart example
nim c -r examples/example.nim

# 3. Explore other examples
nim c -r examples/basic_usage.nim
```

## Example Files Overview

### Core Examples

1. **`example.nim`** - Quick Start
   - Simplest way to use MCP-Jujutsu
   - Analyze commits and propose divisions
   - Interactive execution flow

2. **`basic_usage.nim`** - Essential Operations
   - Analyzing recent commits
   - Comparing division strategies
   - Automated workflows with validation
   - Handling large commits
   - Custom confidence thresholds
   - Robust error handling

### Advanced Examples

3. **`advanced_scenarios.nim`** - Complex Patterns
   - Progressive refinement strategies
   - Intelligent strategy selection
   - Commit quality enforcement
   - Merge commit handling
   - Time-based grouping
   - Cross-branch analysis
   - Custom scoring algorithms

4. **`semantic_commit_division.nim`** - Semantic Analysis
   - Local semantic analysis demonstration
   - MCP client semantic division
   - Strategy comparison
   - Automated semantic workflows

### Specialized Examples

5. **`conflict_resolution_strategies.nim`** - Conflict Management
   - Local conflict resolution patterns
   - MCP-based conflict analysis
   - Merge conflict prediction
   - Resolution recommendations

6. **`workspace_workflows.nim`** - Workspace Management
   - Feature branch workflows
   - Team collaboration patterns
   - Environment-based deployments
   - Experimental development
   - Advanced orchestration

7. **`multi_repo_examples.nim`** - Multi-Repository Operations
   - Cross-repository analysis
   - Coordinated splits
   - Dependency detection
   - Monorepo support
   - Automated multi-repo workflows

8. **`multi_repo_workflow.nim`** - Multi-Repo Orchestration
   - Microservices architecture example
   - Cross-repository dependencies
   - Coordinated releases

## Running the Examples

### Prerequisites

1. **Install MCP-Jujutsu**:
```bash
nimble install
```

2. **Start the Server**:
```bash
# Single repository mode (default)
nimble run

# Multi-repository mode
nimble run -- --hub --port=8080

# With custom repository
nimble run -- --repo-path=/path/to/repo
```

3. **Ensure Jujutsu Repository**:
```bash
cd /path/to/your/repo
jj init --git-repo .
```

### Running Examples

```bash
# Quick start
nim c -r examples/example.nim

# With repository path
nim c -r examples/basic_usage.nim /path/to/repo

# Compile for performance
nim c -d:release -r examples/advanced_scenarios.nim

# Run all examples
for f in examples/*.nim; do
  echo "Running $f..."
  nim c -r "$f"
done
```

## Example Categories

### 🚀 Getting Started
- `example.nim` - Minimal working example
- `basic_usage.nim` - Common operations

### 🧠 Semantic Analysis
- `semantic_commit_division.nim` - Intelligent commit splitting
- `advanced_scenarios.nim` - Complex analysis patterns

### 👥 Collaboration
- `workspace_workflows.nim` - Team development patterns
- `conflict_resolution_strategies.nim` - Handling conflicts

### 🏢 Enterprise
- `multi_repo_examples.nim` - Multi-repository management
- `multi_repo_workflow.nim` - Orchestrated workflows

## Common Patterns

### Client Connection
```nim
import mcp_jujutsu/client/client

let client = newMcpClient("http://localhost:8080/mcp")
```

### Error Handling
```nim
try:
  let result = await client.analyzeCommitRange(repo, "HEAD~5..HEAD")
except MpcError as e:
  echo fmt"MCP Error: {e.msg}"
  # Handle MCP-specific errors
except Exception as e:
  echo fmt"Error: {e.msg}"
```

### Dry Run Pattern
```nim
# Always test first
let proposal = await client.proposeCommitDivision(
  repo, range, "semantic", "medium", 10
)

if proposal["proposal"]["confidence"].getFloat >= 0.8:
  # High confidence - execute
  let result = await client.executeCommitDivision(repo, proposal["proposal"])
else:
  echo "Manual review needed"
```

### Progress Monitoring
```nim
echo "Analyzing large repository..."
let start = epochTime()
let result = await client.analyzeCommitRange(repo, range)
echo fmt"Analysis completed in {epochTime() - start:.2f}s"
```

## Configuration Tips

### Server Configuration
```toml
# mcp-jujutsu.toml
[server]
port = 8080
host = "127.0.0.1"

[repository]
path = "/path/to/repo"

[analysis]
cache_enabled = true
max_commits = 50
```

### Client Options
```nim
# Custom timeout for large operations
let client = newMcpClient("http://localhost:8080/mcp", timeout = 60000)

# Batch operations
let results = await client.batchCall([
  ("analyzeCommitRange", %*{"repo": repo1, "range": range1}),
  ("analyzeCommitRange", %*{"repo": repo2, "range": range2})
])
```

## Troubleshooting

### Connection Issues
```bash
# Check server health
curl http://localhost:8080/health

# View server logs
tail -f logs/mcp-jujutsu.log

# Test with CLI
echo '{"method": "listWorkspaces", "params": {}}' | mcp-jujutsu --stdio
```

### Repository Issues
```bash
# Verify Jujutsu setup
jj status
jj log --limit 10

# Check permissions
ls -la .jj/
```

### Performance Optimization
- Use appropriate strategies for repository size
- Enable server-side caching
- Consider `--parallel` flag for multi-repo
- Use incremental processing for large histories

## Writing New Examples

When creating new examples:

1. **Use Clear Structure**:
```nim
proc demonstrateFeature() {.async.} =
  echo "=== Feature Demonstration ==="
  # Setup
  # Operation
  # Verification
  # Cleanup
```

2. **Include Documentation**:
```nim
## Example: Advanced Feature
## Demonstrates how to use advanced features
## Requires: MCP server in multi-repo mode
```

3. **Handle Errors Gracefully**:
```nim
try:
  # operations
except MpcError:
  # MCP-specific handling
except:
  # General error handling
```

4. **Make It Runnable**:
```nim
when isMainModule:
  waitFor main()
```

## Additional Resources

- [API Reference](../docs/API_REFERENCE.md) - Complete API documentation
- [Configuration Guide](../docs/CONFIGURATION.md) - Server configuration
- [Quick Start Guide](../docs/QUICK_START.md) - Getting started
- [Main Documentation](../README.md) - Project overview

## Contributing

To contribute examples:

1. Create descriptive, self-contained examples
2. Include error handling and validation
3. Add comments explaining the logic
4. Test with both single and multi-repo modes
5. Update this README with your example

## Support

- **Issues**: [GitHub Issues](https://github.com/disruptek/mcp-jujutsu/issues)
- **Discussions**: [GitHub Discussions](https://github.com/disruptek/mcp-jujutsu/discussions)
- **Documentation**: [Full Docs](../docs/)