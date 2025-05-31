## Basic tests for diff formats module

import std/[unittest, strutils, json, options, tables]
import ../../src/core/repository/diff_formats

suite "Basic Diff Format Tests":
  test "DiffFormat enum values":
    check $Native == "Native"
    check $Git == "Git"
    check $Json == "Json"
    check $Markdown == "Markdown"
    check $Html == "Html"
    check $Custom == "Custom"

  test "DiffFormatConfig default values":
    let config = DiffFormatConfig()
    check config.format == Native
    check config.colorize == false
    check config.contextLines == 0
    check config.showLineNumbers == false
    check config.template.isNone

  test "Parse simple git diff":
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,2 +1,2 @@
 line 1
-line 2
+line 2 modified
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 1
    check parsed[0].path == "test.nim"
    check parsed[0].changeType == "modify"
    check parsed[0].additions == 1
    check parsed[0].deletions == 1

  test "Format as JSON - basic":
    let files = @[
      ParsedFileDiff(
        path: "test.nim",
        oldPath: "test.nim",
        changeType: "modify",
        hunks: @[],
        isBinary: false,
        additions: 1,
        deletions: 1
      )
    ]
    
    let jsonOutput = formatAsJson(files)
    let parsed = parseJson(jsonOutput)
    
    check parsed["files"].len == 1
    check parsed["files"][0]["path"].getStr() == "test.nim"

  test "Built-in templates exist":
    check builtinTemplates.len == 3
    check builtinTemplates.hasKey("json")
    check builtinTemplates.hasKey("markdown")
    check builtinTemplates.hasKey("html")

  test "Substitute template variables":
    var vars = initTable[string, string]()
    vars["path"] = "test.nim"
    vars["content"] = "hello"
    
    let template = "File: $path, Content: $content"
    let result = substituteTemplate(template, vars)
    check result == "File: test.nim, Content: hello"

when isMainModule:
  runTests()