## Semantic analyzer for commit division
##
## This module provides advanced semantic analysis of code changes to identify logical boundaries.
## It uses pattern recognition and code structure analysis to group related changes together.

import std/[algorithm, asyncdispatch, json, options, sets, strutils, tables, hashes, sequtils]
# Avoid regex dependency completely - use string patterns only
type RegexType = string
import ../../core/repository/jujutsu

type
  AnalysisResult* = object
    files*: seq[string]
    additions*: int
    deletions*: int
    fileTypes*: Table[string, int]
    changeTypes*: Table[string, int]
    codePatterns*: seq[string]
    dependencies*: Table[string, HashSet[string]]  # Maps files to their dependencies
    semanticGroups*: seq[HashSet[string]]         # Groups of semantically related files
    commits*: JsonNode
    
  ChangeType* = enum
    ctFeature, ctBugfix, ctRefactor, ctDocs, ctTests, ctChore, ctStyle, ctPerformance
  
  CodePattern* = object
    pattern*: string        # Pattern description
    regex*: RegexType      # Regex to identify the pattern
    changeType*: ChangeType # Type of change this pattern indicates
    weight*: float         # Pattern importance weight for scoring
    
  ChangePattern* = object
    pattern*: string
    confidence*: float
    changeType*: ChangeType
    files*: HashSet[string]
    keywords*: HashSet[string]  # Extracted keywords from changes
  
  CommitDivisionProposal* = object
    originalCommitId*: string
    targetCommitId*: string
    proposedCommits*: seq[ProposedCommit]
    totalChanges*: int
    confidenceScore*: float
    
  ProposedCommit* = object
    message*: string
    changes*: seq[FileChange]
    changeType*: ChangeType
    keywords*: seq[string]
    
  FileChange* = object
    path*: string
    changeType*: string  # "add", "modify", "delete"
    diff*: string
    similarityGroups*: seq[int]  # Groups this file belongs to based on similarity
    
  CodeSymbol* = object
    name*: string
    symbolType*: string  # "function", "class", "variable", etc.
    location*: string    # File path
    references*: HashSet[string]  # Other symbols this references
    
  DiffSymbolAnalysis* = object
    addedSymbols*: seq[CodeSymbol]
    removedSymbols*: seq[CodeSymbol]
    modifiedSymbols*: seq[CodeSymbol]

# Default patterns for code analysis - using simple string patterns only
const defaultCodePatterns = [
  CodePattern(
    pattern: "Feature addition",
    regex: "(feat|feature|add|implement|new)",
    changeType: ctFeature,
    weight: 1.0
  ),
  CodePattern(
    pattern: "Bug fix", 
    regex: "(fix|bug|issue|error|crash|exception|fault|correct)",
    changeType: ctBugfix,
    weight: 1.0
  ),
  CodePattern(
    pattern: "Code refactoring",
    regex: "(refactor|clean|restructure|reorganize|simplify|improve)",
    changeType: ctRefactor,
    weight: 0.8
  ),
  CodePattern(
    pattern: "Documentation update",
    regex: "(doc|comment|readme|explain|describe)",
    changeType: ctDocs,
    weight: 0.7
  ),
  CodePattern(
    pattern: "Test addition/update",
    regex: "(test|spec|assert|verify|validate)",
    changeType: ctTests,
    weight: 0.7
  ),
  CodePattern(
    pattern: "Style change",
    regex: "(style|format|indent|whitespace|align|lint)",
    changeType: ctStyle,
    weight: 0.5
  ),
  CodePattern(
    pattern: "Performance improvement",
    regex: "(performance|speed|optimize|fast|slow|memory|cpu|time)",
    changeType: ctPerformance,
    weight: 0.9
  ),
  CodePattern(
    pattern: "Nim procedure definition",
    regex: "proc|func|method|iterator|converter",
    changeType: ctFeature,
    weight: 0.9
  ),
  CodePattern(
    pattern: "Nim type definition",
    regex: "type|object|enum|tuple",
    changeType: ctFeature,
    weight: 0.9
  ),
  CodePattern(
    pattern: "Exception handling",
    regex: "try|except|finally|raise",
    changeType: ctBugfix,
    weight: 0.8
  )
]

proc extractKeywords*(diff: string): HashSet[string] =
  ## Extracts meaningful keywords from a diff using simple string parsing
  result = initHashSet[string]()
  
  # Extract function/class/variable names and other identifiers
  var identifiers = newSeq[string]()
  
  # Simple string parsing only
  for line in diff.splitLines():
    # Skip diff metadata lines
    if line.startsWith("+++") or line.startsWith("---") or line.startsWith("@@"):
      continue
    
    # Remove diff markers for content lines
    var contentLine = line
    if line.startsWith("+") or line.startsWith("-"):
      contentLine = line[1..^1]
    
    # Simple word extraction
    for word in contentLine.split():
      let cleanWord = word.strip(chars = {'(', ')', '[', ']', '{', '}', ',', ';', ':', '.'})
      if cleanWord.len > 2 and cleanWord[0].isAlphaAscii():
        if not [
          "func", "proc", "type", "var", "let", "const",
          "import", "from", "include", "export",
          "if", "else", "elif", "while", "for", "case", "of",
          "return", "break", "continue", "yield",
          "and", "or", "not", "xor", "shl", "shr"
        ].contains(cleanWord):
          identifiers.add(cleanWord)
    
  # Filter and add to results
  for id in identifiers:
    if id.len > 2:
      result.incl(id)

proc extractNimSymbols(diff: string): seq[CodeSymbol] =
  ## Extracts Nim symbols (functions, types, etc.) from a diff using simple string parsing
  result = @[]
  
  # Simple string parsing only
  for line in diff.splitLines():
    # Skip diff metadata and deletion lines
    if line.startsWith("+++") or line.startsWith("---") or line.startsWith("@@") or line.startsWith("-"):
      continue
    
    let cleanLine = line.strip()
    
    # Look for procedure definitions
    if cleanLine.contains("proc ") or cleanLine.contains("func ") or 
       cleanLine.contains("method ") or cleanLine.contains("iterator ") or 
       cleanLine.contains("converter "):
      let words = cleanLine.split()
      for i, word in words:
        if word in ["proc", "func", "method", "iterator", "converter"] and i + 1 < words.len:
          let procName = words[i + 1].strip(chars = {'(', ')', '[', ']', '{', '}', ',', ';', ':', '*'})
          if procName.len > 0:
            result.add(CodeSymbol(
              name: procName,
              symbolType: "procedure",
              location: "",
              references: initHashSet[string]()
            ))
    
    # Look for type definitions
    if cleanLine.contains("type "):
      let words = cleanLine.split()
      for i, word in words:
        if word == "type" and i + 1 < words.len:
          let typeName = words[i + 1].strip(chars = {'(', ')', '[', ']', '{', '}', ',', ';', ':', '='})
          if typeName.len > 0:
            result.add(CodeSymbol(
              name: typeName,
              symbolType: "type",
              location: "",
              references: initHashSet[string]()
            ))

proc calculateSimilarity(keywords1, keywords2: HashSet[string]): float =
  ## Calculates similarity between two sets of keywords using Jaccard similarity
  if keywords1.len == 0 and keywords2.len == 0:
    return 0.0
  
  let intersection = keywords1.intersection(keywords2)
  let union = keywords1.union(keywords2)
  
  return intersection.len.float / union.len.float

proc detectChangeType*(diff: string): ChangeType =
  ## Detects the most likely change type based on diff content using simple string matching
  var scores = initTable[ChangeType, float]()
  
  # Initialize scores
  for ct in ChangeType:
    scores[ct] = 0.0
  
  # Evaluate each pattern using simple string matching only
  for pattern in defaultCodePatterns:
    var matchCount = 0
    
    # Simple string matching
    let keywords = pattern.regex.strip(chars = {'(', ')'}).split('|')
    for line in diff.splitLines():
      for keyword in keywords:
        if line.toLowerAscii().contains(keyword.toLowerAscii()):
          matchCount += 1
          break  # Only count once per line
    
    if matchCount > 0:
      scores[pattern.changeType] += pattern.weight * matchCount.float
  
  # Find the highest scoring change type
  var highestScore = 0.0
  result = ctChore  # Default
  
  for ct, score in scores:
    if score > highestScore:
      highestScore = score
      result = ct

proc analyzeSymbolDependencies(files: seq[jujutsu.FileDiff]): Table[string, HashSet[string]] =
  ## Analyzes dependencies between files based on symbol usage
  result = initTable[string, HashSet[string]]()
  
  # First pass: extract all symbols by file
  var symbolsByFile = initTable[string, HashSet[string]]()
  
  for file in files:
    let keywords = extractKeywords(file.diff)
    symbolsByFile[file.path] = keywords
    result[file.path] = initHashSet[string]()
  
  # Second pass: find dependencies between files
  for filePath, fileSymbols in symbolsByFile:
    for otherFilePath, otherSymbols in symbolsByFile:
      if filePath == otherFilePath:
        continue
      
      # Calculate overlap in symbols
      let intersection = fileSymbols.intersection(otherSymbols)
      if intersection.len > 0:
        # Files share symbols, likely related
        result[filePath].incl(otherFilePath)

proc analyzeChanges*(diffResult: jujutsu.DiffResult): Future[AnalysisResult] {.async, gcsafe.} =
  ## Provides advanced analysis of changes in a diff result
  var result = AnalysisResult(
    files: @[],
    additions: 0,
    deletions: 0,
    fileTypes: initTable[string, int](),
    changeTypes: initTable[string, int](),
    codePatterns: @[],
    dependencies: initTable[string, HashSet[string]](),
    semanticGroups: @[],
    commits: %*[]
  )
  
  # Extract basic statistics
  for file in diffResult.files:
    # Add file to list
    result.files.add(file.path)
    
    # Update change type stats
    if result.changeTypes.hasKey(file.changeType):
      result.changeTypes[file.changeType] += 1
    else:
      result.changeTypes[file.changeType] = 1
    
    # Update file type stats
    let fileExt = if file.path.contains("."): file.path.rsplit(".", 1)[1] else: "none"
    if result.fileTypes.hasKey(fileExt):
      result.fileTypes[fileExt] += 1
    else:
      result.fileTypes[fileExt] = 1
    
    # Count additions and deletions
    for line in file.diff.splitLines():
      if line.startsWith("+") and not line.startsWith("+++"):
        result.additions += 1
      elif line.startsWith("-") and not line.startsWith("---"):
        result.deletions += 1
  
  # Analyze code patterns using simple string matching only
  for pattern in defaultCodePatterns:
    var matchingFiles = 0
    
    # Simple string matching
    let keywords = pattern.regex.strip(chars = {'(', ')'}).split('|')
    for file in diffResult.files:
      for keyword in keywords:
        if file.diff.toLowerAscii().contains(keyword.toLowerAscii()):
          matchingFiles += 1
          break  # Only count once per file
    
    if matchingFiles > 0:
      result.codePatterns.add(pattern.pattern)
  
  # Analyze dependencies between files
  result.dependencies = analyzeSymbolDependencies(diffResult.files)
  
  # Group files into semantic groups based on dependencies and similarity
  var processedFiles = initHashSet[string]()
  
  # First pass: group by direct dependencies
  for filePath, dependencies in result.dependencies:
    if filePath in processedFiles:
      continue
    
    if dependencies.len > 0:
      var group = initHashSet[string]()
      group.incl(filePath)
      for dep in dependencies:
        group.incl(dep)
      
      result.semanticGroups.add(group)
      for path in group:
        processedFiles.incl(path)
  
  # Second pass: add remaining files as individual groups
  for file in diffResult.files:
    if not (file.path in processedFiles):
      var group = initHashSet[string]()
      group.incl(file.path)
      result.semanticGroups.add(group)
      processedFiles.incl(file.path)
  
  return result

proc identifySemanticBoundaries*(diffResult: jujutsu.DiffResult): Future[seq[ChangePattern]] {.async, gcsafe.} =
  ## Identifies semantic boundaries in changes with advanced pattern recognition
  var patterns = newSeq[ChangePattern]()
  
  # Get full analysis result
  let analysis = await analyzeChanges(diffResult)
  
  # Create patterns from semantic groups identified in analysis
  for group in analysis.semanticGroups:
    if group.len == 0:
      continue
    
    # Determine the most common directory for this group
    var dirCounts = initTable[string, int]()
    for filePath in group:
      let dirPath = if filePath.contains("/"): filePath.rsplit("/", 1)[0] else: "root"
      
      if dirCounts.hasKey(dirPath):
        dirCounts[dirPath] += 1
      else:
        dirCounts[dirPath] = 1
    
    var mostCommonDir = "various locations"
    var highestCount = 0
    for dir, count in dirCounts:
      if count > highestCount:
        highestCount = count
        mostCommonDir = dir
    
    # Determine the most common file type
    var extCounts = initTable[string, int]()
    for filePath in group:
      let fileExt = if filePath.contains("."): filePath.rsplit(".", 1)[1] else: "none"
      
      if extCounts.hasKey(fileExt):
        extCounts[fileExt] += 1
      else:
        extCounts[fileExt] = 1
    
    var mostCommonExt = "various types"
    highestCount = 0
    for ext, count in extCounts:
      if count > highestCount:
        highestCount = count
        mostCommonExt = ext
    
    # Collect all diff content from this group
    var combinedDiff = ""
    for file in diffResult.files:
      if file.path in group:
        combinedDiff &= file.diff & "\n"
    
    # Determine the most likely change type
    let changeType = detectChangeType(combinedDiff)
    
    # Extract keywords
    var allKeywords = initHashSet[string]()
    for file in diffResult.files:
      if file.path in group:
        let keywords = extractKeywords(file.diff)
        for keyword in keywords:
          allKeywords.incl(keyword)
    
    # Determine pattern description based on change type and location
    var patternDesc = ""
    case changeType
    of ctFeature:
      patternDesc = "New feature in " & mostCommonDir
    of ctBugfix:
      patternDesc = "Bug fixes in " & mostCommonDir
    of ctRefactor:
      patternDesc = "Refactoring of " & mostCommonDir
    of ctDocs:
      patternDesc = "Documentation for " & mostCommonDir
    of ctTests:
      patternDesc = "Tests for " & mostCommonDir
    of ctStyle:
      patternDesc = "Style improvements in " & mostCommonDir
    of ctPerformance:
      patternDesc = "Performance optimization in " & mostCommonDir
    of ctChore:
      patternDesc = "Maintenance in " & mostCommonDir
    
    # Adjust confidence based on group coherence
    var confidence = 0.7  # Base confidence
    
    # Higher confidence if all files are in the same directory
    if dirCounts.len == 1:
      confidence += 0.1
    
    # Higher confidence if all files are of the same type
    if extCounts.len == 1:
      confidence += 0.1
    
    # Higher confidence if clear keywords are present
    if allKeywords.len > 3:
      confidence += 0.1
    
    # Cap confidence at 0.95
    confidence = min(confidence, 0.95)
    
    # Add the pattern
    patterns.add(ChangePattern(
      pattern: patternDesc,
      confidence: confidence,
      changeType: changeType,
      files: group,
      keywords: allKeywords
    ))
  
  # Additional specialized patterns based on file paths and content
  
  # Documentation updates
  var docFiles = initHashSet[string]()
  for file in diffResult.files:
    if file.path.contains("/doc/") or file.path.contains("/docs/") or 
       file.path.endsWith(".md") or file.path.endsWith(".rst") or 
       file.path.endsWith(".txt") or file.path.contains("README") or 
       file.path.contains("CONTRIBUTING"):
      docFiles.incl(file.path)
  
  if docFiles.len > 0:
    # Extract keywords from doc files
    var docKeywords = initHashSet[string]()
    for file in diffResult.files:
      if file.path in docFiles:
        let keywords = extractKeywords(file.diff)
        for keyword in keywords:
          docKeywords.incl(keyword)
    
    patterns.add(ChangePattern(
      pattern: "Documentation updates",
      confidence: 0.95,
      changeType: ctDocs,
      files: docFiles,
      keywords: docKeywords
    ))
  
  # Test changes
  var testFiles = initHashSet[string]()
  for file in diffResult.files:
    if file.path.contains("/test/") or file.path.contains("/tests/") or 
       file.path.startsWith("test_") or file.path.endsWith("_test.nim") or
       file.path.endsWith(".test.nim"):
      testFiles.incl(file.path)
  
  if testFiles.len > 0:
    # Extract keywords from test files
    var testKeywords = initHashSet[string]()
    for file in diffResult.files:
      if file.path in testFiles:
        let keywords = extractKeywords(file.diff)
        for keyword in keywords:
          testKeywords.incl(keyword)
    
    patterns.add(ChangePattern(
      pattern: "Test changes",
      confidence: 0.95,
      changeType: ctTests,
      files: testFiles,
      keywords: testKeywords
    ))
  
  # Configuration changes
  var configFiles = initHashSet[string]()
  for file in diffResult.files:
    if file.path.contains(".config") or file.path.contains(".conf") or 
       file.path.contains(".json") or file.path.contains(".yml") or 
       file.path.contains(".yaml") or file.path.contains(".toml") or
       file.path.contains(".ini"):
      configFiles.incl(file.path)
  
  if configFiles.len > 0:
    patterns.add(ChangePattern(
      pattern: "Configuration changes",
      confidence: 0.9,
      changeType: ctChore,
      files: configFiles,
      keywords: initHashSet[string]()
    ))
  
  # Sort patterns by confidence (highest first)
  patterns.sort(proc(a, b: ChangePattern): int = 
    if a.confidence > b.confidence: -1
    elif a.confidence < b.confidence: 1
    else: 0
  )
  
  return patterns

proc generateCommitMessage*(changePattern: ChangePattern): string =
  ## Generates a detailed commit message in conventional commits format
  ## based on change pattern analysis
  # Convert change type to conventional commit type
  var commitType = "chore"  # Default
  
  case changePattern.changeType
  of ctFeature:
    commitType = "feat"
  of ctBugfix:
    commitType = "fix"
  of ctRefactor:
    commitType = "refactor"
  of ctDocs:
    commitType = "docs"
  of ctTests:
    commitType = "test"
  of ctStyle:
    commitType = "style"
  of ctPerformance:
    commitType = "perf"
  of ctChore:
    commitType = "chore"
  
  # Generate scope if all files are in the same directory
  var scope = ""
  var allSameDir = true
  var commonDir = ""
  
  for file in changePattern.files:
    let dirPath = if file.contains("/"): file.rsplit("/", 1)[0] else: ""
    if commonDir == "":
      commonDir = dirPath
    elif commonDir != dirPath:
      allSameDir = false
      break
  
  if allSameDir and commonDir != "":
    let dirName = if commonDir.contains("/"): commonDir.rsplit("/", 1)[^1] else: commonDir
    scope = "(" & dirName & ")"
  
  # Generate description
  var description = changePattern.pattern
  
  # Clean up description
  description = description.replace("Changes to ", "update ")
  description = description.replace("Changes in ", "update ")
  
  # Extract most important keywords for the body
  var keywordsList = toSeq(changePattern.keywords)
  keywordsList.sort() # Alphabetical sorting for consistency
  
  # Only keep the most relevant keywords (max 5)
  let importantKeywords = if keywordsList.len > 5: keywordsList[0..4] else: keywordsList
  
  # Create message body if we have keywords
  var messageBody = ""
  if importantKeywords.len > 0:
    messageBody = "\n\nAffected components: " & importantKeywords.join(", ")
  
  # Put it all together
  let message = commitType & scope & ": " & description & messageBody
  
  return message

proc classifyChanges*(files: seq[jujutsu.FileDiff]): Table[string, seq[string]] =
  ## Classifies changes by type for simplified analysis
  ## Returns a table mapping change types to descriptions
  result = initTable[string, seq[string]]()
  result["feature"] = @[]
  result["fix"] = @[]
  result["refactor"] = @[]
  result["docs"] = @[]
  result["test"] = @[]
  result["chore"] = @[]
  
  # Create fake diff result for analysis
  let diffResult = jujutsu.DiffResult(
    commitRange: "HEAD~1..HEAD",
    files: files
  )
  
  # Use async proc in a blocking way for simplicity in tests
  let patterns = identifySemanticBoundaries(diffResult).waitFor
  
  # Convert patterns to simplified classification
  for pattern in patterns:
    case pattern.changeType
    of ctFeature:
      result["feature"].add(pattern.pattern)
    of ctBugfix:
      result["fix"].add(pattern.pattern)
    of ctRefactor:
      result["refactor"].add(pattern.pattern)
    of ctDocs:
      result["docs"].add(pattern.pattern)
    of ctTests:
      result["test"].add(pattern.pattern)
    of ctStyle, ctPerformance, ctChore:
      result["chore"].add(pattern.pattern)

proc generateMessage*(analysis: JsonNode): string =
  ## Generates a combined commit message from analysis result
  ## For compatibility with the test suite
  var message = ""
  
  if analysis.hasKey("changes"):
    # Add feat changes
    if analysis["changes"].hasKey("feature") and analysis["changes"]["feature"].len > 0:
      message &= "feat: " & analysis["changes"]["feature"][0].getStr & "\n"
    
    # Add fix changes
    if analysis["changes"].hasKey("fix") and analysis["changes"]["fix"].len > 0:
      message &= "fix: " & analysis["changes"]["fix"][0].getStr & "\n"
    
    # Add other changes
    for changeType in ["refactor", "docs", "test", "chore"]:
      if analysis["changes"].hasKey(changeType) and analysis["changes"][changeType].len > 0:
        message &= changeType & ": " & analysis["changes"][changeType][0].getStr & "\n"
  
  return message.strip()

# Support for backward compatibility
proc generateCommitMessage*(pattern: string, files: HashSet[string]): string =
  ## Legacy version for backwards compatibility
  var changeType = ctChore
  
  if pattern.contains("fix") or pattern.contains("bug"):
    changeType = ctBugfix
  elif pattern.contains("add") or pattern.contains("new") or pattern.contains("feature"):
    changeType = ctFeature
  elif pattern.contains("test"):
    changeType = ctTests
  elif pattern.contains("doc"):
    changeType = ctDocs
  elif pattern.contains("refactor"):
    changeType = ctRefactor
  
  let changePattern = ChangePattern(
    pattern: pattern,
    confidence: 0.8,
    changeType: changeType,
    files: files,
    keywords: initHashSet[string]()
  )
  
  return generateCommitMessage(changePattern)

proc calculateGroupCohesion(files: seq[jujutsu.FileDiff], keywords: HashSet[string]): float =
  ## Calculates cohesion score for a group of files based on various factors
  if files.len == 0:
    return 0.0
  
  var score = 0.0
  
  # Check if files are in the same directory
  var dirCounts = initTable[string, int]()
  for file in files:
    let dirPath = if file.path.contains("/"): file.path.rsplit("/", 1)[0] else: "root"
    
    if dirCounts.hasKey(dirPath):
      dirCounts[dirPath] += 1
    else:
      dirCounts[dirPath] = 1
  
  # Calculate directory cohesion
  let mostCommonDirCount = max(toSeq(dirCounts.values()))
  let dirCohesion = mostCommonDirCount.float / files.len.float
  score += dirCohesion * 0.3  # Directory cohesion contributes 30% to score
  
  # Check if files are of the same type
  var extCounts = initTable[string, int]()
  for file in files:
    let fileExt = if file.path.contains("."): file.path.rsplit(".", 1)[1] else: "none"
    
    if extCounts.hasKey(fileExt):
      extCounts[fileExt] += 1
    else:
      extCounts[fileExt] = 1
  
  # Calculate file type cohesion
  let mostCommonExtCount = max(toSeq(extCounts.values()))
  let extCohesion = mostCommonExtCount.float / files.len.float
  score += extCohesion * 0.2  # File type cohesion contributes 20% to score
  
  # Check if files have similar change patterns
  var changeTypeCounts = initTable[string, int]()
  for file in files:
    if changeTypeCounts.hasKey(file.changeType):
      changeTypeCounts[file.changeType] += 1
    else:
      changeTypeCounts[file.changeType] = 1
  
  # Calculate change type cohesion
  let mostCommonChangeCount = max(toSeq(changeTypeCounts.values()))
  let changeTypeCohesion = mostCommonChangeCount.float / files.len.float
  score += changeTypeCohesion * 0.2  # Change type cohesion contributes 20% to score
  
  # Check keyword density
  let keywordScore = min(1.0, keywords.len.float / 10.0)  # Cap at 1.0
  score += keywordScore * 0.3  # Keyword density contributes 30% to score
  
  return score

proc optimizeGroupAssignments(patterns: seq[ChangePattern], diffResult: jujutsu.DiffResult): Table[string, seq[jujutsu.FileDiff]] =
  ## Optimizes file grouping to maximize overall cohesion
  result = initTable[string, seq[jujutsu.FileDiff]]()
  var filesAssigned = initHashSet[string]()
  
  # First pass: assign files to their highest confidence patterns
  for pattern in patterns:
    var group = newSeq[jujutsu.FileDiff]()
    
    for file in diffResult.files:
      if file.path in pattern.files and not (file.path in filesAssigned):
        group.add(file)
        filesAssigned.incl(file.path)
    
    if group.len > 0:
      result[pattern.pattern] = group
  
  # Second pass: optimize by trying to move boundary files between groups
  var improved = true
  while improved:
    improved = false
    
    for pattern1, group1 in result:
      for pattern2, group2 in result:
        if pattern1 == pattern2:
          continue
        
        # Try moving boundary files between groups
        for i, file in group1:
          # Skip if this would empty the source group
          if group1.len <= 1:
            continue
          
          # Temporarily move file to see if it improves cohesion
          let tempGroup1 = group1.filterIt(it.path != file.path)
          var tempGroup2 = group2
          tempGroup2.add(file)
          
          # Calculate cohesion before and after
          let allKeywords1 = extractKeywords(group1.mapIt(it.diff).join("\n"))
          let allKeywords2 = extractKeywords(group2.mapIt(it.diff).join("\n"))
          let tempKeywords1 = extractKeywords(tempGroup1.mapIt(it.diff).join("\n"))
          let tempKeywords2 = extractKeywords(tempGroup2.mapIt(it.diff).join("\n"))
          
          let beforeScore1 = calculateGroupCohesion(group1, allKeywords1)
          let beforeScore2 = calculateGroupCohesion(group2, allKeywords2)
          let afterScore1 = calculateGroupCohesion(tempGroup1, tempKeywords1)
          let afterScore2 = calculateGroupCohesion(tempGroup2, tempKeywords2)
          
          let beforeTotal = beforeScore1 + beforeScore2
          let afterTotal = afterScore1 + afterScore2
          
          # If moving improves overall cohesion, make the change permanent
          if afterTotal > beforeTotal:
            result[pattern1] = tempGroup1
            result[pattern2] = tempGroup2
            improved = true
            break
        
        if improved:
          break
      
      if improved:
        break
  
  # Add any unassigned files to a miscellaneous group
  var remainingGroup = newSeq[jujutsu.FileDiff]()
  for file in diffResult.files:
    if not (file.path in filesAssigned):
      remainingGroup.add(file)
  
  if remainingGroup.len > 0:
    result["Miscellaneous changes"] = remainingGroup
  
  return result

proc generateSemanticDivisionProposal*(diffResult: jujutsu.DiffResult): Future[CommitDivisionProposal] {.async, gcsafe.} =
  ## Generates an advanced semantic division proposal with optimized grouping
  var proposal = CommitDivisionProposal(
    originalCommitId: diffResult.commitRange.split("..")[0],
    targetCommitId: diffResult.commitRange.split("..")[1],
    proposedCommits: @[],
    totalChanges: diffResult.files.len,
    confidenceScore: 0.0
  )
  
  # Skip processing if no files in diff
  if diffResult.files.len == 0:
    return proposal
  
  # Identify semantic boundaries
  let patterns = await identifySemanticBoundaries(diffResult)
  
  # Skip processing if no patterns identified
  if patterns.len == 0:
    # Add a single generic commit containing all files
    var changes = newSeq[FileChange]()
    for file in diffResult.files:
      changes.add(FileChange(
        path: file.path,
        changeType: file.changeType,
        diff: file.diff,
        similarityGroups: @[]
      ))
    
    proposal.proposedCommits.add(ProposedCommit(
      message: "chore: update files",
      changes: changes,
      changeType: ctChore,
      keywords: @[]
    ))
    
    return proposal
  
  # Optimize grouping of files
  let fileGroups = optimizeGroupAssignments(patterns, diffResult)
  
  # Generate proposed commits based on optimized groups
  var totalConfidence = 0.0
  var patternByGroup = initTable[string, ChangePattern]()
  
  # Match patterns to groups
  for pattern in patterns:
    if fileGroups.hasKey(pattern.pattern):
      patternByGroup[pattern.pattern] = pattern
  
  # Generate commits from groups
  for groupName, files in fileGroups:
    # Skip empty groups
    if files.len == 0:
      continue
    
    var changes = newSeq[FileChange]()
    var filesSet = initHashSet[string]()
    
    for file in files:
      changes.add(FileChange(
        path: file.path,
        changeType: file.changeType,
        diff: file.diff,
        similarityGroups: @[]
      ))
      filesSet.incl(file.path)
    
    # Find pattern or create generic one
    var pattern: ChangePattern
    if patternByGroup.hasKey(groupName):
      pattern = patternByGroup[groupName]
    else:
      # Combined diff content for this group
      let combinedDiff = files.mapIt(it.diff).join("\n")
      let keywords = extractKeywords(combinedDiff)
      let changeType = detectChangeType(combinedDiff)
      
      pattern = ChangePattern(
        pattern: groupName,
        confidence: 0.7,  # Default confidence for miscellaneous
        changeType: changeType,
        files: filesSet,
        keywords: keywords
      )
    
    # Generate commit message based on pattern
    let message = generateCommitMessage(pattern)
    
    # Extract keywords for this group
    let keywords = toSeq(pattern.keywords)
    
    # Create proposed commit
    proposal.proposedCommits.add(ProposedCommit(
      message: message,
      changes: changes,
      changeType: pattern.changeType,
      keywords: keywords
    ))
    
    totalConfidence += pattern.confidence
  
  # Calculate overall confidence score
  if proposal.proposedCommits.len > 0:
    proposal.confidenceScore = totalConfidence / proposal.proposedCommits.len.float
  
  return proposal