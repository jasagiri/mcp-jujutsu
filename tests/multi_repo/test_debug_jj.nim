## Debug test to understand Jujutsu behavior in test environment

import unittest, asyncdispatch, os, osproc, strutils
import ../../src/core/repository/jujutsu

suite "Debug Jujutsu":
  test "Check Jujutsu Commands":
    let testDir = getTempDir() / "jj_debug_test"
    createDir(testDir)
    
    try:
      # Initialize repo
      let repo = waitFor initJujutsuRepo(testDir, initIfNotExists = true)
      check(repo.isInitialized)
      
      # Create a test file
      writeFile(testDir / "test.txt", "Initial content")
      
      # Try to get status
      echo "\n=== Checking jj status ==="
      let statusCmd = execCmdEx("jj status", workingDir = testDir)
      echo "Exit code: ", statusCmd.exitCode
      echo "Output: ", statusCmd.output
      
      # Try to describe current change
      echo "\n=== Describing change ==="
      let descCmd = execCmdEx("jj describe -m 'Test commit'", workingDir = testDir)
      echo "Exit code: ", descCmd.exitCode
      echo "Output: ", descCmd.output
      
      # Try to get diff
      echo "\n=== Getting diff ==="
      let diffCmd = execCmdEx("jj diff", workingDir = testDir)
      echo "Exit code: ", diffCmd.exitCode
      echo "Output: ", diffCmd.output
      
      # Try root()..@ syntax
      echo "\n=== Getting diff with root()..@ ==="
      let rootDiffCmd = execCmdEx("jj diff --from root() --to @", workingDir = testDir)
      echo "Exit code: ", rootDiffCmd.exitCode
      echo "Output: ", rootDiffCmd.output
      
      # Try to get log
      echo "\n=== Getting log ==="
      let logCmd = execCmdEx("jj log --no-graph -n 5", workingDir = testDir)
      echo "Exit code: ", logCmd.exitCode
      echo "Output: ", logCmd.output
      
      # Test getDiffForCommitRange
      echo "\n=== Testing getDiffForCommitRange ==="
      try:
        let diffResult = waitFor repo.getDiffForCommitRange("root()..@")
        echo "Files found: ", diffResult.files.len
        for file in diffResult.files:
          echo "  File: ", file.path, " (", file.changeType, ")"
          echo "  Diff preview: ", file.diff[0..min(100, file.diff.len-1)]
      except:
        echo "Error getting diff: ", getCurrentExceptionMsg()
      
    finally:
      removeDir(testDir)