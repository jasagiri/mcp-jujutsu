## Jujutsu Workspace Workflow Examples
## Demonstrates workspace management using MCP-Jujutsu client
## Shows real-world development patterns with Jujutsu workspaces

import std/[asyncdispatch, json, os, strutils, sequtils, tables]
import mcp_jujutsu/client/client

# Example 1: Feature Branch Workflow with Workspaces
proc featureBranchWorkflow() {.async.} =
  echo "=== Feature Branch Workflow with Jujutsu Workspaces ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # List current workspaces
    echo "\n1. Listing current workspaces..."
    let listResp = await client.call("listWorkspaces", %*{})
    let workspaces = listResp["result"]["workspaces"]
    
    echo fmt"   Found {workspaces.len} workspace(s)"
    for ws in workspaces:
      echo fmt"   - {ws["name"].getStr}: {ws["path"].getStr}"
    
    # Create feature workspaces
    echo "\n2. Creating feature workspaces..."
    let features = @["user-auth", "payment", "notifications"]
    
    for feature in features:
      let wsName = fmt"feature-{feature}"
      let createParams = %*{
        "name": wsName,
        "path": fmt"{repoPath}/workspaces/{feature}"
      }
      
      let createResp = await client.call("createWorkspace", createParams)
      if createResp["result"]["success"].getBool:
        echo fmt"   ✓ Created workspace: {wsName}"
    
    # Plan workspace workflow
    echo "\n3. Planning feature development workflow..."
    let planParams = %*{
      "workflowType": "featureBranches",
      "parameters": features
    }
    
    let planResp = await client.call("planWorkspaceWorkflow", planParams)
    let plan = planResp["result"]
    
    echo "   Workflow plan created:"
    echo fmt"   - Type: {plan["type"].getStr}"
    echo fmt"   - Steps: {plan["steps"].len}"
    
    # Execute the workflow
    echo "\n4. Executing workflow..."
    let execParams = %*{"plan": plan}
    let execResp = await client.call("executeWorkspaceWorkflow", execParams)
    
    if execResp["result"]["success"].getBool:
      echo "   ✓ Workflow executed successfully!"
    
    # Analyze changes in each workspace
    echo "\n5. Analyzing workspace changes..."
    for feature in features:
      let wsName = fmt"feature-{feature}"
      
      let analysisParams = %*{"workspace": wsName}
      let analysisResp = await client.call("analyzeWorkspaceChanges", analysisParams)
      let analysis = analysisResp["result"]
      
      echo fmt"\n   Workspace: {wsName}"
      echo fmt"   - Modified files: {analysis["modifiedFiles"].len}"
      echo fmt"   - Uncommitted changes: {analysis["hasUncommittedChanges"].getBool}"
      
      # Simulate workspace operation
      if analysis["hasUncommittedChanges"].getBool:
        let opParams = %*{
          "workspace": wsName,
          "operation": "commit",
          "target": "",
          "parameters": {
            "message": fmt"feat({feature}): implement core functionality"
          }
        }
        
        let opResp = await client.call("workspaceOperation", opParams)
        if opResp["result"]["success"].getBool:
          echo fmt"   ✓ Committed changes in {wsName}"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Example 2: Team Collaboration Workflow
proc teamCollaborationWorkflow() {.async.} =
  echo "\n=== Team Collaboration Workflow ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Setup team workspaces
    echo "\n1. Setting up team member workspaces..."
    let teamMembers = @[("alice", "frontend"), ("bob", "api"), ("charlie", "database")]
    
    for (member, area) in teamMembers:
      let wsName = fmt"dev-{member}"
      let createParams = %*{
        "name": wsName,
        "path": fmt"{repoPath}/team/{member}"
      }
      
      let createResp = await client.call("createWorkspace", createParams)
      if createResp["result"]["success"].getBool:
        echo fmt"   ✓ Created workspace for {member} (working on {area})"
    
    # Analyze cross-workspace semantics
    echo "\n2. Analyzing team collaboration patterns..."
    let semanticParams = %*{}
    let semanticResp = await client.call("workspaceSemanticAnalysis", semanticParams)
    let analysis = semanticResp["result"]
    
    echo "   Semantic analysis results:"
    echo fmt"   - Active workspaces: {analysis["workspaceCount"].getInt}"
    echo fmt"   - Shared files: {analysis["sharedFiles"].len}"
    echo fmt"   - Potential conflicts: {analysis["conflicts"].len}"
    
    # Check for conflicts
    if analysis["conflicts"].len > 0:
      echo "\n   ⚠️  Potential conflicts detected:"
      for conflict in analysis["conflicts"]:
        echo fmt"   - {conflict["workspace1"].getStr} ↔ {conflict["workspace2"].getStr}"
        echo fmt"     File: {conflict["file"].getStr}"
        echo fmt"     Recommendation: {conflict["recommendation"].getStr}"
    else:
      echo "\n   ✅ No conflicts - team can work in parallel"
    
    # Simulate collaborative development
    echo "\n3. Simulating collaborative commits..."
    for (member, area) in teamMembers:
      let wsName = fmt"dev-{member}"
      let opParams = %*{
        "workspace": wsName,
        "operation": "commit",
        "target": "",
        "parameters": {
          "message": fmt"feat({area}): {member}'s contribution"
        }
      }
      
      let opResp = await client.call("workspaceOperation", opParams)
      if opResp["result"]["success"].getBool:
        echo fmt"   ✓ {member} committed to {area}"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Example 3: Environment-Based Workflow
proc environmentWorkflow() {.async.} =
  echo "\n=== Environment-Based Workflow ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Create environment workspaces
    echo "\n1. Creating environment workspaces..."
    let environments = @["development", "staging", "production"]
    
    for env in environments:
      let wsName = fmt"{env}-env"
      let createParams = %*{
        "name": wsName,
        "path": fmt"{repoPath}/environments/{env}"
      }
      
      let createResp = await client.call("createWorkspace", createParams)
      if createResp["result"]["success"].getBool:
        echo fmt"   ✓ Created {env} environment"
        
        # Add environment-specific config
        let opParams = %*{
          "workspace": wsName,
          "operation": "commit",
          "target": "",
          "parameters": {
            "message": fmt"config({env}): initialize environment settings"
          }
        }
        
        discard await client.call("workspaceOperation", opParams)
    
    # Demonstrate promotion workflow
    echo "\n2. Environment promotion workflow:"
    echo "   development → staging → production"
    
    # Promote dev to staging
    echo "\n3. Promoting development → staging..."
    let stagingMerge = %*{
      "workspace": "staging-env",
      "operation": "merge",
      "target": "development-env",
      "parameters": {
        "source": "development-env",
        "message": "chore: promote dev to staging"
      }
    }
    
    let stagingResp = await client.call("workspaceOperation", stagingMerge)
    if stagingResp["result"]["success"].getBool:
      echo "   ✓ Successfully promoted to staging"
    
    # Promote staging to production
    echo "\n4. Promoting staging → production..."
    let prodMerge = %*{
      "workspace": "production-env",
      "operation": "merge",
      "target": "staging-env",
      "parameters": {
        "source": "staging-env",
        "message": "chore: promote staging to production"
      }
    }
    
    let prodResp = await client.call("workspaceOperation", prodMerge)
    if prodResp["result"]["success"].getBool:
      echo "   ✓ Successfully promoted to production"
    
    echo "\n5. Deployment pipeline complete!"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Example 4: Experimental Development Workflow
proc experimentalWorkflow() {.async.} =
  echo "\n=== Experimental Development Workflow ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Create experimental workspaces
    echo "\n1. Creating experimental workspaces..."
    let experiments = @["ml-algorithm", "new-ui", "perf-opt"]
    
    for exp in experiments:
      let wsName = fmt"exp-{exp}"
      let createParams = %*{
        "name": wsName,
        "path": fmt"{repoPath}/experiments/{exp}"
      }
      
      let createResp = await client.call("createWorkspace", createParams)
      if createResp["result"]["success"].getBool:
        echo fmt"   ✓ Created experiment: {exp}"
    
    # Plan experimental workflow
    echo "\n2. Planning experimental workflow..."
    let planParams = %*{
      "workflowType": "experimentation",
      "parameters": experiments
    }
    
    let planResp = await client.call("planWorkspaceWorkflow", planParams)
    let plan = planResp["result"]
    
    echo fmt"   Experiments planned: {plan["steps"].len}"
    
    # Simulate running experiments
    echo "\n3. Running experiments..."
    for i, exp in experiments:
      let wsName = fmt"exp-{exp}"
      
      # Check workspace status
      let analysisParams = %*{"workspace": wsName}
      let analysisResp = await client.call("analyzeWorkspaceChanges", analysisParams)
      
      # Simulate experiment success/failure
      let success = i == 1  # Second experiment succeeds
      
      if success:
        echo fmt"\n   ✅ Experiment '{exp}' succeeded!"
        echo "   Promoting to main branch..."
        
        let mergeParams = %*{
          "workspace": wsName,
          "operation": "merge",
          "target": "@",  # Main branch
          "parameters": {
            "destination": "@",
            "message": fmt"feat(experimental): merge successful {exp} experiment"
          }
        }
        
        let mergeResp = await client.call("workspaceOperation", mergeParams)
        if mergeResp["result"]["success"].getBool:
          echo "   ✓ Successfully merged to main"
      else:
        echo fmt"\n   ❌ Experiment '{exp}' did not meet criteria"
        echo "   Keeping in experimental workspace for further work"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Example 5: MCP Integration Showcase
proc mcpIntegrationShowcase() {.async.} =
  echo "\n=== MCP Integration Showcase ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Demonstrate all workspace tools
    echo "\n1. Available workspace tools:"
    let tools = @[
      "listWorkspaces",
      "createWorkspace",
      "switchWorkspace",
      "analyzeWorkspaceChanges",
      "planWorkspaceWorkflow",
      "executeWorkspaceWorkflow",
      "workspaceSemanticAnalysis",
      "workspaceOperation"
    ]
    
    for tool in tools:
      echo fmt"   - {tool}"
    
    # Show workspace information
    echo "\n2. Current workspace information..."
    let listResp = await client.call("listWorkspaces", %*{})
    let workspaces = listResp["result"]["workspaces"]
    
    if workspaces.len > 0:
      echo fmt"   Total workspaces: {workspaces.len}"
      
      # Get detailed info for first workspace
      let firstWs = workspaces[0]["name"].getStr
      let analysisParams = %*{"workspace": firstWs}
      let analysisResp = await client.call("analyzeWorkspaceChanges", analysisParams)
      
      echo fmt"\n   Details for workspace '{firstWs}':"
      echo fmt"   - Has changes: {analysisResp["result"]["hasUncommittedChanges"].getBool}"
      echo fmt"   - Modified files: {analysisResp["result"]["modifiedFiles"].len}"
    
    # Demonstrate semantic analysis
    echo "\n3. Performing semantic analysis across workspaces..."
    let semanticResp = await client.call("workspaceSemanticAnalysis", %*{})
    let semantic = semanticResp["result"]
    
    echo "   Semantic insights:"
    echo fmt"   - Code patterns detected: {semantic["patterns"].len}"
    echo fmt"   - Collaboration opportunities: {semantic["opportunities"].len}"
    echo fmt"   - Risk areas: {semantic["risks"].len}"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Example 6: Advanced Orchestration
proc advancedOrchestration() {.async.} =
  echo "\n=== Advanced Workflow Orchestration ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Phase 1: Setup complex workspace structure
    echo "\n1. Setting up complex workspace structure..."
    
    # Features + environments matrix
    let features = @["auth", "api", "ui"]
    let envs = @["dev", "test", "prod"]
    
    for feature in features:
      for env in envs:
        let wsName = fmt"{feature}-{env}"
        let createParams = %*{
          "name": wsName,
          "path": fmt"{repoPath}/matrix/{feature}/{env}"
        }
        
        let createResp = await client.call("createWorkspace", createParams)
        if createResp["result"]["success"].getBool:
          echo fmt"   ✓ Created: {wsName}"
    
    # Phase 2: Orchestrated development flow
    echo "\n2. Orchestrating development flow..."
    
    # Simulate feature development in dev environments
    for feature in features:
      let devWs = fmt"{feature}-dev"
      let opParams = %*{
        "workspace": devWs,
        "operation": "commit",
        "target": "",
        "parameters": {
          "message": fmt"feat({feature}): implement in dev"
        }
      }
      
      discard await client.call("workspaceOperation", opParams)
    
    # Phase 3: Progressive promotion
    echo "\n3. Progressive promotion (dev → test → prod)..."
    
    for feature in features:
      echo fmt"\n   Promoting {feature}:"
      
      # Dev to test
      let testMerge = %*{
        "workspace": fmt"{feature}-test",
        "operation": "merge",
        "target": fmt"{feature}-dev",
        "parameters": {
          "source": fmt"{feature}-dev"
        }
      }
      
      let testResp = await client.call("workspaceOperation", testMerge)
      if testResp["result"]["success"].getBool:
        echo fmt"   ✓ dev → test"
      
      # Test to prod (with validation)
      let semanticParams = %*{"workspace": fmt"{feature}-test"}
      let semanticResp = await client.call("analyzeWorkspaceChanges", semanticParams)
      
      if not semanticResp["result"]["hasConflicts"].getBool(false):
        let prodMerge = %*{
          "workspace": fmt"{feature}-prod",
          "operation": "merge",
          "target": fmt"{feature}-test",
          "parameters": {
            "source": fmt"{feature}-test"
          }
        }
        
        let prodResp = await client.call("workspaceOperation", prodMerge)
        if prodResp["result"]["success"].getBool:
          echo fmt"   ✓ test → prod"
      else:
        echo fmt"   ⚠️  Conflicts detected, manual review needed"
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"

# Main execution
when isMainModule:
  echo "MCP-Jujutsu Workspace Workflow Examples"
  echo "======================================"
  echo "Note: These examples require:"
  echo "  1. MCP server running (nimble run)"
  echo "  2. A Jujutsu repository"
  echo ""
  
  try:
    waitFor featureBranchWorkflow()
    waitFor teamCollaborationWorkflow()
    waitFor environmentWorkflow()
    waitFor experimentalWorkflow()
    waitFor mcpIntegrationShowcase()
    waitFor advancedOrchestration()
    
    echo "\n" & "="..repeat(50)
    echo "All workspace workflow examples completed!"
  
  except MpcError as e:
    echo fmt"\nMCP Error: {e.msg}"
    echo "Make sure the MCP server is running."
  except Exception as e:
    echo fmt"\nError: {e.msg}"