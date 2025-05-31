## Tests for SSE (Server-Sent Events) transport
##
## Tests the SSE transport implementation for MCP servers.

import std/[unittest, asyncdispatch, json, strutils, tables, httpclient, net]
import ../../src/core/mcp/sse_transport
import ../../src/core/mcp/server

suite "SSE Transport Tests":
  test "Create new SSE transport":
    let mcpServer = newMcpServer("test-server", "1.0.0")
    let transport = newSseTransport("localhost", 8080, mcpServer)
    
    check transport.host == "localhost"
    check transport.port == 8080
    check transport.mcpServer == mcpServer
    check transport.startCalled == false
    check transport.stopCalled == false

  test "Format SSE event - basic":
    let data = %*{"message": "Hello, World!"}
    let event = formatSseEvent("test", data)
    
    check "event: test\n" in event
    check "data: {\"message\":\"Hello, World!\"}\n" in event
    check event.endsWith("\n\n")

  test "Format SSE event - with ID":
    let data = %*{"status": "ok"}
    let event = formatSseEvent("status", data, 42)
    
    check "id: 42\n" in event
    check "event: status\n" in event
    check "data: {\"status\":\"ok\"}\n" in event

  test "Format SSE event - multiline data":
    let data = %*{
      "lines": [
        "first line",
        "second line"
      ]
    }
    let event = formatSseEvent("multiline", data)
    
    # Should split JSON across multiple data: lines
    check "event: multiline\n" in event
    check "data: {" in event
    check "\n\n" in event

  test "Format SSE event - empty event type":
    let data = %*{"test": true}
    let event = formatSseEvent("", data)
    
    check "event:" notin event  # Should not include event field
    check "data: {\"test\":true}\n" in event

  test "SSE transport lifecycle":
    let mcpServer = newMcpServer("test-server", "1.0.0")
    let transport = newSseTransport("127.0.0.1", 0, mcpServer)  # Use port 0 for random port
    
    check transport.startCalled == false
    check transport.stopCalled == false
    
    # Note: We can't easily test actual server start/stop without more infrastructure
    # but we can verify the flags are set correctly

  test "JSON-RPC request handling setup":
    # Test that the transport can be created and configured
    let mcpServer = newMcpServer("test-server", "1.0.0")
    
    # Add a test tool
    mcpServer.registerTool("test_tool", proc(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"result": "success"}
    )
    
    let transport = newSseTransport("localhost", 8081, mcpServer)
    
    check transport.mcpServer.tools.len == 1
    check transport.mcpServer.tools.hasKey("test_tool")

  test "SSE response formatting":
    # Test the SSE formatting for different response types
    
    # Success response
    let successResponse = %*{
      "jsonrpc": "2.0",
      "id": 1,
      "result": {"status": "initialized"}
    }
    let successEvent = formatSseEvent("message", successResponse, 1)
    check "id: 1\n" in successEvent
    check "event: message\n" in successEvent
    check "\"jsonrpc\":\"2.0\"" in successEvent
    
    # Error response
    let errorResponse = %*{
      "jsonrpc": "2.0",
      "id": 2,
      "error": {
        "code": -32601,
        "message": "Method not found"
      }
    }
    let errorEvent = formatSseEvent("error", errorResponse, 2)
    check "id: 2\n" in errorEvent
    check "event: error\n" in errorEvent
    check "\"error\":" in errorEvent
    check "-32601" in errorEvent

  test "Complex SSE data formatting":
    # Test with complex nested data
    let complexData = %*{
      "tools": [
        {
          "name": "analyze_commit",
          "description": "Analyzes a commit",
          "inputSchema": {
            "type": "object",
            "properties": {
              "commitId": {"type": "string"}
            }
          }
        },
        {
          "name": "split_commit",
          "description": "Splits a commit",
          "inputSchema": {
            "type": "object",
            "properties": {
              "commitId": {"type": "string"},
              "parts": {"type": "array"}
            }
          }
        }
      ]
    }
    
    let event = formatSseEvent("tools", complexData, 100)
    check "id: 100\n" in event
    check "event: tools\n" in event
    # The JSON should be split across multiple data: lines
    let dataLines = event.split('\n').filterIt(it.startsWith("data: "))
    check dataLines.len > 0

  test "Edge cases in SSE formatting":
    # Empty data
    let emptyData = newJObject()
    let emptyEvent = formatSseEvent("empty", emptyData)
    check "event: empty\n" in emptyEvent
    check "data: {}\n" in emptyEvent
    
    # Null values
    let nullData = %*{"value": newJNull()}
    let nullEvent = formatSseEvent("null", nullData)
    check "data: {\"value\":null}\n" in nullEvent
    
    # Special characters in event type
    let specialEvent = formatSseEvent("test-event_123", %*{"ok": true})
    check "event: test-event_123\n" in specialEvent

when isMainModule:
  waitFor main()