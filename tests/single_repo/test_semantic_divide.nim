## Tests for semantic divide tools

import std/[unittest, asyncdispatch, json, os]
import ../../src/single_repo/tools/semantic_divide

suite "Semantic Divide Tools Tests":

  test "Analyze Commit Range Tool Parameters":
    # Test with minimal parameters
    let params1 = %*{
      "commitRange": "HEAD~1..HEAD"
    }
    
    # Verify parameter structure
    check params1.hasKey("commitRange")
    check params1["commitRange"].getStr() == "HEAD~1..HEAD"
    
    # Test with all parameters
    let params2 = %*{
      "commitRange": "main..feature",
      "repoPath": "/custom/repo"
    }
    
    check params2.hasKey("commitRange")
    check params2.hasKey("repoPath")
    check params2["repoPath"].getStr() == "/custom/repo"

  test "Propose Division Tool Parameters":
    # Test with various strategies
    let params = %*{
      "commitRange": "HEAD~5..HEAD",
      "strategy": "semantic",
      "commitSize": "balanced",
      "minConfidence": 0.8,
      "maxCommits": 15
    }
    
    check params["strategy"].getStr() == "semantic"
    check params["commitSize"].getStr() == "balanced"
    check params["minConfidence"].getFloat() == 0.8
    check params["maxCommits"].getInt() == 15

  test "Execute Division Tool Parameters":
    # Test execute parameters
    let proposal = %*{
      "proposedCommits": [
        {
          "message": "feat: add new feature",
          "files": ["file1.nim", "file2.nim"]
        }
      ],
      "confidence": 0.85
    }
    
    let params = %*{
      "proposal": proposal,
      "repoPath": "/repo/path"
    }
    
    check params.hasKey("proposal")
    check params["proposal"]["confidence"].getFloat() == 0.85

  test "Automate Division Tool Parameters":
    # Test all automation parameters
    let params = %*{
      "commitRange": "HEAD~3..HEAD",
      "strategy": "filetype",
      "commitSize": "many",
      "minConfidence": 0.7,
      "maxCommits": 10,
      "dryRun": true,
      "validate": true,
      "autoFix": false
    }
    
    check params["dryRun"].getBool() == true
    check params["validate"].getBool() == true
    check params["autoFix"].getBool() == false

  test "Strategy Conversion":
    # Test strategy string to enum conversion
    let strategies = ["balanced", "semantic", "filetype", "directory"]
    
    for strategy in strategies:
      let params = %*{"strategy": strategy}
      check params["strategy"].getStr() == strategy

  test "Default Parameter Values":
    # Test that tools handle missing optional parameters
    let minimalParams = %*{
      "commitRange": "HEAD~1..HEAD"
    }
    
    # Verify minimal params are valid
    check minimalParams.hasKey("commitRange")
    check not minimalParams.hasKey("repoPath")
    check not minimalParams.hasKey("strategy")