## Multi-Repository Examples for MCP-Jujutsu
## This file demonstrates how to work with multiple repositories

import asyncdispatch
import json
import strformat
import tables
import ../src/client/client

# Example 1: Basic multi-repo analysis
proc analyzeMultipleRepos() {.async.} =
  echo "\n=== Example 1: Multi-Repository Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze changes across all repositories
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~3..HEAD"
  )
  
  echo "Repository changes:"
  for repo, stats in analysis.repositories:
    echo fmt"\n{repo}:"
    echo fmt"  Files changed: {stats.fileCount}"
    echo fmt"  Lines added: {stats.additions}"
    echo fmt"  Lines deleted: {stats.deletions}"
  
  if analysis.hasCrossDependencies:
    echo "\nCross-repository dependencies found:"
    for dep in analysis.crossDependencies:
      echo fmt"  {dep.from} -> {dep.to} ({dep.type})"

# Example 2: Selective repository analysis
proc analyzeSpecificRepos() {.async.} =
  echo "\n=== Example 2: Analyzing Specific Repositories ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Only analyze frontend and shared repositories
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~1..HEAD",
    repositories = @["frontend", "shared"]
  )
  
  echo "Selected repository analysis:"
  for repo, stats in analysis.repositories:
    echo fmt"  {repo}: {stats.fileCount} files changed"

# Example 3: Coordinated multi-repo split
proc coordinatedSplit() {.async.} =
  echo "\n=== Example 3: Coordinated Repository Split ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Propose a coordinated split
  let proposal = await client.proposeMultiRepoSplit(
    commitRange = "HEAD~2..HEAD"
  )
  
  echo fmt"Proposal confidence: {proposal.confidence:.2f}"
  echo fmt"Total commit groups: {proposal.commitGroups.len}"
  
  for group in proposal.commitGroups:
    echo fmt"\nGroup: {group.description}"
    echo "  Affects repositories:"
    for repo, commits in group.repositories:
      echo fmt"    {repo}: {commits.len} commits"
    
    if group.dependencies.len > 0:
      echo "  Dependencies:"
      for dep in group.dependencies:
        echo fmt"    {dep}"

# Example 4: Multi-repo workflow with dependency checking
proc dependencyAwareWorkflow() {.async.} =
  echo "\n=== Example 4: Dependency-Aware Workflow ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # First, analyze for dependencies
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~1..HEAD"
  )
  
  if analysis.hasCrossDependencies:
    echo "Dependencies detected! Using coordinated split..."
    
    # Propose coordinated split
    let proposal = await client.proposeMultiRepoSplit(
      commitRange = "HEAD~1..HEAD"
    )
    
    # Check if all dependency constraints are satisfied
    var allSatisfied = true
    for group in proposal.commitGroups:
      if group.dependencies.len > 0:
        echo fmt"\nGroup '{group.description}' has dependencies:"
        for dep in group.dependencies:
          echo fmt"  - {dep}"
    
    if allSatisfied and proposal.confidence > 0.75:
      echo "\nExecuting coordinated split..."
      let result = await client.executeMultiRepoSplit(proposal)
      
      echo "\nCommits created:"
      for repo, commits in result.commitsByRepo:
        echo fmt"  {repo}: {commits.len} commits"
  else:
    echo "No cross-dependencies found. Repositories can be split independently."

# Example 5: Custom repository configuration
proc customRepoConfig() {.async.} =
  echo "\n=== Example 5: Custom Repository Configuration ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Use custom repository configuration
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~1..HEAD",
    configPath = "./custom-repos.json"
  )
  
  echo "Repositories from custom config:"
  for repo in analysis.repositories.keys:
    echo fmt"  - {repo}"

# Example 6: Monorepo with submodules
proc monorepoWorkflow() {.async.} =
  echo "\n=== Example 6: Monorepo Submodule Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze a monorepo structure
  let analysis = await client.analyzeMultiRepoCommits(
    commitRange = "HEAD~1..HEAD",
    repositories = @[
      "monorepo/packages/frontend",
      "monorepo/packages/backend",
      "monorepo/packages/shared"
    ]
  )
  
  # Group by package type
  var packageGroups = initTable[string, seq[string]]()
  for repo in analysis.repositories.keys:
    let packageType = repo.split("/")[^1]  # Get last part
    if not packageGroups.hasKey(packageType):
      packageGroups[packageType] = @[]
    packageGroups[packageType].add(repo)
  
  echo "Package groups:"
  for group, repos in packageGroups:
    echo fmt"  {group}: {repos.len} packages"

# Example 7: Automated multi-repo split with validation
proc automatedMultiRepoSplit() {.async.} =
  echo "\n=== Example 7: Automated Multi-Repo Split ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Fully automated split with all features
  let result = await client.automateMultiRepoSplit(
    commitRange = "HEAD~3..HEAD"
  )
  
  if result.success:
    echo "Automated split completed successfully!"
    
    # Show analysis summary
    echo "\nAnalysis summary:"
    echo fmt"  Total files: {result.analysis.totalFiles}"
    echo fmt"  Total changes: {result.analysis.totalChanges}"
    echo fmt"  Has dependencies: {result.analysis.hasCrossDependencies}"
    
    # Show proposal summary
    echo "\nProposal summary:"
    echo fmt"  Confidence: {result.proposal.confidence:.2f}"
    echo fmt"  Commit groups: {result.proposal.commitGroups.len}"
    
    # Show execution summary
    echo "\nExecution summary:"
    echo fmt"  Total commits created: {result.execution.totalCommits}"
    echo fmt"  Execution time: {result.execution.executionTime}"
    
    echo "\nCommits by repository:"
    for repo, commits in result.execution.commitsByRepo:
      echo fmt"  {repo}: {commits}"

# Example 8: Rollback on failure
proc safeMultiRepoSplit() {.async.} =
  echo "\n=== Example 8: Safe Split with Rollback ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Create a savepoint before operations
  echo "Creating savepoint..."
  # In real implementation, this would create jj operation savepoint
  
  try:
    let proposal = await client.proposeMultiRepoSplit(
      commitRange = "HEAD~1..HEAD"
    )
    
    if proposal.confidence < 0.6:
      raise newException(ValueError, "Confidence too low for safe execution")
    
    let result = await client.executeMultiRepoSplit(proposal)
    echo "Split executed successfully"
    
  except Exception as e:
    echo fmt"Error occurred: {e.msg}"
    echo "Rolling back to savepoint..."
    # In real implementation, this would rollback using jj

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Multi-Repository Examples"
  echo "===================================="
  
  # Note: These examples assume you're running in multi-repo mode
  # Start server with: ./scripts/start-server.sh 8080 multi
  
  waitFor analyzeMultipleRepos()
  waitFor analyzeSpecificRepos()
  waitFor coordinatedSplit()
  waitFor dependencyAwareWorkflow()
  waitFor customRepoConfig()
  waitFor monorepoWorkflow()
  waitFor automatedMultiRepoSplit()
  waitFor safeMultiRepoSplit()
  
  echo "\n\nAll multi-repo examples completed!"