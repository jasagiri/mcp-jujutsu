# MCP-Jujutsu Examples

This directory contains example code demonstrating various use cases for MCP-Jujutsu.

## Example Files

### 1. `example.nim` (Original)
Basic example showing simple client usage.

### 2. `basic_usage.nim`
Comprehensive examples of basic MCP-Jujutsu operations:
- Analyzing recent commits
- Trying different division strategies
- Automated division workflow
- Handling large commits
- Custom confidence thresholds
- Error handling patterns

### 3. `multi_repo_examples.nim`
Examples for multi-repository mode:
- Basic multi-repo analysis
- Selective repository analysis
- Coordinated repository splits
- Dependency-aware workflows
- Monorepo with submodules
- Automated multi-repo operations
- Safe splits with rollback

### 4. `advanced_scenarios.nim`
Advanced usage patterns:
- Progressive refinement strategy
- Intelligent strategy selection
- Commit message quality enforcement
- Handling merge commits
- Time-based commit grouping
- Cross-branch analysis
- Incremental processing
- Custom scoring and filtering

## Running the Examples

### Prerequisites

1. Start the MCP-Jujutsu server:
```bash
# For basic examples (single repo mode)
./scripts/start-server.sh 8080

# For multi-repo examples
./scripts/start-server.sh 8080 multi
```

2. Ensure you have a Jujutsu repository:
```bash
cd /path/to/your/repo
jj init --git-repo .
```

### Running Individual Examples

```bash
# Compile and run an example
nim c -r examples/basic_usage.nim

# Or compile first, then run
nim c examples/basic_usage.nim
./examples/basic_usage

# Run with specific options
nim c -d:release -r examples/advanced_scenarios.nim
```

### Running All Examples

```bash
# Run all single-repo examples
nim c -r examples/basic_usage.nim
nim c -r examples/advanced_scenarios.nim

# Run multi-repo examples (requires multi mode)
nim c -r examples/multi_repo_examples.nim
```

## Example Categories

### Basic Operations
- Commit analysis
- Simple divisions
- Strategy comparison
- Error handling

### Multi-Repository Operations
- Cross-repo analysis
- Dependency detection
- Coordinated splits
- Monorepo support

### Advanced Techniques
- Progressive refinement
- Intelligent strategy selection
- Custom validation
- Performance optimization

## Customizing Examples

Each example can be modified to suit your needs:

1. **Change the server URL**:
```nim
let client = newMcpClient("http://your-server:8080/mcp")
```

2. **Adjust parameters**:
```nim
let proposal = await client.proposeCommitDivision(
  commitRange = "main..feature",  # Your range
  strategy = "semantic",          # Your strategy
  maxCommits = 20                 # Your limit
)
```

3. **Add custom logic**:
```nim
# Add your own validation
if proposal.confidence < 0.9:
  echo "Need manual review"
```

## Common Patterns

### Error Handling
```nim
try:
  let result = await client.analyzeCommitRange(range)
except MpcError as e:
  echo "MCP error: ", e.msg
except Exception as e:
  echo "Unexpected: ", e.msg
```

### Dry Run First
```nim
# Always test with dry run
let test = await client.automateCommitDivision(
  commitRange = range,
  dryRun = true
)

if test.success:
  # Execute for real
  let result = await client.automateCommitDivision(
    commitRange = range,
    dryRun = false
  )
```

### Progress Monitoring
```nim
echo "Starting analysis..."
let start = epochTime()
let result = await client.analyzeCommitRange(range)
echo fmt"Completed in {epochTime() - start:.2f}s"
```

## Troubleshooting

### Connection Issues
- Ensure server is running: `curl http://localhost:8080/health`
- Check server logs: `tail -f logs/mcp-jujutsu.log`

### Repository Issues
- Verify jj is initialized: `jj status`
- Check working directory: `pwd`

### Performance Issues
- Use appropriate strategies for large repos
- Enable caching in server config
- Consider incremental processing

## Contributing Examples

To add new examples:

1. Create a new `.nim` file in this directory
2. Include comprehensive comments
3. Add error handling
4. Update this README
5. Test with both single and multi modes

## Additional Resources

- [API Reference](../docs/API_REFERENCE.md)
- [Configuration Guide](../docs/CONFIGURATION.md)
- [Main README](../README.md)