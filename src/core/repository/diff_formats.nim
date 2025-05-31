## Diff formats and template system module
##
## This module provides support for multiple diff output formats and a template system
## for customizable diff presentation.

import std/[strutils, tables, json, options, re, strformat]
import ../logging/logger

type
  DiffFormat* = enum
    ## Supported diff output formats
    Native      ## Jujutsu's native diff format
    Git         ## Git-style unified diff format  
    Json        ## JSON structured format
    Markdown    ## Markdown formatted diff
    Html        ## HTML formatted diff
    Custom      ## Custom template-based format

  DiffLine* = object
    ## Represents a single line in a diff
    lineType*: char      # '+', '-', ' ', '@'
    content*: string
    oldLineNo*: Option[int]
    newLineNo*: Option[int]

  DiffHunk* = object
    ## Represents a hunk (section) of changes
    oldStart*: int
    oldCount*: int
    newStart*: int  
    newCount*: int
    header*: string
    lines*: seq[DiffLine]

  ParsedFileDiff* = object
    ## Parsed representation of a file diff
    path*: string
    oldPath*: string     # For renames
    changeType*: string  # "add", "modify", "delete", "rename", "copy"
    hunks*: seq[DiffHunk]
    isBinary*: bool
    additions*: int
    deletions*: int

  DiffTemplate* = object
    ## Template for custom diff formatting
    name*: string
    description*: string
    fileHeader*: string      # Template for file headers
    hunkHeader*: string      # Template for hunk headers
    addLine*: string         # Template for added lines
    deleteLine*: string      # Template for deleted lines
    contextLine*: string     # Template for context lines
    footer*: string          # Template for diff footer

  DiffFormatConfig* = object
    ## Configuration for diff formatting
    format*: DiffFormat
    colorize*: bool
    contextLines*: int
    showLineNumbers*: bool
    diffTemplate*: Option[DiffTemplate]

# Built-in templates
const
  JSON_TEMPLATE = DiffTemplate(
    name: "json",
    description: "JSON structured output",
    fileHeader: "",
    hunkHeader: "", 
    addLine: "",
    deleteLine: "",
    contextLine: "",
    footer: ""
  )

  MARKDOWN_TEMPLATE = DiffTemplate(
    name: "markdown", 
    description: "Markdown formatted diff",
    fileHeader: "### $path\n\n```diff",
    hunkHeader: "@@ -$oldStart,$oldCount +$newStart,$newCount @@ $header",
    addLine: "+ $content",
    deleteLine: "- $content", 
    contextLine: "  $content",
    footer: "```\n"
  )

  HTML_TEMPLATE = DiffTemplate(
    name: "html",
    description: "HTML formatted diff",
    fileHeader: """<div class="diff-file">
  <div class="diff-header">$path</div>
  <table class="diff-table">""",
    hunkHeader: """<tr class="hunk-header"><td colspan="3">@@ -$oldStart,$oldCount +$newStart,$newCount @@ $header</td></tr>""",
    addLine: """<tr class="added"><td class="line-num">$oldLineNo</td><td class="line-num">$newLineNo</td><td class="line-content">+ $content</td></tr>""",
    deleteLine: """<tr class="deleted"><td class="line-num">$oldLineNo</td><td class="line-num">$newLineNo</td><td class="line-content">- $content</td></tr>""",
    contextLine: """<tr class="context"><td class="line-num">$oldLineNo</td><td class="line-num">$newLineNo</td><td class="line-content">  $content</td></tr>""",
    footer: """  </table>
</div>"""
  )

var builtinTemplates* = {
  "json": JSON_TEMPLATE,
  "markdown": MARKDOWN_TEMPLATE,
  "html": HTML_TEMPLATE
}.toTable

proc parseGitDiff*(diffContent: string): seq[ParsedFileDiff] =
  ## Parse git-style diff output into structured format
  result = @[]
  
  var currentFile: Option[ParsedFileDiff] = none(ParsedFileDiff)
  var currentHunk: Option[DiffHunk] = none(DiffHunk)
  var oldLineNo = 0
  var newLineNo = 0
  
  for line in diffContent.splitLines():
    if line.startsWith("diff --git"):
      # Save previous file if exists
      if currentHunk.isSome and currentFile.isSome:
        var file = currentFile.get
        file.hunks.add(currentHunk.get)
        currentFile = some(file)
      if currentFile.isSome:
        result.add(currentFile.get)
      
      # Start new file
      let parts = line.split(' ')
      if parts.len >= 4:
        let path = parts[3].replace("b/", "")
        currentFile = some(ParsedFileDiff(
          path: path,
          oldPath: parts[2].replace("a/", ""),
          changeType: "modify",
          hunks: @[],
          isBinary: false,
          additions: 0,
          deletions: 0
        ))
        currentHunk = none(DiffHunk)
    
    elif line.startsWith("new file"):
      if currentFile.isSome:
        var file = currentFile.get
        file.changeType = "add"
        currentFile = some(file)
    
    elif line.startsWith("deleted file"):
      if currentFile.isSome:
        var file = currentFile.get
        file.changeType = "delete"
        currentFile = some(file)
    
    elif line.startsWith("rename from"):
      if currentFile.isSome:
        var file = currentFile.get
        file.changeType = "rename"
        file.oldPath = line.replace("rename from ", "")
        currentFile = some(file)
    
    elif line.startsWith("Binary files"):
      if currentFile.isSome:
        var file = currentFile.get
        file.isBinary = true
        currentFile = some(file)
    
    elif line.startsWith("@@"):
      # Save previous hunk if exists
      if currentHunk.isSome and currentFile.isSome:
        var file = currentFile.get
        file.hunks.add(currentHunk.get)
        currentFile = some(file)
      
      # Parse hunk header: @@ -old_start,old_count +new_start,new_count @@ header
      let hunkPattern = re"@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@(.*)"
      var matches: array[5, string]
      if line.match(hunkPattern, matches):
        let oldStart = parseInt(matches[0])
        let oldCount = if matches[1] == "": 1 else: parseInt(matches[1])
        let newStart = parseInt(matches[2])
        let newCount = if matches[3] == "": 1 else: parseInt(matches[3])
        let header = matches[4].strip()
        
        currentHunk = some(DiffHunk(
          oldStart: oldStart,
          oldCount: oldCount,
          newStart: newStart,
          newCount: newCount,
          header: header,
          lines: @[]
        ))
        
        oldLineNo = oldStart
        newLineNo = newStart
    
    elif currentHunk.isSome and line.len > 0:
      var hunk = currentHunk.get
      let lineType = line[0]
      let content = if line.len > 1: line[1..^1] else: ""
      
      case lineType
      of '+':
        hunk.lines.add(DiffLine(
          lineType: lineType,
          content: content,
          oldLineNo: none(int),
          newLineNo: some(newLineNo)
        ))
        newLineNo += 1
        if currentFile.isSome:
          var file = currentFile.get
          file.additions += 1
          currentFile = some(file)
      
      of '-':
        hunk.lines.add(DiffLine(
          lineType: lineType,
          content: content,
          oldLineNo: some(oldLineNo),
          newLineNo: none(int)
        ))
        oldLineNo += 1
        if currentFile.isSome:
          var file = currentFile.get
          file.deletions += 1
          currentFile = some(file)
      
      of ' ':
        hunk.lines.add(DiffLine(
          lineType: lineType,
          content: content,
          oldLineNo: some(oldLineNo),
          newLineNo: some(newLineNo)
        ))
        oldLineNo += 1
        newLineNo += 1
      
      else:
        discard
      
      currentHunk = some(hunk)
  
  # Add final file and hunk
  if currentHunk.isSome and currentFile.isSome:
    var file = currentFile.get
    file.hunks.add(currentHunk.get)
    currentFile = some(file)
  if currentFile.isSome:
    result.add(currentFile.get)

proc parseNativeDiff*(diffContent: string): seq[ParsedFileDiff] =
  ## Parse Jujutsu's native diff format
  result = @[]
  
  var currentFile: Option[ParsedFileDiff] = none(ParsedFileDiff)
  var currentHunk: Option[DiffHunk] = none(DiffHunk)
  var inDiffSection = false
  
  for line in diffContent.splitLines():
    # Native format uses different markers
    if line.startsWith("Modified ") or line.startsWith("Added ") or 
       line.startsWith("Deleted ") or line.startsWith("Renamed "):
      # Save previous file if exists
      if currentFile.isSome:
        if currentHunk.isSome:
          var file = currentFile.get
          file.hunks.add(currentHunk.get)
          currentFile = some(file)
        result.add(currentFile.get)
      
      # Parse file info
      let parts = line.split(' ', 1)
      if parts.len >= 2:
        let changeType = case parts[0].toLowerAscii()
          of "modified": "modify"
          of "added": "add"
          of "deleted": "delete"
          of "renamed": "rename"
          else: "modify"
        
        let path = parts[1].strip()
        currentFile = some(ParsedFileDiff(
          path: path,
          oldPath: path,
          changeType: changeType,
          hunks: @[],
          isBinary: false,
          additions: 0,
          deletions: 0
        ))
        currentHunk = none(DiffHunk)
        inDiffSection = false
    
    elif line.startsWith("   ") and currentFile.isSome and not inDiffSection:
      # File section header or metadata
      discard
    
    elif line == "   +" or line == "   -":
      # Start of diff section
      inDiffSection = true
      if currentHunk.isNone:
        currentHunk = some(DiffHunk(
          oldStart: 1,
          oldCount: 0,
          newStart: 1,
          newCount: 0,
          header: "",
          lines: @[]
        ))
    
    elif inDiffSection and currentHunk.isSome and line.startsWith("    "):
      # Diff content line
      var hunk = currentHunk.get
      let content = line[4..^1]
      
      # In native format, lines are prefixed differently
      if line.startsWith("    +"):
        hunk.lines.add(DiffLine(
          lineType: '+',
          content: content[1..^1],
          oldLineNo: none(int),
          newLineNo: some(hunk.newStart + hunk.newCount)
        ))
        hunk.newCount += 1
        if currentFile.isSome:
          var file = currentFile.get
          file.additions += 1
          currentFile = some(file)
      
      elif line.startsWith("    -"):
        hunk.lines.add(DiffLine(
          lineType: '-',
          content: content[1..^1],
          oldLineNo: some(hunk.oldStart + hunk.oldCount),
          newLineNo: none(int)
        ))
        hunk.oldCount += 1
        if currentFile.isSome:
          var file = currentFile.get
          file.deletions += 1
          currentFile = some(file)
      
      else:
        hunk.lines.add(DiffLine(
          lineType: ' ',
          content: content,
          oldLineNo: some(hunk.oldStart + hunk.oldCount),
          newLineNo: some(hunk.newStart + hunk.newCount)
        ))
        hunk.oldCount += 1
        hunk.newCount += 1
      
      currentHunk = some(hunk)
  
  # Add final file
  if currentFile.isSome:
    if currentHunk.isSome:
      var file = currentFile.get
      file.hunks.add(currentHunk.get)
      currentFile = some(file)
    result.add(currentFile.get)

proc substituteTemplate*(templateStr: string, vars: Table[string, string]): string =
  ## Substitute variables in a template string
  result = templateStr
  for key, value in vars:
    result = result.replace("$" & key, value)

proc formatDiffLine(line: DiffLine, diffTemplate: DiffTemplate, showLineNumbers: bool): string =
  ## Format a single diff line using a template
  var vars = initTable[string, string]()
  vars["content"] = line.content
  vars["oldLineNo"] = if line.oldLineNo.isSome: $line.oldLineNo.get else: ""
  vars["newLineNo"] = if line.newLineNo.isSome: $line.newLineNo.get else: ""
  
  case line.lineType
  of '+':
    result = substituteTemplate(diffTemplate.addLine, vars)
  of '-':
    result = substituteTemplate(diffTemplate.deleteLine, vars)
  else:
    result = substituteTemplate(diffTemplate.contextLine, vars)

proc formatHunk(hunk: DiffHunk, diffTemplate: DiffTemplate, showLineNumbers: bool): string =
  ## Format a diff hunk using a template
  var vars = initTable[string, string]()
  vars["oldStart"] = $hunk.oldStart
  vars["oldCount"] = $hunk.oldCount
  vars["newStart"] = $hunk.newStart
  vars["newCount"] = $hunk.newCount
  vars["header"] = hunk.header
  
  result = substituteTemplate(diffTemplate.hunkHeader, vars) & "\n"
  
  for line in hunk.lines:
    result.add(formatDiffLine(line, diffTemplate, showLineNumbers) & "\n")

proc formatFileDiff(file: ParsedFileDiff, diffTemplate: DiffTemplate, showLineNumbers: bool): string =
  ## Format a file diff using a template
  var vars = initTable[string, string]()
  vars["path"] = file.path
  vars["oldPath"] = file.oldPath
  vars["changeType"] = file.changeType
  vars["additions"] = $file.additions
  vars["deletions"] = $file.deletions
  
  result = substituteTemplate(diffTemplate.fileHeader, vars) & "\n"
  
  for hunk in file.hunks:
    result.add(formatHunk(hunk, diffTemplate, showLineNumbers))
  
  result.add(substituteTemplate(diffTemplate.footer, vars))

proc formatAsJson(files: seq[ParsedFileDiff]): string =
  ## Format diff as JSON
  var jsonObj = %* {
    "files": []
  }
  
  for file in files:
    var fileObj = %* {
      "path": file.path,
      "oldPath": file.oldPath,
      "changeType": file.changeType,
      "additions": file.additions,
      "deletions": file.deletions,
      "isBinary": file.isBinary,
      "hunks": []
    }
    
    for hunk in file.hunks:
      var hunkObj = %* {
        "oldStart": hunk.oldStart,
        "oldCount": hunk.oldCount,
        "newStart": hunk.newStart,
        "newCount": hunk.newCount,
        "header": hunk.header,
        "lines": []
      }
      
      for line in hunk.lines:
        hunkObj["lines"].add(%* {
          "type": $line.lineType,
          "content": line.content,
          "oldLineNo": if line.oldLineNo.isSome: %line.oldLineNo.get else: %nil,
          "newLineNo": if line.newLineNo.isSome: %line.newLineNo.get else: %nil
        })
      
      fileObj["hunks"].add(hunkObj)
    
    jsonObj["files"].add(fileObj)
  
  return $jsonObj

proc formatDiff*(diffContent: string, config: DiffFormatConfig, isNative: bool = false): string {.gcsafe.} =
  ## Format diff content according to the specified format
  let parsedFiles = if isNative:
    parseNativeDiff(diffContent)
  else:
    parseGitDiff(diffContent)
  
  case config.format
  of Native:
    # Return as-is for native format
    return diffContent
  
  of Git:
    # Return as-is for git format if already in git format
    if not isNative:
      return diffContent
    else:
      # TODO: Convert native to git format
      return diffContent
  
  of Json:
    return formatAsJson(parsedFiles)
  
  of Markdown:
    let diffTemplate = MARKDOWN_TEMPLATE
    result = ""
    for file in parsedFiles:
      result.add(formatFileDiff(file, diffTemplate, config.showLineNumbers) & "\n")
  
  of Html:
    let diffTemplate = HTML_TEMPLATE
    result = """<!DOCTYPE html>
<html>
<head>
<style>
.diff-file { margin: 20px 0; border: 1px solid #ddd; }
.diff-header { background: #f7f7f7; padding: 10px; font-weight: bold; }
.diff-table { width: 100%; border-collapse: collapse; font-family: monospace; }
.diff-table td { padding: 2px 5px; }
.line-num { width: 50px; text-align: right; color: #999; }
.added { background: #dfd; }
.deleted { background: #fdd; }
.context { background: #fff; }
.hunk-header { background: #eef; color: #00d; }
</style>
</head>
<body>
"""
    for file in parsedFiles:
      result.add(formatFileDiff(file, diffTemplate, config.showLineNumbers))
    result.add("\n</body>\n</html>")
  
  of Custom:
    if config.diffTemplate.isSome:
      let diffTemplate = config.diffTemplate.get
      result = ""
      for file in parsedFiles:
        result.add(formatFileDiff(file, diffTemplate, config.showLineNumbers) & "\n")
    else:
      # Fallback to git format
      return diffContent

proc loadTemplate*(path: string): DiffTemplate =
  ## Load a custom template from a file
  # Template file format (JSON):
  # {
  #   "name": "custom",
  #   "description": "My custom template",
  #   "fileHeader": "=== $path ===",
  #   "hunkHeader": "Changes from $oldStart to $newStart:",
  #   "addLine": "[+] $content",
  #   "deleteLine": "[-] $content",
  #   "contextLine": "[ ] $content",
  #   "footer": "\n"
  # }
  let jsonContent = readFile(path)
  let jsonObj = parseJson(jsonContent)
  
  result = DiffTemplate(
    name: jsonObj{"name"}.getStr("custom"),
    description: jsonObj{"description"}.getStr(""),
    fileHeader: jsonObj{"fileHeader"}.getStr(""),
    hunkHeader: jsonObj{"hunkHeader"}.getStr(""),
    addLine: jsonObj{"addLine"}.getStr(""),
    deleteLine: jsonObj{"deleteLine"}.getStr(""),
    contextLine: jsonObj{"contextLine"}.getStr(""),
    footer: jsonObj{"footer"}.getStr("")
  )

proc saveTemplate*(diffTemplate: DiffTemplate, path: string) =
  ## Save a template to a file
  let jsonObj = %* {
    "name": diffTemplate.name,
    "description": diffTemplate.description,
    "fileHeader": diffTemplate.fileHeader,
    "hunkHeader": diffTemplate.hunkHeader,
    "addLine": diffTemplate.addLine,
    "deleteLine": diffTemplate.deleteLine,
    "contextLine": diffTemplate.contextLine,
    "footer": diffTemplate.footer
  }
  
  writeFile(path, $jsonObj)