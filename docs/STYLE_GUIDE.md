# Documentation Style Guide

This guide ensures consistency across all MCP-Jujutsu documentation.

## General Principles

1. **Clarity First** - Write for developers who are new to the project
2. **Examples Everywhere** - Include code examples for every concept
3. **Bilingual When Needed** - Provide Japanese translations for key documents
4. **Keep It Current** - Update docs alongside code changes

## File Naming

- Documentation files: `UPPER_SNAKE_CASE.md` (e.g., `API_REFERENCE.md`)
- Example files: `lower_snake_case.nim` (e.g., `basic_usage.nim`)
- Use descriptive names that indicate content

## Document Structure

### Required Sections

Every documentation file should include:

```markdown
# Document Title

Brief description of what this document covers.

## Table of Contents (for long documents)

- [Section 1](#section-1)
- [Section 2](#section-2)

## Main Content

### Subsections as needed
```

### API Documentation Format

```markdown
### toolName

Brief description of what the tool does.

**Parameters:**

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| param1 | string | Yes | - | What this parameter does |
| param2 | number | No | 10 | Another parameter |

**Response:**

```json
{
  "field1": "value",
  "field2": 123
}
```

**Example:**

```bash
mcp-client call toolName '{"param1": "value"}'
```
```

## Code Examples

### Nim Code

```nim
## Module documentation header
##
## Detailed description of what this module does.

import std/[asyncdispatch, json]

type
  MyType* = object
    ## Type documentation
    field*: string  ## Field documentation

proc myProc*(param: string): string =
  ## Procedure documentation.
  ##
  ## Parameters:
  ##   - param: Description of parameter
  ##
  ## Returns: Description of return value
  result = "example"
```

### Command Line Examples

Always show both the command and expected output:

```bash
# Command
nimble build

# Expected output
Compiling mcp_jujutsu...
Success: mcp_jujutsu built successfully
```

## Language Guidelines

### English Documentation

- Use present tense ("runs" not "will run")
- Use active voice ("The server processes requests" not "Requests are processed by the server")
- Be concise but complete
- Define acronyms on first use

### Japanese Documentation

- Use 丁寧語 (polite form) for general documentation
- Technical terms can remain in English with Japanese explanation
- Follow standard Japanese technical writing conventions

### Bilingual Format

For bilingual documents, use this format:

```markdown
## Section Title / セクションタイトル

English content goes here.

日本語の内容はここに記載します。
```

Or side-by-side for short content:

```markdown
- Feature / 機能: Description / 説明
```

## Common Patterns

### Feature Lists

```markdown
- **Feature Name**: Brief description of what it does
- **Another Feature**: More description with `code` examples
```

### Configuration Examples

```json
{
  "setting": "value",  // Comment explaining the setting
  "nested": {
    "option": true   // Another explanation
  }
}
```

### Troubleshooting Sections

```markdown
### Problem: Brief problem description

**Symptoms:**
- What the user sees
- Error messages

**Solution:**
```bash
# Commands to fix the issue
```

**Explanation:**
Why this fixes the problem.
```

## Markdown Conventions

- Use `##` for main sections, `###` for subsections
- Use backticks for inline code: `nimble build`
- Use triple backticks with language hints for code blocks
- Use tables for structured data
- Use `**bold**` for emphasis, not CAPS
- Link to other docs: `[API Reference](./API_REFERENCE.md)`

## Version Documentation

When documenting version-specific features:

```markdown
### Feature Name (v0.2.0+)

This feature requires version 0.2.0 or higher.
```

## Maintenance

### When to Update

Update documentation when:
- Adding new features
- Changing APIs
- Fixing bugs that affect usage
- Improving examples based on user feedback

### Review Checklist

Before committing documentation:
- [ ] Spell check completed
- [ ] Code examples tested
- [ ] Links verified
- [ ] Formatting consistent
- [ ] Table of contents updated (if applicable)

## Tools and Resources

- Markdown preview: Use VS Code or similar
- Spell check: `aspell` or editor built-in
- Link checker: `markdown-link-check`
- Format checker: `markdownlint`

## Examples of Good Documentation

See these files for reference:
- `API_REFERENCE.md` - Comprehensive API documentation
- `INSTALLATION.md` - Step-by-step guide with platform variations
- `examples/basic_usage.nim` - Well-commented code examples