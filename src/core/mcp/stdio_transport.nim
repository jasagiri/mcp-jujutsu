## Stdio Transport implementation for MCP Server
##
## This module implements stdio (standard input/output) transport for MCP,
## allowing the server to communicate via stdin/stdout using JSON-RPC 2.0.

import std/[asyncdispatch, json, strutils, tables, streams, os]
import ./server
import ../logging/logger

type
  StdioTransport* = ref object of Transport
    ## Stdio transport for MCP communication
    server: McpServer
    running: bool
    inputStream: FileStream
    outputStream: FileStream

proc sendResponse(transport: StdioTransport, response: JsonNode) =
  ## Sends a JSON-RPC response over stdout
  let responseStr = $response
  transport.outputStream.writeLine(responseStr)
  transport.outputStream.flush()
  
  let ctx = newLogContext("stdio-transport", "sendResponse")
    .withMetadata("responseLength", $responseStr.len)
  debug("Sent response", ctx)

proc handleRequest(transport: StdioTransport, request: JsonNode): Future[void] {.async.} =
  ## Handles a single JSON-RPC request
  let ctx = newLogContext("stdio-transport", "handleRequest")
  
  # Extract request components
  let id = if request.hasKey("id"): request["id"] else: newJNull()
  let methodName = if request.hasKey("method"): request["method"].getStr("") else: ""
  let params = if request.hasKey("params"): request["params"] else: newJObject()
  
  let requestCtx = ctx
    .withMetadata("method", methodName)
    .withMetadata("hasId", $(not id.isNil))
  
  debug("Processing request", requestCtx)
  
  var response: JsonNode
  
  case methodName
  of "initialize":
    let result = await transport.server.handleInitialize(params)
    response = %*{
      "jsonrpc": "2.0",
      "id": id,
      "result": result
    }
  
  of "shutdown":
    await transport.server.handleShutdown()
    response = %*{
      "jsonrpc": "2.0",
      "id": id,
      "result": newJNull()
    }
    transport.running = false
  
  of "tools/call":
    let toolName = params["name"].getStr()
    let toolParams = if params.hasKey("arguments"): params["arguments"] else: newJObject()
    let result = await transport.server.handleToolCall(toolName, toolParams)
    
    if result.hasKey("error"):
      response = %*{
        "jsonrpc": "2.0",
        "id": id,
        "error": result["error"]
      }
    else:
      response = %*{
        "jsonrpc": "2.0",
        "id": id,
        "result": result
      }
  
  of "resources/read":
    let resourceType = params["type"].getStr()
    let resourceId = params["id"].getStr()
    let resourceParams = if params.hasKey("params"): params["params"] else: newJObject()
    let result = await transport.server.handleResourceRequest(resourceType, resourceId, resourceParams)
    
    if result.hasKey("error"):
      response = %*{
        "jsonrpc": "2.0",
        "id": id,
        "error": result["error"]
      }
    else:
      response = %*{
        "jsonrpc": "2.0",
        "id": id,
        "result": result
      }
  
  of "tools/list":
    let toolNames = transport.server.getToolNames()
    var tools = newJArray()
    for name in toolNames:
      tools.add(%*{"name": name})
    
    response = %*{
      "jsonrpc": "2.0",
      "id": id,
      "result": {
        "tools": tools
      }
    }
  
  of "resources/list":
    let resourceTypes = transport.server.getResourceTypes()
    var resources = newJArray()
    for resType in resourceTypes:
      resources.add(%*{"type": resType})
    
    response = %*{
      "jsonrpc": "2.0",
      "id": id,
      "result": {
        "resources": resources
      }
    }
  
  else:
    response = %*{
      "jsonrpc": "2.0",
      "id": id,
      "error": {
        "code": -32601,
        "message": "Method not found: " & methodName
      }
    }
  
  # Send response if request had an id
  if not id.isNil:
    transport.sendResponse(response)

proc readLoop(transport: StdioTransport) {.async.} =
  ## Main loop for reading and processing requests from stdin
  let ctx = newLogContext("stdio-transport", "readLoop")
  info("Starting stdio read loop", ctx)
  
  while transport.running:
    try:
      # Read line from stdin
      let line = transport.inputStream.readLine()
      
      if line == "":
        # EOF reached
        debug("EOF reached on stdin", ctx)
        transport.running = false
        break
      
      # Parse JSON-RPC request
      let request = parseJson(line)
      
      # Validate JSON-RPC format
      if not request.hasKey("jsonrpc") or request["jsonrpc"].getStr() != "2.0":
        let errorResponse = %*{
          "jsonrpc": "2.0",
          "id": request.getOrDefault("id"),
          "error": {
            "code": -32600,
            "message": "Invalid Request: missing or incorrect jsonrpc version"
          }
        }
        transport.sendResponse(errorResponse)
        continue
      
      if not request.hasKey("method"):
        let errorResponse = %*{
          "jsonrpc": "2.0",
          "id": request.getOrDefault("id"),
          "error": {
            "code": -32600,
            "message": "Invalid Request: missing method"
          }
        }
        transport.sendResponse(errorResponse)
        continue
      
      # Handle the request
      await transport.handleRequest(request)
      
    except JsonParsingError as e:
      let errorCtx = ctx.withMetadata("error", e.msg)
      error("Failed to parse JSON-RPC request", errorCtx)
      
      # Send parse error response
      let errorResponse = %*{
        "jsonrpc": "2.0",
        "id": newJNull(),
        "error": {
          "code": -32700,
          "message": "Parse error: " & e.msg
        }
      }
      transport.sendResponse(errorResponse)
      
    except Exception as e:
      let errorCtx = ctx.withMetadata("error", e.msg)
      logException(e, "Error in read loop", errorCtx)
      
      # Send internal error response
      let errorResponse = %*{
        "jsonrpc": "2.0",
        "id": newJNull(),
        "error": {
          "code": -32603,
          "message": "Internal error: " & e.msg
        }
      }
      transport.sendResponse(errorResponse)
  
  info("Stdio read loop ended", ctx)

method start*(transport: StdioTransport): Future[void] {.async.} =
  ## Starts the stdio transport
  let ctx = newLogContext("stdio-transport", "start")
  info("Starting stdio transport", ctx)
  
  transport.running = true
  
  # Start the read loop
  asyncCheck transport.readLoop()

method stop*(transport: StdioTransport): Future[void] {.async.} =
  ## Stops the stdio transport
  let ctx = newLogContext("stdio-transport", "stop")
  info("Stopping stdio transport", ctx)
  
  transport.running = false
  
  # Close streams
  if not transport.inputStream.isNil:
    transport.inputStream.close()
  if not transport.outputStream.isNil:
    transport.outputStream.close()

proc newStdioTransport*(server: McpServer): StdioTransport =
  ## Creates a new stdio transport
  result = StdioTransport(
    server: server,
    running: false,
    inputStream: newFileStream(stdin),
    outputStream: newFileStream(stdout)
  )