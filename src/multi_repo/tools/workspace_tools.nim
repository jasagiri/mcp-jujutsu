## MCP Tools for Jujutsu Workspace Management
##
## This module provides MCP tools for managing Jujutsu workspaces
## and implementing workspace-based development workflows

import std/[asyncdispatch, json, strutils, sequtils, options, tables]
import ../../core/repository/jujutsu_workspace
import ../../core/logging/logger

# MCP Tool: List Workspaces
proc listWorkspacesTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to list all workspaces in a repository
  let repositoryPath = params["repository_path"].getStr()
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    let workspaces = await manager.listWorkspaces()
    
    result = %* {
      "workspaces": workspaces.mapIt(%* {
        "name": it.name,
        "path": it.path,
        "is_active": it.isActive,
        "last_sync": it.lastSync,
        "conflicts": it.conflicts.len
      }),
      "total_count": workspaces.len,
      "active_workspace": if manager.activeWorkspace.isSome: 
                           %manager.activeWorkspace.get() 
                         else: newJNull()
    }
    
    let ctx = newLogContext("mcp-tool", "list-workspaces")
      .withMetadata("repository", repositoryPath)
      .withMetadata("count", $workspaces.len)
    info("Listed workspaces successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "list-workspaces")
      .withMetadata("repository", repositoryPath)
    error("Failed to list workspaces: " & e.msg, ctx)
    
    result = %* {
      "error": e.msg,
      "workspaces": [],
      "total_count": 0
    }

# MCP Tool: Create Workspace
proc createWorkspaceTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to create a new workspace
  let repositoryPath = params["repository_path"].getStr()
  let workspaceName = params["workspace_name"].getStr()
  let workspacePath = params.getOrDefault("workspace_path").getStr("")
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    let workspace = await manager.createWorkspace(workspaceName, workspacePath)
    
    result = %* {
      "status": "success",
      "workspace": {
        "name": workspace.name,
        "path": workspace.path,
        "repository": workspace.repository
      },
      "message": "Workspace created successfully"
    }
    
    let ctx = newLogContext("mcp-tool", "create-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
      .withMetadata("path", workspace.path)
    info("Created workspace successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "create-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
    error("Failed to create workspace: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to create workspace"
    }

# MCP Tool: Switch Workspace
proc switchWorkspaceTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to switch to a different workspace
  let repositoryPath = params["repository_path"].getStr()
  let workspaceName = params["workspace_name"].getStr()
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    # First list workspaces to populate the manager
    discard await manager.listWorkspaces()
    
    await manager.switchWorkspace(workspaceName)
    
    result = %* {
      "status": "success",
      "active_workspace": workspaceName,
      "message": "Switched to workspace successfully"
    }
    
    let ctx = newLogContext("mcp-tool", "switch-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
    info("Switched workspace successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "switch-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
    error("Failed to switch workspace: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to switch workspace"
    }

# MCP Tool: Analyze Workspace Changes
proc analyzeWorkspaceChangesTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to analyze changes in a workspace
  let repositoryPath = params["repository_path"].getStr()
  let workspaceName = params["workspace_name"].getStr()
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    # First list workspaces to populate the manager
    discard await manager.listWorkspaces()
    
    let analysis = await manager.analyzeWorkspaceChanges(workspaceName)
    
    result = %* {
      "status": "success",
      "analysis": analysis,
      "message": "Workspace analysis completed"
    }
    
    let ctx = newLogContext("mcp-tool", "analyze-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
    info("Analyzed workspace changes successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "analyze-workspace")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
    error("Failed to analyze workspace: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to analyze workspace"
    }

# MCP Tool: Plan Workspace Workflow
proc planWorkspaceWorkflowTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to plan a workspace-based development workflow
  let repositoryPath = params["repository_path"].getStr()
  let strategyStr = params["strategy"].getStr()
  let features = params["features"].getElems().mapIt(it.getStr())
  
  try:
    let strategy = case strategyStr:
      of "feature_branches": wsFeatureBranches
      of "environments": wsEnvironments  
      of "team_members": wsTeamMembers
      of "experimentation": wsExperimentation
      else: wsFeatureBranches
    
    let manager = newWorkspaceManager(repositoryPath)
    let plan = await manager.planWorkspaceWorkflow(strategy, features)
    
    result = %* {
      "status": "success",
      "plan": plan,
      "message": "Workspace workflow planned successfully"
    }
    
    let ctx = newLogContext("mcp-tool", "plan-workflow")
      .withMetadata("repository", repositoryPath)
      .withMetadata("strategy", strategyStr)
      .withMetadata("features", $features.len)
    info("Planned workspace workflow successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "plan-workflow")
      .withMetadata("repository", repositoryPath)
      .withMetadata("strategy", strategyStr)
    error("Failed to plan workflow: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to plan workspace workflow"
    }

# MCP Tool: Execute Workspace Workflow
proc executeWorkspaceWorkflowTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to execute a planned workspace workflow
  let repositoryPath = params["repository_path"].getStr()
  let plan = params["plan"]
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    let result_data = await manager.executeWorkspaceWorkflow(plan)
    
    result = %* {
      "status": "success",
      "execution_result": result_data,
      "message": "Workspace workflow executed successfully"
    }
    
    let ctx = newLogContext("mcp-tool", "execute-workflow")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workflowId", result_data["workflow_id"].getStr())
    info("Executed workspace workflow successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "execute-workflow")
      .withMetadata("repository", repositoryPath)
    error("Failed to execute workflow: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to execute workspace workflow"
    }

# MCP Tool: Workspace Semantic Analysis
proc workspaceSemanticAnalysisTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to perform semantic analysis across workspaces
  let repositoryPath = params["repository_path"].getStr()
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    # First list workspaces to populate the manager
    discard await manager.listWorkspaces()
    
    let analysis = await manager.analyzeWorkspaceSemantics()
    
    result = %* {
      "status": "success",
      "semantic_analysis": analysis,
      "message": "Workspace semantic analysis completed"
    }
    
    let ctx = newLogContext("mcp-tool", "semantic-analysis")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspaces", $len(manager.workspaces))
    info("Completed workspace semantic analysis", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "semantic-analysis")
      .withMetadata("repository", repositoryPath)
    error("Failed to perform semantic analysis: " & e.msg, ctx)
    
    result = %* {
      "status": "error", 
      "error": e.msg,
      "message": "Failed to perform workspace semantic analysis"
    }

# MCP Tool: Workspace Operation
proc workspaceOperationTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## MCP tool to execute operations in a workspace
  let repositoryPath = params["repository_path"].getStr()
  let workspaceName = params["workspace_name"].getStr()
  let operation = params["operation"].getStr()
  let target = params.getOrDefault("target").getStr("")
  let operationParams = if params.hasKey("parameters"): params["parameters"] else: %*{}
  
  try:
    let manager = newWorkspaceManager(repositoryPath)
    # First list workspaces to populate the manager
    discard await manager.listWorkspaces()
    
    let workspaceOp = WorkspaceOperation(
      workspace: workspaceName,
      operation: operation,
      target: target,
      parameters: operationParams
    )
    
    let opResult = await manager.executeWorkspaceOperation(workspaceOp)
    
    result = %* {
      "status": "success",
      "operation_result": opResult,
      "message": "Workspace operation completed successfully"
    }
    
    let ctx = newLogContext("mcp-tool", "workspace-operation")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
      .withMetadata("operation", operation)
    info("Executed workspace operation successfully", ctx)
    
  except Exception as e:
    let ctx = newLogContext("mcp-tool", "workspace-operation")
      .withMetadata("repository", repositoryPath)
      .withMetadata("workspace", workspaceName)
      .withMetadata("operation", operation)
    error("Failed to execute workspace operation: " & e.msg, ctx)
    
    result = %* {
      "status": "error",
      "error": e.msg,
      "message": "Failed to execute workspace operation"
    }