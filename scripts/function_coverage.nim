#!/usr/bin/env nim
## Function-level coverage analysis for MCP-Jujutsu
##
## This script analyzes which functions are exported and potentially tested

import std/[os, strutils, sequtils, tables, sets, re, algorithm, strformat]

type
  FunctionInfo = object
    name: string
    isExported: bool
    file: string
    line: int

  ModuleInfo = object
    path: string
    functions: seq[FunctionInfo]
    types: seq[string]
    
proc extractFunctions(filePath: string): ModuleInfo =
  ## Extract function definitions from a Nim source file
  result.path = filePath
  result.functions = @[]
  result.types = @[]
  
  if not fileExists(filePath):
    return
    
  let content = readFile(filePath)
  let lines = content.splitLines()
  
  # Patterns for function definitions
  let procPattern = re"^\s*(proc|func|method|template|macro)\s+(\w+)\*?\s*\("
  let typePattern = re"^\s*type\s*$"
  let typeDefPattern = re"^\s*(\w+)\*?\s*=\s*"
  
  var inTypeSection = false
  
  for i, line in lines:
    # Check for type section
    if line.match(typePattern):
      inTypeSection = true
      continue
      
    # Check for type definitions
    if inTypeSection and line.match(typeDefPattern):
      var matches: array[1, string]
      if line.match(typeDefPattern, matches):
        result.types.add(matches[0])
      continue
      
    # End of type section
    if inTypeSection and not line.startsWith("  ") and line.strip() != "":
      inTypeSection = false
      
    # Check for function definitions
    var matches: array[2, string]
    if line.match(procPattern, matches):
      let funcType = matches[0]
      let funcName = matches[1]
      let isExported = "*" in line.split("(")[0]
      
      result.functions.add(FunctionInfo(
        name: funcName,
        isExported: isExported,
        file: filePath,
        line: i + 1
      ))

proc findTestReferences(testFile: string, functionName: string): bool =
  ## Check if a function is referenced in a test file
  if not fileExists(testFile):
    return false
    
  let content = readFile(testFile).toLowerAscii()
  let funcLower = functionName.toLowerAscii()
  
  # Check for direct calls, references in strings, etc.
  return funcLower in content

proc analyzeModuleCoverage(srcFile: string, testFiles: seq[string]): tuple[total: int, tested: int, untested: seq[string]] =
  ## Analyze coverage for a single module
  let moduleInfo = extractFunctions(srcFile)
  var testedFuncs = 0
  var untestedFuncs: seq[string] = @[]
  
  for funcInfo in moduleInfo.functions:
    if not funcInfo.isExported:
      continue  # Skip private functions
      
    var isTested = false
    for testFile in testFiles:
      if findTestReferences(testFile, funcInfo.name):
        isTested = true
        break
        
    if isTested:
      testedFuncs += 1
    else:
      untestedFuncs.add(funcInfo.name)
      
  result = (moduleInfo.functions.filterIt(it.isExported).len, testedFuncs, untestedFuncs)

proc formatModuleName(path: string): string =
  ## Format module path for display
  result = path.replace("src/", "").replace(".nim", "")

proc main() =
  echo "MCP-Jujutsu Function Coverage Analysis"
  echo "======================================"
  echo ""
  
  # Find all source files
  var sourceFiles: seq[string] = @[]
  for file in walkDirRec("src"):
    if file.endsWith(".nim"):
      sourceFiles.add(file)
      
  # Find all test files
  var testFiles: seq[string] = @[]
  for file in walkDirRec("tests"):
    if file.endsWith(".nim") and "test_" in file:
      testFiles.add(file)
      
  echo "Source files: ", sourceFiles.len
  echo "Test files: ", testFiles.len
  echo ""
  
  # Sort source files for consistent output
  sourceFiles.sort()
  
  var totalFunctions = 0
  var totalTested = 0
  var moduleResults: seq[tuple[name: string, total: int, tested: int, percentage: float, untested: seq[string]]] = @[]
  
  for srcFile in sourceFiles:
    let moduleName = formatModuleName(srcFile)
    
    # Find relevant test files for this module
    let baseFileName = srcFile.extractFilename().replace(".nim", "")
    var relevantTests: seq[string] = @[]
    
    for testFile in testFiles:
      let testBaseName = testFile.extractFilename().replace("test_", "").replace(".nim", "")
      if testBaseName.toLowerAscii() == baseFileName.toLowerAscii() or
         baseFileName.toLowerAscii() in testFile.toLowerAscii():
        relevantTests.add(testFile)
        
    # Also check comprehensive test files
    relevantTests.add("tests/test_mcp_jujutsu_comprehensive.nim")
    relevantTests.add("tests/test_comprehensive_coverage.nim")
    
    let (funcCount, testedCount, untestedFuncs) = analyzeModuleCoverage(srcFile, relevantTests)
    
    if funcCount > 0:
      let percentage = (testedCount.float / funcCount.float) * 100
      moduleResults.add((moduleName, funcCount, testedCount, percentage, untestedFuncs))
      totalFunctions += funcCount
      totalTested += testedCount
  
  # Display results
  echo "Module Coverage:"
  echo "----------------"
  
  for (module, total, tested, percentage, untested) in moduleResults:
    let status = if percentage >= 100.0: "✓" else: "✗"
    echo fmt"{status} {module:<40} {tested}/{total} ({percentage:>5.1f}%)"
    
    if untested.len > 0 and percentage < 100.0:
      for funcName in untested:
        echo fmt"    - {funcName}"
  
  # Overall summary
  let overallPercentage = if totalFunctions > 0: (totalTested.float / totalFunctions.float) * 100 else: 0.0
  
  echo ""
  echo "Overall Function Coverage:"
  echo "-------------------------"
  echo fmt"Total exported functions: {totalFunctions}"
  echo fmt"Tested functions: {totalTested}"
  echo fmt"Coverage: {overallPercentage:.1f}%"
  
  if overallPercentage >= 100.0:
    echo ""
    echo "✅ 100% function coverage achieved!"
  else:
    echo ""
    echo "❌ Coverage is below 100%"
    echo ""
    echo "Modules needing attention:"
    for (module, total, tested, percentage, untested) in moduleResults:
      if percentage < 100.0:
        echo fmt"  - {module}: {percentage:.1f}% ({total - tested} functions untested)"

when isMainModule:
  main()