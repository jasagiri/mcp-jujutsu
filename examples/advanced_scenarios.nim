## Advanced Usage Scenarios for MCP-Jujutsu
## This file demonstrates complex and advanced use cases

import asyncdispatch
import json
import strformat
import times
import sequtils
import ../src/client/client

# Example 1: Progressive refinement strategy
proc progressiveRefinement() {.async.} =
  echo "\n=== Example 1: Progressive Refinement Strategy ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Start with a broad analysis
  var currentRange = "HEAD~10..HEAD"
  var iteration = 1
  
  while true:
    echo fmt"\nIteration {iteration}: Analyzing {currentRange}"
    
    let analysis = await client.analyzeCommitRange(currentRange)
    
    if analysis.fileCount <= 20:
      # Small enough to handle directly
      let result = await client.automateCommitDivision(
        commitRange = currentRange,
        strategy = "semantic"
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
  
  # Analyze commit characteristics
  let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
  
  # Determine best strategy based on analysis
  var strategy: string
  var commitSize: string
  
  # Check file type distribution
  let uniqueFileTypes = analysis.fileTypes.len
  let dominantType = analysis.fileTypes.pairs.toSeq.maxBy(proc(x: auto): auto = x[1])
  
  if uniqueFileTypes <= 2 and dominantType[1].float / analysis.fileCount.float > 0.8:
    strategy = "filetype"
    echo fmt"Detected dominant file type: {dominantType[0]} ({dominantType[1]} files)"
  elif analysis.codePatterns.getOrDefault("newFunctions", 0) > 10:
    strategy = "semantic"
    echo "Detected many new functions, using semantic strategy"
  else:
    strategy = "directory"
    echo "Using directory-based strategy"
  
  # Determine commit size preference
  if analysis.fileCount > 50:
    commitSize = "many"
    echo "Large change set, preferring many small commits"
  elif analysis.fileCount < 10:
    commitSize = "few"
    echo "Small change set, preferring few larger commits"
  else:
    commitSize = "balanced"
    echo "Medium change set, using balanced approach"
  
  # Execute with selected strategy
  let result = await client.automateCommitDivision(
    commitRange = "HEAD~1..HEAD",
    strategy = strategy,
    commitSize = commitSize
  )
  
  echo fmt"\nStrategy '{strategy}' with '{commitSize}' size created {result.commitIds.len} commits"

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
  
  # Propose division with validation
  let result = await client.automateCommitDivision(
    commitRange = "HEAD~1..HEAD",
    strategy = "semantic",
    validate = true,
    autoFix = true,
    dryRun = true
  )
  
  echo "Validation results:"
  for validation in result.validation.results:
    let customValidation = validateCommitMessage(validation.message)
    if customValidation.valid:
      echo fmt"  ✓ {validation.message}"
    else:
      echo fmt"  ✗ {validation.message} - {customValidation.reason}"

# Example 4: Handling merge commits
proc handleMergeCommits() {.async.} =
  echo "\n=== Example 4: Handling Merge Commits ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Check if HEAD is a merge commit
  # In real implementation, would use jj to check
  let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
  
  if analysis.fileCount > 100:  # Likely a merge
    echo "Detected potential merge commit"
    
    # For merges, analyze each parent separately
    echo "\nAnalyzing first parent..."
    let parent1 = await client.analyzeCommitRange("HEAD^1~1..HEAD^1")
    
    echo "\nAnalyzing second parent..."
    let parent2 = await client.analyzeCommitRange("HEAD^2~1..HEAD^2")
    
    echo fmt"\nFirst parent: {parent1.fileCount} files"
    echo fmt"Second parent: {parent2.fileCount} files"
    
    # Handle the larger parent
    let targetRange = if parent1.fileCount > parent2.fileCount:
      "HEAD^1~1..HEAD^1"
    else:
      "HEAD^2~1..HEAD^2"
    
    echo fmt"\nProcessing larger parent: {targetRange}"
    let result = await client.automateCommitDivision(
      commitRange = targetRange,
      strategy = "semantic"
    )

# Example 5: Time-based commit grouping
proc timeBasedGrouping() {.async.} =
  echo "\n=== Example 5: Time-Based Commit Grouping ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze multiple commits
  let analysis = await client.analyzeCommitRange("HEAD~7..HEAD")
  
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
        commitRange = dayRange,
        strategy = "semantic",
        maxCommits = 3
      )

# Example 6: Cross-branch analysis
proc crossBranchAnalysis() {.async.} =
  echo "\n=== Example 6: Cross-Branch Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Compare feature branch with main
  echo "Analyzing differences between branches..."
  
  let featureAnalysis = await client.analyzeCommitRange("main..feature-branch")
  let mainAnalysis = await client.analyzeCommitRange("feature-branch..main")
  
  echo fmt"\nFeature branch ahead by:"
  echo fmt"  Files: {featureAnalysis.fileCount}"
  echo fmt"  Additions: {featureAnalysis.totalAdditions}"
  echo fmt"  Deletions: {featureAnalysis.totalDeletions}"
  
  echo fmt"\nMain branch ahead by:"
  echo fmt"  Files: {mainAnalysis.fileCount}"
  echo fmt"  Additions: {mainAnalysis.totalAdditions}"
  echo fmt"  Deletions: {mainAnalysis.totalDeletions}"
  
  if featureAnalysis.fileCount > 20:
    echo "\nFeature branch has many changes, proposing split before merge..."
    let proposal = await client.proposeCommitDivision(
      commitRange = "main..feature-branch",
      strategy = "semantic",
      commitSize = "balanced"
    )
    echo fmt"Proposed {proposal.proposedCommits.len} commits for cleaner history"

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
    
    let analysis = await client.analyzeCommitRange(range)
    processedFiles += analysis.fileCount
    
    if analysis.fileCount > 10:
      # Split this commit
      let result = await client.automateCommitDivision(
        commitRange = range,
        strategy = "semantic",
        maxCommits = 3
      )
      createdCommits += result.commitIds.len
      echo fmt"  Split into {result.commitIds.len} commits"
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
  
  # Get proposal
  let proposal = await client.proposeCommitDivision(
    commitRange = "HEAD~2..HEAD",
    strategy = "semantic",
    maxCommits = 10
  )
  
  # Custom scoring function
  proc scoreCommit(commit: ProposedCommit): float =
    result = commit.confidence
    
    # Bonus for certain types
    if commit.type == "feat":
      result += 0.1
    elif commit.type == "fix":
      result += 0.15
    
    # Penalty for too many files
    if commit.files.len > 10:
      result -= 0.2
    elif commit.files.len == 1:
      result -= 0.1  # Too granular
    
    # Bonus for good scope
    if commit.scope in ["api", "core", "auth"]:
      result += 0.1
  
  # Re-score and filter commits
  echo "Original proposals:"
  for commit in proposal.proposedCommits:
    echo fmt"  {commit.type}({commit.scope}): {commit.description} - confidence: {commit.confidence:.2f}"
  
  echo "\nAfter custom scoring:"
  var filtered = newSeq[ProposedCommit]()
  for commit in proposal.proposedCommits:
    let score = scoreCommit(commit)
    if score >= 0.7:
      filtered.add(commit)
      echo fmt"  ✓ {commit.type}({commit.scope}): {commit.description} - score: {score:.2f}"
    else:
      echo fmt"  ✗ {commit.type}({commit.scope}): {commit.description} - score: {score:.2f} (filtered)"
  
  echo fmt"\nKept {filtered.len}/{proposal.proposedCommits.len} commits after filtering"

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Advanced Scenarios"
  echo "=============================="
  
  waitFor progressiveRefinement()
  waitFor intelligentStrategySelection()
  waitFor enforceCommitQuality()
  waitFor handleMergeCommits()
  waitFor timeBasedGrouping()
  waitFor crossBranchAnalysis()
  waitFor incrementalProcessing()
  waitFor customScoringWorkflow()
  
  echo "\n\nAll advanced examples completed!"