## Multi-Repository Workflow Example
## Demonstrates orchestrating changes across multiple repositories
## using MCP-Jujutsu in multi-repo (hub) mode

import std/[os, strutils, sequtils, tables, json, times, asyncdispatch]
import mcp_jujutsu/client/client

# Multi-repo project structure
type
  Repository = object
    name: string
    path: string
    remote: string
    branch: string
    dependencies: seq[string]
    lastSync: DateTime

  MultiRepoProject = object
    name: string
    repositories: seq[Repository]
    syncStrategy: SyncStrategy
    workspaceRoot: string

  SyncStrategy = enum
    ssSequential = "sequential"    # Sync repos one by one
    ssParallel = "parallel"        # Sync all repos at once
    ssDependencyOrder = "ordered"  # Sync respecting dependencies

  CrossRepoChange = object
    description: string
    affectedRepos: seq[string]
    commits: Table[string, string]  # repo -> commit message
    order: seq[string]             # Deployment order

# Example: Microservices project with multiple repositories
let microservicesProject = MultiRepoProject(
  name: "E-commerce Platform",
  workspaceRoot: "/workspace/ecommerce",
  syncStrategy: ssDependencyOrder,
  repositories: @[
    Repository(
      name: "shared-types",
      path: "packages/shared-types",
      remote: "git@github.com:company/shared-types.git",
      branch: "main",
      dependencies: @[]
    ),
    Repository(
      name: "auth-service",
      path: "services/auth",
      remote: "git@github.com:company/auth-service.git",
      branch: "main",
      dependencies: @["shared-types"]
    ),
    Repository(
      name: "user-service",
      path: "services/user",
      remote: "git@github.com:company/user-service.git",
      branch: "main",
      dependencies: @["shared-types", "auth-service"]
    ),
    Repository(
      name: "product-service",
      path: "services/product",
      remote: "git@github.com:company/product-service.git",
      branch: "main",
      dependencies: @["shared-types"]
    ),
    Repository(
      name: "order-service",
      path: "services/order",
      remote: "git@github.com:company/order-service.git",
      branch: "main",
      dependencies: @["shared-types", "user-service", "product-service"]
    ),
    Repository(
      name: "web-frontend",
      path: "frontends/web",
      remote: "git@github.com:company/web-frontend.git",
      branch: "main",
      dependencies: @["shared-types"]
    ),
    Repository(
      name: "mobile-app",
      path: "frontends/mobile",
      remote: "git@github.com:company/mobile-app.git",
      branch: "main",
      dependencies: @["shared-types"]
    )
  ]
)

# Example cross-repository changes
let exampleChanges = @[
  CrossRepoChange(
    description: "Add user preferences feature",
    affectedRepos: @["shared-types", "user-service", "auth-service", "web-frontend"],
    commits: {
      "shared-types": "feat(types): add UserPreferences interface",
      "user-service": "feat(api): implement user preferences endpoints",
      "auth-service": "feat(auth): add preference-based permissions",
      "web-frontend": "feat(ui): add user preferences settings page"
    }.toTable,
    order: @["shared-types", "auth-service", "user-service", "web-frontend"]
  ),
  CrossRepoChange(
    description: "Implement product recommendations",
    affectedRepos: @["product-service", "user-service", "order-service", "web-frontend"],
    commits: {
      "product-service": "feat(ml): add recommendation engine",
      "user-service": "feat(api): expose user behavior data",
      "order-service": "feat(analytics): track purchase patterns",
      "web-frontend": "feat(ui): display personalized recommendations"
    }.toTable,
    order: @["user-service", "order-service", "product-service", "web-frontend"]
  )
]

# Multi-repo management with MCP client
proc initializeMultiRepoWorkspace*(project: MultiRepoProject) {.async.} =
  ## Sets up the multi-repo workspace using MCP client
  echo &"Initializing multi-repo workspace: {project.name}"
  echo &"Workspace root: {project.workspaceRoot}"
  echo "=" * 60
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  # Create workspace structure
  createDir(project.workspaceRoot)
  createDir(project.workspaceRoot / "packages")
  createDir(project.workspaceRoot / "services")
  createDir(project.workspaceRoot / "frontends")
  
  # Check repository status via MCP
  echo "\nChecking repository status..."
  try:
    let analysisParams = %*{
      "commitRange": "HEAD~1..HEAD",
      "repositories": project.repositories.mapIt(it.name)
    }
    
    let response = await client.call("analyzeMultiRepoCommits", analysisParams)
    let analysis = response["result"]
    
    echo "\nRepository status:"
    for repo, stats in analysis["repositories"]:
      echo fmt"  {repo}: {stats["fileCount"].getInt} recent changes"
  except MpcError as e:
    echo fmt"\nNote: {e.msg}"
    echo "Make sure the server is running in multi-repo mode (--hub flag)"

proc analyzeRepoDependencies*(project: MultiRepoProject): Table[string, seq[string]] =
  ## Analyzes and validates repository dependencies
  echo "\nAnalyzing repository dependencies..."
  
  # Build dependency graph
  for repo in project.repositories:
    result[repo.name] = repo.dependencies
  
  # Check for circular dependencies
  proc hasCircularDep(repo: string, visited: var seq[string]): bool =
    if repo in visited:
      return true
    visited.add(repo)
    
    if repo in result:
      for dep in result[repo]:
        if hasCircularDep(dep, visited):
          return true
    
    visited.del(visited.find(repo))
    return false
  
  for repo in project.repositories:
    var visited: seq[string] = @[]
    if hasCircularDep(repo.name, visited):
      echo &"  ⚠️  Warning: Circular dependency detected involving {repo.name}"
  
  echo "\nDependency Graph:"
  for repo, deps in result:
    if deps.len > 0:
      echo &"  {repo} → {deps.join(\", \")}"
    else:
      echo &"  {repo} (no dependencies)"

proc planCrossRepoChange*(change: CrossRepoChange, project: MultiRepoProject): 
                         JsonNode =
  ## Plans the execution of a cross-repository change
  result = %* {
    "change": change.description,
    "affected_repos": change.affectedRepos,
    "execution_plan": [],
    "estimated_time": "15-30 minutes",
    "risk_level": "medium"
  }
  
  echo &"\nPlanning cross-repo change: {change.description}"
  echo &"Affected repositories: {change.affectedRepos.join(\", \")}"
  
  # Determine execution order based on dependencies
  var executionOrder: seq[string] = @[]
  var remaining = change.order
  var iterations = 0
  
  while remaining.len > 0 and iterations < 10:
    iterations += 1
    var executed: seq[string] = @[]
    
    for repo in remaining:
      # Check if all dependencies are already in execution order
      let repoObj = project.repositories.filterIt(it.name == repo)[0]
      let depsmet = repoObj.dependencies.allIt(
        it notin change.affectedRepos or it in executionOrder
      )
      
      if depsmet:
        executionOrder.add(repo)
        executed.add(repo)
    
    # Remove executed repos from remaining
    remaining = remaining.filterIt(it notin executed)
  
  echo "\nExecution order:"
  for i, repo in executionOrder:
    echo &"  {i + 1}. {repo}: {change.commits[repo]}"
    
    result["execution_plan"].add(%* {
      "step": i + 1,
      "repository": repo,
      "action": "commit",
      "message": change.commits[repo],
      "depends_on": project.repositories
        .filterIt(it.name == repo)[0]
        .dependencies
        .filterIt(it in change.affectedRepos)
    })

proc executeMultiRepoWorkflow*(change: CrossRepoChange, 
                              project: MultiRepoProject,
                              dryRun = true) {.async.} =
  ## Executes a cross-repository change workflow using MCP
  echo &"\n{'=' * 60}"
  echo &"Executing Multi-Repo Workflow: {change.description}"
  echo &"{'=' * 60}"
  
  let client = newMcpClient("http://localhost:8080/mcp")
  let plan = planCrossRepoChange(change, project)
  
  if dryRun:
    echo "\n[DRY RUN MODE - Using MCP proposal mode]"
    
    # Use MCP to propose the multi-repo split
    let proposalParams = %*{
      "commitRange": "HEAD~1..HEAD",
      "repositories": change.affectedRepos
    }
    
    try:
      let proposalResp = await client.call("proposeMultiRepoSplit", proposalParams)
      let proposal = proposalResp["result"]
      
      echo fmt"\nProposal confidence: {proposal["confidence"].getFloat:.1%}"
      echo fmt"Commit groups: {proposal["commitGroups"].len}"
    except MpcError as e:
      echo fmt"\nMCP Error: {e.msg}"
  else:
    # Execute via MCP
    echo "\n[EXECUTION MODE - Using MCP automation]"
    
    let autoParams = %*{
      "commitRange": "HEAD~1..HEAD",
      "repositories": change.affectedRepos
    }
    
    try:
      let autoResp = await client.call("automateMultiRepoSplit", autoParams)
      let result = autoResp["result"]
      
      if result["success"].getBool:
        echo "\n✓ Multi-repo workflow executed successfully!"
        
        echo "\nCommits created:"
        for repo, commits in result["execution"]["commitsByRepo"]:
          echo fmt"  {repo}: {commits.len} commits"
    except MpcError as e:
      echo fmt"\nMCP Error: {e.msg}"
  
  echo &"\n{'=' * 60}"

# Semantic analysis across repositories
proc analyzeCrossRepoImpact*(change: CrossRepoChange, 
                            project: MultiRepoProject): JsonNode =
  ## Analyzes the impact of changes across repositories
  result = %* {
    "analysis_type": "cross-repository-impact",
    "change": change.description,
    "metrics": {
      "affected_repos": change.affectedRepos.len,
      "total_repos": project.repositories.len,
      "impact_percentage": (change.affectedRepos.len / 
                           project.repositories.len * 100).formatFloat(ffDecimal, 1)
    },
    "semantic_categories": {},
    "deployment_strategy": "",
    "rollback_plan": []
  }
  
  # Categorize changes semantically
  for repo, commit in change.commits:
    let category = if commit.startsWith("feat"):
        "feature"
      elif commit.startsWith("fix"):
        "bugfix"
      elif commit.startsWith("refactor"):
        "refactoring"
      else:
        "other"
    
    if category notin result["semantic_categories"]:
      result["semantic_categories"][category] = newJArray()
    
    result["semantic_categories"][category].add(%* {
      "repository": repo,
      "commit": commit
    })
  
  # Determine deployment strategy
  if change.affectedRepos.len > project.repositories.len div 2:
    result["deployment_strategy"] = %"phased"
    echo "\n⚠️  High impact change affecting >50% of repositories"
    echo "Recommended: Phased deployment with monitoring"
  else:
    result["deployment_strategy"] = %"standard"
  
  # Generate rollback plan
  for i in countdown(change.order.len - 1, 0):
    let repo = change.order[i]
    result["rollback_plan"].add(%* {
      "step": change.order.len - i,
      "repository": repo,
      "action": "revert last commit"
    })

# Advanced multi-repo features
proc generateMultiRepoReport*(project: MultiRepoProject, 
                             changes: seq[CrossRepoChange]): JsonNode =
  ## Generates comprehensive multi-repo project report
  result = %* {
    "project": project.name,
    "generated_at": now().format("yyyy-MM-dd HH:mm:ss"),
    "repositories": project.repositories.len,
    "total_changes": changes.len,
    "repository_details": [],
    "change_history": [],
    "insights": [],
    "recommendations": []
  }
  
  # Add repository details
  for repo in project.repositories:
    result["repository_details"].add(%* {
      "name": repo.name,
      "path": repo.path,
      "dependencies": repo.dependencies,
      "dependents": project.repositories
        .filterIt(repo.name in it.dependencies)
        .mapIt(it.name)
    })
  
  # Add change history
  for change in changes:
    let impact = analyzeCrossRepoImpact(change, project)
    result["change_history"].add(%* {
      "description": change.description,
      "impact": impact["metrics"],
      "categories": impact["semantic_categories"]
    })
  
  # Generate insights
  let avgReposPerChange = changes
    .mapIt(it.affectedRepos.len)
    .foldl(a + b, 0) / changes.len
  
  result["insights"].add(%&"Average repositories affected per change: {avgReposPerChange:.1f}")
  
  if avgReposPerChange > 3:
    result["insights"].add(%"High coupling detected between repositories")
    result["recommendations"].add(%"Consider consolidating tightly coupled services")
  
  # Check for hotspot repositories
  var repoChangeCount = initCountTable[string]()
  for change in changes:
    for repo in change.affectedRepos:
      repoChangeCount.inc(repo)
  
  let mostChanged = repoChangeCount.largest
  if mostChanged.val > changes.len div 2:
    result["insights"].add(%&"Repository '{mostChanged.key}' is a change hotspot")
    result["recommendations"].add(%&"Review architecture around {mostChanged.key}")

# Example workflow demonstration
proc demonstrateMultiRepoWorkflow*() {.async.} =
  echo "Multi-Repository Workflow Demonstration"
  echo "======================================="
  echo "Note: Requires MCP server in multi-repo mode (--hub)"
  echo ""
  
  try:
    # Initialize workspace
    await initializeMultiRepoWorkspace(microservicesProject)
    
    # Analyze dependencies
    let deps = analyzeRepoDependencies(microservicesProject)
    
    # MCP-based cross-repo analysis
    echo "\n\nUsing MCP for cross-repository analysis..."
    let client = newMcpClient("http://localhost:8080/mcp")
    
    # Analyze recent changes across all repos
    let analysisParams = %*{
      "commitRange": "HEAD~5..HEAD"
    }
    
    let analysisResp = await client.call("analyzeMultiRepoCommits", analysisParams)
    let analysis = analysisResp["result"]
    
    if analysis["hasCrossDependencies"].getBool:
      echo "\n⚠️  Cross-repository dependencies detected!"
      for dep in analysis["crossDependencies"]:
        echo fmt"  {dep["from"].getStr} → {dep["to"].getStr}"
    
    # Process each change
    for change in exampleChanges:
      echo &"\n{'*' * 60}"
      await executeMultiRepoWorkflow(change, microservicesProject, dryRun = true)
      
      let impact = analyzeCrossRepoImpact(change, microservicesProject)
      echo "\nImpact Analysis:"
      echo impact.pretty
    
    # Generate comprehensive report
    let outputDir = "build/multi-repo-reports"
    createDir(outputDir)
    
    let report = generateMultiRepoReport(microservicesProject, exampleChanges)
    writeFile(outputDir / "multi-repo-report.json", report.pretty)
    
    echo &"\n\nMulti-repo report saved to: {outputDir}/multi-repo-report.json"
    echo "\nKey Insights:"
    for insight in report["insights"]:
      echo &"  • {insight.getStr}"
    
    echo "\nRecommendations:"
    for rec in report["recommendations"]:
      echo &"  • {rec.getStr}"
      
  except MpcError as e:
    echo fmt"\nMCP Error: {e.msg}"
    echo "Make sure the server is running in multi-repo mode:"
    echo "  nimble run -- --hub --port=8080"
  except Exception as e:
    echo fmt"\nError: {e.msg}"

# MCP-specific multi-repo tools demonstration
proc demonstrateMcpMultiRepoTools() {.async.} =
  echo "\n\nMCP Multi-Repository Tools"
  echo "==========================" 
  
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # 1. List configured repositories
    echo "\n1. Analyzing configured repositories..."
    let listParams = %*{"commitRange": "HEAD~1..HEAD"}
    let listResp = await client.call("analyzeMultiRepoCommits", listParams)
    
    echo "   Configured repositories:"
    for repo in listResp["result"]["repositories"].keys:
      echo fmt"   - {repo}"
    
    # 2. Propose coordinated split
    echo "\n2. Proposing coordinated commit split..."
    let proposalParams = %*{
      "commitRange": "HEAD~3..HEAD"
    }
    
    let proposalResp = await client.call("proposeMultiRepoSplit", proposalParams)
    let proposal = proposalResp["result"]
    
    echo fmt"   Confidence: {proposal["confidence"].getFloat:.1%}"
    echo fmt"   Proposed groups: {proposal["commitGroups"].len}"
    
    for group in proposal["commitGroups"]:
      echo fmt"\n   Group: {group["description"].getStr}"
      for repo in group["repositories"].keys:
        echo fmt"     - {repo}"
    
    # 3. Check for dependency violations
    echo "\n3. Checking dependency constraints..."
    if proposal["dependencyViolations"].len > 0:
      echo "   ⚠️  Dependency violations found:"
      for violation in proposal["dependencyViolations"]:
        echo fmt"   - {violation.getStr}"
    else:
      echo "   ✓ All dependency constraints satisfied"
    
    # 4. Demonstrate automated execution (dry run)
    echo "\n4. Automated multi-repo split (dry run)..."
    let autoParams = %*{
      "commitRange": "HEAD~1..HEAD",
      "dryRun": true
    }
    
    # Note: In real usage, remove dryRun for actual execution
    echo "   [Dry run - no actual changes]"
    
  except MpcError as e:
    echo fmt"\nMCP Error: {e.msg}"
    echo "\nTroubleshooting:"
    echo "1. Ensure server is in multi-repo mode: nimble run -- --hub"
    echo "2. Check repository configuration in repos.toml"
    echo "3. Verify all repositories are accessible"

when isMainModule:
  waitFor demonstrateMultiRepoWorkflow()
  waitFor demonstrateMcpMultiRepoTools()