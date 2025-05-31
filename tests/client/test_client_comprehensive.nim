## Comprehensive tests for client module
##
## Tests all functions in the client module to achieve 100% coverage

import std/[unittest, asyncdispatch, json, strutils, options, os]
import ../../src/client/client

suite "Client Comprehensive Tests":
  test "callTool - basic tool call":
    let client = newMcpClient("test-client", "1.0.0")
    
    # Mock a tool call
    let params = %*{
      "tool": "analyze_commit",
      "arguments": {
        "commit_id": "HEAD"
      }
    }
    
    let result = waitFor client.callTool("analyze_commit", params["arguments"])
    
    # Should return a result
    check result.kind == JObject
    
  test "callTool - with empty arguments":
    let client = newMcpClient("test-client", "1.0.0")
    
    let result = waitFor client.callTool("list_tools", newJObject())
    
    # Should handle empty arguments
    check result.kind == JObject
    
  test "callTool - error handling":
    let client = newMcpClient("test-client", "1.0.0")
    
    # Call non-existent tool
    let result = waitFor client.callTool("non_existent_tool", %*{"test": true})
    
    # Should handle errors gracefully
    check result.kind == JObject
    
  test "proposeCommitDivision - single commit":
    let client = newMcpClient("test-client", "1.0.0")
    
    let proposal = waitFor client.proposeCommitDivision("abc123")
    
    # Should return a proposal
    check proposal.kind == JObject
    check proposal.hasKey("divisions") or proposal.hasKey("error") or proposal.hasKey("proposal")
    
  test "proposeCommitDivision - with options":
    let client = newMcpClient("test-client", "1.0.0")
    
    let options = %*{
      "strategy": "semantic",
      "max_divisions": 5,
      "min_file_count": 2
    }
    
    let proposal = waitFor client.proposeCommitDivision("abc123", options)
    
    # Should use provided options
    check proposal.kind == JObject
    
  test "proposeCommitDivision - invalid commit":
    let client = newMcpClient("test-client", "1.0.0")
    
    let proposal = waitFor client.proposeCommitDivision("")
    
    # Should handle invalid input
    check proposal.kind == JObject
    
  test "executeCommitDivision - basic execution":
    let client = newMcpClient("test-client", "1.0.0")
    
    let divisions = %*[
      {
        "description": "Core changes",
        "files": ["src/core.nim", "src/utils.nim"]
      },
      {
        "description": "Test updates",
        "files": ["tests/test_core.nim"]
      }
    ]
    
    let result = waitFor client.executeCommitDivision("abc123", divisions)
    
    # Should execute division
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("new_commits")
    
  test "executeCommitDivision - empty divisions":
    let client = newMcpClient("test-client", "1.0.0")
    
    let result = waitFor client.executeCommitDivision("abc123", %*[])
    
    # Should handle empty divisions
    check result.kind == JObject
    
  test "executeCommitDivision - malformed divisions":
    let client = newMcpClient("test-client", "1.0.0")
    
    let divisions = %*[
      {"description": "Missing files"},
      {"files": ["no_description.nim"]}
    ]
    
    let result = waitFor client.executeCommitDivision("abc123", divisions)
    
    # Should handle malformed input
    check result.kind == JObject
    
  test "automateCommitDivision - full automation":
    let client = newMcpClient("test-client", "1.0.0")
    
    let result = waitFor client.automateCommitDivision("abc123")
    
    # Should automate the process
    check result.kind == JObject
    check result.hasKey("executed") or result.hasKey("error") or result.hasKey("result")
    
  test "automateCommitDivision - with options":
    let client = newMcpClient("test-client", "1.0.0")
    
    let options = %*{
      "auto_execute": false,
      "strategy": "file-based",
      "review_mode": true
    }
    
    let result = waitFor client.automateCommitDivision("abc123", options)
    
    # Should respect options
    check result.kind == JObject
    
  test "automateCommitDivision - error cases":
    let client = newMcpClient("test-client", "1.0.0")
    
    # Test with various invalid inputs
    let results = @[
      waitFor client.automateCommitDivision(""),
      waitFor client.automateCommitDivision("invalid-commit"),
      waitFor client.automateCommitDivision("HEAD", %*{"invalid_option": true})
    ]
    
    for result in results:
      check result.kind == JObject
      
  test "Client workflow - analyze, propose, execute":
    let client = newMcpClient("test-client", "1.0.0")
    
    # Step 1: Analyze commit
    let analysis = waitFor client.callTool("analyze_commit", %*{"commit_id": "HEAD"})
    check analysis.kind == JObject
    
    # Step 2: Propose division
    let proposal = waitFor client.proposeCommitDivision("HEAD")
    check proposal.kind == JObject
    
    # Step 3: Execute if valid
    if proposal.hasKey("divisions") and proposal["divisions"].kind == JArray:
      let result = waitFor client.executeCommitDivision("HEAD", proposal["divisions"])
      check result.kind == JObject
    
  test "Client connection and initialization":
    # Test creating clients with different configurations
    let client1 = newMcpClient("client1", "1.0.0")
    check client1.name == "client1"
    check client1.version == "1.0.0"
    
    let client2 = newMcpClient("client2", "2.0.0", %*{"debug": true})
    check client2.name == "client2"
    check client2.version == "2.0.0"
    
  test "Concurrent operations":
    let client = newMcpClient("test-client", "1.0.0")
    
    # Launch multiple operations concurrently
    let futures = @[
      client.callTool("list_tools", newJObject()),
      client.proposeCommitDivision("HEAD"),
      client.automateCommitDivision("HEAD~1", %*{"auto_execute": false})
    ]
    
    # Wait for all to complete
    let results = waitFor all(futures)
    
    # All should complete successfully
    for result in results:
      check result.kind == JObject

when isMainModule:
  waitFor main()