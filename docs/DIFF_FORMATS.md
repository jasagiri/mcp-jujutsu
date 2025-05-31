# Diff Formats Documentation

MCP-Jujutsu now supports multiple diff output formats, allowing you to choose the most appropriate format for your use case. This document describes the available formats and how to use them.

## Supported Formats

### 1. Native Format
Jujutsu's native diff format, which provides a clean, human-readable output.

```
Modified src/test.nim
   First line
   Second line
   +
    +Added line
   Third line
```

### 2. Git Format (Default)
Standard Git unified diff format, compatible with most tools and IDEs.

```diff
diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,3 +1,4 @@
 import std/strutils
 
+# New comment
 proc hello() =
```

### 3. JSON Format
Structured JSON output for programmatic processing.

```json
{
  "files": [
    {
      "path": "test.nim",
      "changeType": "modify",
      "additions": 2,
      "deletions": 1,
      "hunks": [
        {
          "oldStart": 1,
          "oldCount": 3,
          "newStart": 1,
          "newCount": 4,
          "lines": [...]
        }
      ]
    }
  ]
}
```

### 4. Markdown Format
Markdown-formatted diffs suitable for documentation and GitHub comments.

```markdown
### test.nim

```diff
@@ -1,3 +1,4 @@ proc test()
 import std/strutils
 
+# New comment
 proc hello() =
```
```

### 5. HTML Format
HTML output with styling, perfect for web-based diff viewers.

```html
<div class="diff-file">
  <div class="diff-header">test.nim</div>
  <table class="diff-table">
    <tr class="added">
      <td class="line-num"></td>
      <td class="line-num">2</td>
      <td class="line-content">+ # New comment</td>
    </tr>
  </table>
</div>
```

### 6. Custom Format
Use your own template to create custom diff formats.

## Configuration

### Using Configuration File

Add a `[diff]` section to your `mcp-jujutsu.toml`:

```toml
[diff]
# Diff output format: "native", "git", "json", "markdown", "html", "custom"
format = "markdown"

# Enable colored diff output
colorize = false

# Number of context lines in diffs
context_lines = 3

# Show line numbers in diff output
show_line_numbers = true

# Path to custom diff template file (only used when format = "custom")
template_path = "templates/my-template.json"
```

### Command Line Options

```bash
# Set diff format
mcp-jujutsu --diff-format=json

# Enable colored output
mcp-jujutsu --diff-colorize

# Set context lines
mcp-jujutsu --diff-context=5

# Show line numbers
mcp-jujutsu --diff-line-numbers

# Use custom template
mcp-jujutsu --diff-format=custom --diff-template=templates/review.json
```

## Custom Templates

Create custom diff formats using template files. Templates are JSON files that define how each part of the diff should be formatted.

### Template Structure

```json
{
  "name": "my-template",
  "description": "My custom diff format",
  "fileHeader": "=== $path ($changeType) ===",
  "hunkHeader": "Changes from $oldStart to $newStart:",
  "addLine": " + $content",
  "deleteLine": " - $content",
  "contextLine": "   $content",
  "footer": "\nStats: +$additions -$deletions"
}
```

### Available Variables

- `$path` - File path
- `$oldPath` - Old file path (for renames)
- `$changeType` - Type of change (add, modify, delete, rename)
- `$oldStart`, `$oldCount` - Old hunk line numbers
- `$newStart`, `$newCount` - New hunk line numbers
- `$header` - Hunk header text
- `$content` - Line content
- `$oldLineNo`, `$newLineNo` - Line numbers
- `$additions`, `$deletions` - File statistics

### Example Templates

#### Simple Text Format
```json
{
  "name": "simple",
  "description": "Simple text-based diff format",
  "fileHeader": "\n=== File: $path ===",
  "hunkHeader": "\n--- Changes at lines $oldStart-$oldCount -> $newStart-$newCount ---",
  "addLine": " + $content",
  "deleteLine": " - $content",
  "contextLine": "   $content",
  "footer": ""
}
```

#### Code Review Format
```json
{
  "name": "review",
  "description": "Code review friendly format",
  "fileHeader": "\n📁 $path ($changeType)\n",
  "hunkHeader": "\n📍 Lines $oldStart-$oldCount → $newStart-$newCount",
  "addLine": "  ✅ $content",
  "deleteLine": "  ❌ $content",
  "contextLine": "     $content",
  "footer": "\n  📊 +$additions -$deletions\n"
}
```

#### Compact Format
```json
{
  "name": "compact",
  "description": "Compact diff format without context lines",
  "fileHeader": "$path:",
  "hunkHeader": "",
  "addLine": "+$newLineNo: $content",
  "deleteLine": "-$oldLineNo: $content",
  "contextLine": "",
  "footer": ""
}
```

## Programmatic Usage

### Using DiffFormatConfig

```nim
import mcp_jujutsu/core/repository/[jujutsu, diff_formats]

# Configure diff format
let config = DiffFormatConfig(
  format: Markdown,
  colorize: false,
  contextLines: 3,
  showLineNumbers: true
)

# Get formatted diff
let diff = await repo.getDiffForCommitRange("@", config)
```

### Using Custom Templates

```nim
# Load template from file
let template = loadTemplate("templates/review.json")

# Or create template in code
let template = DiffTemplate(
  name: "inline",
  fileHeader: "File: $path",
  addLine: "+ $content",
  # ... other fields
)

# Use with config
let config = DiffFormatConfig(
  format: Custom,
  template: some(template)
)
```

### Creating Config from Application Settings

```nim
import mcp_jujutsu/core/config/config

# Load application config
let appConfig = parseCommandLine()

# Create diff format config
let formatConfig = createDiffFormatConfig(appConfig)

# Use with repository
let diff = await repo.getDiffForCommitRange("@", formatConfig)
```

## Use Cases

### 1. IDE Integration
Use JSON format for structured data that IDEs can parse and display with their own UI.

### 2. Documentation
Use Markdown format for diffs that will be included in documentation or GitHub issues.

### 3. Web Applications
Use HTML format for web-based diff viewers with built-in styling.

### 4. CLI Tools
Use Native or Git format for command-line tools and terminal output.

### 5. Custom Workflows
Create custom templates for specific workflows like code reviews, changelogs, or reports.

## Performance Considerations

- **Native format** is fastest as it requires no additional parsing
- **Git format** is efficient and widely compatible
- **JSON format** adds parsing overhead but provides structured data
- **Markdown/HTML formats** are best for human consumption, not large diffs
- **Custom templates** performance depends on template complexity

## Troubleshooting

### Template Not Loading
- Ensure the template file path is correct
- Verify the JSON syntax is valid
- Check file permissions

### Missing Variables in Output
- Not all variables are available in all contexts
- Line numbers are only available when `showLineNumbers` is true
- Statistics are calculated after parsing, not available in line templates

### Format Not Recognized
- Check spelling of format name (case-insensitive)
- Ensure custom template is specified when using "custom" format
- Verify configuration file syntax