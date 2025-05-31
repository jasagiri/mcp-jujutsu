## Test to fix the diff parser for Jujutsu output

import os, osproc, strutils

let testDir = getTempDir() / "jj_parser_test"
if dirExists(testDir):
  removeDir(testDir)
createDir(testDir)

discard execCmdEx("jj git init", workingDir = testDir)
writeFile(testDir / "test.nim", "proc hello() = echo \"world\"")

# Get raw diff output
let result = execCmdEx("jj diff --git", workingDir = testDir)
echo "=== Raw jj diff --git output ==="
echo result.output
echo "=== End output ==="

# Check if output contains "diff"
echo "\nContains 'diff ': ", result.output.contains("diff ")
echo "First line: ", result.output.splitLines()[0]

removeDir(testDir)