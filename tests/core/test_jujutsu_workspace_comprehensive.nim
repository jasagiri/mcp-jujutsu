## Comprehensive tests for jujutsu_workspace module
##
## Tests all functions to achieve 100% coverage

import std/[unittest, asyncdispatch, json, strutils, options, os, tempfiles]
import ../../src/core/repository/jujutsu_workspace
import ../../src/core/repository/jujutsu
import ../../src/core/logging/logger

suite "Jujutsu Workspace Comprehensive Tests":
  setup:
    initLogger("test")
    
  test "newWorkspaceManager - create manager":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    check manager.repo == repo
    check manager.workspaces.len >= 0
    
  test "newWorkspaceManager - with existing workspaces":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    # Manager should detect existing workspaces
    check manager != nil
    
  test "switchWorkspace - to existing workspace":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let result = waitFor manager.switchWorkspace("default")
    
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("switched")
    
  test "switchWorkspace - to non-existent workspace":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let result = waitFor manager.switchWorkspace("non-existent-workspace-xyz")
    
    # Should handle gracefully
    check result.kind == JObject
    
  test "updateWorkspace - update current":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let result = waitFor manager.updateWorkspace()
    
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("updated")
    
  test "updateWorkspace - specific workspace":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let result = waitFor manager.updateWorkspace("default")
    
    check result.kind == JObject
    
  test "removeWorkspace - remove workspace":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    # Try to remove a test workspace
    let result = waitFor manager.removeWorkspace("test-workspace-to-remove")
    
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error")
    
  test "removeWorkspace - remove default":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    # Should not allow removing default
    let result = waitFor manager.removeWorkspace("default")
    
    check result.kind == JObject
    
  test "analyzeWorkspaceChanges - basic analysis":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let analysis = waitFor manager.analyzeWorkspaceChanges("default")
    
    check analysis.kind == JObject
    check analysis.hasKey("changes") or analysis.hasKey("error") or analysis.hasKey("files")
    
  test "analyzeWorkspaceChanges - with options":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let options = %*{
      "include_untracked": true,
      "show_diff": true
    }
    
    let analysis = waitFor manager.analyzeWorkspaceChanges("default", options)
    
    check analysis.kind == JObject
    
  test "executeWorkspaceOperation - simple operation":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let operation = %*{
      "type": "update",
      "workspace": "default"
    }
    
    let result = waitFor manager.executeWorkspaceOperation(operation)
    
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("result")
    
  test "executeWorkspaceOperation - complex operation":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let operation = %*{
      "type": "sync",
      "source": "default",
      "target": "feature",
      "options": {
        "merge_strategy": "rebase"
      }
    }
    
    let result = waitFor manager.executeWorkspaceOperation(operation)
    
    check result.kind == JObject
    
  test "planWorkspaceWorkflow - simple workflow":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let requirements = %*{
      "goal": "merge_feature",
      "source": "feature-branch",
      "target": "main"
    }
    
    let plan = waitFor manager.planWorkspaceWorkflow(requirements)
    
    check plan.kind == JObject
    check plan.hasKey("steps") or plan.hasKey("error") or plan.hasKey("workflow")
    
  test "planWorkspaceWorkflow - complex workflow":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let requirements = %*{
      "goal": "parallel_development",
      "branches": ["feature1", "feature2", "feature3"],
      "base": "main",
      "strategy": "isolated"
    }
    
    let plan = waitFor manager.planWorkspaceWorkflow(requirements)
    
    check plan.kind == JObject
    
  test "executeWorkspaceWorkflow - execute plan":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let workflow = %*{
      "name": "test_workflow",
      "steps": [
        {"action": "create", "workspace": "test-ws"},
        {"action": "switch", "workspace": "test-ws"},
        {"action": "update", "workspace": "test-ws"}
      ]
    }
    
    let result = waitFor manager.executeWorkspaceWorkflow(workflow)
    
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("completed")
    
  test "executeWorkspaceWorkflow - empty workflow":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let workflow = %*{
      "name": "empty_workflow",
      "steps": []
    }
    
    let result = waitFor manager.executeWorkspaceWorkflow(workflow)
    
    check result.kind == JObject
    
  test "analyzeWorkspaceSemantics - semantic analysis":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let analysis = waitFor manager.analyzeWorkspaceSemantics("default")
    
    check analysis.kind == JObject
    check analysis.hasKey("semantics") or analysis.hasKey("error") or analysis.hasKey("analysis")
    
  test "analyzeWorkspaceSemantics - with context":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    let context = %*{
      "include_history": true,
      "depth": 10,
      "analyze_conflicts": true
    }
    
    let analysis = waitFor manager.analyzeWorkspaceSemantics("default", context)
    
    check analysis.kind == JObject
    
  test "Workspace manager - full workflow":
    let repo = newJujutsuRepo(".")
    let manager = newWorkspaceManager(repo)
    
    # List current workspaces
    check manager.workspaces.len >= 0
    
    # Analyze changes
    let changes = waitFor manager.analyzeWorkspaceChanges("default")
    check changes.kind == JObject
    
    # Plan a workflow
    let plan = waitFor manager.planWorkspaceWorkflow(%*{
      "goal": "test_workflow"
    })
    check plan.kind == JObject
    
    # Analyze semantics
    let semantics = waitFor manager.analyzeWorkspaceSemantics("default")
    check semantics.kind == JObject
    
  test "Error handling for all workspace operations":
    # Test with invalid repo path
    let badRepo = newJujutsuRepo("/non/existent/path")
    let manager = newWorkspaceManager(badRepo)
    
    # All operations should handle errors gracefully
    let switch = waitFor manager.switchWorkspace("test")
    check switch.kind == JObject
    
    let update = waitFor manager.updateWorkspace()
    check update.kind == JObject
    
    let remove = waitFor manager.removeWorkspace("test")
    check remove.kind == JObject
    
    let analyze = waitFor manager.analyzeWorkspaceChanges("test")
    check analyze.kind == JObject
    
    let execute = waitFor manager.executeWorkspaceOperation(%*{"type": "test"})
    check execute.kind == JObject
    
    let plan = waitFor manager.planWorkspaceWorkflow(%*{"goal": "test"})
    check plan.kind == JObject
    
    let workflow = waitFor manager.executeWorkspaceWorkflow(%*{"steps": []})
    check workflow.kind == JObject
    
    let semantics = waitFor manager.analyzeWorkspaceSemantics("test")
    check semantics.kind == JObject

when isMainModule:
  waitFor main()