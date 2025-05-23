## Basic Usage Examples for MCP-Jujutsu Client
## This file demonstrates common use cases for the MCP-Jujutsu client library

import asyncdispatch
import json
import strformat
import ../src/client/client

# Example 1: Basic commit analysis
proc analyzeRecentCommits() {.async.} =
  echo "\n=== Example 1: Analyzing Recent Commits ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze the last 5 commits
  let analysis = await client.analyzeCommitRange("HEAD~5..HEAD")
  
  echo fmt"Files changed: {analysis.fileCount}"
  echo fmt"Lines added: {analysis.totalAdditions}"
  echo fmt"Lines deleted: {analysis.totalDeletions}"
  
  echo "\nFile types modified:"
  for fileType, count in analysis.fileTypes:
    echo fmt"  {fileType}: {count} files"

# Example 2: Propose commit division with different strategies
proc tryDifferentStrategies() {.async.} =
  echo "\n=== Example 2: Comparing Division Strategies ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  let strategies = ["balanced", "semantic", "filetype", "directory"]
  
  for strategy in strategies:
    let proposal = await client.proposeCommitDivision(
      commitRange = "HEAD~1..HEAD",
      strategy = strategy,
      maxCommits = 5
    )
    
    echo fmt"\nStrategy: {strategy}"
    echo fmt"  Confidence: {proposal.confidence:.2f}"
    echo fmt"  Proposed commits: {proposal.proposedCommits.len}"
    echo fmt"  Average commit size: {proposal.statistics.averageCommitSize}"

# Example 3: Automated commit division with validation
proc automatedDivisionWorkflow() {.async.} =
  echo "\n=== Example 3: Automated Division with Validation ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # First, do a dry run to see what would happen
  let dryRunResult = await client.automateCommitDivision(
    commitRange = "HEAD~2..HEAD",
    strategy = "semantic",
    dryRun = true,
    validate = true,
    minConfidence = 0.8
  )
  
  if dryRunResult.proposal.confidence >= 0.8:
    echo "Dry run successful! Proposed commits:"
    for commit in dryRunResult.proposal.proposedCommits:
      echo fmt"  - {commit.type}({commit.scope}): {commit.description}"
    
    # If dry run looks good, execute for real
    echo "\nExecuting actual division..."
    let result = await client.automateCommitDivision(
      commitRange = "HEAD~2..HEAD",
      strategy = "semantic",
      dryRun = false,
      validate = true,
      autoFix = true
    )
    
    echo fmt"Created {result.commitIds.len} commits"
    for id in result.commitIds:
      echo fmt"  - {id}"
  else:
    echo fmt"Confidence too low: {dryRunResult.proposal.confidence:.2f}"

# Example 4: Working with large commits
proc handleLargeCommit() {.async.} =
  echo "\n=== Example 4: Handling Large Commits ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # First analyze to see the size
  let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
  
  if analysis.fileCount > 20:
    echo fmt"Large commit detected: {analysis.fileCount} files"
    
    # For large commits, use "many" size preference
    let proposal = await client.proposeCommitDivision(
      commitRange = "HEAD~1..HEAD",
      strategy = "directory",  # Group by directory for large commits
      commitSize = "many",     # Create many small commits
      maxCommits = 20         # Allow up to 20 commits
    )
    
    echo fmt"Proposed {proposal.proposedCommits.len} commits:"
    for i, commit in proposal.proposedCommits:
      echo fmt"  {i+1}. {commit.type}: {commit.description} ({commit.files.len} files)"

# Example 5: Custom confidence thresholds
proc customConfidenceWorkflow() {.async.} =
  echo "\n=== Example 5: Custom Confidence Thresholds ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Try progressively lower confidence thresholds
  var executed = false
  let thresholds = [0.9, 0.8, 0.7, 0.6]
  
  for threshold in thresholds:
    if not executed:
      let result = await client.automateCommitDivision(
        commitRange = "HEAD~1..HEAD",
        strategy = "semantic",
        minConfidence = threshold,
        dryRun = true
      )
      
      if result.proposal.confidence >= threshold:
        echo fmt"Found valid proposal at {threshold:.1f} confidence"
        echo fmt"Actual confidence: {result.proposal.confidence:.2f}"
        executed = true
        
        # Execute the division
        let execResult = await client.executeCommitDivision(
          proposal = result.proposal
        )
        echo fmt"Successfully created {execResult.commitIds.len} commits"

# Example 6: Error handling
proc robustCommitDivision() {.async.} =
  echo "\n=== Example 6: Robust Error Handling ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Try to analyze an invalid range
    let analysis = await client.analyzeCommitRange("INVALID..RANGE")
  except MpcError as e:
    echo fmt"MCP Error: {e.msg}"
    echo fmt"Error code: {e.code}"
    
    # Fall back to a valid range
    echo "Falling back to HEAD~1..HEAD"
    let analysis = await client.analyzeCommitRange("HEAD~1..HEAD")
    echo fmt"Analysis successful: {analysis.fileCount} files"
  except Exception as e:
    echo fmt"Unexpected error: {e.msg}"

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Client Examples"
  echo "=========================="
  
  # Run all examples
  waitFor analyzeRecentCommits()
  waitFor tryDifferentStrategies()
  waitFor automatedDivisionWorkflow()
  waitFor handleLargeCommit()
  waitFor customConfidenceWorkflow()
  waitFor robustCommitDivision()
  
  echo "\n\nAll examples completed!"