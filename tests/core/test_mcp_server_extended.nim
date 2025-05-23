## Extended tests for MCP server functionality

import std/[unittest, asyncdispatch, json, tables, options, strutils]
import ../../src/core/mcp/server
import ../../src/core/config/config

suite "Extended MCP Server Tests":
  test "Server Configuration":
    let config = newDefaultConfig()
    let server = newMcpServer(config)
    
    check server.config.serverName == "MCP-Jujutsu"
    check server.config.serverPort == 8080
    check server.initialized == false

  test "Multiple Tool Registration":
    let config = newDefaultConfig()
    let server = newMcpServer(config)
    
    # Register multiple tools
    proc tool1(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"tool": "tool1", "params": params}
    
    proc tool2(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"tool": "tool2", "params": params}
    
    proc tool3(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"tool": "tool3", "params": params}
    
    server.registerTool("analyzeCode", tool1)
    server.registerTool("splitCommit", tool2)
    server.registerTool("validateCommit", tool3)
    
    check server.tools.len == 3
    check server.tools.hasKey("analyzeCode")
    check server.tools.hasKey("splitCommit")
    check server.tools.hasKey("validateCommit")

  test "Multiple Resource Registration":
    let config = newDefaultConfig()
    let server = newMcpServer(config)
    
    # Register multiple resources (using direct assignment since registerResource might not exist)
    proc resource1(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"resource": "resource1", "id": id}
    
    proc resource2(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"resource": "resource2", "id": id}
    
    server.resources["repository"] = resource1
    server.resources["analysis"] = resource2
    
    check server.resources.len == 2
    check server.resources.hasKey("repository")
    check server.resources.hasKey("analysis")

  test "Transport Start/Stop":
    # Test base transport methods
    let transport = Transport(
      startCalled: false,
      stopCalled: false
    )
    
    # Test start method
    waitFor transport.start()
    check transport.startCalled == true
    
    # Test stop method
    waitFor transport.stop()
    check transport.stopCalled == true

  test "Error Handling in Handlers":
    let config = newDefaultConfig()
    let server = newMcpServer(config)
    
    # Register a tool that throws an error
    proc errorTool(params: JsonNode): Future[JsonNode] {.async.} =
      raise newException(ValueError, "Test error in tool")
    
    server.registerTool("errorTool", errorTool)
    
    # The handleToolCall should handle the error gracefully
    let response = waitFor server.handleToolCall("errorTool", %*{})
    check response.hasKey("error")
    let errorMessage = response["error"]["message"].getStr()
    check errorMessage.find("Test error in tool") >= 0

  test "Resource Handler with Parameters":
    let config = newDefaultConfig()
    let server = newMcpServer(config)
    
    # Register a resource that uses parameters
    proc paramResource(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      let filter = if params.hasKey("filter"): params["filter"].getStr() else: "*"
      return %*{
        "id": id,
        "filter": filter,
        "data": ["item1", "item2", "item3"]
      }
    
    server.registerResourceType("filtered", paramResource)
    
    let params = %*{
      "filter": "*.nim"
    }
    
    let response = waitFor server.handleResourceRequest("filtered", "test-id", params)
    check response["id"].getStr() == "test-id"
    check response["filter"].getStr() == "*.nim"
    check response["data"].len == 3