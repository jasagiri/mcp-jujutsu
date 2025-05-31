## Debug test to understand command quoting

import unittest, os, osproc, strutils
import ../../src/core/repository/jujutsu_version

suite "Debug Command Quoting":
  test "Check quoteShellArg":
    echo "Testing quoteShellArg:"
    echo "  root() -> ", quoteShellArg("root()")
    echo "  @ -> ", quoteShellArg("@")
    echo "  root()..@ -> ", quoteShellArg("root()..@")
    
    # Test actual command execution with proper quoting
    let testDir = getTempDir() / "jj_quote_test"
    createDir(testDir)
    
    try:
      # Initialize jj repo
      discard execCmdEx("jj git init", workingDir = testDir)
      
      # Create a file
      writeFile(testDir / "test.txt", "content")
      
      # Test different quoting approaches
      echo "\nTesting command execution:"
      
      # Direct command
      let cmd1 = "jj diff --from 'root()' --to '@'"
      let result1 = execCmdEx(cmd1, workingDir = testDir)
      echo "Command: ", cmd1
      echo "Exit code: ", result1.exitCode
      echo "Output preview: ", result1.output[0..min(100, result1.output.len-1)]
      
      # Using quoteShellArg
      let fromArg = quoteShellArg("root()")
      let toArg = quoteShellArg("@")
      let cmd2 = "jj diff --from " & fromArg & " --to " & toArg
      echo "\nCommand with quoteShellArg: ", cmd2
      let result2 = execCmdEx(cmd2, workingDir = testDir)
      echo "Exit code: ", result2.exitCode
      echo "Output preview: ", result2.output[0..min(100, result2.output.len-1)]
      
    finally:
      removeDir(testDir)