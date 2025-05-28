## Core MCP Server implementation
##
## This module implements the base Model Context Protocol server functionality
## that is common to both single-repository and multi-repository modes.

import std/[asyncdispatch, json, options, strutils, tables]
import ../config/config
import ../logging/logger

type
  ToolHandler* = proc(params: JsonNode): Future[JsonNode] {.gcsafe.}
    ## Handler function for MCP tools. Takes parameters and returns a JSON result.
  
  ResourceHandler* = proc(id: string, params: JsonNode): Future[JsonNode] {.gcsafe.}
    ## Handler function for MCP resources. Takes resource ID and parameters.
  
  Transport* = ref object of RootObj
    ## Base class for MCP transport implementations (HTTP, stdio, etc.)
    startCalled*: bool  ## Flag indicating if start() has been called
    stopCalled*: bool   ## Flag indicating if stop() has been called
  
  McpServer* = ref object
    ## Base MCP server that handles protocol operations
    config*: Config                              ## Server configuration
    tools*: Table[string, ToolHandler]          ## Registered tool handlers
    resources*: Table[string, ResourceHandler]   ## Registered resource handlers
    transports*: seq[Transport]                  ## Active transport layers
    initialized*: bool                           ## Server initialization status

# Transport base methods
method start*(transport: Transport): Future[void] {.base, async.} =
  ## Start method for the Transport base class
  transport.startCalled = true
  result = newFuture[void]()
  complete(result)

method stop*(transport: Transport): Future[void] {.base, async.} =
  ## Stop method for the Transport base class
  transport.stopCalled = true
  result = newFuture[void]()
  complete(result)

proc newMcpServer*(config: Config): McpServer =
  ## Creates a new base MCP server instance
  # Configure logger from MCP config
  if not configureFromConfig(globalLogger, config):
    warn("Failed to configure logger from MCP config")
  
  # Initialize the logger
  globalLogger.init()
  info("Creating new MCP server instance")
  
  result = McpServer(
    config: config,
    tools: initTable[string, ToolHandler](),
    resources: initTable[string, ResourceHandler](),
    transports: @[],
    initialized: false
  )

proc registerTool*(server: McpServer, name: string, handler: ToolHandler) =
  ## Registers a tool with the server
  server.tools[name] = handler

proc registerResourceType*(server: McpServer, resourceType: string, handler: ResourceHandler) =
  ## Registers a resource type with the server
  server.resources[resourceType] = handler

proc addTransport*(server: McpServer, transport: Transport) =
  ## Adds a transport to the server
  server.transports.add(transport)

proc getToolNames*(server: McpServer): seq[string] =
  ## Gets a list of all registered tool names
  result = @[]
  for name in server.tools.keys:
    result.add(name)

proc getResourceTypes*(server: McpServer): seq[string] =
  ## Gets a list of all registered resource types
  result = @[]
  for resourceType in server.resources.keys:
    result.add(resourceType)

proc handleInitialize*(server: McpServer, params: JsonNode): Future[JsonNode] {.async.} =
  ## Handles an initialize request
  let ctx = newLogContext("mcp-server", "initialize")
  
  info("Initializing MCP server", ctx)
  
  # Extract client capabilities from params
  if params.hasKey("client"):
    let clientInfo = params["client"]
    let clientCtx = ctx.withMetadata("client", clientInfo.getStr())
    debug("Client info received", clientCtx)
  
  # Respond with server capabilities
  let toolNames = server.getToolNames()
  let resourceTypes = server.getResourceTypes()
  
  let capabilitiesCtx = ctx
    .withMetadata("toolCount", $toolNames.len)
    .withMetadata("resourceCount", $resourceTypes.len)
  
  debug("Building server capabilities", capabilitiesCtx)
  
  var capabilities = %*{
    "protocol": {
      "version": "2025-03-26",
      "name": "ModelContextProtocol"
    },
    "server": {
      "name": "MCP-Jujutsu",
      "version": "0.1.0"
    },
    "tools": {
      "supported": true,
      "methods": toolNames
    },
    "resources": {
      "supported": true,
      "types": resourceTypes
    }
  }
  
  # Mark server as initialized
  server.initialized = true
  
  info("MCP server initialized successfully", capabilitiesCtx)
  return capabilities

proc handleShutdown*(server: McpServer): Future[void] {.async.} =
  ## Handles a shutdown request
  let ctx = newLogContext("mcp-server", "shutdown")
    .withMetadata("transportCount", $server.transports.len)
  
  info("Shutting down MCP server...", ctx)
  
  for transport in server.transports:
    try:
      await transport.stop()
    except Exception as e:
      logException(e, "Error stopping transport", ctx)
  
  info("MCP server shutdown complete", ctx)
  
  # Close the logger when the server shuts down
  globalLogger.close()

proc handleToolCall*(server: McpServer, toolName: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Handles a tool call
  if not server.tools.hasKey(toolName):
    return %*{
      "error": {
        "code": -32601,
        "message": "Method not found: " & toolName
      }
    }
  
  try:
    let ctx = newLogContext("mcp-server", "toolCall")
      .withMetadata("toolName", toolName)
    
    debug("Executing tool: " & toolName, ctx)
    let result = await server.tools[toolName](params)
    debug("Tool execution completed: " & toolName, ctx)
    return result
  except Exception as e:
    let ctx = newLogContext("mcp-server", "toolCall")
      .withMetadata("toolName", toolName)
    
    logException(e, "Error executing tool", ctx)
    
    return %*{
      "error": {
        "code": -32000,
        "message": "Error executing tool: " & e.msg
      }
    }

proc handleResourceRequest*(server: McpServer, resourceType: string, id: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Handles a resource request
  if not server.resources.hasKey(resourceType):
    return %*{
      "error": {
        "code": -32601,
        "message": "Resource type not found: " & resourceType
      }
    }
  
  try:
    let ctx = newLogContext("mcp-server", "resourceRequest")
      .withMetadata("resourceType", resourceType)
      .withMetadata("resourceId", id)
    
    debug("Retrieving resource: " & resourceType & "/" & id, ctx)
    let result = await server.resources[resourceType](id, params)
    debug("Resource retrieval completed: " & resourceType & "/" & id, ctx)
    return result
  except Exception as e:
    let ctx = newLogContext("mcp-server", "resourceRequest")
      .withMetadata("resourceType", resourceType)
      .withMetadata("resourceId", id)
    
    logException(e, "Error retrieving resource", ctx)
    
    return %*{
      "error": {
        "code": -32000,
        "message": "Error retrieving resource: " & e.msg
      }
    }

proc start*(server: McpServer): Future[void] {.async.} =
  ## Starts the server
  let ctx = newLogContext("mcp-server", "start")
    .withMetadata("transportCount", $server.transports.len)
  
  info("Starting MCP server...", ctx)
  var startFutures: seq[Future[void]] = @[]
  
  for transport in server.transports:
    startFutures.add(transport.start())
  
  for future in startFutures:
    await future
  
  info("MCP server started successfully", ctx)