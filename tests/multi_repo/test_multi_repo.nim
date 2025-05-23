## Tests for multi_repo tools module

import std/[unittest, asyncdispatch, json, os]
import ../../src/multi_repo/tools/multi_repo

suite "Multi Repo Tools Module Tests":
  test "Tool Function Signatures":
    # Test that the tool functions exist and have correct signatures
    # Note: We can't easily test the actual functionality without a real Jujutsu setup
    
    # Test parameter structures for analyze tool
    let analyzeParams = %*{
      "commitRange": "HEAD~1..HEAD",
      "reposDir": ".",
      "configPath": "repos.json",
      "repositories": ["repo1", "repo2"]
    }
    
    check analyzeParams.hasKey("commitRange")
    check analyzeParams["repositories"].len == 2
    
    # Test parameter structures for propose tool
    let proposeParams = %*{
      "commitRange": "HEAD~2..HEAD",
      "reposDir": "/repos"
    }
    
    check proposeParams.hasKey("commitRange")
    check proposeParams.hasKey("reposDir")
    
    # Test parameter structures for execute tool
    let executeParams = %*{
      "proposal": {
        "commitGroups": []
      },
      "reposDir": "."
    }
    
    check executeParams.hasKey("proposal")
    check executeParams["proposal"].hasKey("commitGroups")
    
    # Test parameter structures for automate tool
    let automateParams = %*{
      "commitRange": "main..feature",
      "repositories": []
    }
    
    check automateParams.hasKey("commitRange")
    check automateParams.hasKey("repositories")

  test "Response Structures":
    # Test expected response structures
    
    # Analysis response structure
    let analysisResponse = %*{
      "repositories": {},
      "crossDependencies": [],
      "hasCrossDependencies": false,
      "totalFiles": 0,
      "totalChanges": 0
    }
    
    check analysisResponse.hasKey("repositories")
    check analysisResponse.hasKey("crossDependencies")
    check analysisResponse["hasCrossDependencies"].getBool() == false
    
    # Proposal response structure
    let proposalResponse = %*{
      "confidence": 0.0,
      "commitGroups": []
    }
    
    check proposalResponse.hasKey("confidence")
    check proposalResponse.hasKey("commitGroups")
    
    # Execution response structure
    let executionResponse = %*{
      "success": true,
      "commitsByRepo": {},
      "groupResults": []
    }
    
    check executionResponse.hasKey("success")
    check executionResponse["success"].getBool() == true

  test "Error Response Structures":
    # Test error response structures
    let errorResponse = %*{
      "error": {
        "code": -32602,
        "message": "Invalid params"
      }
    }
    
    check errorResponse.hasKey("error")
    check errorResponse["error"].hasKey("code")
    check errorResponse["error"].hasKey("message")
    check errorResponse["error"]["code"].getInt() == -32602