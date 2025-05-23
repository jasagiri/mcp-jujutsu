## Example usage of the Semantic Divide MCP client
##
## This file demonstrates how to use the MCP client to interact with the
## Semantic Divide server for Jujutsu repositories.

import std/[asyncdispatch, json, os, strformat]
import ../src/client/client

proc printJsonResult(title: string, json: JsonNode) =
  echo "\n", title, ":"
  echo "-".repeat(title.len + 1)
  echo json.pretty

proc example() {.async.} =
  # Create a new MCP client
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Use the current directory as the repository path if not specified
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  echo fmt"Using repository: {repoPath}"
  
  # Commit range to analyze
  let commitRange = "HEAD~1..HEAD"
  echo fmt"Analyzing commit range: {commitRange}"
  
  try:
    # Step 1: Analyze the commit range
    echo "\nStep 1: Analyzing commit range..."
    let analysis = await client.analyzeCommitRange(repoPath, commitRange)
    printJsonResult("Analysis Result", analysis)
    
    # Step 2: Propose a commit division
    echo "\nStep 2: Proposing commit division..."
    let proposal = await client.proposeCommitDivision(repoPath, commitRange)
    printJsonResult("Proposal Result", proposal)
    
    # Step 3: Display the number of proposed commits
    let numCommits = proposal["proposal"]["proposedCommits"].len
    echo fmt"\nProposal suggests dividing into {numCommits} commits:"
    for i, commit in proposal["proposal"]["proposedCommits"]:
      let message = commit["message"].getStr
      let numChanges = commit["changes"].len
      echo fmt"  {i+1}. {message} ({numChanges} file changes)"
    
    # Step 4: Ask user if they want to execute the division
    echo "\nWould you like to execute this division? (y/n)"
    let response = stdin.readLine().toLowerAscii()
    
    if response == "y" or response == "yes":
      # Step 5: Execute the commit division
      echo "\nStep 5: Executing commit division..."
      let result = await client.executeCommitDivision(repoPath, proposal["proposal"])
      printJsonResult("Execution Result", result)
      
      echo "\nCommit division completed successfully!"
    else:
      echo "\nCommit division cancelled."
  
  except McpError as e:
    echo "Error: ", e.msg

when isMainModule:
  waitFor example()