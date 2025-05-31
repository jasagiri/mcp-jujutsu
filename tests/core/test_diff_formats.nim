## Tests for diff formats module

import std/[unittest, asyncdispatch, strutils, json, options, tables, os, tempfiles]
import ../../src/core/repository/diff_formats
import ../../src/core/config/config

suite "Diff Format Tests":
  test "Parse git diff - basic file modification":
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,5 +1,6 @@
 import std/strutils
 
+# New comment
 proc hello() =
   echo "Hello"
-  echo "World"
+  echo "World!"
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 1
    check parsed[0].path == "test.nim"
    check parsed[0].changeType == "modify"
    check parsed[0].additions == 2
    check parsed[0].deletions == 1
    check parsed[0].hunks.len == 1
    check parsed[0].hunks[0].oldStart == 1
    check parsed[0].hunks[0].oldCount == 5
    check parsed[0].hunks[0].newStart == 1
    check parsed[0].hunks[0].newCount == 6

  test "Parse git diff - new file":
    let gitDiff = """diff --git a/new.nim b/new.nim
new file mode 100644
index 0000000..abc123 100644
--- /dev/null
+++ b/new.nim
@@ -0,0 +1,3 @@
+proc test() =
+  echo "New file"
+  return
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 1
    check parsed[0].path == "new.nim"
    check parsed[0].changeType == "add"
    check parsed[0].additions == 3
    check parsed[0].deletions == 0

  test "Parse git diff - deleted file":
    let gitDiff = """diff --git a/old.nim b/old.nim
deleted file mode 100644
index abc123..0000000 100644
--- a/old.nim
+++ /dev/null
@@ -1,2 +0,0 @@
-echo "This file"
-echo "is deleted"
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 1
    check parsed[0].path == "old.nim"
    check parsed[0].changeType == "delete"
    check parsed[0].additions == 0
    check parsed[0].deletions == 2

  test "Parse native diff - basic modification":
    let nativeDiff = """Modified src/test.nim
   First line
   Second line
   +
    +Added line
   Third line
"""
    
    let parsed = parseNativeDiff(nativeDiff)
    check parsed.len == 1
    check parsed[0].path == "src/test.nim"
    check parsed[0].changeType == "modify"
    check parsed[0].additions == 1
    check parsed[0].deletions == 0

  test "Format as JSON":
    let files = @[
      ParsedFileDiff(
        path: "test.nim",
        oldPath: "test.nim",
        changeType: "modify",
        hunks: @[
          DiffHunk(
            oldStart: 1,
            oldCount: 3,
            newStart: 1,
            newCount: 4,
            header: "proc test()",
            lines: @[
              DiffLine(lineType: ' ', content: "import std/strutils", oldLineNo: some(1), newLineNo: some(1)),
              DiffLine(lineType: '+', content: "import std/json", oldLineNo: none(int), newLineNo: some(2)),
              DiffLine(lineType: ' ', content: "", oldLineNo: some(2), newLineNo: some(3)),
              DiffLine(lineType: '-', content: "proc old() =", oldLineNo: some(3), newLineNo: none(int)),
              DiffLine(lineType: '+', content: "proc new() =", oldLineNo: none(int), newLineNo: some(4))
            ]
          )
        ],
        isBinary: false,
        additions: 2,
        deletions: 1
      )
    ]
    
    let jsonOutput = formatAsJson(files)
    let parsed = parseJson(jsonOutput)
    
    check parsed["files"].len == 1
    check parsed["files"][0]["path"].getStr() == "test.nim"
    check parsed["files"][0]["changeType"].getStr() == "modify"
    check parsed["files"][0]["additions"].getInt() == 2
    check parsed["files"][0]["deletions"].getInt() == 1
    check parsed["files"][0]["hunks"].len == 1
    check parsed["files"][0]["hunks"][0]["lines"].len == 5

  test "Format with Markdown template":
    let config = DiffFormatConfig(
      format: Markdown,
      colorize: false,
      contextLines: 3,
      showLineNumbers: false
    )
    
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,3 +1,3 @@
 proc test() =
-  echo "old"
+  echo "new"
 return
"""
    
    let formatted = formatDiff(gitDiff, config)
    check "### test.nim" in formatted
    check "```diff" in formatted
    check "+ echo \"new\"" in formatted
    check "- echo \"old\"" in formatted
    check "```" in formatted

  test "Format with HTML template":
    let config = DiffFormatConfig(
      format: Html,
      colorize: false,
      contextLines: 3,
      showLineNumbers: true
    )
    
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,2 +1,2 @@
-old line
+new line
"""
    
    let formatted = formatDiff(gitDiff, config)
    check "<div class=\"diff-file\">" in formatted
    check "<div class=\"diff-header\">test.nim</div>" in formatted
    check "<tr class=\"deleted\">" in formatted
    check "<tr class=\"added\">" in formatted
    check "</html>" in formatted

  test "Load and save custom template":
    let template = DiffTemplate(
      name: "test",
      description: "Test template",
      fileHeader: "File: $path",
      hunkHeader: "Hunk: $oldStart,$oldCount -> $newStart,$newCount",
      addLine: "[+] $content",
      deleteLine: "[-] $content",
      contextLine: "[ ] $content",
      footer: "---"
    )
    
    let (_, tempPath) = createTempFile("test_template_", ".json")
    defer: removeFile(tempPath)
    
    saveTemplate(template, tempPath)
    let loaded = loadTemplate(tempPath)
    
    check loaded.name == "test"
    check loaded.description == "Test template"
    check loaded.fileHeader == "File: $path"
    check loaded.addLine == "[+] $content"

  test "Format with custom template":
    let template = DiffTemplate(
      name: "custom",
      description: "Custom format",
      fileHeader: "=== $path ===",
      hunkHeader: "@@@ $oldStart,$oldCount -> $newStart,$newCount @@@",
      addLine: "ADD: $content",
      deleteLine: "DEL: $content",
      contextLine: "CTX: $content",
      footer: "END OF $path"
    )
    
    let config = DiffFormatConfig(
      format: Custom,
      colorize: false,
      contextLines: 3,
      showLineNumbers: false,
      template: some(template)
    )
    
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -1,3 +1,3 @@
 line 1
-line 2
+line 2 modified
 line 3
"""
    
    let formatted = formatDiff(gitDiff, config)
    check "=== test.nim ===" in formatted
    check "@@@ 1,3 -> 1,3 @@@" in formatted
    check "CTX: line 1" in formatted
    check "DEL: line 2" in formatted
    check "ADD: line 2 modified" in formatted
    check "CTX: line 3" in formatted
    check "END OF test.nim" in formatted

  test "Handle binary files":
    let gitDiff = """diff --git a/image.png b/image.png
Binary files a/image.png and b/image.png differ
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 1
    check parsed[0].path == "image.png"
    check parsed[0].isBinary == true

  test "Parse multiple files in one diff":
    let gitDiff = """diff --git a/file1.nim b/file1.nim
index abc123..def456 100644
--- a/file1.nim
+++ b/file1.nim
@@ -1,2 +1,2 @@
-old content
+new content
diff --git a/file2.nim b/file2.nim
new file mode 100644
index 0000000..abc123 100644
--- /dev/null
+++ b/file2.nim
@@ -0,0 +1,1 @@
+added file
"""
    
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 2
    check parsed[0].path == "file1.nim"
    check parsed[0].changeType == "modify"
    check parsed[1].path == "file2.nim"
    check parsed[1].changeType == "add"

  test "Handle empty diff":
    let gitDiff = ""
    let parsed = parseGitDiff(gitDiff)
    check parsed.len == 0

  test "Substitute template variables":
    var vars = initTable[string, string]()
    vars["path"] = "test.nim"
    vars["content"] = "hello world"
    vars["lineNo"] = "42"
    
    let template = "File: $path, Line $lineNo: $content"
    let result = substituteTemplate(template, vars)
    check result == "File: test.nim, Line 42: hello world"

  test "Format with line numbers":
    let config = DiffFormatConfig(
      format: Markdown,
      colorize: false,
      contextLines: 3,
      showLineNumbers: true
    )
    
    # This test verifies that line numbers are properly handled
    # when showLineNumbers is true
    let gitDiff = """diff --git a/test.nim b/test.nim
index abc123..def456 100644
--- a/test.nim
+++ b/test.nim
@@ -10,3 +10,4 @@
 line 10
 line 11
+line 11.5
 line 12
"""
    
    let formatted = formatDiff(gitDiff, config)
    check formatted.contains("line 11.5")

when isMainModule:
  waitFor main()