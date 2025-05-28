## Test cases for stdio transport
##
## This module tests the stdio transport functionality for MCP server.

import unittest, asyncdispatch, json, tables, streams, os
import ../../src/core/mcp/server
import ../../src/core/mcp/stdio_transport
import ../../src/core/config/config

# Mock streams for testing
type
  MockStream = ref object of FileStream
    data: string
    position: int
    output: seq[string]
    closed: bool

proc newMockStream(data: string = ""): MockStream =
  result = MockStream(
    data: data,
    position: 0,
    output: @[],
    closed: false
  )

proc readLine(s: MockStream): string =
  if s.closed:
    raise newException(IOError, "Stream is closed")
  
  if s.position >= s.data.len:
    return ""
  
  result = ""
  while s.position < s.data.len and s.data[s.position] != '\n':
    result.add(s.data[s.position])
    inc(s.position)
  
  if s.position < s.data.len and s.data[s.position] == '\n':
    inc(s.position)

proc writeLine(s: MockStream, line: string) =
  if s.closed:
    raise newException(IOError, "Stream is closed")
  s.output.add(line)

proc flush(s: MockStream) =
  if s.closed:
    raise newException(IOError, "Stream is closed")
  # No-op for mock

proc close(s: MockStream) =
  s.closed = true

proc isNil(s: MockStream): bool =
  return s == nil

# Helper to create a JSON-RPC request
proc createRequest(id: JsonNode, meth: string, params: JsonNode = newJObject()): JsonNode =
  result = %*{
    "jsonrpc": "2.0",
    "method": meth,
    "params": params
  }
  if not id.isNil:
    result["id"] = id

# Helper to parse response from mock output stream
proc getLastResponse(mockOut: MockStream): JsonNode =
  if mockOut.output.len > 0:
    return parseJson(mockOut.output[^1])
  return newJNull()

suite "StdioTransport Tests":
  var server: McpServer
  var transport: StdioTransport
  var mockIn: MockStream
  var mockOut: MockStream

  setup:
    # Create server with test config
    let config = Config(
      repoPath: "/test/repo",
      httpHost: "localhost",
      httpPort: 8080,
      useHttp: false,
      useStdio: true,
      serverMode: SingleRepo
    )
    server = newMcpServer(config)
    
    # Create transport
    transport = newStdioTransport(server)
    
    # Create mock streams
    mockIn = newMockStream()
    mockOut = newMockStream()

  test "StdioTransport Creation":
    # Test creating a new stdio transport
    check(transport != nil)
    # Skip checking private fields
    # Just verify the transport is created successfully

  test "Send Response":
    # Test response sending through public API
    # Cannot directly access private fields, so we test indirectly
    
    let response = %*{
      "jsonrpc": "2.0",
      "id": 1,
      "result": {"test": "value"}
    }
    
    transport.sendResponse(response)
    
    check(mockOut.output.len == 1)
    let sent = parseJson(mockOut.output[0])
    check(sent == response)

  test "Handle Initialize Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    let request = createRequest(%*1, "initialize", %*{
      "protocolVersion": "1.0",
      "capabilities": {}
    })
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 1)
    check(response.hasKey("result"))
    check(response["result"].hasKey("protocolVersion"))

  test "Handle Shutdown Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    let request = createRequest(%*2, "shutdown")
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 2)
    check(response["result"].kind == JNull)
    check(not transport.running)

  test "Handle Tools List Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a test tool
    proc testTool(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"result": "test"}
    
    server.registerTool("test_tool", testTool)
    
    let request = createRequest(%*3, "tools/list")
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 3)
    check(response.hasKey("result"))
    check(response["result"].hasKey("tools"))
    check(response["result"]["tools"].len == 1)
    check(response["result"]["tools"][0]["name"].getStr() == "test_tool")

  test "Handle Tool Call Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a test tool
    proc echoTool(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"echo": params["message"].getStr()}
    
    server.registerTool("echo", echoTool)
    
    let request = createRequest(%*4, "tools/call", %*{
      "name": "echo",
      "arguments": {"message": "hello"}
    })
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 4)
    check(response.hasKey("result"))
    check(response["result"]["echo"].getStr() == "hello")

  test "Handle Unknown Method":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    let request = createRequest(%*5, "unknown/method")
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 5)
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32601)
    check(response["error"]["message"].getStr().contains("Method not found"))

  test "Handle Request Without ID (Notification)":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    let request = %*{
      "jsonrpc": "2.0",
      "method": "test/notification",
      "params": {}
    }
    
    waitFor transport.handleRequest(request)
    
    # No response should be sent for notifications
    check(mockOut.output.len == 0)

  test "Read Loop - Valid Request":
    # Replace streams with mocks
    let requestData = """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
"""
    mockIn = newMockStream(requestData)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check response was sent
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 1)
    check(response.hasKey("result"))

  test "Read Loop - Invalid JSON":
    # Replace streams with mocks
    let invalidData = """invalid json data
"""
    mockIn = newMockStream(invalidData)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check error response was sent
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32700)  # Parse error
    check(response["error"]["message"].getStr().contains("Parse error"))

  test "Read Loop - Missing JSONRPC Version":
    # Replace streams with mocks
    let invalidRequest = """{"id":1,"method":"test","params":{}}
"""
    mockIn = newMockStream(invalidRequest)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check error response was sent
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32600)  # Invalid Request
    check(response["error"]["message"].getStr().contains("missing or incorrect jsonrpc version"))

  test "Read Loop - Wrong JSONRPC Version":
    # Replace streams with mocks
    let wrongVersionRequest = """{"jsonrpc":"1.0","id":1,"method":"test","params":{}}
"""
    mockIn = newMockStream(wrongVersionRequest)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check error response was sent
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32600)  # Invalid Request
    check(response["error"]["message"].getStr().contains("missing or incorrect jsonrpc version"))

  test "Read Loop - Missing Method":
    # Replace streams with mocks
    let noMethodRequest = """{"jsonrpc":"2.0","id":1,"params":{}}
"""
    mockIn = newMockStream(noMethodRequest)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check error response was sent
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32600)  # Invalid Request
    check(response["error"]["message"].getStr().contains("missing method"))

  test "Read Loop - EOF Handling":
    # Replace streams with mocks
    mockIn = newMockStream("")  # Empty stream simulates EOF
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop
    waitFor transport.readLoop()
    
    # Should have stopped running
    check(not transport.running)
    check(mockOut.output.len == 0)  # No error response for EOF

  test "Read Loop - Multiple Requests":
    # Replace streams with mocks
    let multipleRequests = """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}
"""
    mockIn = newMockStream(multipleRequests)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(200)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Check both responses were sent
    check(mockOut.output.len == 2)
    
    let response1 = parseJson(mockOut.output[0])
    check(response1["id"].getInt() == 1)
    check(response1["result"].hasKey("tools"))
    
    let response2 = parseJson(mockOut.output[1])
    check(response2["id"].getInt() == 2)
    check(response2["result"].hasKey("resources"))

  test "Start and Stop Transport":
    # Test starting the transport
    waitFor transport.start()
    check(transport.running)
    
    # Test stopping the transport
    waitFor transport.stop()
    check(not transport.running)

  test "Stop Transport Closes Streams":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Start and stop transport
    waitFor transport.start()
    waitFor transport.stop()
    
    # Check streams were closed
    check(mockIn.closed)
    check(mockOut.closed)

  test "Handle Resources List Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a test resource
    proc testResource(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"id": id, "content": "test"}
    
    server.registerResource("test_type", testResource)
    
    let request = createRequest(%*6, "resources/list")
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 6)
    check(response.hasKey("result"))
    check(response["result"].hasKey("resources"))
    check(response["result"]["resources"].len == 1)
    check(response["result"]["resources"][0]["type"].getStr() == "test_type")

  test "Handle Resource Read Request":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a test resource
    proc fileResource(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"content": "File content for " & id}
    
    server.registerResource("file", fileResource)
    
    let request = createRequest(%*7, "resources/read", %*{
      "type": "file",
      "id": "test.txt",
      "params": {}
    })
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 7)
    check(response.hasKey("result"))
    check(response["result"]["content"].getStr() == "File content for test.txt")

  test "Handle Tool Call Error":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a tool that returns an error
    proc errorTool(params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"error": {"code": -1, "message": "Tool error"}}
    
    server.registerTool("error_tool", errorTool)
    
    let request = createRequest(%*8, "tools/call", %*{
      "name": "error_tool",
      "arguments": {}
    })
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 8)
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -1)
    check(response["error"]["message"].getStr() == "Tool error")

  test "Handle Resource Read Error":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Register a resource that returns an error
    proc errorResource(id: string, params: JsonNode): Future[JsonNode] {.async.} =
      return %*{"error": {"code": -2, "message": "Resource not found"}}
    
    server.registerResource("error_type", errorResource)
    
    let request = createRequest(%*9, "resources/read", %*{
      "type": "error_type",
      "id": "missing",
      "params": {}
    })
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 9)
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -2)
    check(response["error"]["message"].getStr() == "Resource not found")

  test "Large Message Handling":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Create a large parameter object
    var largeParams = newJObject()
    for i in 0..999:
      largeParams["field" & $i] = %*("value" & $i)
    
    let request = createRequest(%*10, "tools/list", largeParams)
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 10)
    check(response.hasKey("result"))

  test "Empty Message Handling":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    let request = createRequest(%*11, "tools/list", newJObject())
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 11)
    check(response.hasKey("result"))

  test "Concurrent Read Write Operations":
    # This test simulates concurrent operations
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Create multiple requests
    var requests: seq[Future[void]] = @[]
    
    for i in 1..5:
      let request = createRequest(%*i, "tools/list")
      requests.add(transport.handleRequest(request))
    
    # Wait for all requests to complete
    waitFor all(requests)
    
    # Check all responses were sent
    check(mockOut.output.len == 5)
    
    # Verify each response
    for i in 0..4:
      let response = parseJson(mockOut.output[i])
      check(response["jsonrpc"].getStr() == "2.0")
      check(response["id"].getInt() == i + 1)
      check(response.hasKey("result"))

  test "Handle Request with Missing Optional Fields":
    # Replace streams with mocks
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Request without params field
    let request = %*{
      "jsonrpc": "2.0",
      "id": 12,
      "method": "tools/list"
    }
    
    waitFor transport.handleRequest(request)
    
    let response = getLastResponse(mockOut)
    check(response["jsonrpc"].getStr() == "2.0")
    check(response["id"].getInt() == 12)
    check(response.hasKey("result"))

  test "Stream Error Handling":
    # Test handling when stream operations fail
    transport.outputStream = mockOut
    mockOut.closed = true  # Simulate closed stream
    
    let response = %*{
      "jsonrpc": "2.0",
      "id": 1,
      "result": {"test": "value"}
    }
    
    # This should not crash despite closed stream
    try:
      transport.sendResponse(response)
      check(false)  # Should have raised exception
    except IOError:
      check(true)  # Expected exception

  test "Read Loop Exception Handling":
    # Create a stream that will cause an exception
    let exceptionData = """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
"""
    mockIn = newMockStream(exceptionData)
    transport.inputStream = mockIn
    transport.outputStream = mockOut
    
    # Override handleRequest to throw exception
    proc failingHandler(params: JsonNode): Future[JsonNode] {.async.} =
      raise newException(Exception, "Test exception")
    
    server.registerTool("tools/list", failingHandler)
    transport.running = true
    
    # Start read loop in background
    let readTask = transport.readLoop()
    
    # Wait a bit for processing
    waitFor sleepAsync(100)
    
    # Stop the transport
    transport.running = false
    
    # Wait for read loop to complete
    waitFor readTask
    
    # Should have sent internal error response
    check(mockOut.output.len == 1)
    let response = parseJson(mockOut.output[0])
    check(response["jsonrpc"].getStr() == "2.0")
    check(response.hasKey("error"))
    check(response["error"]["code"].getInt() == -32603)  # Internal error