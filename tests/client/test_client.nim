## Test cases for client library
##
## This module tests the client library for the MCP-Jujutsu tool.

import unittest, asyncdispatch, json, options, strutils
import ../../src/client/client

suite "MCP Client Tests":
  
  setup:
    let client = newMcpClient("http://localhost:8080/mcp")
  
  test "Client Construction":
    check(client != nil)
    check(client.baseUrl == "http://localhost:8080/mcp")
    check(client.httpClient != nil)
  
  # Note: These tests would normally require a running server
  # For now, they're just placeholder tests
  
  test "Format Request":
    let params = %*{
      "repoPath": "/path/to/repo",
      "commitRange": "HEAD~1..HEAD"
    }
    
    let payload = %*{
      "jsonrpc": "2.0",
      "method": "analyzeCommitRange",
      "params": params,
      "id": 1
    }
    
    check(payload.hasKey("jsonrpc"))
    check(payload["jsonrpc"].getStr == "2.0")
    check(payload.hasKey("method"))
    check(payload["method"].getStr == "analyzeCommitRange")
    check(payload.hasKey("params"))
    check(payload["params"]["repoPath"].getStr == "/path/to/repo")
    check(payload["params"]["commitRange"].getStr == "HEAD~1..HEAD")
    check(payload.hasKey("id"))
    check(payload["id"].getInt == 1)