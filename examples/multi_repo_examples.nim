## Multi-Repository Examples for MCP-Jujutsu
## This file demonstrates how to work with multiple repositories
## using the MCP server in multi-repo (hub) mode

import asyncdispatch
import json
import strformat
import tables
import os
import mcp_jujutsu/client/client

# Example 1: Basic multi-repo analysis
proc analyzeMultipleRepos() {.async.} =
  echo "\n=== Example 1: Multi-Repository Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Note: The server should be running in multi-repo mode (--hub flag)
  # Analyze changes across all configured repositories
  let analysisParams = %*{
    "commitRange": "HEAD~3..HEAD"
  }
  
  let response = await client.call("analyzeMultiRepoCommits", analysisParams)
  let analysis = response["result"]
  
  echo "Repository changes:"
  for repo, stats in analysis["repositories"]:
    echo fmt"\n{repo}:"
    echo fmt"  Files changed: {stats["fileCount"].getInt}"
    echo fmt"  Lines added: {stats["additions"].getInt}"
    echo fmt"  Lines deleted: {stats["deletions"].getInt}"
  
  if analysis["hasCrossDependencies"].getBool:
    echo "\nCross-repository dependencies found:"
    for dep in analysis["crossDependencies"]:
      echo fmt"  {dep["from"].getStr} -> {dep["to"].getStr} ({dep["type"].getStr})"

# Example 2: Selective repository analysis
proc analyzeSpecificRepos() {.async.} =
  echo "\n=== Example 2: Analyzing Specific Repositories ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Only analyze specific repositories
  let analysisParams = %*{
    "commitRange": "HEAD~1..HEAD",
    "repositories": ["frontend", "shared"]
  }
  
  let response = await client.call("analyzeMultiRepoCommits", analysisParams)
  let analysis = response["result"]
  
  echo "Selected repository analysis:"
  for repo, stats in analysis["repositories"]:
    echo fmt"  {repo}: {stats["fileCount"].getInt} files changed"

# Example 3: Coordinated multi-repo split
proc coordinatedSplit() {.async.} =
  echo "\n=== Example 3: Coordinated Repository Split ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Propose a coordinated split across all repositories
  let proposalParams = %*{
    "commitRange": "HEAD~2..HEAD"
  }
  
  let response = await client.call("proposeMultiRepoSplit", proposalParams)
  let proposal = response["result"]
  
  echo fmt"Proposal confidence: {proposal["confidence"].getFloat:.2f}"
  echo fmt"Total commit groups: {proposal["commitGroups"].len}"
  
  for group in proposal["commitGroups"]:
    echo fmt"\nGroup: {group["description"].getStr}"
    echo "  Affects repositories:"
    for repo, commits in group["repositories"]:
      echo fmt"    {repo}: {commits.len} commits"
    
    if group["dependencies"].len > 0:
      echo "  Dependencies:"
      for dep in group["dependencies"]:
        echo fmt"    {dep.getStr}"

# Example 4: Multi-repo workflow with dependency checking
proc dependencyAwareWorkflow() {.async.} =
  echo "\n=== Example 4: Dependency-Aware Workflow ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # First, analyze for dependencies
  let analysisParams = %*{
    "commitRange": "HEAD~1..HEAD"
  }
  
  let analysisResp = await client.call("analyzeMultiRepoCommits", analysisParams)
  let analysis = analysisResp["result"]
  
  if analysis["hasCrossDependencies"].getBool:
    echo "Dependencies detected! Using coordinated split..."
    
    # Propose coordinated split
    let proposalParams = %*{
      "commitRange": "HEAD~1..HEAD"
    }
    
    let proposalResp = await client.call("proposeMultiRepoSplit", proposalParams)
    let proposal = proposalResp["result"]
    
    # Check if all dependency constraints are satisfied
    var allSatisfied = true
    for group in proposal["commitGroups"]:
      if group["dependencies"].len > 0:
        echo fmt"\nGroup '{group["description"].getStr}' has dependencies:"
        for dep in group["dependencies"]:
          echo fmt"  - {dep.getStr}"
    
    if allSatisfied and proposal["confidence"].getFloat > 0.75:
      echo "\nExecuting coordinated split..."
      let execParams = %*{
        "proposal": proposal
      }
      
      let execResp = await client.call("executeMultiRepoSplit", execParams)
      let result = execResp["result"]
      
      echo "\nCommits created:"
      for repo, commits in result["commitsByRepo"]:
        echo fmt"  {repo}: {commits.len} commits"
  else:
    echo "No cross-dependencies found. Repositories can be split independently."

# Example 5: Custom repository configuration
proc customRepoConfig() {.async.} =
  echo "\n=== Example 5: Custom Repository Configuration ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Note: Custom config is typically set when starting the server
  # This example shows analyzing with the current server configuration
  let analysisParams = %*{
    "commitRange": "HEAD~1..HEAD"
  }
  
  let response = await client.call("analyzeMultiRepoCommits", analysisParams)
  let analysis = response["result"]
  
  echo "Repositories configured in server:"
  for repo in analysis["repositories"].keys:
    echo fmt"  - {repo}"

# Example 6: Monorepo with submodules
proc monorepoWorkflow() {.async.} =
  echo "\n=== Example 6: Monorepo Submodule Analysis ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Analyze specific paths in a monorepo structure
  let analysisParams = %*{
    "commitRange": "HEAD~1..HEAD",
    "repositories": [
      "packages/frontend",
      "packages/backend",
      "packages/shared"
    ]
  }
  
  let response = await client.call("analyzeMultiRepoCommits", analysisParams)
  let analysis = response["result"]
  
  # Group by package type
  var packageGroups = initTable[string, seq[string]]()
  for repo in analysis["repositories"].keys:
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
  let autoParams = %*{
    "commitRange": "HEAD~3..HEAD"
  }
  
  let response = await client.call("automateMultiRepoSplit", autoParams)
  let result = response["result"]
  
  if result["success"].getBool:
    echo "Automated split completed successfully!"
    
    # Show analysis summary
    echo "\nAnalysis summary:"
    echo fmt"  Total files: {result["analysis"]["totalFiles"].getInt}"
    echo fmt"  Total changes: {result["analysis"]["totalChanges"].getInt}"
    echo fmt"  Has dependencies: {result["analysis"]["hasCrossDependencies"].getBool}"
    
    # Show proposal summary
    echo "\nProposal summary:"
    echo fmt"  Confidence: {result["proposal"]["confidence"].getFloat:.2f}"
    echo fmt"  Commit groups: {result["proposal"]["commitGroups"].len}"
    
    # Show execution summary
    echo "\nExecution summary:"
    echo fmt"  Total commits created: {result["execution"]["totalCommits"].getInt}"
    echo fmt"  Execution time: {result["execution"]["executionTime"].getStr}"
    
    echo "\nCommits by repository:"
    for repo, commits in result["execution"]["commitsByRepo"]:
      echo fmt"  {repo}: {commits.len} commits"

# Example 8: Rollback on failure
proc safeMultiRepoSplit() {.async.} =
  echo "\n=== Example 8: Safe Split with Rollback ==="
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Create a savepoint before operations
  echo "Creating savepoint..."
  # In real implementation, this would create jj operation savepoint
  
  try:
    let proposalParams = %*{
      "commitRange": "HEAD~1..HEAD"
    }
    
    let proposalResp = await client.call("proposeMultiRepoSplit", proposalParams)
    let proposal = proposalResp["result"]
    
    if proposal["confidence"].getFloat < 0.6:
      raise newException(ValueError, "Confidence too low for safe execution")
    
    let execParams = %*{
      "proposal": proposal
    }
    
    let execResp = await client.call("executeMultiRepoSplit", execParams)
    echo "Split executed successfully"
    
  except Exception as e:
    echo fmt"Error occurred: {e.msg}"
    echo "Rolling back to savepoint..."
    # In real implementation, this would rollback using jj

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Multi-Repository Examples"
  echo "===================================="
  echo "Note: Start the server in multi-repo mode first:"
  echo "  nimble run -- --hub --port=8080"
  echo "  or: docker-compose --profile multi up"
  echo ""
  
  try:
    waitFor analyzeMultipleRepos()
    waitFor analyzeSpecificRepos()
    waitFor coordinatedSplit()
    waitFor dependencyAwareWorkflow()
    waitFor customRepoConfig()
    waitFor monorepoWorkflow()
    waitFor automatedMultiRepoSplit()
    waitFor safeMultiRepoSplit()
  except MpcError as e:
    echo fmt"\nMCP Error: {e.msg}"
    echo "Make sure the server is running in multi-repo mode."
  except Exception as e:
    echo fmt"\nError: {e.msg}"
  
  echo "\n\nAll multi-repo examples completed!"