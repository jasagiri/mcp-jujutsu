## Tests for Jujutsu workspace functionality
##
## This module tests workspace management operations for the Jujutsu integration.

import std/[unittest, asyncdispatch, json, options, os, strutils]
import ../../src/core/repository/jujutsu_workspace

suite "Jujutsu Workspace Tests":
  
  setup:
    # Use a temporary directory for testing
    let testDir = getTempDir() / "mcp_jujutsu_workspace_test"
    if dirExists(testDir):
      removeDir(testDir)
    createDir(testDir)
  
  teardown:
    # Clean up test directory
    let testDir = getTempDir() / "mcp_jujutsu_workspace_test"
    if dirExists(testDir):
      removeDir(testDir)
  
  test "parseWorkspaceList parses workspace output correctly":
    let output = """
main: /path/to/main (active)
feature: /path/to/feature
bugfix: /path/to/bugfix (stale)
"""
    
    let workspaces = parseWorkspaceList(output)
    
    check workspaces.len == 3
    check workspaces[0].name == "main"
    check workspaces[0].path == "/path/to/main"
    check workspaces[0].isActive == true
    
    check workspaces[1].name == "feature"
    check workspaces[1].path == "/path/to/feature"
    check workspaces[1].isActive == false
    
    check workspaces[2].name == "bugfix"
    check workspaces[2].path == "/path/to/bugfix"
    check workspaces[2].isActive == false
  
  test "parseWorkspaceList handles empty output":
    let output = ""
    let workspaces = parseWorkspaceList(output)
    check workspaces.len == 0
  
  test "parseWorkspaceList handles malformed lines":
    let output = """
main: /path/to/main (active)
invalid line without colon
feature: /path/to/feature
: empty name
"""
    
    let workspaces = parseWorkspaceList(output)
    check workspaces.len == 2
    check workspaces[0].name == "main"
    check workspaces[1].name == "feature"
  
  test "listWorkspaces handles non-existent repository":
    let nonExistentPath = "/path/that/does/not/exist"
    
    expect(Exception):
      discard waitFor listWorkspaces(nonExistentPath)
  
  test "createWorkspace validates input parameters":
    let testDir2 = getTempDir() / "mcp_jujutsu_workspace_test"
    
    # Test empty workspace name
    expect(ValueError):
      waitFor createWorkspace(testDir2, "", testDir2 / "empty")
    
    # Test empty workspace path
    expect(ValueError):
      waitFor createWorkspace(testDir2, "test", "")
  
  test "analyzeWorkspace handles empty workspace list":
    let testDir3 = getTempDir() / "mcp_jujutsu_workspace_test"
    
    # Create a mock workspace analysis for empty list
    let analysis = waitFor analyzeWorkspaceState(testDir3, @[])
    
    check analysis.totalWorkspaces == 0
    check analysis.activeWorkspaces == 0
    check analysis.conflictedWorkspaces == 0
    check analysis.staleWorkspaces == 0
    check analysis.recommendations.len == 1
    check analysis.recommendations[0].contains("No workspaces")
  
  test "analyzeWorkspaceState provides correct analysis":
    let workspaces = @[
      JujutsuWorkspace(
        name: "main",
        path: "/path/main",
        repository: "test-repo",
        isActive: true,
        lastSync: "recent",
        conflicts: @[]
      ),
      JujutsuWorkspace(
        name: "feature",
        path: "/path/feature", 
        repository: "test-repo",
        isActive: false,
        lastSync: "old",
        conflicts: @[]
      ),
      JujutsuWorkspace(
        name: "bugfix",
        path: "/path/bugfix",
        repository: "test-repo", 
        isActive: false,
        lastSync: "recent",
        conflicts: @["conflict1", "conflict2"]
      )
    ]
    
    let analysis = waitFor analyzeWorkspaceState("/test/path", workspaces)
    
    check analysis.totalWorkspaces == 3
    check analysis.activeWorkspaces == 1
    check analysis.conflictedWorkspaces == 1
    check analysis.staleWorkspaces == 1
    check analysis.recommendations.len >= 1
  
  test "WorkspaceStrategy enum values are correct":
    check wsFeatureBranches == WorkspaceStrategy.wsFeatureBranches
    check wsEnvironments == WorkspaceStrategy.wsEnvironments
    check wsTeamMembers == WorkspaceStrategy.wsTeamMembers
    check wsExperimentation == WorkspaceStrategy.wsExperimentation
  
  test "executeWorkspaceStrategy handles different strategies":
    let testDir4 = getTempDir() / "mcp_jujutsu_workspace_test"
    let workspaces = @[
      JujutsuWorkspace(
        name: "main",
        path: "/path/main",
        repository: "test-repo",
        isActive: true,
        lastSync: "recent",
        conflicts: @[]
      )
    ]
    
    # Test feature branches strategy
    let featureResult = waitFor executeWorkspaceStrategy(testDir4, workspaces, wsFeatureBranches, "test-operation")
    check featureResult.success == false  # Will fail since no real jj command
    check featureResult.strategy == wsFeatureBranches
    
    # Test environments strategy  
    let envResult = waitFor executeWorkspaceStrategy(testDir4, workspaces, wsEnvironments, "test-operation")
    check envResult.success == false  # Will fail since no real jj command
    check envResult.strategy == wsEnvironments
  
  test "getWorkspaceCommands generates correct commands":
    let workspaces = @[
      JujutsuWorkspace(
        name: "main",
        path: "/path/main",
        repository: "test-repo",
        isActive: true,
        lastSync: "recent", 
        conflicts: @[]
      ),
      JujutsuWorkspace(
        name: "feature",
        path: "/path/feature",
        repository: "test-repo",
        isActive: false,
        lastSync: "old",
        conflicts: @[]
      )
    ]
    
    let commands = getWorkspaceCommands(workspaces, wsFeatureBranches, "commit", "test message")
    
    check commands.len == 2
    check commands[0].command.contains("jj commit")
    check commands[0].command.contains("test message")
    check commands[0].workspacePath == "/path/main"
    
    check commands[1].command.contains("jj commit")
    check commands[1].command.contains("test message")
    check commands[1].workspacePath == "/path/feature"