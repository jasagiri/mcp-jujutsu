## Check the state of a Jujutsu repo after our setup

import os, osproc, strutils

let testDir = getTempDir() / "jj_state_test"
createDir(testDir)

# Initialize and add files
discard execCmdEx("jj git init", workingDir = testDir)
writeFile(testDir / "test.txt", "content")
discard execCmdEx("jj describe -m 'Initial'", workingDir = testDir)

# Check various states
echo "=== Status ==="
echo execCmdEx("jj status", workingDir = testDir).output

echo "\n=== Log ==="
echo execCmdEx("jj log --no-graph -n 3", workingDir = testDir).output

echo "\n=== Diff @ (current uncommitted) ==="
echo execCmdEx("jj diff", workingDir = testDir).output

echo "\n=== Diff @- (previous commit) ==="
echo execCmdEx("jj diff -r @-", workingDir = testDir).output

echo "\n=== Diff root()..@ (all history) ==="
echo execCmdEx("jj diff --from root() --to @", workingDir = testDir).output

removeDir(testDir)