## Advanced Usage Scenarios for MCP-Jujutsu
## This file demonstrates complex and advanced use cases
## with sophisticated patterns and optimizations

import asyncdispatch
import json
import strformat
import times
import sequtils
import os
import mcp_jujutsu/client/client

# Example 1: Progressive refinement strategy
proc progressiveRefinement() {.async.} =
  echo "\n=== Example 1: Progressive Refinement Strategy ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Start with a broad analysis
  var currentRange = "HEAD~10..HEAD"
  var iteration = 1
  
  while true:
    echo fmt"\nIteration {iteration}: Analyzing {currentRange}"
    
    let analysis = await client.analyzeCommitRange("/path/to/repo", currentRange)
    
    if analysis.fileCount <= 20:
      # Small enough to handle directly
      let result = await client.automateCommitDivision(
        "/path/to/repo",
        currentRange,
        "semantic",
        "medium",
        10,
        0.7,
        false,
        true,
        false
      )
      echo fmt"Created {result.commitIds.len} commits"
      break
    else:
      # Too large, split the range
      echo fmt"Too many files ({analysis.fileCount}), splitting range..."
      currentRange = fmt"HEAD~{5}..HEAD"  # Adjust range
      iteration += 1

# Example 2: Intelligent strategy selection
proc intelligentStrategySelection() {.async.} =
  echo "\n=== Example 2: Intelligent Strategy Selection ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  # Analyze commit characteristics
  let analysis = await client.analyzeCommitRange(repoPath, "HEAD~1..HEAD")
  
  # Determine best strategy based on analysis
  var strategy: string
  var commitSize: string
  
  # Check file type distribution from analysis response
  let fileTypes = analysis["analysis"]["fileTypes"]
  let fileCount = analysis["analysis"]["fileCount"].getInt
  let uniqueFileTypes = fileTypes.len
  
  if uniqueFileTypes <= 2:
    # Find dominant file type
    var maxCount = 0
    var dominantType = ""
    for ft, count in fileTypes:
      if count.getInt > maxCount:
        maxCount = count.getInt
        dominantType = ft
    
    if maxCount.float / fileCount.float > 0.8:
      strategy = "filetype"
      echo fmt"Detected dominant file type: {dominantType} ({maxCount} files)"
    else:
      strategy = "semantic"
      echo "Mixed file types, using semantic strategy"
  else:
    strategy = "directory"
    echo "Many file types, using directory-based strategy"
  
  # Determine commit size preference
  if fileCount > 50:
    commitSize = "many"
    echo "Large change set, preferring many small commits"
  elif fileCount < 10:
    commitSize = "few"
    echo "Small change set, preferring few larger commits"
  else:
    commitSize = "medium"
    echo "Medium change set, using balanced approach"
  
  # Execute with selected strategy
  let result = await client.automateCommitDivision(
    repoPath,
    "HEAD~1..HEAD",
    strategy,
    commitSize,
    15,     # maxCommits
    0.75,   # minConfidence
    false,  # dryRun
    true,   # validate
    true    # autoFix
  )
  
  echo fmt"\nStrategy '{strategy}' with '{commitSize}' size created {result["result"]["commitIds"].len} commits"

# Example 3: Commit message quality enforcement
proc enforceCommitQuality() {.async.} =
  echo "\n=== Example 3: Commit Message Quality Enforcement ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Custom validation function
  proc validateCommitMessage(msg: string): tuple[valid: bool, reason: string] =
    if msg.len < 10:
      return (false, "Message too short")
    if not msg.contains("(") or not msg.contains(")"):
      return (false, "Missing scope in parentheses")
    if msg[0].isLowerAscii:
      return (true, "")  # Lowercase is correct for conventional commits
    return (false, "Should start with lowercase")
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  # Propose division with validation
  let result = await client.automateCommitDivision(
    repoPath,
    "HEAD~1..HEAD",
    "semantic",
    "medium",
    10,
    0.7,
    true,   # dryRun
    true,   # validate
    true    # autoFix
  )
  
  echo "Validation results:"
  let commits = result["result"]["proposal"]["proposedCommits"]
  for commit in commits:
    let msg = commit["message"].getStr
    let customValidation = validateCommitMessage(msg)
    if customValidation.valid:
      echo fmt"  ✓ {msg}"
    else:
      echo fmt"  ✗ {msg} - {customValidation.reason}"

# Example 4: Handling merge commits
proc handleMergeCommits() {.async.} =
  echo "\n=== Example 4: Handling Merge Commits ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  # Check if HEAD is a merge commit
  let analysis = await client.analyzeCommitRange(repoPath, "HEAD~1..HEAD")
  
  let fileCount = analysis["analysis"]["fileCount"].getInt
  
  if fileCount > 100:  # Likely a merge
    echo "Detected potential merge commit"
    
    # For merges, analyze each parent separately
    echo "\nAnalyzing first parent..."
    let parent1 = await client.analyzeCommitRange(repoPath, "HEAD^1~1..HEAD^1")
    
    echo "\nAnalyzing second parent..."
    let parent2 = await client.analyzeCommitRange(repoPath, "HEAD^2~1..HEAD^2")
    
    let parent1Files = parent1["analysis"]["fileCount"].getInt
    let parent2Files = parent2["analysis"]["fileCount"].getInt
    
    echo fmt"\nFirst parent: {parent1Files} files"
    echo fmt"Second parent: {parent2Files} files"
    
    # Handle the larger parent
    let targetRange = if parent1Files > parent2Files:
      "HEAD^1~1..HEAD^1"
    else:
      "HEAD^2~1..HEAD^2"
    
    echo fmt"\nProcessing larger parent: {targetRange}"
    let result = await client.automateCommitDivision(
      repoPath,
      targetRange,
      "semantic",
      "medium",
      10,
      0.7,
      false,
      true,
      false
    )

# Example 5: Time-based commit grouping
proc timeBasedGrouping() {.async.} =
  echo "\n=== Example 5: Time-Based Commit Grouping ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  # Analyze multiple commits
  let analysis = await client.analyzeCommitRange(repoPath, "HEAD~7..HEAD")
  
  # Group commits by day (simulated)
  echo "Grouping commits by time period..."
  
  # In real implementation, would use jj log to get timestamps
  let now = now()
  var commitsByDay = initTable[string, seq[string]]()
  
  # Simulate grouping
  for i in 0..6:
    let day = now - initDuration(days = i)
    let dayStr = day.format("yyyy-MM-dd")
    commitsByDay[dayStr] = @[fmt"HEAD~{i}"]
  
  echo "\nCommits by day:"
  for day, commits in commitsByDay:
    echo fmt"  {day}: {commits.len} commits"
    
    if commits.len > 3:
      echo fmt"    -> Too many commits for {day}, will split semantically"
      let dayRange = fmt"{commits[^1]}..{commits[0]}"
      let _ = await client.proposeCommitDivision(
        repoPath,
        dayRange,
        "semantic",
        "medium",
        3
      )

# Example 6: Cross-branch analysis
proc crossBranchAnalysis() {.async.} =
  echo "\n=== Example 6: Cross-Branch Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Compare feature branch with main
  echo "Analyzing differences between branches..."
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  let featureAnalysis = await client.analyzeCommitRange(repoPath, "main..feature-branch")
  let mainAnalysis = await client.analyzeCommitRange(repoPath, "feature-branch..main")
  
  echo fmt"\nFeature branch ahead by:"
  echo fmt"  Files: {featureAnalysis["analysis"]["fileCount"].getInt}"
  echo fmt"  Additions: {featureAnalysis["analysis"]["totalAdditions"].getInt}"
  echo fmt"  Deletions: {featureAnalysis["analysis"]["totalDeletions"].getInt}"
  
  echo fmt"\nMain branch ahead by:"
  echo fmt"  Files: {mainAnalysis["analysis"]["fileCount"].getInt}"
  echo fmt"  Additions: {mainAnalysis["analysis"]["totalAdditions"].getInt}"
  echo fmt"  Deletions: {mainAnalysis["analysis"]["totalDeletions"].getInt}"
  
  if featureAnalysis["analysis"]["fileCount"].getInt > 20:
    echo "\nFeature branch has many changes, proposing split before merge..."
    let proposal = await client.proposeCommitDivision(
      repoPath,
      "main..feature-branch",
      "semantic",
      "medium",
      10
    )
    echo fmt"Proposed {proposal["proposal"]["proposedCommits"].len} commits for cleaner history"

# Example 7: Incremental processing
proc incrementalProcessing() {.async.} =
  echo "\n=== Example 7: Incremental Processing ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Process commits one at a time
  let totalCommits = 5
  var processedFiles = 0
  var createdCommits = 0
  
  for i in countdown(totalCommits, 1):
    let range = fmt"HEAD~{i}..HEAD~{i-1}"
    echo fmt"\nProcessing commit {totalCommits - i + 1}/{totalCommits}: {range}"
    
    let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
    let analysis = await client.analyzeCommitRange(repoPath, range)
    let fileCount = analysis["analysis"]["fileCount"].getInt
    processedFiles += fileCount
    
    if fileCount > 10:
      # Split this commit
      let result = await client.automateCommitDivision(
        repoPath,
        range,
        "semantic",
        "medium",
        3,
        0.7,
        false,
        true,
        false
      )
      let commitCount = result["result"]["commitIds"].len
      createdCommits += commitCount
      echo fmt"  Split into {commitCount} commits"
    else:
      # Keep as is
      createdCommits += 1
      echo "  Keeping as single commit"
  
  echo fmt"\n\nSummary:"
  echo fmt"  Original commits: {totalCommits}"
  echo fmt"  Created commits: {createdCommits}"
  echo fmt"  Total files processed: {processedFiles}"
  echo fmt"  Expansion ratio: {createdCommits.float / totalCommits.float:.2f}x"

# Example 8: Custom scoring and filtering
proc customScoringWorkflow() {.async.} =
  echo "\n=== Example 8: Custom Scoring and Filtering ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  
  # Get proposal
  let proposal = await client.proposeCommitDivision(
    repoPath,
    "HEAD~2..HEAD",
    "semantic",
    "medium",
    10
  )
  
  # Custom scoring function
  proc scoreCommit(commit: JsonNode): float =
    result = commit["confidence"].getFloat
    
    # Extract type and scope from message
    let msg = commit["message"].getStr
    let parts = msg.split("(")
    let commitType = if parts.len > 0: parts[0] else: ""
    let scope = if parts.len > 1: parts[1].split(")")[0] else: ""
    
    # Bonus for certain types
    if commitType == "feat":
      result += 0.1
    elif commitType == "fix":
      result += 0.15
    
    # Penalty for too many files
    let fileCount = commit["changes"].len
    if fileCount > 10:
      result -= 0.2
    elif fileCount == 1:
      result -= 0.1  # Too granular
    
    # Bonus for good scope
    if scope in ["api", "core", "auth"]:
      result += 0.1
  
  # Re-score and filter commits
  let commits = proposal["proposal"]["proposedCommits"]
  echo "Original proposals:"
  for commit in commits:
    let msg = commit["message"].getStr
    let conf = commit["confidence"].getFloat
    echo fmt"  {msg} - confidence: {conf:.2f}"
  
  echo "\nAfter custom scoring:"
  var filtered = 0
  for commit in commits:
    let score = scoreCommit(commit)
    let msg = commit["message"].getStr
    if score >= 0.7:
      filtered += 1
      echo fmt"  ✓ {msg} - score: {score:.2f}"
    else:
      echo fmt"  ✗ {msg} - score: {score:.2f} (filtered)"
  
  echo fmt"\nKept {filtered}/{commits.len} commits after filtering"

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Advanced Scenarios"
  echo "=============================="
  echo "Note: Replace '/path/to/repo' with your repository path"
  echo "or pass it as a command line argument."
  echo ""
  
  try:
    waitFor progressiveRefinement()
    waitFor intelligentStrategySelection()
    waitFor enforceCommitQuality()
    waitFor handleMergeCommits()
    waitFor timeBasedGrouping()
    waitFor crossBranchAnalysis()
    waitFor incrementalProcessing()
    waitFor customScoringWorkflow()
    
    echo "\n\nAll advanced examples completed!"
  except MpcError as e:
    echo fmt"\nMCP Error: {e.msg}"
    echo "Make sure the MCP server is running."
  except Exception as e:
    echo fmt"\nError: {e.msg}"