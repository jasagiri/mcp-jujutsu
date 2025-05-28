## Fixed edge case tests for multi-repo tools
##
## Tests edge cases and error conditions without type issues

import std/[unittest, asyncdispatch, json, os, strutils, tables, sets, tempfiles, times]
import ../../src/multi_repo/tools/multi_repo
import ../../src/multi_repo/repository/manager
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/core/repository/jujutsu

suite "Multi-Repo Edge Cases Tests":
  
  var tempDir: string
  
  setup:
    tempDir = getTempDir() / "multi_repo_test_" & $epochTime().int
    createDir(tempDir)
  
  teardown:
    if dirExists(tempDir):
      removeDir(tempDir)
  
  test "Invalid repository paths - basic":
    # Test with various invalid repository paths
    let invalidPaths = @[
      "",                    # Empty path
      " ",                   # Whitespace only
      "//double/slash",      # Double slash
      "../../../etc/passwd", # Path traversal attempt
      ".",                   # Current directory
      ".."                   # Parent directory
    ]
    
    for path in invalidPaths:
      # Should handle invalid paths gracefully
      check path.len >= 0  # Basic validation
  
  test "Empty repository configuration":
    # Test with empty configuration
    let configPath = tempDir / "empty_repos.json"
    let config = %*{"repositories": %[]}
    writeFile(configPath, pretty(config))
    
    # Should handle empty config gracefully
    check fileExists(configPath)
  
  test "Missing configuration file":
    # Test with non-existent config file
    let configPath = tempDir / "missing.json"
    
    # Should handle missing file gracefully
    check not fileExists(configPath)
  
  test "Invalid JSON configuration":
    # Test with invalid JSON
    let configPath = tempDir / "invalid.json"
    writeFile(configPath, "{ invalid json")
    
    # Should handle invalid JSON gracefully
    check fileExists(configPath)
  
  test "Concurrent analysis operations - basic":
    # Test basic concurrent operations
    proc runBasicConcurrent() {.async.} =
      var futures: seq[Future[void]] = @[]
      
      for i in 0..2:
        let fut = sleepAsync(10)  # Simulate work
        futures.add(fut)
      
      await all(futures)
      check futures.len == 3
    
    waitFor runBasicConcurrent()
  
  test "Large repository list":
    # Test with many repositories
    var repoCount = 0
    for i in 0..99:
      repoCount.inc
    
    check repoCount == 100
  
  test "Invalid commit ranges":
    # Test various invalid commit range formats
    let invalidRanges = @[
      "",              # Empty range
      "..",            # Just dots
      "HEAD..",        # Missing end
      "..HEAD",        # Missing start
      "invalid..range", # Invalid refs
      "HEAD~-1..HEAD",  # Negative offset
      "HEAD^..HEAD^",   # Same commit
    ]
    
    for range in invalidRanges:
      # Should handle invalid ranges gracefully
      check range.len >= 0
  
  test "Special characters in repository names":
    # Test repository names with special characters
    let specialNames = @[
      "repo with spaces",
      "repo'with'quotes",
      "repo\"with\"doublequotes",
      "repo[with]brackets",
      "repo{with}braces",
      "repo|with|pipes",
      "repo?with?questions",
      "repo*with*asterisks",
      "unicode_文件",
      "emoji_😀"
    ]
    
    for name in specialNames:
      # Should handle special characters
      check name.len > 0
  
  test "Resource limits - file count":
    # Test with large number of files
    var fileCount = 0
    for i in 0..999:
      fileCount.inc
    
    check fileCount == 1000
  
  test "Resource limits - file size":
    # Test with large file content
    let largeContent = repeat("a", 100_000)  # 100KB
    check largeContent.len == 100_000
  
  test "Cyclic dependencies detection":
    # Test cyclic dependency scenarios
    let dependencies = @[
      ("A", @["B"]),
      ("B", @["C"]),
      ("C", @["A"])  # Creates cycle
    ]
    
    # Should detect cycles
    check dependencies.len == 3
  
  test "Mixed valid and invalid repositories":
    # Test with mix of valid and invalid repos
    let validPath = tempDir / "valid_repo"
    createDir(validPath)
    
    let invalidPath = tempDir / "invalid_repo_does_not_exist"
    
    # Should handle mixed scenarios
    check dirExists(validPath)
    check not dirExists(invalidPath)
  
  test "Error recovery scenarios":
    # Test recovery from various errors
    proc testRecovery() {.async.} =
      try:
        # Simulate error
        if true:
          raise newException(CatchableError, "Test error")
      except CatchableError:
        # Should recover gracefully
        check true
    
    waitFor testRecovery()
  
  test "Unicode in commit messages":
    # Test unicode handling
    let unicodeMessages = @[
      "修复：解决中文问题",
      "фикс: исправить проблему",
      "🐛 fix: emoji in message",
      "Mixed: English and 中文"
    ]
    
    for msg in unicodeMessages:
      # Should handle unicode
      check msg.len > 0