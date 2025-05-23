#!/usr/bin/env nim
## Simple coverage report generator for MCP-Jujutsu
##
## This script analyzes which source files have corresponding test files

import os, strutils, sequtils, algorithm

# Find all source files
var sourceFiles: seq[string] = @[]
for file in walkDirRec("src"):
  if file.endsWith(".nim"):
    sourceFiles.add(file)

# Find all test files
var testFiles: seq[string] = @[]
for file in walkDirRec("tests"):
  if file.endsWith(".nim") and file.contains("test_"):
    testFiles.add(file)

echo "Coverage Report for MCP-Jujutsu"
echo "================================"
echo ""
echo "Source files: ", sourceFiles.len
echo "Test files: ", testFiles.len
echo ""
echo "Source modules:"

# Sort source files for consistent output
sourceFiles.sort()

var testedModules: seq[string] = @[]
var untestedModules: seq[string] = @[]

for file in sourceFiles:
  let moduleName = file.replace("src/", "").replace(".nim", "")
  let baseFileName = moduleName.split("/")[^1]
  
  var hasTest = false
  var testFileName = ""
  
  for testFile in testFiles:
    let testBaseName = testFile.split("/")[^1].replace("test_", "").replace(".nim", "")
    if testBaseName.toLowerAscii == baseFileName.toLowerAscii:
      hasTest = true
      testFileName = testFile
      break
  
  if hasTest:
    echo "  ✓ ", moduleName.alignLeft(40), " -> ", testFileName.replace("tests/", "")
    testedModules.add(moduleName)
  else:
    echo "  ✗ ", moduleName
    untestedModules.add(moduleName)

# Calculate coverage percentage
let coveragePercent = (testedModules.len.float / sourceFiles.len.float) * 100

echo ""
echo "Summary:"
echo "--------"
echo "Tested modules: ", testedModules.len
echo "Untested modules: ", untestedModules.len
echo "Coverage: ", testedModules.len, "/", sourceFiles.len, " (", coveragePercent.formatFloat(ffDecimal, 1), "%)"

if untestedModules.len > 0:
  echo ""
  echo "Untested modules:"
  for module in untestedModules:
    echo "  - ", module

echo ""
echo "Note: This is a simple file-based coverage report."
echo "It checks if each source file has a corresponding test file."
echo "For detailed line coverage, use specialized tools."