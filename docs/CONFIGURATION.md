# MCP-Jujutsu Configuration Guide

This guide covers all configuration options for MCP-Jujutsu, including server settings, analysis parameters, repository configurations, and logging options.

## Table of Contents

- [Configuration Files](#configuration-files)
- [Server Configuration](#server-configuration)
- [Analysis Configuration](#analysis-configuration)
- [Multi-Repository Configuration](#multi-repository-configuration)
- [Logging Configuration](#logging-configuration)
- [Environment Variables](#environment-variables)
- [Configuration Examples](#configuration-examples)
- [Best Practices](#best-practices)

## Configuration Files

MCP-Jujutsu supports both TOML and JSON configuration formats. TOML is the default and recommended format.

| File | Purpose | Required | Formats |
|------|---------|----------|---------|
| `mcp-jujutsu.toml` / `config.json` | Main server and analysis configuration | No (uses defaults) | TOML (preferred), JSON |
| `repos.toml` / `repos.json` | Multi-repository definitions | Yes (for multi-repo mode) | TOML (preferred), JSON |
| `.env` | Environment variables | No | Environment |
| `logging.toml` / `logging.json` | Advanced logging configuration | No | TOML, JSON |

### Configuration Search Order

Configuration files are searched in the following priority order:

1. `mcp-jujutsu.toml` (current directory)
2. `.mcp-jujutsu.toml` (current directory)  
3. `config.toml` (current directory)
4. `~/.config/mcp-jujutsu/config.toml`
5. JSON equivalents of the above paths

The first configuration file found will be used.

## Server Configuration

The main configuration file controls server behavior and analysis settings. You can use either TOML or JSON format.

### Basic Structure

**TOML Format (Recommended):**

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
path = "."
repos_dir = "."
config_path = "./repos.toml"

[ai]
endpoint = "https://api.openai.com/v1/chat/completions"
api_key = ""
model = "gpt-4"
```

**JSON Format (Legacy):**

```json
{
  "server": {
    "port": 8080,
    "host": "localhost",
    "mode": "single",
    "timeout": 300,
    "maxRequestSize": "10MB"
  },
  "analysis": {
    // Analysis settings
  },
  "logging": {
    // Logging settings
  }
}
```

### Server Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | number | 8080 | Server port |
| `host` | string | "localhost" | Server host |
| `mode` | string | "single" | Server mode: "single" or "multi" |
| `timeout` | number | 300 | Request timeout in seconds |
| `maxRequestSize` | string | "10MB" | Maximum request size |
| `workers` | number | CPU count | Number of worker threads |
| `enableCors` | boolean | true | Enable CORS support |
| `corsOrigins` | array | ["*"] | Allowed CORS origins |

### Advanced Server Configuration

```json
{
  "server": {
    "port": 8080,
    "host": "0.0.0.0",
    "mode": "multi",
    "timeout": 600,
    "maxRequestSize": "50MB",
    "workers": 4,
    "enableCors": true,
    "corsOrigins": ["http://localhost:3000", "https://myapp.com"],
    "ssl": {
      "enabled": true,
      "cert": "/path/to/cert.pem",
      "key": "/path/to/key.pem"
    },
    "rateLimit": {
      "enabled": true,
      "maxRequests": 100,
      "windowSeconds": 60
    }
  }
}
```

## Analysis Configuration

Configure how MCP-Jujutsu analyzes and divides commits.

### Basic Analysis Settings

```json
{
  "analysis": {
    "defaultStrategy": "semantic",
    "defaultCommitSize": "balanced",
    "minConfidence": 0.7,
    "maxCommits": 10,
    "enableCache": true,
    "cacheExpiry": 3600
  }
}
```

### Analysis Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `defaultStrategy` | string | "balanced" | Default division strategy |
| `defaultCommitSize` | string | "balanced" | Default commit size preference |
| `minConfidence` | float | 0.7 | Minimum confidence for proposals |
| `maxCommits` | number | 10 | Maximum commits per division |
| `enableCache` | boolean | true | Enable analysis caching |
| `cacheExpiry` | number | 3600 | Cache expiry in seconds |
| `ignorePatterns` | array | [] | File patterns to ignore |
| `semanticWeights` | object | {} | Weights for semantic analysis |

### Advanced Analysis Configuration

```json
{
  "analysis": {
    "defaultStrategy": "semantic",
    "defaultCommitSize": "balanced",
    "minConfidence": 0.8,
    "maxCommits": 15,
    "enableCache": true,
    "cacheExpiry": 7200,
    "ignorePatterns": [
      "*.log",
      "*.tmp",
      "node_modules/**",
      "vendor/**"
    ],
    "semanticWeights": {
      "functionality": 0.4,
      "fileType": 0.2,
      "directory": 0.2,
      "dependencies": 0.2
    },
    "strategies": {
      "semantic": {
        "minGroupSize": 2,
        "maxGroupSize": 20,
        "similarityThreshold": 0.6
      },
      "filetype": {
        "groupRelated": true,
        "priorities": ["nim", "js", "ts", "py"]
      },
      "directory": {
        "maxDepth": 3,
        "groupTests": true
      }
    }
  }
}
```

## Multi-Repository Configuration

Configure multiple repositories for coordinated analysis and splitting.

### Repository Definition (`repos.json`)

```json
{
  "defaultBranch": "main",
  "repositories": [
    {
      "name": "frontend",
      "path": "./repos/frontend",
      "branch": "main",
      "dependencies": ["shared", "api-client"],
      "priority": 1
    },
    {
      "name": "backend",
      "path": "./repos/backend",
      "branch": "main",
      "dependencies": ["shared", "database"],
      "priority": 1
    },
    {
      "name": "shared",
      "path": "./repos/shared",
      "branch": "main",
      "dependencies": [],
      "priority": 2
    }
  ],
  "dependencyRules": {
    "allowCycles": false,
    "requireExplicit": true
  }
}
```

### Repository Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `name` | string | Yes | Repository identifier |
| `path` | string | Yes | Path to repository |
| `branch` | string | No | Default branch (inherits global) |
| `dependencies` | array | No | List of dependency names |
| `priority` | number | No | Processing priority (1-10) |
| `ignore` | boolean | No | Ignore this repository |
| `config` | object | No | Repository-specific config |

### Advanced Multi-Repository Configuration

```json
{
  "defaultBranch": "main",
  "parallelProcessing": true,
  "maxParallel": 4,
  "repositories": [
    {
      "name": "monorepo",
      "path": "./repos/monorepo",
      "branch": "develop",
      "submodules": [
        {
          "name": "frontend",
          "path": "packages/frontend",
          "dependencies": ["shared"]
        },
        {
          "name": "backend",
          "path": "packages/backend",
          "dependencies": ["shared", "database"]
        }
      ],
      "config": {
        "strategy": "directory",
        "ignorePatterns": ["*.test.js"]
      }
    }
  ],
  "dependencyRules": {
    "allowCycles": false,
    "requireExplicit": true,
    "transitiveAnalysis": true,
    "customRules": [
      {
        "from": "frontend",
        "to": "backend",
        "type": "forbidden",
        "reason": "Frontend should not directly depend on backend"
      }
    ]
  },
  "coordination": {
    "groupRelatedChanges": true,
    "preserveAtomicity": true,
    "rollbackOnFailure": true
  }
}
```

## Logging Configuration

Configure logging behavior for debugging and monitoring.

### Basic Logging Settings

```json
{
  "logging": {
    "level": "info",
    "format": "json",
    "output": "stdout"
  }
}
```

### Logging Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | string | "info" | Log level: debug, info, warn, error |
| `format` | string | "json" | Output format: json, plain, pretty |
| `output` | string | "stdout" | Output destination |
| `file` | string | - | Log file path |
| `maxSize` | string | "100MB" | Maximum log file size |
| `maxFiles` | number | 5 | Maximum number of log files |
| `timestamps` | boolean | true | Include timestamps |

### Advanced Logging Configuration

```json
{
  "logging": {
    "level": "debug",
    "format": "json",
    "output": "both",
    "file": "./logs/mcp-jujutsu.log",
    "maxSize": "50MB",
    "maxFiles": 10,
    "timestamps": true,
    "prettyPrint": false,
    "categories": {
      "server": "info",
      "analysis": "debug",
      "repository": "warn",
      "mcp": "info"
    },
    "filters": [
      {
        "category": "analysis",
        "level": "debug",
        "pattern": "semantic.*"
      }
    ]
  }
}
```

## Environment Variables

MCP-Jujutsu supports configuration through environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_PORT` | Server port | 8080 |
| `MCP_HOST` | Server host | localhost |
| `MCP_MODE` | Server mode (single/multi) | single |
| `MCP_CONFIG` | Config file path | ./config.json |
| `MCP_REPOS_CONFIG` | Repos config path | ./repos.json |
| `MCP_LOG_LEVEL` | Log level | info |
| `MCP_CACHE_DIR` | Cache directory | ./.cache |
| `MCP_TIMEOUT` | Request timeout (seconds) | 300 |
| `JJ_PATH` | Path to jj executable | jj |

### Using Environment Variables

```bash
# .env file
MCP_PORT=9000
MCP_MODE=multi
MCP_LOG_LEVEL=debug
MCP_CACHE_DIR=/tmp/mcp-cache
JJ_PATH=/usr/local/bin/jj
```

```bash
# Or export directly
export MCP_PORT=9000
export MCP_MODE=multi
./scripts/start-server.sh
```

## Configuration Examples

### Development Configuration

```json
{
  "server": {
    "port": 8080,
    "host": "localhost",
    "mode": "single",
    "timeout": 600
  },
  "analysis": {
    "defaultStrategy": "semantic",
    "minConfidence": 0.6,
    "maxCommits": 20,
    "enableCache": false
  },
  "logging": {
    "level": "debug",
    "format": "pretty",
    "output": "stdout"
  }
}
```

### Production Configuration

```json
{
  "server": {
    "port": 443,
    "host": "0.0.0.0",
    "mode": "multi",
    "timeout": 300,
    "workers": 8,
    "ssl": {
      "enabled": true,
      "cert": "/etc/ssl/certs/server.crt",
      "key": "/etc/ssl/private/server.key"
    },
    "rateLimit": {
      "enabled": true,
      "maxRequests": 1000,
      "windowSeconds": 3600
    }
  },
  "analysis": {
    "defaultStrategy": "semantic",
    "minConfidence": 0.8,
    "maxCommits": 10,
    "enableCache": true,
    "cacheExpiry": 86400
  },
  "logging": {
    "level": "info",
    "format": "json",
    "output": "file",
    "file": "/var/log/mcp-jujutsu/server.log",
    "maxSize": "100MB",
    "maxFiles": 30
  }
}
```

### CI/CD Configuration

```json
{
  "server": {
    "port": 8080,
    "mode": "single",
    "timeout": 120
  },
  "analysis": {
    "defaultStrategy": "balanced",
    "minConfidence": 0.9,
    "maxCommits": 5,
    "enableCache": false
  },
  "logging": {
    "level": "warn",
    "format": "json",
    "output": "stdout",
    "categories": {
      "server": "error",
      "analysis": "warn"
    }
  }
}
```

## Best Practices

### 1. Environment-Specific Configurations

Create separate configuration files for different environments:

```
configs/
├── development.json
├── staging.json
├── production.json
└── test.json
```

Load using environment variable:
```bash
MCP_CONFIG=./configs/production.json ./scripts/start-server.sh
```

### 2. Secure Sensitive Data

Never commit sensitive data. Use environment variables:

```json
{
  "server": {
    "ssl": {
      "cert": "${SSL_CERT_PATH}",
      "key": "${SSL_KEY_PATH}"
    }
  }
}
```

### 3. Validate Configurations

Use the built-in validation:

```bash
mcp-jujutsu validate-config ./config.json
```

### 4. Monitor Performance

Enable detailed logging in development:

```json
{
  "logging": {
    "level": "debug",
    "categories": {
      "analysis": "debug",
      "performance": "info"
    }
  }
}
```

### 5. Optimize for Your Workflow

Adjust analysis settings based on your repository:

- Large commits: Increase `maxCommits`
- Complex codebases: Use `semantic` strategy
- Monorepos: Use `directory` strategy
- Fast iteration: Lower `minConfidence`

### 6. Cache Management

Configure caching based on your needs:

```json
{
  "analysis": {
    "enableCache": true,
    "cacheExpiry": 3600,
    "cacheDir": "/tmp/mcp-cache",
    "maxCacheSize": "1GB"
  }
}
```

### 7. Repository-Specific Overrides

Use repository-specific configurations:

```json
{
  "repositories": [
    {
      "name": "legacy-code",
      "config": {
        "strategy": "directory",
        "minConfidence": 0.6,
        "ignorePatterns": ["*.generated.js"]
      }
    }
  ]
}
```