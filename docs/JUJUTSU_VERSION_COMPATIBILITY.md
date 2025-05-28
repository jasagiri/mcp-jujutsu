# Jujutsu Version Compatibility

MCP-Jujutsu supports multiple versions of Jujutsu through automatic version detection and command adaptation.

## Supported Versions

| Jujutsu Version | Status | Notes |
|----------------|--------|-------|
| 0.28.x+ | ✅ Full Support | Auto-tracking, `@-` syntax |
| 0.27.x | ✅ Full Support | Manual add, `@~` syntax |
| 0.26.x | ✅ Full Support | Different init command |
| 0.25.x | ⚠️ Limited | Missing some features |
| < 0.25 | ❌ Not supported | Too many breaking changes |

## Version-Specific Features

### Jujutsu 0.28.0+
- **Auto-tracking**: Files are automatically tracked without `jj add`
- **New revset syntax**: Uses `@-` instead of `@~` for parent commits
- **Template shortcuts**: Supports `commit_id.short()` syntax
- **Concurrent operations**: Better support for parallel operations

### Jujutsu 0.27.x
- **Manual tracking**: Requires `jj add` for new files
- **Old revset syntax**: Uses `@~` for parent commits
- **Template support**: Full template syntax support
- **Workspace commands**: Full workspace support

### Jujutsu 0.26.x and earlier
- **Different init**: Uses `jj init --git` instead of `jj git init`
- **Basic features**: Core functionality with some limitations

## How It Works

### 1. Version Detection
```nim
let version = await getJujutsuVersion()
# Automatically detects: jj 0.28.2 -> Version(0, 28, 2)
```

### 2. Command Adaptation
```nim
let commands = await getJujutsuCommands()
let initCmd = buildInitCommand(commands)
# Returns version-appropriate command:
# v0.28+: "jj git init"
# v0.26-: "jj init --git"
```

### 3. Capability Detection
```nim
let capabilities = getJujutsuCapabilities(version)
if not capabilities.hasAutoTracking:
  # Use manual jj add commands
```

## Usage Examples

### Creating a Repository
```nim
# Version-aware repository initialization
let repo = await initJujutsuRepo(path, initIfNotExists = true)
# Automatically uses the correct init command for detected version
```

### Creating Commits
```nim
# Version-aware commit creation
let commitId = await repo.createCommit("Add new feature", @[
  ("file1.txt", "content1"),
  ("file2.txt", "content2")
])
# Automatically handles:
# - File tracking (auto vs manual)
# - Revset syntax (@- vs @~)
# - Template syntax variations
```

### Getting Diffs
```nim
# Version-aware diff retrieval
let diff = await repo.getDiffForCommitRange("@-..@")
# Automatically translates revsets for older versions
```

## Configuration

### Manual Version Override
```nim
# For testing or specific environments
import jujutsu_version

# Override detected version
let customCommands = getCommandsForVersion(parseVersion("0.27.0"))
```

### Cache Management
```nim
# Clear version cache if needed (e.g., after Jujutsu upgrade)
clearVersionCache()
```

## Troubleshooting

### Version Detection Issues
If version detection fails, the system falls back to v0.28.0 behavior. Check:
1. Is `jj --version` working?
2. Is Jujutsu in your PATH?
3. Check logs for version detection errors

### Command Failures
If commands fail unexpectedly:
1. Check if you're using an unsupported version
2. Verify the detected version is correct
3. Try clearing the version cache
4. Check if your Jujutsu installation is complete

### Performance
Version detection is cached after the first call. To force re-detection:
```nim
clearVersionCache()
let newVersion = await getJujutsuVersion()
```

## Adding New Version Support

To add support for a new Jujutsu version:

1. Update `VERSION_CONFIGS` in `jujutsu_version.nim`
2. Add new capabilities to `getJujutsuCapabilities`
3. Update command builders if needed
4. Add tests for the new version

Example:
```nim
# Add to VERSION_CONFIGS
(version: "0.29.0", config: JujutsuCommands(
  initCommand: "jj git init",
  addCommand: "",
  parentRevset: "@-",
  diffCommand: "jj diff --new-flag",
  logTemplate: "-T"
))
```

## Best Practices

1. **Always use version-aware functions** instead of hardcoded commands
2. **Check capabilities** before using advanced features
3. **Handle graceful fallbacks** for unsupported operations
4. **Test with multiple versions** if possible
5. **Monitor logs** for version detection and adaptation messages

## Migration Guide

### From hardcoded commands:
```nim
# Old way (brittle)
let cmd = "jj git init"

# New way (version-aware)
let commands = await getJujutsuCommands()
let cmd = buildInitCommand(commands)
```

### From manual revset building:
```nim
# Old way
let revset = "@~..@"

# New way
let commands = await getJujutsuCommands()
let revset = buildRangeRevset(commands)
```