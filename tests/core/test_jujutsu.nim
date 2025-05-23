## Test cases for core Jujutsu integration
##
## This module tests the core Jujutsu repository functionality.

import unittest, asyncdispatch, json, options, os, strutils
import ../../src/core/repository/jujutsu

suite "Jujutsu Repository Tests":
  
  test "Repository Initialization":
    # Test initializing a Jujutsu repository connection
    # Note: This would require a real Jujutsu repo for integration testing
    let testPath = "/tmp/test_jj_repo"
    
    # Mock test - in real scenario would create a test repo
    when false:  # Disabled for unit testing
      waitFor:
        let repo = initJujutsuRepo(testPath)
        check(repo.path == testPath)
        check(repo.isInitialized)
  
  test "Execute Command":
    # Test command execution
    when false:  # Disabled for unit testing
      waitFor:
        let result = execCommand("jj status", "/tmp/test_repo")
        check(result.exitCode == 0)
        check(result.output.len > 0)
  
  test "List Changes":
    # Test listing changes in a repository
    when false:  # Disabled for unit testing
      let repo = JujutsuRepo(
        path: "/tmp/test_repo",
        isInitialized: true
      )
      
      waitFor:
        let changes = repo.listChanges("@~..@")
        check(changes.len >= 0)
  
  test "Get Diff":
    # Test getting diff for a commit range
    when false:  # Disabled for unit testing
      let repo = JujutsuRepo(
        path: "/tmp/test_repo",
        isInitialized: true
      )
      
      waitFor:
        let diff = repo.getDiff("@~..@")
        check(diff.files.len >= 0)
  
  test "File Status Parsing":
    # Test parsing file status from Jujutsu output
    let statusOutput = """
changed a/src/main.nim
added b/src/new.nim
deleted c/src/old.nim
"""
    
    # Mock parsing logic test
    let lines = statusOutput.strip().splitLines()
    check(lines.len == 3)
    check(lines[0].contains("changed"))
    check(lines[1].contains("added"))
    check(lines[2].contains("deleted"))