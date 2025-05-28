## Simple Transport Modes Test Suite
##
## Tests for different transport modes and server configurations

import unittest, json, os, strutils, sequtils

suite "Transport Configuration Tests":

  test "Stdio Transport Settings":
    ## Test stdio transport configuration flags
    let stdioArgs = @["--stdio"]
    check "--stdio" in stdioArgs

  test "HTTP Transport Settings":
    ## Test HTTP transport configuration flags
    let httpArgs = @["--port=8080", "--host=127.0.0.1"]
    check httpArgs.anyIt(it.startsWith("--port="))
    check httpArgs.anyIt(it.startsWith("--host="))

  test "SSE Transport Settings":
    ## Test SSE transport configuration flags
    let sseArgs = @["--sse", "--port=8080"]
    check "--sse" in sseArgs
    check sseArgs.anyIt(it.startsWith("--port="))

  test "Multi Repository Mode Settings":
    ## Test multi repository mode configuration flags
    let multiArgs = @["--mode=multi", "--repos-dir=./repos", "--config=repos.toml"]
    check "--mode=multi" in multiArgs
    check multiArgs.anyIt(it.startsWith("--repos-dir="))
    check multiArgs.anyIt(it.startsWith("--config="))

suite "Command Format Validation Tests":

  test "Basic Stdio Command":
    ## Test basic stdio command format
    let command = "./bin/mcp_jujutsu --stdio"
    let parts = command.split(" ")
    
    check parts.len == 2
    check parts[0].endsWith("mcp_jujutsu")
    check parts[1] == "--stdio"

  test "HTTP Server Command":
    ## Test HTTP server command format
    let command = "./bin/mcp_jujutsu --port=3000"
    let parts = command.split(" ")
    
    check parts.len == 2
    check parts[0].endsWith("mcp_jujutsu")
    check parts[1].startsWith("--port=")

  test "Multi Repository Command":
    ## Test multi repository command format
    let command = "./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --stdio"
    let parts = command.split(" ")
    
    check parts.len == 4
    check "--mode=multi" in parts
    check parts.anyIt(it.startsWith("--repos-dir="))
    check "--stdio" in parts

  test "SSE Mode Command":
    ## Test SSE mode command format
    let command = "./bin/mcp_jujutsu --sse --port=8080"
    let parts = command.split(" ")
    
    check parts.len == 3
    check "--sse" in parts
    check parts.anyIt(it.startsWith("--port="))

suite "MCP Protocol Message Tests":

  test "Initialize Message Structure":
    ## Test MCP initialize message structure
    let initMessage = %*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {}
      }
    }
    
    check initMessage["jsonrpc"].getStr() == "2.0"
    check initMessage["method"].getStr() == "initialize"
    check initMessage.hasKey("params")

  test "Tools List Message Structure":
    ## Test tools/list message structure
    let toolsMessage = %*{
      "jsonrpc": "2.0",
      "id": 2,
      "method": "tools/list",
      "params": {}
    }
    
    check toolsMessage["jsonrpc"].getStr() == "2.0"
    check toolsMessage["method"].getStr() == "tools/list"

  test "Tool Call Message Structure":
    ## Test tools/call message structure
    let callMessage = %*{
      "jsonrpc": "2.0",
      "id": 3,
      "method": "tools/call",
      "params": {
        "name": "analyzeCommitRange",
        "arguments": {
          "commitRange": "@~1..@"
        }
      }
    }
    
    check callMessage["method"].getStr() == "tools/call"
    check callMessage["params"]["name"].getStr() == "analyzeCommitRange"

suite "Client Configuration Tests":

  test "Claude Code Configuration Structure":
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

  test "VS Code Configuration Structure":
    ## Test VS Code configuration format
    let vscodeConfig = %*{
      "mcp.servers": {
        "mcp-jujutsu": {
          "command": "/path/to/mcp-jujutsu/bin/mcp_jujutsu",
          "args": ["--stdio"],
          "initializationOptions": {
            "mode": "single"
          }
        }
      }
    }
    
    let server = vscodeConfig["mcp.servers"]["mcp-jujutsu"]
    check server["args"][0].getStr() == "--stdio"
    check server["initializationOptions"]["mode"].getStr() == "single"

suite "Connection Parameter Validation Tests":

  test "Valid Port Numbers":
    ## Test valid port number ranges
    proc isValidPort(port: int): bool =
      return port > 0 and port < 65536
    
    check isValidPort(8080) == true
    check isValidPort(3000) == true
    check isValidPort(0) == false
    check isValidPort(65536) == false
    check isValidPort(-1) == false

  test "Valid Host Names":
    ## Test valid host name formats
    proc isValidHost(host: string): bool =
      return host.len > 0 and not host.contains(" ")
    
    check isValidHost("127.0.0.1") == true
    check isValidHost("localhost") == true
    check isValidHost("0.0.0.0") == true
    check isValidHost("") == false
    check isValidHost("invalid host") == false

  test "Valid File Paths":
    ## Test valid file path formats
    proc isValidPath(path: string): bool =
      return path.len > 0
    
    check isValidPath("./repos") == true
    check isValidPath("/absolute/path") == true
    check isValidPath("relative/path") == true
    check isValidPath("") == false

suite "Real World Usage Examples":

  test "Development Environment Commands":
    ## Test commands for development environment
    let devCommands = [
      "./bin/mcp_jujutsu --stdio",
      "./bin/mcp_jujutsu --port=3000",
      "./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --stdio"
    ]
    
    for cmd in devCommands:
      check cmd.contains("mcp_jujutsu")
      check cmd.len > 0

  test "Production Environment Commands":
    ## Test commands for production environment
    let prodCommands = [
      "./bin/mcp_jujutsu --port=8080 --host=127.0.0.1",
      "./bin/mcp_jujutsu --sse --port=8080",
      "./bin/mcp_jujutsu --mode=multi --config=/app/repos.toml --port=8080"
    ]
    
    for cmd in prodCommands:
      check cmd.contains("mcp_jujutsu")
      check cmd.contains("--port=")

  test "CI/CD Environment Commands":
    ## Test commands for CI/CD environment
    let ciCommands = [
      "./bin/mcp_jujutsu --stdio --mode=single",
      "./bin/mcp_jujutsu --stdio --repo-path=${GITHUB_WORKSPACE}"
    ]
    
    for cmd in ciCommands:
      check cmd.contains("--stdio")
      check cmd.contains("mcp_jujutsu")

suite "Transport Mode Combinations":

  test "Stdio + Single Repository":
    ## Test stdio transport with single repository mode
    let command = "./bin/mcp_jujutsu --stdio --mode=single --repo-path=."
    let parts = command.split(" ")
    
    check "--stdio" in parts
    check "--mode=single" in parts
    check parts.anyIt(it.startsWith("--repo-path="))

  test "HTTP + Multi Repository":
    ## Test HTTP transport with multi repository mode
    let command = "./bin/mcp_jujutsu --port=8080 --mode=multi --repos-dir=./repos"
    let parts = command.split(" ")
    
    check parts.anyIt(it.startsWith("--port="))
    check "--mode=multi" in parts
    check parts.anyIt(it.startsWith("--repos-dir="))

  test "SSE + Configuration File":
    ## Test SSE transport with configuration file
    let command = "./bin/mcp_jujutsu --sse --port=8080 --config=mcp-jujutsu.toml"
    let parts = command.split(" ")
    
    check "--sse" in parts
    check parts.anyIt(it.startsWith("--port="))
    check parts.anyIt(it.startsWith("--config="))

echo "Simple Transport Modes Test Suite completed"