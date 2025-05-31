## SSE (Server-Sent Events) Transport for MCP
##
## Implements the SSE transport protocol for MCP servers.
## This allows HTTP-based streaming communication with Claude.

import std/[asyncdispatch, asynchttpserver, json, strutils, times, tables]
import server

type
  SseTransport* = ref object of Transport
    host*: string
    port*: int
    server*: AsyncHttpServer
    mcpServer*: McpServer
    
proc newSseTransport*(host: string, port: int, mcpServer: McpServer): SseTransport =
  ## Create a new SSE transport
  result = SseTransport(
    host: host,
    port: port,
    server: newAsyncHttpServer(),
    mcpServer: mcpServer,
    startCalled: false,
    stopCalled: false
  )

proc formatSseEvent*(eventType: string, data: JsonNode, id: int = 0): string =
  ## Format a JSON message as an SSE event
  result = ""
  if id > 0:
    result.add("id: " & $id & "\n")
  if eventType.len > 0:
    result.add("event: " & eventType & "\n")
  
  # Split data into lines and prefix each with "data: "
  let jsonStr = $data
  for line in jsonStr.splitLines():
    result.add("data: " & line & "\n")
  
  result.add("\n")  # Empty line to end the event

proc handleJsonRpcOverSse(transport: SseTransport, req: Request) {.async.} =
  ## Handle JSON-RPC requests and return SSE-formatted responses
  try:
    # Parse request body
    let body = req.body
    if body.len == 0:
      await req.respond(Http400, "Empty request body")
      return
      
    let jsonReq = parseJson(body)
    
    # Extract request details
    let methodName = jsonReq{"method"}.getStr()
    let params = jsonReq{"params"}
    let id = jsonReq{"id"}
    
    if methodName.len == 0:
      await req.respond(Http400, "Missing method name")
      return
    
    # Process the request
    var response: JsonNode
    var eventType = "message"
    
    case methodName:
    of "initialize":
      let result = await transport.mcpServer.handleInitialize(params)
      response = %*{"jsonrpc": "2.0", "id": id, "result": result}
      
    of "tools/list":
      # Get the list of tools from the server
      var tools: seq[JsonNode] = @[]
      for name, handler in transport.mcpServer.tools:
        # For now, we just return the tool names
        # In a full implementation, tool metadata would be stored separately
        tools.add(%*{
          "name": name,
          "description": "Tool: " & name,
          "inputSchema": {}
        })
      response = %*{"jsonrpc": "2.0", "id": id, "result": {"tools": tools}}
      
    of "tools/call":
      if params.hasKey("name"):
        let toolName = params["name"].getStr()
        let toolParams = if params.hasKey("arguments"): params["arguments"] else: newJObject()
        let result = await transport.mcpServer.handleToolCall(toolName, toolParams)
        response = %*{"jsonrpc": "2.0", "id": id, "result": result}
      else:
        response = %*{
          "jsonrpc": "2.0", 
          "id": id, 
          "error": {"code": -32602, "message": "Invalid params: missing 'name'"}
        }
        eventType = "error"
        
    else:
      response = %*{
        "jsonrpc": "2.0", 
        "id": id, 
        "error": {"code": -32601, "message": "Method not found: " & methodName}
      }
      eventType = "error"
    
    # Format response as SSE
    let sseResponse = formatSseEvent(eventType, response, 1)
    
    # Set SSE headers
    let headers = newHttpHeaders([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache"),
      ("Connection", "close"),  # Close after sending
      ("Access-Control-Allow-Origin", "*"),
      ("Access-Control-Allow-Methods", "POST, OPTIONS"),
      ("Access-Control-Allow-Headers", "Content-Type"),
      ("X-Accel-Buffering", "no")
    ])
    
    # Send SSE response
    await req.respond(Http200, sseResponse, headers)
    
  except JsonParsingError as e:
    echo "Failed to parse JSON request: ", e.msg
    await req.respond(Http400, "Invalid JSON: " & e.msg)
  except CatchableError as e:
    echo "Error handling SSE request: ", e.msg
    await req.respond(Http500, "Internal server error: " & e.msg)

proc handleHttpRequest(transport: SseTransport, req: Request) {.async.} =
  ## Handle HTTP requests for SSE transport
  try:
    # Handle CORS preflight
    if req.reqMethod == HttpOptions:
      let headers = newHttpHeaders([
        ("Access-Control-Allow-Origin", "*"),
        ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
        ("Access-Control-Allow-Headers", "Content-Type, Accept"),
        ("Access-Control-Max-Age", "86400")
      ])
      await req.respond(Http200, "", headers)
      return
    
    # All paths handle JSON-RPC with SSE response
    if req.reqMethod == HttpPost:
      await transport.handleJsonRpcOverSse(req)
    else:
      await req.respond(Http405, "Method not allowed")
      
  except CatchableError as e:
    echo "Error handling HTTP request: ", e.msg
    try:
      await req.respond(Http500, "Internal server error")
    except CatchableError:
      discard

method start*(transport: SseTransport): Future[void] {.async.} =
  ## Start the SSE transport server
  echo "Starting SSE transport on ", transport.host, ":", transport.port
  transport.startCalled = true
  
  proc callback(req: Request) {.async.} =
    await transport.handleHttpRequest(req)
  
  try:
    asyncCheck transport.server.serve(Port(transport.port), callback, transport.host)
  except OSError as e:
    echo "Failed to start SSE server: ", e.msg
    transport.startCalled = false

method stop*(transport: SseTransport): Future[void] {.async.} =
  ## Stop the SSE transport server
  echo "Stopping SSE transport"
  transport.stopCalled = true
  transport.server.close()