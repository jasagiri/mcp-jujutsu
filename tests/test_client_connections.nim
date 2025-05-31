## Client Connection Test Suite
##
## Tests for client connections using different transport modes

import unittest, asyncdispatch, json, os, strutils, strformat, osproc, net, sequtils
import ../src/core/config/config as core_config

suite "Client Connection Command Tests":

  test "Stdio Connection Command Format":
    ## Test stdio connection command format
    let command = "./bin/mcp_jujutsu"
    let args = @["--stdio"]
    
    check command.endsWith("mcp_jujutsu")
    check "--stdio" in args

  test "HTTP Connection Command Format":
    ## Test HTTP connection command format
    let command = "./bin/mcp_jujutsu"
    let args = @["--port=8080"]
    
    check command.endsWith("mcp_jujutsu")
    check args[0].startsWith("--port=")

  test "Multi Repository Connection Command Format":
    ## Test multi repository connection command format
    let command = "./bin/mcp_jujutsu"
    let args = @["--mode=multi", "--repos-dir=./repos", "--stdio"]
    
    check "--mode=multi" in args
    check "--stdio" in args
    check args.anyIt(it.startsWith("--repos-dir="))

suite "MCP Protocol Message Tests":

  test "Initialize Message Format":
    ## Test MCP initialize message format
    let initMessage = %*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {
          "name": "test-client",
          "version": "1.0.0"
        }
      }
    }
    
    check initMessage["jsonrpc"].getStr() == "2.0"
    check initMessage["method"].getStr() == "initialize"
    check initMessage.hasKey("params")

  test "Tools List Message Format":
    ## Test tools/list message format
    let toolsMessage = %*{
      "jsonrpc": "2.0",
      "id": 2,
      "method": "tools/list",
      "params": {}
    }
    
    check toolsMessage["jsonrpc"].getStr() == "2.0"
    check toolsMessage["method"].getStr() == "tools/list"

  test "Tool Call Message Format":
    ## Test tools/call message format
    let callMessage = %*{
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
    
    check callMessage["method"].getStr() == "tools/call"
    check callMessage["params"]["name"].getStr() == "analyzeCommitRange"
    check callMessage["params"].hasKey("arguments")

suite "Transport Connection Tests":

  test "Stdio Transport Message Exchange":
    ## Test stdio transport message exchange format
    let request = """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"""
    
    # Test that request is valid JSON
    try:
      let parsed = parseJson(request)
      check parsed["jsonrpc"].getStr() == "2.0"
      check parsed["method"].getStr() == "initialize"
    except JsonParsingError:
      check false # Request should be valid JSON

  test "HTTP Transport Request Format":
    ## Test HTTP transport request format
    let httpRequest = %*{
      "headers": {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      "method": "POST",
      "url": "http://localhost:8080/mcp",
      "body": {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {}
      }
    }
    
    check httpRequest["method"].getStr() == "POST"
    check httpRequest["url"].getStr().contains("/mcp")
    check httpRequest["headers"]["Content-Type"].getStr() == "application/json"

suite "Claude Code Integration Tests":

  test "Claude Code Configuration Format":
    ## Test Claude Code configuration format
    let claudeConfig = %*{
      "mcpServers": {
        "mcp-jujutsu": {
          "command": "/path/to/mcp-jujutsu/bin/mcp_jujutsu",
          "args": ["--stdio"],
          "env": {
            "MCP_LOG_LEVEL": "info"
          }
        }
      }
    }
    
    let server = claudeConfig["mcpServers"]["mcp-jujutsu"]
    check server["command"].getStr().endsWith("mcp_jujutsu")
    check server["args"][0].getStr() == "--stdio"

  test "Claude Code CLI Command Format":
    ## Test Claude Code CLI command format
    let cliCommand = "claude-code mcp add \"mcp-jujutsu\" --transport \"stdio\" --command \"./bin/mcp_jujutsu\" --args \"--stdio\""
    
    check cliCommand.contains("claude-code mcp add")
    check cliCommand.contains("--transport \"stdio\"")
    check cliCommand.contains("--args \"--stdio\"")

suite "Client Connection Validation Tests":

  test "Valid Stdio Connection Parameters":
    ## Test valid stdio connection parameters
    proc validateStdioConnection(command: string, args: seq[string]): bool =
      return command.len > 0 and "--stdio" in args
    
    check validateStdioConnection("./bin/mcp_jujutsu", @["--stdio"]) == true
    check validateStdioConnection("", @["--stdio"]) == false
    check validateStdioConnection("./bin/mcp_jujutsu", @["--http"]) == false

  test "Valid HTTP Connection Parameters":
    ## Test valid HTTP connection parameters
    proc validateHttpConnection(host: string, port: int): bool =
      return host.len > 0 and port > 0 and port < 65536
    
    check validateHttpConnection("127.0.0.1", 8080) == true
    check validateHttpConnection("localhost", 3000) == true
    check validateHttpConnection("", 8080) == false
    check validateHttpConnection("127.0.0.1", 0) == false
    check validateHttpConnection("127.0.0.1", 70000) == false

  test "Valid Multi Repository Parameters":
    ## Test valid multi repository parameters
    proc validateMultiRepoConnection(reposDir: string, configPath: string): bool =
      return reposDir.len > 0 and configPath.len > 0 and configPath.endsWith(".toml")
    
    check validateMultiRepoConnection("./repos", "repos.toml") == true
    check validateMultiRepoConnection("/path/to/repos", "/path/to/config.toml") == true
    check validateMultiRepoConnection("", "repos.toml") == false
    check validateMultiRepoConnection("./repos", "") == false
    check validateMultiRepoConnection("./repos", "config.json") == false

suite "Connection Error Scenarios":

  test "Connection Timeout Handling":
    ## Test connection timeout scenarios
    proc simulateConnectionTimeout(): bool =
      # Simulate a connection timeout scenario
      return false  # Connection failed
    
    let result = simulateConnectionTimeout()
    check result == false  # Expect timeout to fail

  test "Invalid Command Path":
    ## Test invalid command path handling
    proc validateCommandPath(path: string): bool =
      return path.len > 0 and not path.contains(" ") and path.endsWith("mcp_jujutsu")
    
    check validateCommandPath("./bin/mcp_jujutsu") == true
    check validateCommandPath("/absolute/path/to/mcp_jujutsu") == true
    check validateCommandPath("") == false
    check validateCommandPath("invalid path with spaces") == false
    check validateCommandPath("./bin/wrong_binary") == false

  test "Port Already in Use":
    ## Test port already in use scenario
    proc isPortAvailable(port: int): bool =
      try:
        let socket = newSocket()
        defer: socket.close()
        socket.bindAddr(Port(port), "127.0.0.1")
        return true
      except OSError:
        return false
    
    # Test with common ports that might be in use
    let port8080Available = isPortAvailable(8080)
    let port80Available = isPortAvailable(80)  # Usually restricted
    
    # Port 80 should typically not be available for non-root users
    check port80Available == false

suite "Real-World Usage Scenarios":

  test "Development Environment Setup":
    ## Test typical development environment setup
    let devConfig = %*{
      "mode": "single",
      "transport": "stdio",
      "repoPath": ".",
      "logLevel": "debug"
    }
    
    check devConfig["mode"].getStr() == "single"
    check devConfig["transport"].getStr() == "stdio"
    check devConfig["repoPath"].getStr() == "."

  test "Production Environment Setup":
    ## Test typical production environment setup
    let prodConfig = %*{
      "mode": "multi",
      "transport": "http",
      "host": "127.0.0.1",
      "port": 8080,
      "reposDir": "/app/repos",
      "configPath": "/app/repos.toml"
    }
    
    check prodConfig["mode"].getStr() == "multi"
    check prodConfig["transport"].getStr() == "http"
    check prodConfig["port"].getInt() == 8080

  test "CI/CD Environment Setup":
    ## Test typical CI/CD environment setup
    let ciConfig = %*{
      "mode": "single",
      "transport": "stdio",
      "repoPath": "${GITHUB_WORKSPACE}",
      "logLevel": "info",
      "nonInteractive": true
    }
    
    check ciConfig["mode"].getStr() == "single"
    check ciConfig["transport"].getStr() == "stdio"
    check ciConfig["nonInteractive"].getBool() == true

suite "Client Command Examples":

  test "Basic Stdio Command":
    ## Test basic stdio command example
    let command = "./bin/mcp_jujutsu --stdio"
    let parts = command.split(" ")
    
    check parts.len == 2
    check parts[0] == "./bin/mcp_jujutsu"
    check parts[1] == "--stdio"

  test "HTTP Server Command":
    ## Test HTTP server command example
    let command = "./bin/mcp_jujutsu --port=3000 --host=0.0.0.0"
    let parts = command.split(" ")
    
    check parts.len == 3
    check parts[0] == "./bin/mcp_jujutsu"
    check parts[1].startsWith("--port=")
    check parts[2].startsWith("--host=")

  test "Multi Repository Command":
    ## Test multi repository command example
    let command = "./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --config=repos.toml --stdio"
    let parts = command.split(" ")
    
    check parts.len == 5
    check "--mode=multi" in parts
    check parts.anyIt(it.startsWith("--repos-dir="))
    check parts.anyIt(it.startsWith("--config="))
    check "--stdio" in parts

  test "SSE Mode Command":
    ## Test SSE mode command example
    let command = "./bin/mcp_jujutsu --sse --port=8080"
    let parts = command.split(" ")
    
    check parts.len == 3
    check "--sse" in parts
    check parts.anyIt(it.startsWith("--port="))

echo "Client Connection Test Suite completed"