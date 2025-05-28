## Tests for workspace MCP tools
##
## This module tests the MCP tools for workspace management.

import std/[unittest, asyncdispatch, json, options, os, strutils]
import ../../src/multi_repo/tools/workspace_tools
import ../../src/core/repository/jujutsu_workspace

suite "Workspace MCP Tools Tests":
  
  setup:
    # Use a temporary directory for testing
    let testDir = getTempDir() / "mcp_workspace_tools_test"
    if dirExists(testDir):
      removeDir(testDir)
    createDir(testDir)
  
  teardown:
    # Clean up test directory
    let testDir = getTempDir() / "mcp_workspace_tools_test"
    if dirExists(testDir):
      removeDir(testDir)
  
  test "listWorkspacesTool validates required parameters":
    # Test missing repoPath parameter
    let emptyParams = %*{}
    let result = waitFor listWorkspacesTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
  
  test "listWorkspacesTool handles valid parameters":
    let params = %*{
      "repoPath": "/nonexistent/path"
    }
    
    let result = waitFor listWorkspacesTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "createWorkspaceTool validates required parameters":
    # Test missing parameters
    let emptyParams = %*{}
    let result = waitFor createWorkspaceTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
    
    # Test missing name parameter
    let partialParams = %*{
      "repoPath": "/test/path"
    }
    let result2 = waitFor createWorkspaceTool(partialParams)
    
    check result2.hasKey("error")
    check result2["error"]["message"].getStr().contains("name")
  
  test "createWorkspaceTool handles valid parameters":
    let params = %*{
      "repoPath": "/nonexistent/path",
      "name": "test-workspace",
      "path": "/test/workspace/path"
    }
    
    let result = waitFor createWorkspaceTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "switchWorkspaceTool validates required parameters":
    # Test missing parameters
    let emptyParams = %*{}
    let result = waitFor switchWorkspaceTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
    
    # Test missing name parameter
    let partialParams = %*{
      "repoPath": "/test/path"
    }
    let result2 = waitFor switchWorkspaceTool(partialParams)
    
    check result2.hasKey("error")
    check result2["error"]["message"].getStr().contains("name")
  
  test "analyzeWorkspaceTool validates required parameters":
    # Test missing repoPath parameter
    let emptyParams = %*{}
    let result = waitFor analyzeWorkspaceTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
  
  test "analyzeWorkspaceTool handles valid parameters":
    let params = %*{
      "repoPath": "/nonexistent/path"
    }
    
    let result = waitFor analyzeWorkspaceTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "synchronizeWorkspacesTool validates required parameters":
    # Test missing repoPath parameter
    let emptyParams = %*{}
    let result = waitFor synchronizeWorkspacesTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
  
  test "executeWorkspaceOperationTool validates required parameters":
    # Test missing parameters
    let emptyParams = %*{}
    let result = waitFor executeWorkspaceOperationTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"]["message"].getStr().contains("repoPath")
    
    # Test missing operation parameter
    let partialParams = %*{
      "repoPath": "/test/path"
    }
    let result2 = waitFor executeWorkspaceOperationTool(partialParams)
    
    check result2.hasKey("error")
    check result2["error"]["message"].getStr().contains("operation")
  
  test "executeWorkspaceOperationTool handles different operations":
    let params = %*{
      "repoPath": "/nonexistent/path",
      "operation": "commit",
      "message": "test commit"
    }
    
    let result = waitFor executeWorkspaceOperationTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "executeWorkspaceOperationTool handles strategy parameter":
    let params = %*{
      "repoPath": "/nonexistent/path",
      "operation": "commit",
      "message": "test commit",
      "strategy": "environments"
    }
    
    let result = waitFor executeWorkspaceOperationTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "executeWorkspaceOperationTool handles unknown strategy":
    let params = %*{
      "repoPath": "/nonexistent/path", 
      "operation": "commit",
      "message": "test commit",
      "strategy": "unknown_strategy"
    }
    
    let result = waitFor executeWorkspaceOperationTool(params)
    # Should still try to execute with default strategy
    check result.hasKey("error")
  
  test "synchronizeWorkspacesTool handles optional target parameter":
    let params = %*{
      "repoPath": "/nonexistent/path",
      "target": "specific-workspace"
    }
    
    let result = waitFor synchronizeWorkspacesTool(params)
    # Should return error for non-existent path
    check result.hasKey("error")
  
  test "tool error messages are properly formatted":
    let emptyParams = %*{}
    let result = waitFor listWorkspacesTool(emptyParams)
    
    check result.hasKey("error")
    check result["error"].hasKey("code")
    check result["error"].hasKey("message")
    check result["error"]["code"].getInt() == -32602  # Invalid params error code
  
  test "tools handle null parameters gracefully":
    let nullParams = newJNull()
    
    let result1 = waitFor listWorkspacesTool(nullParams)
    check result1.hasKey("error")
    
    let result2 = waitFor createWorkspaceTool(nullParams)
    check result2.hasKey("error")
    
    let result3 = waitFor switchWorkspaceTool(nullParams)
    check result3.hasKey("error")
    
    let result4 = waitFor analyzeWorkspaceTool(nullParams)
    check result4.hasKey("error")
    
    let result5 = waitFor synchronizeWorkspacesTool(nullParams)
    check result5.hasKey("error")
    
    let result6 = waitFor executeWorkspaceOperationTool(nullParams)
    check result6.hasKey("error")