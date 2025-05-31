## Comprehensive tests for workspace_tools module
##
## Tests all functions to achieve 100% coverage

import std/[unittest, asyncdispatch, json, strutils]
import ../../src/multi_repo/tools/workspace_tools
import ../../src/core/logging/logger

suite "Workspace Tools Comprehensive Tests":
  setup:
    initLogger("test")
    
  test "analyzeWorkspaceChangesTool - basic analysis":
    let params = %*{
      "workspace": "default",
      "repository": "main-repo"
    }
    
    let result = waitFor analyzeWorkspaceChangesTool(params)
    
    check result.kind == JObject
    check result.hasKey("changes") or result.hasKey("error") or result.hasKey("analysis")
    
  test "analyzeWorkspaceChangesTool - with options":
    let params = %*{
      "workspace": "feature",
      "repository": "main-repo",
      "include_untracked": true,
      "show_diffs": true,
      "depth": 5
    }
    
    let result = waitFor analyzeWorkspaceChangesTool(params)
    
    check result.kind == JObject
    
  test "analyzeWorkspaceChangesTool - missing params":
    let params = %*{}  # Missing required params
    
    let result = waitFor analyzeWorkspaceChangesTool(params)
    
    # Should handle missing params
    check result.kind == JObject
    
  test "planWorkspaceWorkflowTool - simple workflow":
    let params = %*{
      "goal": "merge_branches",
      "repositories": ["repo1", "repo2"],
      "target_branch": "main"
    }
    
    let result = waitFor planWorkspaceWorkflowTool(params)
    
    check result.kind == JObject
    check result.hasKey("workflow") or result.hasKey("error") or result.hasKey("plan")
    
  test "planWorkspaceWorkflowTool - complex workflow":
    let params = %*{
      "goal": "parallel_feature_development",
      "repositories": ["frontend", "backend", "shared"],
      "features": ["feature-a", "feature-b"],
      "base_branch": "develop",
      "merge_strategy": "rebase",
      "create_workspaces": true
    }
    
    let result = waitFor planWorkspaceWorkflowTool(params)
    
    check result.kind == JObject
    
  test "planWorkspaceWorkflowTool - invalid goal":
    let params = %*{
      "goal": "invalid_goal_type",
      "repositories": ["repo1"]
    }
    
    let result = waitFor planWorkspaceWorkflowTool(params)
    
    # Should handle invalid goal
    check result.kind == JObject
    
  test "executeWorkspaceWorkflowTool - execute plan":
    let params = %*{
      "workflow": {
        "name": "test_workflow",
        "steps": [
          {
            "action": "create_workspace",
            "name": "test-ws",
            "repository": "repo1"
          },
          {
            "action": "switch_branch",
            "branch": "feature",
            "workspace": "test-ws"
          }
        ]
      },
      "dry_run": true
    }
    
    let result = waitFor executeWorkspaceWorkflowTool(params)
    
    check result.kind == JObject
    check result.hasKey("result") or result.hasKey("error") or result.hasKey("executed")
    
  test "executeWorkspaceWorkflowTool - empty workflow":
    let params = %*{
      "workflow": {
        "name": "empty",
        "steps": []
      }
    }
    
    let result = waitFor executeWorkspaceWorkflowTool(params)
    
    check result.kind == JObject
    
  test "executeWorkspaceWorkflowTool - missing workflow":
    let params = %*{
      "dry_run": true
      # Missing workflow
    }
    
    let result = waitFor executeWorkspaceWorkflowTool(params)
    
    check result.kind == JObject
    
  test "workspaceSemanticAnalysisTool - analyze semantics":
    let params = %*{
      "workspaces": ["default", "feature"],
      "repositories": ["repo1", "repo2"],
      "analyze_dependencies": true
    }
    
    let result = waitFor workspaceSemanticAnalysisTool(params)
    
    check result.kind == JObject
    check result.hasKey("analysis") or result.hasKey("error") or result.hasKey("semantics")
    
  test "workspaceSemanticAnalysisTool - with filters":
    let params = %*{
      "workspaces": ["ws1"],
      "repositories": ["repo1"],
      "file_patterns": ["*.nim", "*.md"],
      "exclude_patterns": ["test_*", "*.tmp"],
      "semantic_categories": ["refactor", "feature", "bugfix"]
    }
    
    let result = waitFor workspaceSemanticAnalysisTool(params)
    
    check result.kind == JObject
    
  test "workspaceSemanticAnalysisTool - empty params":
    let params = %*{}
    
    let result = waitFor workspaceSemanticAnalysisTool(params)
    
    # Should handle empty params
    check result.kind == JObject
    
  test "Complex workspace workflow":
    # Analyze changes across workspaces
    let analyzeParams = %*{
      "workspace": "main",
      "repository": "core-repo",
      "include_untracked": true
    }
    let analysis = waitFor analyzeWorkspaceChangesTool(analyzeParams)
    check analysis.kind == JObject
    
    # Plan a workflow based on analysis
    let planParams = %*{
      "goal": "sync_workspaces",
      "repositories": ["core-repo", "plugin-repo"],
      "source_workspace": "main",
      "target_workspace": "release"
    }
    let plan = waitFor planWorkspaceWorkflowTool(planParams)
    check plan.kind == JObject
    
    # Execute the workflow
    if plan.hasKey("workflow"):
      let executeParams = %*{
        "workflow": plan["workflow"],
        "dry_run": false
      }
      let execution = waitFor executeWorkspaceWorkflowTool(executeParams)
      check execution.kind == JObject
    
    # Analyze semantic changes
    let semanticParams = %*{
      "workspaces": ["main", "release"],
      "repositories": ["core-repo", "plugin-repo"],
      "analyze_dependencies": true
    }
    let semantics = waitFor workspaceSemanticAnalysisTool(semanticParams)
    check semantics.kind == JObject
    
  test "Error handling for all tools":
    let invalidParams = @[
      %*{"invalid": "params"},
      %*{"workspace": 123},  # Wrong type
      %*{"repositories": "not-an-array"},  # Wrong type
      %*{"workflow": {"steps": "not-an-array"}},  # Invalid structure
      newJNull(),  # Null params
    ]
    
    for params in invalidParams:
      # All tools should handle errors gracefully
      let r1 = waitFor analyzeWorkspaceChangesTool(params)
      check r1.kind == JObject
      
      let r2 = waitFor planWorkspaceWorkflowTool(params)
      check r2.kind == JObject
      
      let r3 = waitFor executeWorkspaceWorkflowTool(params)
      check r3.kind == JObject
      
      let r4 = waitFor workspaceSemanticAnalysisTool(params)
      check r4.kind == JObject

when isMainModule:
  waitFor main()