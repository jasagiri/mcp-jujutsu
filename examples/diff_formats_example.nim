## Example: Using different diff formats with mcp-jujutsu
##
## This example demonstrates how to use the new diff format functionality
## to get diffs in various formats including native, git, JSON, Markdown, HTML,
## and custom templates.

import std/[asyncdispatch, json, os, strformat]
import ../src/core/repository/[jujutsu, diff_formats]
import ../src/core/config/config

proc displayDiffExample(repo: JujutsuRepo, commitRange: string) {.async.} =
  echo &"\n=== Diff Examples for {commitRange} ===\n"
  
  # 1. Git format (default)
  echo "1. Git Format:"
  echo "-" * 50
  let gitConfig = DiffFormatConfig(
    format: Git,
    colorize: false,
    contextLines: 3,
    showLineNumbers: false
  )
  let gitDiff = await repo.getDiffForCommitRange(commitRange, gitConfig)
  if gitDiff.files.len > 0:
    echo gitDiff.files[0].diff[0..min(500, gitDiff.files[0].diff.len-1)]
    echo "..."
  
  # 2. Native Jujutsu format
  echo "\n2. Native Format:"
  echo "-" * 50
  let nativeConfig = DiffFormatConfig(
    format: Native,
    colorize: false,
    contextLines: 3,
    showLineNumbers: false
  )
  let nativeDiff = await repo.getDiffForCommitRange(commitRange, nativeConfig)
  if nativeDiff.files.len > 0:
    echo nativeDiff.files[0].diff[0..min(500, nativeDiff.files[0].diff.len-1)]
    echo "..."
  
  # 3. JSON format
  echo "\n3. JSON Format:"
  echo "-" * 50
  let jsonConfig = DiffFormatConfig(
    format: Json,
    colorize: false,
    contextLines: 3,
    showLineNumbers: false
  )
  let jsonDiff = await repo.getDiffForCommitRange(commitRange, jsonConfig)
  if jsonDiff.files.len > 0:
    # The diff field contains the formatted JSON for all files
    let jsonData = parseJson(jsonDiff.files[0].diff)
    echo jsonData.pretty()
  
  # 4. Markdown format
  echo "\n4. Markdown Format:"
  echo "-" * 50
  let markdownConfig = DiffFormatConfig(
    format: Markdown,
    colorize: false,
    contextLines: 3,
    showLineNumbers: true
  )
  let markdownDiff = await repo.getDiffForCommitRange(commitRange, markdownConfig)
  if markdownDiff.files.len > 0:
    echo markdownDiff.files[0].diff[0..min(500, markdownDiff.files[0].diff.len-1)]
    echo "..."
  
  # 5. HTML format (just show a snippet)
  echo "\n5. HTML Format (snippet):"
  echo "-" * 50
  let htmlConfig = DiffFormatConfig(
    format: Html,
    colorize: false,
    contextLines: 3,
    showLineNumbers: true
  )
  let htmlDiff = await repo.getDiffForCommitRange(commitRange, htmlConfig)
  if htmlDiff.files.len > 0:
    echo htmlDiff.files[0].diff[0..min(300, htmlDiff.files[0].diff.len-1)]
    echo "..."
  
  # 6. Custom template
  echo "\n6. Custom Template Format:"
  echo "-" * 50
  let customTemplate = DiffTemplate(
    name: "simple",
    description: "Simple custom format",
    fileHeader: "\n📄 File: $path ($changeType)",
    hunkHeader: "\n  📍 Lines $oldStart-$oldCount → $newStart-$newCount",
    addLine: "    ✅ $content",
    deleteLine: "    ❌ $content",
    contextLine: "       $content",
    footer: "\n  📊 Stats: +$additions -$deletions\n"
  )
  
  let customConfig = DiffFormatConfig(
    format: Custom,
    colorize: false,
    contextLines: 2,
    showLineNumbers: false,
    template: some(customTemplate)
  )
  let customDiff = await repo.getDiffForCommitRange(commitRange, customConfig)
  if customDiff.files.len > 0:
    echo customDiff.files[0].diff[0..min(500, customDiff.files[0].diff.len-1)]
    echo "..."
  
  # Show statistics
  echo &"\n=== Statistics for {commitRange} ==="
  echo &"Files changed: {gitDiff.stats[\"files\"].getInt()}"
  echo &"Additions: {gitDiff.stats[\"additions\"].getInt()}"
  echo &"Deletions: {gitDiff.stats[\"deletions\"].getInt()}"

proc demonstrateConfigBasedFormatting(repo: JujutsuRepo, config: Config) {.async.} =
  echo "\n=== Using Configuration-based Formatting ===\n"
  
  # Create format config from application config
  let formatConfig = createDiffFormatConfig(config)
  
  echo &"Configured format: {config.diffFormat}"
  echo &"Colorize: {config.diffColorize}"
  echo &"Context lines: {config.diffContextLines}"
  echo &"Show line numbers: {config.diffShowLineNumbers}"
  
  if config.diffFormat == "custom" and config.diffTemplatePath != "":
    echo &"Custom template: {config.diffTemplatePath}"
  
  let diff = await repo.getDiffForCommitRange("@", formatConfig)
  
  if diff.files.len > 0:
    echo "\nFormatted output:"
    echo "-" * 50
    echo diff.files[0].diff[0..min(500, diff.files[0].diff.len-1)]
    echo "..."

proc main() {.async.} =
  # Initialize repository
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  echo &"Initializing repository at: {repoPath}"
  let repo = await initJujutsuRepo(repoPath)
  
  # Example 1: Show different formats for the current commit
  await displayDiffExample(repo, "@")
  
  # Example 2: Show how to use configuration-based formatting
  var config = newDefaultConfig()
  config.diffFormat = "markdown"
  config.diffShowLineNumbers = true
  config.diffContextLines = 5
  
  await demonstrateConfigBasedFormatting(repo, config)
  
  # Example 3: Save and load a custom template
  echo "\n=== Custom Template File Example ===\n"
  
  let templatePath = "example_template.json"
  let exampleTemplate = DiffTemplate(
    name: "code-review",
    description: "Format optimized for code reviews",
    fileHeader: "\n========================================\nFile: $path\nChange Type: $changeType\n========================================",
    hunkHeader: "\nSection: Lines $oldStart-$oldCount → $newStart-$newCount",
    addLine: "  [ADD] $content",
    deleteLine: "  [DEL] $content",
    contextLine: "       $content",
    footer: "\nSummary: +$additions lines, -$deletions lines\n"
  )
  
  saveTemplate(exampleTemplate, templatePath)
  echo &"Saved template to: {templatePath}"
  
  # Load and use the template
  let loadedTemplate = loadTemplate(templatePath)
  let templateConfig = DiffFormatConfig(
    format: Custom,
    colorize: false,
    contextLines: 3,
    showLineNumbers: false,
    template: some(loadedTemplate)
  )
  
  let templateDiff = await repo.getDiffForCommitRange("@", templateConfig)
  if templateDiff.files.len > 0:
    echo "\nUsing loaded template:"
    echo "-" * 50
    echo templateDiff.files[0].diff[0..min(500, templateDiff.files[0].diff.len-1)]
  
  # Clean up
  removeFile(templatePath)
  
  echo "\n=== Example Complete ==="

when isMainModule:
  waitFor main()