## Test to understand why jj diff returns no changes

import os, osproc, strutils

let testDir = getTempDir() / "jj_diff_test"
if dirExists(testDir):
  removeDir(testDir)
createDir(testDir)

echo "=== Test 1: Fresh repo with file ==="
discard execCmdEx("jj git init", workingDir = testDir)
writeFile(testDir / "test.txt", "content")

echo "Status after creating file:"
echo execCmdEx("jj status", workingDir = testDir).output

echo "\nDiff @ (should show new file):"
echo execCmdEx("jj diff", workingDir = testDir).output

echo "\n=== Test 2: After describe ==="
discard execCmdEx("jj describe -m 'Test'", workingDir = testDir)

echo "\nStatus after describe:"
echo execCmdEx("jj status", workingDir = testDir).output

echo "\nDiff @ (after describe):"
echo execCmdEx("jj diff", workingDir = testDir).output

echo "\n=== Test 3: Creating another file ==="
writeFile(testDir / "test2.txt", "more content")

echo "\nStatus after second file:"
echo execCmdEx("jj status", workingDir = testDir).output

echo "\nDiff @ (should show both files):"
echo execCmdEx("jj diff", workingDir = testDir).output

echo "\n=== Test 4: Try -r @ explicitly ==="
echo execCmdEx("jj diff -r @", workingDir = testDir).output

removeDir(testDir)