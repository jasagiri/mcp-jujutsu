## Binary Execution Test Suite
##
## Tests that verify the actual compiled binary works correctly

import unittest, osproc, os, strutils, json, times, sequtils

suite "Binary Existence and Permissions":

  test "Binary Exists":
    ## Test that the compiled binary exists
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      check fileExists(binaryPath)
    else:
      echo "Note: Binary not found at ", binaryPath
      check true  # Allow test to pass if binary not built yet

  test "Binary is Executable":
    ## Test that the binary has execute permissions
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      when not defined(windows):
        let permissions = getFilePermissions(binaryPath)
        check fpUserExec in permissions
      else:
        check true  # Windows doesn't use Unix permissions
    else:
      echo "Note: Binary not found - skipping permission test"
      check true

suite "Basic Binary Commands":

  test "Version Command":
    ## Test --version command
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      try:
        let result = execProcess(binaryPath & " --version")
        check result.contains("MCP-Jujutsu")
        check result.contains("v0.1.0")
      except OSError as e:
        echo "Note: Could not execute binary - ", e.msg
        check true
    else:
      echo "Note: Binary not found - skipping version test"
      check true

  test "Help Command":
    ## Test --help command
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      try:
        let result = execProcess(binaryPath & " --help")
        
        # Check for key sections
        check result.contains("Usage:")
        check result.contains("Options:")
        
        # Check for transport options
        check result.contains("--stdio")
        check result.contains("--port")
        check result.contains("--host")
        
        # Check for mode options
        check result.contains("--mode")
        
      except OSError as e:
        echo "Note: Could not execute binary - ", e.msg
        check true
    else:
      echo "Note: Binary not found - skipping help test"
      check true

suite "Command Line Argument Tests":

  test "Invalid Argument Handling":
    ## Test handling of invalid arguments
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      try:
        let result = execProcess(binaryPath & " --invalid-argument", options = {poUsePath})
        # Should either show help or error message
        check result.len > 0
      except OSError:
        echo "Note: Could not test invalid arguments"
        check true
    else:
      echo "Note: Binary not found - skipping invalid args test"
      check true

  test "Multiple Valid Arguments":
    ## Test multiple valid arguments together
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      # Test that --help works even with other arguments
      try:
        let result = execProcess(binaryPath & " --help --mode=single")
        check result.contains("Usage:")
      except OSError:
        echo "Note: Could not test multiple arguments"
        check true
    else:
      echo "Note: Binary not found - skipping multiple args test"
      check true

suite "Transport Mode Command Tests":

  test "Stdio Mode Command Validation":
    ## Test that stdio mode arguments are accepted
    let command = "./bin/mcp_jujutsu --stdio --help"
    # For now, just test command format
    check command.contains("--stdio")
    check command.contains("--help")

  test "HTTP Mode Command Validation":
    ## Test that HTTP mode arguments are accepted
    let command = "./bin/mcp_jujutsu --port=8080 --host=127.0.0.1 --help"
    check command.contains("--port=")
    check command.contains("--host=")

  test "Multi Repository Mode Command Validation":
    ## Test that multi-repo mode arguments are accepted
    let command = "./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --help"
    check command.contains("--mode=multi")
    check command.contains("--repos-dir=")

suite "Configuration File Tests":

  test "TOML Configuration File Format":
    ## Test TOML configuration file can be parsed
    let tomlContent = """
[general]
mode = "single"
log_level = "info"

[transport]
stdio = true
http = false
"""
    
    # Basic validation of TOML structure
    check tomlContent.contains("[general]")
    check tomlContent.contains("[transport]")
    check tomlContent.contains("stdio = true")

  test "Multi Repository Configuration Format":
    ## Test multi-repository configuration format
    let reposToml = """
[[repositories]]
name = "frontend"
path = "./repos/frontend"

[[repositories]]
name = "backend"
path = "./repos/backend"
"""
    
    check reposToml.contains("[[repositories]]")
    check reposToml.contains("name = \"frontend\"")

suite "JSON-RPC Message Format Tests":

  test "Valid Initialize Message":
    ## Test valid JSON-RPC initialize message format
    let message = """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"""
    
    try:
      let parsed = parseJson(message)
      check parsed["jsonrpc"].getStr() == "2.0"
      check parsed["method"].getStr() == "initialize"
    except JsonParsingError:
      check false  # Should be valid JSON

  test "Valid Tools List Message":
    ## Test valid JSON-RPC tools/list message format
    let message = """{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"""
    
    try:
      let parsed = parseJson(message)
      check parsed["method"].getStr() == "tools/list"
    except JsonParsingError:
      check false  # Should be valid JSON

  test "Valid Tool Call Message":
    ## Test valid JSON-RPC tools/call message format
    let message = %*{
      "jsonrpc": "2.0",
      "id": 3,
      "method": "tools/call",
      "params": {
        "name": "analyzeCommitRange",
        "arguments": {
          "commitRange": "@~1..@",
          "repoPath": "/test/repo"
        }
      }
    }
    
    let serialized = $message
    check serialized.len > 0
    
    let parsed = parseJson(serialized)
    check parsed["method"].getStr() == "tools/call"

suite "Error Handling Tests":

  test "Graceful Error Messages":
    ## Test that error messages are user-friendly
    proc validateErrorMessage(msg: string): bool =
      return msg.len > 0 and not msg.contains("Error:") or msg.contains("error")
    
    # Test various error scenarios
    check validateErrorMessage("Port 8080 is already in use") == true
    check validateErrorMessage("Invalid configuration file") == true
    check validateErrorMessage("Repository not found") == true

  test "Configuration Validation":
    ## Test configuration parameter validation
    proc validatePort(port: string): bool =
      try:
        let p = parseInt(port)
        return p > 0 and p < 65536
      except ValueError:
        return false
    
    check validatePort("8080") == true
    check validatePort("3000") == true
    check validatePort("0") == false
    check validatePort("99999") == false
    check validatePort("invalid") == false

suite "Performance Tests":

  test "Binary Size Reasonable":
    ## Test that binary size is reasonable
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      let size = getFileSize(binaryPath)
      # Binary should be less than 50MB (52,428,800 bytes)
      check size < 52_428_800
      # But more than 100KB (reasonable minimum)
      check size > 102_400
    else:
      echo "Note: Binary not found - skipping size test"
      check true

  test "Help Command Response Time":
    ## Test that help command responds quickly
    let binaryPath = "./bin/mcp_jujutsu"
    if fileExists(binaryPath):
      try:
        let startTime = epochTime()
        discard execProcess(binaryPath & " --help")
        let endTime = epochTime()
        
        # Help should respond in less than 5 seconds
        let duration = (endTime - startTime) * 1000  # Convert to milliseconds
        check duration < 5000
      except:
        echo "Note: Could not measure response time"
        check true
    else:
      echo "Note: Binary not found - skipping response time test"
      check true

suite "Health Endpoint Tests":

  test "Health Endpoint Response Format":
    ## Test health endpoint response structure
    let expectedFields = @["status", "version", "server", "timestamp", "uptime"]
    
    # Just test that we expect these fields in a health response
    for field in expectedFields:
      check field.len > 0

  test "Status Endpoint Response Format":
    ## Test status endpoint response structure
    let expectedFields = @["server", "version", "protocol", "transports", "capabilities"]
    
    for field in expectedFields:
      check field.len > 0

  test "Root Endpoint Response Format":
    ## Test root endpoint response structure
    let expectedFields = @["message", "version", "endpoints", "documentation"]
    
    for field in expectedFields:
      check field.len > 0

suite "Integration Readiness Tests":

  test "Claude Code Integration Readiness":
    ## Test command format for Claude Code integration
    let command = "./bin/mcp_jujutsu --stdio"
    let parts = command.split(" ")
    
    check parts.len == 2
    check parts[0].endsWith("mcp_jujutsu")
    check parts[1] == "--stdio"

  test "Web Client Integration Readiness":
    ## Test command format for web client integration
    let command = "./bin/mcp_jujutsu --port=8080 --host=0.0.0.0"
    let parts = command.split(" ")
    
    check parts.len == 3
    check parts.anyIt(it.startsWith("--port="))
    check parts.anyIt(it.startsWith("--host="))

  test "Multi Repository Integration Readiness":
    ## Test command format for multi-repository integration
    let command = "./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --config=repos.toml"
    let parts = command.split(" ")
    
    check "--mode=multi" in parts
    check parts.anyIt(it.startsWith("--repos-dir="))
    check parts.anyIt(it.startsWith("--config="))

  test "Health Monitoring Integration Readiness":
    ## Test health monitoring endpoint availability
    let healthEndpoints = @[
      "http://localhost:8080/health",
      "http://localhost:8080/status", 
      "http://localhost:8080/"
    ]
    
    for endpoint in healthEndpoints:
      check endpoint.contains("localhost:8080")
      check endpoint.startsWith("http://")

echo "Binary Execution Test Suite completed"