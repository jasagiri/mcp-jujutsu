## Test cases for single repository semantic analysis
##
## This module tests the semantic analyzer for single repository mode.

import unittest, asyncdispatch, json, options, tables, strutils
import ../../src/single_repo/analyzer/semantic
import ../../src/core/repository/jujutsu

suite "Semantic Analyzer Tests":
  
  test "Change Type Detection":
    # Test detection of different types of changes
    let files = @[
      jujutsu.FileDiff(
        path: "src/main.nim",
        changeType: "modified",
        diff: """+import newmodule
-import oldmodule
+proc newFunction() =
-proc oldFunction() ="""
      )
    ]
    
    let result = classifyChanges(files)
    check(result.hasKey("feature"))
    check(result.hasKey("refactor"))
  
  test "Release Please Format":
    # Test message generation in release-please format
    let analysis = %*{
      "changes": {
        "feature": ["Add new function"],
        "fix": ["Fix bug in parser"]
      }
    }
    
    let message = generateMessage(analysis)
    check(message.contains("feat:"))
    check(message.contains("fix:"))
  
  test "Empty Changes":
    # Test behavior with no changes
    let files: seq[jujutsu.FileDiff] = @[]
    let result = classifyChanges(files)
    # The function returns default empty categories
    check(result.len == 6)
    check(result.hasKey("feature"))
    check(result.hasKey("fix"))
    check(result.hasKey("refactor"))
    check(result.hasKey("docs"))
    check(result.hasKey("test"))
    check(result.hasKey("chore"))
    # All categories should be empty
    for category, items in result:
      check(items.len == 0)
  
  test "Large Diff Handling":
    # Test handling of large diffs
    var largeDiff = ""
    for i in 0..1000:
      largeDiff.add("+line " & $i & "\n")
    
    let files = @[
      jujutsu.FileDiff(
        path: "large_file.nim",
        changeType: "modified",
        diff: largeDiff
      )
    ]
    
    let result = classifyChanges(files)
    check(result.len > 0)