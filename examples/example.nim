## Quick Start Example for MCP-Jujutsu
##
## This simple example demonstrates the core workflow:
## 1. Analyze commits
## 2. Propose semantic division
## 3. Execute the division

import std/[asyncdispatch, json, os, strformat, strutils]
import ../src/client/client

proc printJsonResult(title: string, json: JsonNode) =
  echo "\n", title, ":"
  echo "-".repeat(title.len + 1)
  echo json.pretty

proc example() {.async.} =
  # Setup
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  echo "MCP-Jujutsu Quick Start"
  echo "======================"
  echo fmt"Repository: {repoPath}"
  echo fmt"Server: http://localhost:8080"
  echo ""
  
  try:
    # Step 1: Analyze commits
    echo "[1/3] Analyzing commits..."
    let analysis = await client.analyzeCommitRange(repoPath, "HEAD~1..HEAD")
    
    # Extract key metrics from the JSON response
    let fileCount = analysis["fileCount"].getInt
    let additions = analysis["totalAdditions"].getInt
    let deletions = analysis["totalDeletions"].getInt
    
    echo fmt"      {fileCount} files | +{additions} -{deletions} lines"
    
    # Step 2: Propose division
    echo "\n[2/3] Creating semantic division proposal..."
    let proposal = await client.proposeCommitDivision(repoPath, "HEAD~1..HEAD")
    
    # Extract proposal details
    let proposedCommits = proposal["proposedCommits"]
    let confidence = proposal["confidence"].getFloat
    
    echo fmt"      Confidence: {confidence * 100:.1f}%"
    echo fmt"      Proposed {proposedCommits.len} commits:"
    
    for i in 0..<proposedCommits.len:
      let commit = proposedCommits[i]
      let msg = commit["message"].getStr
      let files = commit["changes"].len
      echo fmt"      {i+1}. {msg} ({files} files)"
    
    # Step 3: Execute if approved
    if confidence >= 0.8:
      echo "\n[3/3] High confidence! Execute division? (y/n): "
      let answer = stdin.readLine().toLowerAscii()
      
      if answer == "y":
        echo "      Executing..."
        let result = await client.executeCommitDivision(repoPath, proposal)
        
        let commitIds = result["commitIds"]
        echo fmt"      ✓ Created {commitIds.len} commits successfully!"
        
        for id in commitIds:
          echo fmt"        - {id.getStr[0..7]}..."
      else:
        echo "      Cancelled."
    else:
      echo "\n[3/3] Confidence too low for automatic execution."
      echo "      Consider adjusting the commit range or strategy."
  
  except McpError as e:
    echo fmt"\n✗ Error: {e.msg}"
    echo "\nTroubleshooting:"
    echo "  1. Is the MCP server running? (nimble run)"
    echo "  2. Are you in a Jujutsu repository?"
    echo "  3. Is the commit range valid?"
  except Exception as e:
    echo fmt"\n✗ Unexpected error: {e.msg}"

when isMainModule:
  waitFor example()