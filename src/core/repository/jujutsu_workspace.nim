## Jujutsu Workspace Management Module
##
## This module provides comprehensive support for Jujutsu workspace operations,
## enabling parallel development across multiple working copies

import std/[asyncdispatch, json, os, sequtils, strutils, tables, options, osproc, times]
import ../logging/logger
import jujutsu_version

type
  JujutsuWorkspace* = object
    name*: string
    path*: string
    repository*: string  # Path to the repository root
    isActive*: bool
    lastSync*: string    # Last sync timestamp
    conflicts*: seq[string]  # List of conflicted files
    
  WorkspaceManager* = ref object
    repositoryRoot*: string
    workspaces*: Table[string, JujutsuWorkspace]
    activeWorkspace*: Option[string]
    
  WorkspaceOperation* = object
    workspace*: string
    operation*: string
    target*: string
    parameters*: JsonNode
    
  WorkflowStrategy* = enum
    wsFeatureBranches   ## Each workspace for feature development
    wsEnvironments      ## Each workspace for different environments
    wsTeamMembers       ## Each workspace for team member
    wsExperimentation   ## Each workspace for experiments
  
  WorkspaceStrategy* = WorkflowStrategy  ## Alias for compatibility
  
  WorkspaceAnalysis* = object
    totalWorkspaces*: int
    activeWorkspaces*: int
    conflictedWorkspaces*: int
    staleWorkspaces*: int
    recommendations*: seq[string]
  
  WorkspaceExecutionResult* = object
    success*: bool
    strategy*: WorkspaceStrategy
    operation*: string
    results*: seq[string]
    errors*: seq[string]
  
  WorkspaceCommand* = object
    command*: string
    workspacePath*: string
    workspaceName*: string

proc newWorkspaceManager*(repositoryRoot: string): WorkspaceManager =
  ## Create a new workspace manager for a repository
  result = WorkspaceManager(
    repositoryRoot: repositoryRoot,
    workspaces: initTable[string, JujutsuWorkspace](),
    activeWorkspace: none(string)
  )

proc listWorkspaces*(manager: WorkspaceManager): Future[seq[JujutsuWorkspace]] {.async.} =
  ## List all workspaces in the repository
  let commands = await getJujutsuCommands()
  let capabilities = getJujutsuCapabilities(commands.version)
  
  if not capabilities.hasWorkspaceCommand:
    let ctx = newLogContext("workspace", "list")
      .withMetadata("repository", manager.repositoryRoot)
    warn("Workspace commands not available in this Jujutsu version", ctx)
    return @[]
  
  # Execute jj workspace list
  let cmd = "jj workspace list"
  let (output, exitCode) = execCmdEx(cmd, workingDir = manager.repositoryRoot)
  
  if exitCode != 0:
    let ctx = newLogContext("workspace", "list")
      .withMetadata("repository", manager.repositoryRoot)
      .withMetadata("exitCode", $exitCode)
    error("Failed to list workspaces: " & output, ctx)
    raise newException(IOError, "Failed to list workspaces: " & output)
  
  # Parse workspace list output
  for line in output.splitLines():
    if line.strip().len == 0:
      continue
      
    # Parse workspace info from output
    # Format typically: "workspace_name: /path/to/workspace"
    let parts = line.split(":")
    if parts.len >= 2:
      let name = parts[0].strip()
      let path = parts[1].strip()
      
      let workspace = JujutsuWorkspace(
        name: name,
        path: path,
        repository: manager.repositoryRoot,
        isActive: line.contains("(current)") or line.contains("*"),
        lastSync: "",
        conflicts: @[]
      )
      
      result.add(workspace)
      manager.workspaces[name] = workspace
      
      if workspace.isActive:
        manager.activeWorkspace = some(name)

proc createWorkspace*(manager: WorkspaceManager, 
                     name: string, 
                     path: string = ""): Future[JujutsuWorkspace] {.async.} =
  ## Create a new workspace
  let commands = await getJujutsuCommands()
  let capabilities = getJujutsuCapabilities(commands.version)
  
  if not capabilities.hasWorkspaceCommand:
    raise newException(IOError, "Workspace commands not available in this Jujutsu version")
  
  let workspacePath = if path == "": manager.repositoryRoot / ".." / name else: path
  
  # Create workspace directory if it doesn't exist
  if not dirExists(parentDir(workspacePath)):
    createDir(parentDir(workspacePath))
  
  # Execute jj workspace add
  let cmd = "jj workspace add " & name & " " & workspacePath
  let (output, exitCode) = execCmdEx(cmd, workingDir = manager.repositoryRoot)
  
  if exitCode != 0:
    let ctx = newLogContext("workspace", "create")
      .withMetadata("name", name)
      .withMetadata("path", workspacePath)
      .withMetadata("exitCode", $exitCode)
    error("Failed to create workspace: " & output, ctx)
    raise newException(IOError, "Failed to create workspace: " & output)
  
  result = JujutsuWorkspace(
    name: name,
    path: workspacePath,
    repository: manager.repositoryRoot,
    isActive: false,
    lastSync: "",
    conflicts: @[]
  )
  
  manager.workspaces[name] = result
  
  let ctx = newLogContext("workspace", "create")
    .withMetadata("name", name)
    .withMetadata("path", workspacePath)
  info("Workspace created successfully", ctx)

proc switchWorkspace*(manager: WorkspaceManager, name: string): Future[void] {.async.} =
  ## Switch to a different workspace
  if name notin manager.workspaces:
    raise newException(ValueError, "Workspace not found: " & name)
  
  # Change current directory to workspace
  let workspace = manager.workspaces[name]
  setCurrentDir(workspace.path)
  
  # Update active workspace
  if manager.activeWorkspace.isSome:
    let oldActive = manager.activeWorkspace.get()
    manager.workspaces[oldActive].isActive = false
  
  manager.workspaces[name].isActive = true
  manager.activeWorkspace = some(name)
  
  let ctx = newLogContext("workspace", "switch")
    .withMetadata("workspace", name)
    .withMetadata("path", workspace.path)
  info("Switched to workspace", ctx)

proc updateWorkspace*(manager: WorkspaceManager, name: string): Future[void] {.async.} =
  ## Update a workspace to latest changes
  if name notin manager.workspaces:
    raise newException(ValueError, "Workspace not found: " & name)
  
  let workspace = manager.workspaces[name]
  
  # Execute update in workspace directory
  let cmd = "jj workspace update-stale"
  let (output, exitCode) = execCmdEx(cmd, workingDir = workspace.path)
  
  if exitCode != 0:
    let ctx = newLogContext("workspace", "update")
      .withMetadata("workspace", name)
      .withMetadata("exitCode", $exitCode)
    error("Failed to update workspace: " & output, ctx)
    raise newException(IOError, "Failed to update workspace: " & output)
  
  # Update sync timestamp
  manager.workspaces[name].lastSync = $now()
  
  let ctx = newLogContext("workspace", "update")
    .withMetadata("workspace", name)
  info("Workspace updated successfully", ctx)

proc removeWorkspace*(manager: WorkspaceManager, name: string): Future[void] {.async.} =
  ## Remove a workspace
  if name notin manager.workspaces:
    raise newException(ValueError, "Workspace not found: " & name)
  
  let workspace = manager.workspaces[name]
  
  if workspace.isActive:
    raise newException(ValueError, "Cannot remove active workspace")
  
  # Execute workspace forget
  let cmd = "jj workspace forget " & name
  let (output, exitCode) = execCmdEx(cmd, workingDir = manager.repositoryRoot)
  
  if exitCode != 0:
    let ctx = newLogContext("workspace", "remove")
      .withMetadata("workspace", name)
      .withMetadata("exitCode", $exitCode)
    error("Failed to remove workspace: " & output, ctx)
    raise newException(IOError, "Failed to remove workspace: " & output)
  
  # Remove from manager
  manager.workspaces.del(name)
  
  if manager.activeWorkspace.isSome and manager.activeWorkspace.get() == name:
    manager.activeWorkspace = none(string)
  
  let ctx = newLogContext("workspace", "remove")
    .withMetadata("workspace", name)
  info("Workspace removed successfully", ctx)

proc analyzeWorkspaceChanges*(manager: WorkspaceManager, 
                             workspace: string): Future[JsonNode] {.async.} =
  ## Analyze changes in a specific workspace
  if workspace notin manager.workspaces:
    raise newException(ValueError, "Workspace not found: " & workspace)
  
  let ws = manager.workspaces[workspace]
  
  # Get status in workspace
  let statusCmd = "jj status"
  let (statusOutput, statusCode) = execCmdEx(statusCmd, workingDir = ws.path)
  
  if statusCode != 0:
    raise newException(IOError, "Failed to get workspace status: " & statusOutput)
  
  # Get diff for current changes
  let diffCmd = "jj diff"
  let (diffOutput, diffCode) = execCmdEx(diffCmd, workingDir = ws.path)
  
  result = %* {
    "workspace": workspace,
    "path": ws.path,
    "status": statusOutput,
    "has_changes": not statusOutput.contains("The working copy is clean"),
    "diff": if diffCode == 0: diffOutput else: "",
    "conflicts": ws.conflicts,
    "last_sync": ws.lastSync
  }

proc executeWorkspaceOperation*(manager: WorkspaceManager, 
                               op: WorkspaceOperation): Future[JsonNode] {.async.} =
  ## Execute an operation in a specific workspace
  if op.workspace notin manager.workspaces:
    raise newException(ValueError, "Workspace not found: " & op.workspace)
  
  let workspace = manager.workspaces[op.workspace]
  
  let ctx = newLogContext("workspace", "operation")
    .withMetadata("workspace", op.workspace)
    .withMetadata("operation", op.operation)
    .withMetadata("target", op.target)
  
  case op.operation:
  of "commit":
    let message = op.parameters["message"].getStr()
    let cmd = "jj describe -m \"" & message.replace("\"", "\\\"") & "\""
    let (output, exitCode) = execCmdEx(cmd, workingDir = workspace.path)
    
    if exitCode != 0:
      error("Failed to commit in workspace: " & output, ctx)
      raise newException(IOError, "Failed to commit: " & output)
    
    info("Commit successful in workspace", ctx)
    result = %* {"status": "success", "output": output}
    
  of "merge":
    let source = op.parameters["source"].getStr()
    let cmd = "jj merge " & source
    let (output, exitCode) = execCmdEx(cmd, workingDir = workspace.path)
    
    if exitCode != 0:
      error("Failed to merge in workspace: " & output, ctx)
      result = %* {"status": "conflict", "output": output}
    else:
      info("Merge successful in workspace", ctx)
      result = %* {"status": "success", "output": output}
      
  of "rebase":
    let destination = op.parameters["destination"].getStr()
    let cmd = "jj rebase -d " & destination
    let (output, exitCode) = execCmdEx(cmd, workingDir = workspace.path)
    
    if exitCode != 0:
      error("Failed to rebase in workspace: " & output, ctx)
      result = %* {"status": "conflict", "output": output}
    else:
      info("Rebase successful in workspace", ctx)
      result = %* {"status": "success", "output": output}
      
  else:
    raise newException(ValueError, "Unknown operation: " & op.operation)

proc planWorkspaceWorkflow*(manager: WorkspaceManager, 
                           strategy: WorkflowStrategy,
                           features: seq[string]): Future[JsonNode] {.async.} =
  ## Plan a workspace-based development workflow
  result = %* {
    "strategy": $strategy,
    "features": features,
    "workspaces": [],
    "workflow_steps": [],
    "parallel_capacity": features.len
  }
  
  case strategy:
  of wsFeatureBranches:
    # Create one workspace per feature
    for i, feature in features:
      let workspaceName = "feature-" & feature.replace(" ", "-").toLowerAscii()
      result["workspaces"].add(%* {
        "name": workspaceName,
        "purpose": "feature development",
        "feature": feature,
        "path": manager.repositoryRoot / ".." / workspaceName
      })
      
      result["workflow_steps"].add(%* {
        "step": i + 1,
        "action": "create_workspace",
        "workspace": workspaceName,
        "description": "Create workspace for " & feature
      })
      
      result["workflow_steps"].add(%* {
        "step": i + 2,
        "action": "develop_feature",
        "workspace": workspaceName,
        "description": "Implement " & feature
      })
  
  of wsEnvironments:
    # Create workspaces for different environments
    let environments = @["development", "staging", "production"]
    for i, env in environments:
      let workspaceName = env & "-env"
      result["workspaces"].add(%* {
        "name": workspaceName,
        "purpose": "environment testing",
        "environment": env,
        "path": manager.repositoryRoot / ".." / workspaceName
      })
  
  of wsTeamMembers:
    # Create workspaces for team members
    for i, feature in features:
      let workspaceName = "dev-" & $i
      result["workspaces"].add(%* {
        "name": workspaceName,
        "purpose": "individual development",
        "assigned_feature": feature,
        "path": manager.repositoryRoot / ".." / workspaceName
      })
  
  of wsExperimentation:
    # Create experimental workspaces
    for i, feature in features:
      let workspaceName = "experiment-" & $i
      result["workspaces"].add(%* {
        "name": workspaceName,
        "purpose": "experimentation",
        "experiment": feature,
        "path": manager.repositoryRoot / ".." / workspaceName
      })

proc executeWorkspaceWorkflow*(manager: WorkspaceManager, 
                              plan: JsonNode): Future[JsonNode] {.async.} =
  ## Execute a planned workspace workflow
  result = %* {
    "workflow_id": "wf-" & $now().toTime().toUnix(),
    "status": "running",
    "completed_steps": [],
    "failed_steps": [],
    "created_workspaces": []
  }
  
  for step in plan["workflow_steps"]:
    try:
      let action = step["action"].getStr()
      let workspaceName = step["workspace"].getStr()
      
      case action:
      of "create_workspace":
        let workspacePath = plan["workspaces"]
          .getElems()
          .filterIt(it["name"].getStr() == workspaceName)[0]["path"].getStr()
        
        let workspace = await manager.createWorkspace(workspaceName, workspacePath)
        result["created_workspaces"].add(%workspaceName)
        result["completed_steps"].add(step)
        
      of "develop_feature":
        # This would involve actual development work
        # For now, just mark as completed
        result["completed_steps"].add(step)
        
      else:
        result["failed_steps"].add(%* {
          "step": step,
          "error": "Unknown action: " & action
        })
        
    except Exception as e:
      result["failed_steps"].add(%* {
        "step": step,
        "error": e.msg
      })
  
  if result["failed_steps"].getElems().len == 0:
    result["status"] = %"completed"
  else:
    result["status"] = %"partial"

# Workspace-aware semantic analysis
proc analyzeWorkspaceSemantics*(manager: WorkspaceManager): Future[JsonNode] {.async.} =
  ## Perform semantic analysis across all workspaces
  result = %* {
    "analysis_type": "multi_workspace_semantic",
    "workspaces": {},
    "cross_workspace_conflicts": [],
    "merge_recommendations": [],
    "collaboration_insights": {}
  }
  
  # Analyze each workspace
  for name, workspace in manager.workspaces:
    let analysis = await manager.analyzeWorkspaceChanges(name)
    result["workspaces"][name] = analysis
    
    # Check for potential conflicts with other workspaces
    if analysis["has_changes"].getBool():
      for otherName, otherWorkspace in manager.workspaces:
        if otherName != name:
          let otherAnalysis = await manager.analyzeWorkspaceChanges(otherName)
          if otherAnalysis["has_changes"].getBool():
            # Potential conflict detected
            result["cross_workspace_conflicts"].add(%* {
              "workspace1": name,
              "workspace2": otherName,
              "risk_level": "medium",
              "recommendation": "coordinate merge timing"
            })
  
  # Generate merge recommendations
  let activeWorkspaces = manager.workspaces.values.toSeq()
    .filterIt(it.isActive or it.lastSync != "")
  
  if activeWorkspaces.len > 1:
    result["merge_recommendations"].add(%* {
      "strategy": "sequential_merge",
      "order": activeWorkspaces.mapIt(it.name),
      "reason": "minimize conflicts"
    })

# Standalone convenience functions for easier use
proc parseWorkspaceList*(output: string): seq[JujutsuWorkspace] =
  ## Parse workspace list output from jj workspace list
  result = @[]
  
  for line in output.strip().splitLines():
    if line.strip().len == 0:
      continue
    
    # Expected format: "name: path (status)"
    if not line.contains(":"):
      continue
    
    let parts = line.split(":", 1)
    if parts.len != 2:
      continue
    
    let name = parts[0].strip()
    if name.len == 0:
      continue
    
    let rest = parts[1].strip()
    var path = rest
    var isActive = false
    
    # Check for status markers
    if rest.contains(" (active)"):
      path = rest.replace(" (active)", "").strip()
      isActive = true
    elif rest.contains(" (stale)"):
      path = rest.replace(" (stale)", "").strip()
    
    result.add(JujutsuWorkspace(
      name: name,
      path: path,
      repository: "",
      isActive: isActive,
      lastSync: if isActive: "recent" else: "old",
      conflicts: @[]
    ))

proc listWorkspaces*(repoPath: string): Future[seq[JujutsuWorkspace]] {.async.} =
  ## List workspaces for a repository path (standalone function)
  let manager = newWorkspaceManager(repoPath)
  return await manager.listWorkspaces()

proc createWorkspace*(repoPath: string, name: string, workspacePath: string): Future[void] {.async.} =
  ## Create a workspace (standalone function)
  if name.len == 0:
    raise newException(ValueError, "Workspace name cannot be empty")
  
  if workspacePath.len == 0:
    raise newException(ValueError, "Workspace path cannot be empty")
  
  let manager = newWorkspaceManager(repoPath)
  discard await manager.createWorkspace(name, workspacePath)

proc switchWorkspace*(repoPath: string, name: string): Future[void] {.async.} =
  ## Switch to a workspace (standalone function)
  let manager = newWorkspaceManager(repoPath)
  await manager.switchWorkspace(name)

proc analyzeWorkspaceState*(repoPath: string, workspaces: seq[JujutsuWorkspace]): Future[WorkspaceAnalysis] {.async.} =
  ## Analyze workspace state (standalone function)
  result = WorkspaceAnalysis(
    totalWorkspaces: workspaces.len,
    activeWorkspaces: 0,
    conflictedWorkspaces: 0,
    staleWorkspaces: 0,
    recommendations: @[]
  )
  
  for workspace in workspaces:
    if workspace.isActive:
      result.activeWorkspaces += 1
    
    if workspace.conflicts.len > 0:
      result.conflictedWorkspaces += 1
    
    if workspace.lastSync == "old":
      result.staleWorkspaces += 1
  
  # Generate recommendations
  if result.totalWorkspaces == 0:
    result.recommendations.add("No workspaces found. Consider creating workspaces for parallel development.")
  elif result.conflictedWorkspaces > 0:
    result.recommendations.add("Resolve conflicts in " & $result.conflictedWorkspaces & " workspace(s)")
  elif result.staleWorkspaces > 0:
    result.recommendations.add("Update " & $result.staleWorkspaces & " stale workspace(s)")
  else:
    result.recommendations.add("All workspaces are up to date")

# Forward declaration
proc getWorkspaceCommands*(workspaces: seq[JujutsuWorkspace], strategy: WorkspaceStrategy, 
                         operation: string, message: string): seq[WorkspaceCommand]

proc executeWorkspaceStrategy*(repoPath: string, workspaces: seq[JujutsuWorkspace], 
                             strategy: WorkspaceStrategy, operation: string): Future[WorkspaceExecutionResult] {.async.} =
  ## Execute workspace strategy (standalone function)
  result = WorkspaceExecutionResult(
    success: false,
    strategy: strategy,
    operation: operation,
    results: @[],
    errors: @[]
  )
  
  try:
    let commands = getWorkspaceCommands(workspaces, strategy, operation, "automated message")
    
    for cmd in commands:
      let (output, exitCode) = execCmdEx(cmd.command)
      
      if exitCode == 0:
        result.results.add("Success: " & cmd.command)
      else:
        result.errors.add("Failed: " & cmd.command & " - " & output)
    
    result.success = result.errors.len == 0
    
  except Exception as e:
    result.errors.add("Execution error: " & e.msg)
    result.success = false

proc getWorkspaceCommands*(workspaces: seq[JujutsuWorkspace], strategy: WorkspaceStrategy, 
                         operation: string, message: string): seq[WorkspaceCommand] =
  ## Get commands for workspace operations
  result = @[]
  
  for workspace in workspaces:
    var command = ""
    
    case operation:
    of "commit":
      command = "jj commit -m \"" & message & "\""
    of "push":
      command = "jj git push"
    of "sync":
      command = "jj workspace update-stale"
    else:
      command = "jj " & operation
    
    result.add(WorkspaceCommand(
      command: command,
      workspacePath: workspace.path,
      workspaceName: workspace.name
    ))