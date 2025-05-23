# MCP-Jujutsu API Reference

This document provides a comprehensive reference for all MCP tools, resources, and client library APIs available in MCP-Jujutsu.

## Table of Contents

- [Single Repository Tools](#single-repository-tools)
- [Multi-Repository Tools](#multi-repository-tools)
- [Resources](#resources)
- [Client Library API](#client-library-api)
- [Response Formats](#response-formats)
- [Error Handling](#error-handling)

## Single Repository Tools

### analyzeCommitRange

Analyzes a commit range and returns detailed information about changes.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze (e.g., "HEAD~1..HEAD", "main..feature") |
| `repoPath` | string | No | "." | Path to the repository |

**Response:**

```json
{
  "fileCount": 15,
  "totalAdditions": 324,
  "totalDeletions": 87,
  "fileTypes": {
    "nim": 8,
    "json": 3,
    "md": 4
  },
  "changeTypes": {
    "modified": 10,
    "added": 4,
    "deleted": 1
  },
  "codePatterns": {
    "newFunctions": 12,
    "modifiedFunctions": 8,
    "newTypes": 3
  },
  "files": [
    {
      "path": "src/analyzer/semantic.nim",
      "additions": 45,
      "deletions": 12,
      "changeType": "modified"
    }
  ]
}
```

### proposeCommitDivision

Proposes a semantic division of a commit range using advanced analysis.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze |
| `repoPath` | string | No | "." | Path to the repository |
| `strategy` | string | No | "balanced" | Division strategy: "balanced", "semantic", "filetype", "directory" |
| `commitSize` | string | No | "balanced" | Commit size preference: "balanced", "many", "few" |
| `minConfidence` | float | No | 0.7 | Minimum confidence threshold (0.0-1.0) |
| `maxCommits` | int | No | 10 | Maximum number of commits to propose |

**Response:**

```json
{
  "confidence": 0.85,
  "strategy": "semantic",
  "proposedCommits": [
    {
      "type": "feat",
      "scope": "analyzer",
      "description": "add semantic pattern recognition",
      "files": [
        "src/analyzer/semantic.nim",
        "src/analyzer/patterns.nim"
      ],
      "confidence": 0.9,
      "reasoning": "New feature addition with related files"
    },
    {
      "type": "fix",
      "scope": "server",
      "description": "resolve memory leak in request handler",
      "files": [
        "src/core/mcp/server.nim"
      ],
      "confidence": 0.8,
      "reasoning": "Bug fix isolated to server component"
    }
  ],
  "statistics": {
    "totalFiles": 15,
    "totalChanges": 411,
    "averageCommitSize": 137,
    "commitCount": 3
  }
}
```

### executeCommitDivision

Executes a commit division based on a proposal.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `proposal` | object | Yes | - | The proposal object from `proposeCommitDivision` |
| `repoPath` | string | No | "." | Path to the repository |

**Response:**

```json
{
  "success": true,
  "commitIds": [
    "abc123def456",
    "789ghi012jkl"
  ],
  "commits": [
    {
      "id": "abc123def456",
      "message": "feat(analyzer): add semantic pattern recognition",
      "files": 2
    },
    {
      "id": "789ghi012jkl",
      "message": "fix(server): resolve memory leak in request handler",
      "files": 1
    }
  ]
}
```

### automateCommitDivision

Automates the entire commit division process with validation and auto-fix options.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze |
| `repoPath` | string | No | "." | Path to the repository |
| `strategy` | string | No | "balanced" | Division strategy |
| `commitSize` | string | No | "balanced" | Commit size preference |
| `minConfidence` | float | No | 0.7 | Minimum confidence threshold |
| `maxCommits` | int | No | 10 | Maximum number of commits |
| `dryRun` | boolean | No | false | Perform analysis without making changes |
| `validate` | boolean | No | false | Validate commit messages |
| `autoFix` | boolean | No | false | Auto-fix invalid commit messages |

**Response:**

```json
{
  "success": true,
  "dryRun": false,
  "commitIds": ["abc123", "def456"],
  "proposal": {
    "confidence": 0.85,
    "proposedCommits": [...]
  },
  "validation": {
    "allValid": true,
    "results": [
      {
        "commitId": "abc123",
        "valid": true,
        "message": "feat(analyzer): add semantic pattern recognition"
      }
    ]
  },
  "statistics": {
    "originalCommits": 1,
    "createdCommits": 2,
    "filesProcessed": 15,
    "executionTime": "2.3s"
  }
}
```

## Multi-Repository Tools

### analyzeMultiRepoCommits

Analyzes commits across multiple repositories with dependency detection.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze |
| `reposDir` | string | No | "." | Directory containing repositories |
| `configPath` | string | No | "repos.json" | Path to repository configuration |
| `repositories` | array | No | all | List of repository names to analyze |

**Response:**

```json
{
  "repositories": {
    "frontend": {
      "fileCount": 10,
      "additions": 234,
      "deletions": 45
    },
    "backend": {
      "fileCount": 8,
      "additions": 167,
      "deletions": 23
    }
  },
  "crossDependencies": [
    {
      "from": "frontend",
      "to": "shared",
      "type": "import",
      "files": ["src/api/client.js"]
    }
  ],
  "hasCrossDependencies": true,
  "totalFiles": 18,
  "totalChanges": 469
}
```

### proposeMultiRepoSplit

Proposes a coordinated split of commits across multiple repositories.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze |
| `reposDir` | string | No | "." | Directory containing repositories |
| `configPath` | string | No | "repos.json" | Path to repository configuration |
| `repositories` | array | No | all | List of repository names |

**Response:**

```json
{
  "confidence": 0.82,
  "commitGroups": [
    {
      "groupId": "group-1",
      "description": "API client updates",
      "repositories": {
        "frontend": {
          "commits": [
            {
              "type": "feat",
              "description": "add new API client methods",
              "files": ["src/api/client.js"]
            }
          ]
        },
        "shared": {
          "commits": [
            {
              "type": "feat",
              "description": "add API type definitions",
              "files": ["types/api.d.ts"]
            }
          ]
        }
      },
      "dependencies": ["frontend->shared"]
    }
  ],
  "statistics": {
    "totalGroups": 3,
    "totalCommits": 7,
    "averageGroupSize": 2.3
  }
}
```

### executeMultiRepoSplit

Executes a multi-repository split based on a proposal.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `proposal` | object | Yes | - | The proposal from `proposeMultiRepoSplit` |
| `reposDir` | string | No | "." | Directory containing repositories |
| `configPath` | string | No | "repos.json" | Path to repository configuration |

**Response:**

```json
{
  "success": true,
  "commitsByRepo": {
    "frontend": ["abc123", "def456"],
    "backend": ["ghi789"],
    "shared": ["jkl012", "mno345"]
  },
  "groupResults": [
    {
      "groupId": "group-1",
      "success": true,
      "commits": 3
    }
  ]
}
```

### automateMultiRepoSplit

Automates the entire multi-repository split process.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `commitRange` | string | Yes | - | The commit range to analyze |
| `reposDir` | string | No | "." | Directory containing repositories |
| `configPath` | string | No | "repos.json" | Path to repository configuration |
| `repositories` | array | No | all | List of repository names |

**Response:**

```json
{
  "success": true,
  "analysis": {...},
  "proposal": {...},
  "execution": {
    "commitsByRepo": {...},
    "totalCommits": 7,
    "executionTime": "5.2s"
  }
}
```

## Resources

Resources provide read-only access to repository data. They are accessed through the MCP resources API.

### Single Repository Resources

- **jujutsuRepo** - Initialize and manage a Jujutsu repository
- **commitDiff** - Get diff information for a commit range
- **commitAnalysis** - Perform semantic analysis on commits
- **commitHistory** - Get commit history from a repository

### Multi-Repository Resources

- **repoGroup** - Create and manage groups of repositories
- **repoCommit** - Get information about specific commits
- **crossRepoDiff** - Get diff information across repositories
- **dependencyGraph** - Get dependency relationships
- **crossDependencyAnalysis** - Analyze cross-repo dependencies

## Client Library API

### Creating a Client

```nim
import mcp_jujutsu/client/client

# Create client with default settings
let client = newMcpClient("http://localhost:8080/mcp")

# Create client with custom timeout
let client = newMcpClient(
  url = "http://localhost:8080/mcp",
  timeout = 30.seconds
)
```

### Client Methods

#### analyzeCommitRange

```nim
proc analyzeCommitRange(
  client: MpcClient,
  commitRange: string,
  repoPath: string = "."
): Future[CommitAnalysis] {.async.}
```

#### proposeCommitDivision

```nim
proc proposeCommitDivision(
  client: MpcClient,
  commitRange: string,
  repoPath: string = ".",
  strategy: DivisionStrategy = BalancedStrategy,
  commitSize: CommitSize = BalancedSize,
  minConfidence: float = 0.7,
  maxCommits: int = 10
): Future[DivisionProposal] {.async.}
```

#### executeCommitDivision

```nim
proc executeCommitDivision(
  client: MpcClient,
  proposal: DivisionProposal,
  repoPath: string = "."
): Future[ExecutionResult] {.async.}
```

### Types and Enums

```nim
type
  DivisionStrategy* = enum
    BalancedStrategy = "balanced"
    SemanticStrategy = "semantic"
    FiletypeStrategy = "filetype"
    DirectoryStrategy = "directory"

  CommitSize* = enum
    BalancedSize = "balanced"
    ManySize = "many"
    FewSize = "few"

  CommitAnalysis* = object
    fileCount*: int
    totalAdditions*: int
    totalDeletions*: int
    fileTypes*: Table[string, int]
    changeTypes*: Table[string, int]
    codePatterns*: Table[string, int]
    files*: seq[FileChange]

  DivisionProposal* = object
    confidence*: float
    strategy*: string
    proposedCommits*: seq[ProposedCommit]
    statistics*: ProposalStats

  ExecutionResult* = object
    success*: bool
    commitIds*: seq[string]
    commits*: seq[CreatedCommit]
```

## Response Formats

All MCP responses follow the JSON-RPC 2.0 specification:

### Success Response

```json
{
  "jsonrpc": "2.0",
  "result": {
    // Tool-specific result data
  },
  "id": 1
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {
      "field": "commitRange",
      "reason": "Invalid format"
    }
  },
  "id": 1
}
```

## Error Handling

### Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid request structure |
| -32601 | Method not found | Unknown tool or method |
| -32602 | Invalid params | Invalid parameters |
| -32603 | Internal error | Server error |
| -32000 | Repository error | Jujutsu operation failed |
| -32001 | Analysis error | Semantic analysis failed |
| -32002 | Execution error | Commit execution failed |

### Client Error Handling

```nim
try:
  let result = await client.analyzeCommitRange("HEAD~1..HEAD")
  echo result.fileCount
except MpcError as e:
  echo "MCP error: ", e.msg
  echo "Error code: ", e.code
except Exception as e:
  echo "Unexpected error: ", e.msg
```

### Best Practices

1. **Always handle errors** - MCP operations can fail due to repository state or network issues
2. **Check confidence scores** - Use the confidence threshold appropriate for your use case
3. **Use dry run for testing** - Test complex operations before executing
4. **Validate proposals** - Review proposed commits before execution
5. **Monitor cross-dependencies** - Be aware of dependencies when working with multiple repositories