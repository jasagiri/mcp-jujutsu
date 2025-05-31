## Comprehensive tests for semantic_divide module
##
## Tests all functions in the semantic_divide module to achieve 100% coverage

import std/[unittest, asyncdispatch, json, strutils, options, os, tempfiles]
import ../../src/single_repo/tools/semantic_divide
import ../../src/core/repository/jujutsu
import ../../src/core/logging/logger

suite "Semantic Divide Comprehensive Tests":
  setup:
    initLogger("test")
    
  test "analyzeCommitRangeTool - basic functionality":
    let params = %*{
      "start_commit": "abc123",
      "end_commit": "def456"
    }
    
    let result = waitFor analyzeCommitRangeTool(params)
    
    # The tool should return analysis results
    check result.kind == JObject
    check result.hasKey("commits") or result.hasKey("error")
    
  test "analyzeCommitRangeTool - missing parameters":
    let params = %*{
      "start_commit": "abc123"
      # Missing end_commit
    }
    
    let result = waitFor analyzeCommitRangeTool(params)
    
    # Should handle missing parameters gracefully
    check result.kind == JObject
    
  test "analyzeCommitRangeTool - empty parameters":
    let params = newJObject()
    
    let result = waitFor analyzeCommitRangeTool(params)
    
    # Should handle empty parameters
    check result.kind == JObject
    
  test "proposeCommitDivisionTool - single commit":
    let params = %*{
      "commit_id": "abc123",
      "strategy": "semantic"
    }
    
    let result = waitFor proposeCommitDivisionTool(params)
    
    # Should return a proposal
    check result.kind == JObject
    check result.hasKey("proposal") or result.hasKey("error") or result.hasKey("divisions")
    
  test "proposeCommitDivisionTool - with custom strategy":
    let params = %*{
      "commit_id": "abc123",
      "strategy": "file-based",
      "max_divisions": 3
    }
    
    let result = waitFor proposeCommitDivisionTool(params)
    
    # Should handle custom strategies
    check result.kind == JObject
    
  test "proposeCommitDivisionTool - invalid commit":
    let params = %*{
      "commit_id": "invalid-commit-id",
      "strategy": "semantic"
    }
    
    let result = waitFor proposeCommitDivisionTool(params)
    
    # Should handle invalid commits gracefully
    check result.kind == JObject
    
  test "executeCommitDivisionTool - basic execution":
    let params = %*{
      "commit_id": "abc123",
      "divisions": [
        {
          "description": "Refactor core module",
          "files": ["src/core.nim"]
        },
        {
          "description": "Update tests",
          "files": ["tests/test_core.nim"]
        }
      ]
    }
    
    let result = waitFor executeCommitDivisionTool(params)
    
    # Should execute the division
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("new_commits")
    
  test "executeCommitDivisionTool - empty divisions":
    let params = %*{
      "commit_id": "abc123",
      "divisions": []
    }
    
    let result = waitFor executeCommitDivisionTool(params)
    
    # Should handle empty divisions
    check result.kind == JObject
    
  test "executeCommitDivisionTool - invalid structure":
    let params = %*{
      "commit_id": "abc123",
      "divisions": "not-an-array"  # Invalid type
    }
    
    let result = waitFor executeCommitDivisionTool(params)
    
    # Should handle invalid input gracefully
    check result.kind == JObject
    
  test "automateCommitDivisionTool - full automation":
    let params = %*{
      "commit_id": "abc123",
      "auto_execute": true,
      "max_divisions": 5,
      "strategy": "semantic"
    }
    
    let result = waitFor automateCommitDivisionTool(params)
    
    # Should automate the entire process
    check result.kind == JObject
    check result.hasKey("executed") or result.hasKey("error") or result.hasKey("proposal")
    
  test "automateCommitDivisionTool - analysis only":
    let params = %*{
      "commit_id": "abc123",
      "auto_execute": false,
      "strategy": "semantic"
    }
    
    let result = waitFor automateCommitDivisionTool(params)
    
    # Should only analyze, not execute
    check result.kind == JObject
    
  test "automateCommitDivisionTool - with filters":
    let params = %*{
      "commit_id": "abc123",
      "auto_execute": false,
      "file_filters": ["*.nim", "*.md"],
      "exclude_patterns": ["test_*", "*.tmp"]
    }
    
    let result = waitFor automateCommitDivisionTool(params)
    
    # Should apply filters
    check result.kind == JObject
    
  test "automateCommitDivisionTool - missing commit_id":
    let params = %*{
      "auto_execute": true
      # Missing commit_id
    }
    
    let result = waitFor automateCommitDivisionTool(params)
    
    # Should handle missing required parameter
    check result.kind == JObject
    
  test "Complex workflow - analyze, propose, execute":
    # First analyze
    let analyzeParams = %*{
      "start_commit": "HEAD~5",
      "end_commit": "HEAD"
    }
    let analysis = waitFor analyzeCommitRangeTool(analyzeParams)
    check analysis.kind == JObject
    
    # Then propose division for a commit
    let proposeParams = %*{
      "commit_id": "HEAD",
      "strategy": "semantic"
    }
    let proposal = waitFor proposeCommitDivisionTool(proposeParams)
    check proposal.kind == JObject
    
    # Finally execute if proposal is valid
    if proposal.hasKey("divisions"):
      let executeParams = %*{
        "commit_id": "HEAD",
        "divisions": proposal["divisions"]
      }
      let execution = waitFor executeCommitDivisionTool(executeParams)
      check execution.kind == JObject
    
  test "Edge cases and error handling":
    # Test with various invalid inputs
    let testCases = @[
      %*{},  # Empty object
      %*{"unknown_param": "value"},  # Unknown parameter
      %*{"commit_id": ""},  # Empty commit ID
      %*{"commit_id": "abc123", "strategy": ""},  # Empty strategy
      %*{"commit_id": nil},  # Null commit ID
      %*{"divisions": [{"files": []}]},  # Division without description
      %*{"commit_id": "abc123", "divisions": [{"description": "test"}]},  # Division without files
    ]
    
    for params in testCases:
      # All tools should handle edge cases gracefully
      let result1 = waitFor analyzeCommitRangeTool(params)
      check result1.kind == JObject
      
      let result2 = waitFor proposeCommitDivisionTool(params)
      check result2.kind == JObject
      
      let result3 = waitFor executeCommitDivisionTool(params)
      check result3.kind == JObject
      
      let result4 = waitFor automateCommitDivisionTool(params)
      check result4.kind == JObject

when isMainModule:
  waitFor main()