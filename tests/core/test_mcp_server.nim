## Test cases for core MCP server
##
## This module tests the core MCP server functionality.

import unittest, asyncdispatch, json, tables
import ../../src/core/mcp/server
import ../../src/core/config/config

suite "Core MCP Server Tests":
  
  test "Server Creation":
    # Test creating a new MCP server
    let config = Config(
      repoPath: "/test/repo",
      httpHost: "localhost",
      httpPort: 8080,
      useHttp: true,
      useStdio: false,
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    check(server != nil)
    check(server.config == config)
    check(not server.initialized)
  
  test "Tool Registration":
    # Test registering tools with the server
    let config = Config(
      repoPath: "/test/repo",
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    
    proc testTool(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"result": "test"}
    
    server.registerTool("test_tool", testTool)
    check(server.tools.hasKey("test_tool"))
  
  test "Resource Registration":
    # Test registering resource types
    let config = Config(
      repoPath: "/test/repo",
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    
    proc testResource(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"id": id, "type": "test"}
    
    server.registerResourceType("test_resource", testResource)
    check(server.resources.hasKey("test_resource"))
  
  test "Initialize Handler":
    # Test initialization handling
    let config = Config(
      repoPath: "/test/repo",
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    
    let responseFuture = server.handleInitialize(%*{})
    let response = waitFor responseFuture
    check(response.hasKey("protocol"))
    check(response.hasKey("server"))
    check(server.initialized)
  
  test "Tool Call Handler":
    # Test handling tool calls
    let config = Config(
      repoPath: "/test/repo",
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    
    proc testTool(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"echo": params["message"]}
    
    server.registerTool("echo", testTool)
    
    let responseFuture = server.handleToolCall("echo", %*{"message": "hello"})
    let response = waitFor responseFuture
    check(response["echo"].getStr == "hello")
  
  test "Transport Management":
    # Test adding transports
    let config = Config(
      repoPath: "/test/repo",
      serverMode: SingleRepo
    )
    
    let server = newMcpServer(config)
    
    # Create a mock transport
    let transport = Transport()
    server.addTransport(transport)
    
    check(server.transports.len == 1)