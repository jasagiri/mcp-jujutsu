## MCP-Jujutsu - Main Entry Point
##
## This module provides the main entry point for the MCP-Jujutsu server,
## which can run in either single-repository mode or multi-repository mode.

import std/[asyncdispatch, asynchttpserver, parseopt, strutils, json, net, os, posix, times]

# Core components
import core/config/config as core_config
import core/mcp/server as base_server

# Single repository mode components
import single_repo/config/config as single_config
import single_repo/mcp/server as single_server

# Multi repository mode components
import multi_repo/config/config as multi_config
import multi_repo/mcp/server as multi_server

# Import transports
import core/mcp/stdio_transport
import core/mcp/sse_transport

# Global variable for signal handler
var globalServerPort: int = 0

# HTTP Transport - Common for both modes
type
  HttpTransport* = ref object of base_server.Transport
    host*: string
    port*: int
    server*: AsyncHttpServer
    mcpServer*: base_server.McpServer

proc newHttpTransport*(host: string, port: int, mcpServer: base_server.McpServer): HttpTransport =
  result = HttpTransport(
    host: host,
    port: port,
    server: newAsyncHttpServer(),
    mcpServer: mcpServer,
    startCalled: false,
    stopCalled: false
  )

proc handleHttpRequest(transport: HttpTransport, req: Request): Future[void] {.async.} =
  ## Handle HTTP requests for MCP protocol
  try:
    # Basic CORS headers
    let headers = newHttpHeaders([
      ("Access-Control-Allow-Origin", "*"),
      ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
      ("Access-Control-Allow-Headers", "Content-Type"),
      ("Content-Type", "application/json")
    ])
    
    if req.reqMethod == HttpOptions:
      await req.respond(Http200, "", headers)
      return
    
    # Handle health check endpoint
    if req.reqMethod == HttpGet and req.url.path == "/health":
      let healthResponse = %*{
        "status": "healthy",
        "version": "0.1.0",
        "server": "MCP-Jujutsu",
        "timestamp": $now(),
        "uptime": "running"
      }
      await req.respond(Http200, $healthResponse, headers)
      return
    
    # Handle status endpoint
    if req.reqMethod == HttpGet and req.url.path == "/status":
      let statusResponse = %*{
        "server": "MCP-Jujutsu",
        "version": "0.1.0",
        "protocol": "MCP",
        "transports": ["http", "stdio"],
        "capabilities": {
          "tools": true,
          "resources": true
        }
      }
      await req.respond(Http200, $statusResponse, headers)
      return
    
    # Handle root endpoint
    if req.reqMethod == HttpGet and req.url.path == "/":
      let welcomeResponse = %*{
        "message": "MCP-Jujutsu Server",
        "version": "0.1.0",
        "endpoints": {
          "health": "/health",
          "status": "/status",
          "mcp": "/mcp"
        },
        "documentation": "https://github.com/jasagiri/mcp-jujutsu"
      }
      await req.respond(Http200, $welcomeResponse, headers)
      return
    
    # Only allow POST for MCP endpoint
    if req.reqMethod != HttpPost:
      await req.respond(Http405, "Method not allowed", headers)
      return
    
    # Parse JSON-RPC request
    let body = req.body
    let jsonReq = parseJson(body)
    
    # Handle MCP requests
    if jsonReq.hasKey("method"):
      let methodName = jsonReq["method"].getStr()
      let params = if jsonReq.hasKey("params"): jsonReq["params"] else: newJObject()
      let id = if jsonReq.hasKey("id"): jsonReq["id"] else: newJNull()
      
      var response: JsonNode
      
      case methodName:
      of "initialize":
        let result = await transport.mcpServer.handleInitialize(params)
        response = %*{"jsonrpc": "2.0", "id": id, "result": result}
      of "tools/call":
        if params.hasKey("name"):
          let toolName = params["name"].getStr()
          let toolParams = if params.hasKey("arguments"): params["arguments"] else: newJObject()
          let result = await transport.mcpServer.handleToolCall(toolName, toolParams)
          response = %*{"jsonrpc": "2.0", "id": id, "result": result}
        else:
          response = %*{"jsonrpc": "2.0", "id": id, "error": {"code": -32602, "message": "Invalid params: missing 'name'"}}
      else:
        response = %*{"jsonrpc": "2.0", "id": id, "error": {"code": -32601, "message": "Method not found"}}
      
      await req.respond(Http200, $response, headers)
    else:
      await req.respond(Http400, "Invalid JSON-RPC request", headers)
    
  except JsonParsingError:
    await req.respond(Http400, "Invalid JSON", newHttpHeaders([("Content-Type", "text/plain")]))
  except CatchableError as e:
    await req.respond(Http500, "Internal server error: " & e.msg, newHttpHeaders([("Content-Type", "text/plain")]))

proc isPortInUse(port: int, host: string = "127.0.0.1"): bool =
  ## Check if a port is already in use
  try:
    let socket = newSocket()
    defer: socket.close()
    socket.bindAddr(Port(port), host)
    return false
  except OSError:
    return true

proc findAvailablePort(startPort: int, host: string = "127.0.0.1"): int =
  ## Find the next available port starting from startPort
  var port = startPort
  while port < startPort + 100:  # Try up to 100 ports
    if not isPortInUse(port, host):
      return port
    inc port
  raise newException(OSError, "No available ports found in range")

method start*(transport: HttpTransport): Future[void] {.async.} =
  # Check if port is in use and find alternative if needed
  var actualPort = transport.port
  if isPortInUse(transport.port, transport.host):
    echo "Port ", transport.port, " is already in use"
    try:
      actualPort = findAvailablePort(transport.port, transport.host)
      echo "Using alternative port: ", actualPort
      transport.port = actualPort
    except OSError as e:
      echo "Error: ", e.msg
      return
  
  echo "Starting HTTP transport on ", transport.host, ":", actualPort
  transport.startCalled = true
  
  proc callback(req: Request) {.async.} =
    await transport.handleHttpRequest(req)
  
  try:
    # AsyncHttpServer in Nim doesn't expose socket options directly
    # The server will handle socket reuse internally
    asyncCheck transport.server.serve(Port(actualPort), callback, transport.host)
  except OSError as e:
    echo "Failed to start HTTP server: ", e.msg
    transport.startCalled = false

method stop*(transport: HttpTransport): Future[void] {.async.} =
  echo "Stopping HTTP transport"
  transport.stopCalled = true
  transport.server.close()

proc configureTransportsSingle(server: single_server.SingleRepoServer, config: core_config.Config) =
  ## Configures transports for single repository server
  if config.useHttp:
    # Check if SSE mode is requested
    if config.useSse:
      let sseTransport = sse_transport.newSseTransport(config.httpHost, config.httpPort, server.baseServer)
      server.baseServer.addTransport(sseTransport)
      echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort, " (SSE mode)"
    else:
      let httpTransport = newHttpTransport(config.httpHost, config.httpPort, server.baseServer)
      server.baseServer.addTransport(httpTransport)
      echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort

  if config.useStdio:
    let stdioTransport = stdio_transport.newStdioTransport(server.baseServer)
    server.baseServer.addTransport(stdioTransport)
    echo "MCP-Jujutsu server ready on stdio"

proc configureTransportsMulti(server: multi_server.MultiRepoServer, config: core_config.Config) =
  ## Configures transports for multi repository server
  if config.useHttp:
    # Check if SSE mode is requested
    if config.useSse:
      let sseTransport = sse_transport.newSseTransport(config.httpHost, config.httpPort, server.baseServer)
      server.baseServer.addTransport(sseTransport)
      echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort, " (SSE mode)"
    else:
      let httpTransport = newHttpTransport(config.httpHost, config.httpPort, server.baseServer)
      server.baseServer.addTransport(httpTransport)
      echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort

  if config.useStdio:
    let stdioTransport = stdio_transport.newStdioTransport(server.baseServer)
    server.baseServer.addTransport(stdioTransport)
    echo "MCP-Jujutsu server ready on stdio"

proc getPidFilePath(port: int = 0): string =
  ## Get the path for the PID file, optionally for a specific port
  let tempDir = getTempDir()
  if port > 0:
    return tempDir / ("mcp_jujutsu_" & $port & ".pid")
  else:
    return tempDir / "mcp_jujutsu.pid"

proc writePidFile(port: int) =
  ## Write current process ID and port to PID file
  let pidFile = getPidFilePath(port)
  try:
    writeFile(pidFile, $getCurrentProcessId() & ":" & $port)
  except IOError:
    echo "Warning: Could not write PID file: ", pidFile

proc readPidFile(port: int = 0): tuple[pid: int, port: int] =
  ## Read PID and port from PID file for a specific port
  let pidFile = getPidFilePath(port)
  try:
    if fileExists(pidFile):
      let content = readFile(pidFile).strip()
      let parts = content.split(":")
      if parts.len == 2:
        return (parseInt(parts[0]), parseInt(parts[1]))
  except CatchableError:
    discard
  return (0, 0)

proc cleanupPidFile(port: int = 0) =
  ## Remove PID file on exit
  let pidFile = getPidFilePath(port)
  try:
    if fileExists(pidFile):
      removeFile(pidFile)
  except CatchableError:
    discard

proc isProcessRunning(pid: int): bool =
  ## Check if a process is still running
  try:
    when defined(windows):
      # Windows implementation would go here
      return false
    else:
      # Unix-like systems
      let result = kill(Pid(pid), cint(0))  # Signal 0 checks if process exists
      return result == 0
  except CatchableError:
    return false

proc stopExistingServer(targetPort: int): bool =
  ## Stop existing server running on the specified port
  let (pid, port) = readPidFile(targetPort)
  if pid > 0 and port == targetPort and isProcessRunning(pid):
    echo "Found existing server on port ", port, " (PID: ", pid, ")"
    try:
      when defined(windows):
        # Windows implementation would go here
        return false
      else:
        # Unix-like systems
        # First try graceful shutdown
        discard kill(Pid(pid), SIGTERM)  # Send SIGTERM to gracefully stop
        
        # Wait for process to stop gracefully (up to 3 seconds)
        var gracefulRetries = 0
        while gracefulRetries < 30 and isProcessRunning(pid):
          sleep(100)  # Wait 100ms
          inc gracefulRetries
        
        # Force kill if still running
        if isProcessRunning(pid):
          echo "Process didn't stop gracefully, force killing..."
          discard kill(Pid(pid), SIGKILL)
          sleep(500)
        
        # Ensure process is fully stopped
        var processRetries = 0
        while processRetries < 10 and isProcessRunning(pid):
          sleep(100)  # Wait 100ms
          inc processRetries
        
        if isProcessRunning(pid):
          echo "Error: Failed to stop process ", pid
          return false
        
        # Clean up PID file immediately after process stops
        cleanupPidFile(targetPort)
        
        # Now wait for port to be released with exponential backoff
        var portRetries = 0
        var waitTime = 100  # Start with 100ms
        while portRetries < 30 and isPortInUse(port, "127.0.0.1"):
          sleep(waitTime)
          if waitTime < 1000:  # Cap at 1 second
            waitTime = waitTime * 2  # Exponential backoff
          inc portRetries
          
          # Try to forcefully close any lingering sockets every 10 retries
          if portRetries mod 10 == 0:
            echo "Port ", port, " still in use, waiting... (attempt ", portRetries, "/30)"
        
        if isPortInUse(port, "127.0.0.1"):
          echo "Warning: Port ", port, " is still in use after ", portRetries, " attempts"
          echo "The OS may take additional time to release the port"
          # Give it one more longer wait
          sleep(2000)
          if not isPortInUse(port, "127.0.0.1"):
            echo "Port ", port, " is now available"
            return true
          return false
        
        echo "Successfully stopped server on port ", port, " and port is now available"
        return true
    except CatchableError as e:
      echo "Warning: Could not stop existing server: ", e.msg
      return false
  elif pid > 0 and port != targetPort:
    # PID file exists but for different port
    echo "Found PID file for different port (", port, "), cleaning up..."
    cleanupPidFile(targetPort)
  return true

proc printUsage() =
  echo "MCP-Jujutsu - Semantic Commit Division Server"
  echo "Usage: mcp_jujutsu [options]"
  echo "Options:"
  echo "  -h, --help                  Show this help message"
  echo "  --mode=MODE                 Server mode: single (default) or multi"
  echo "  --port=NUM                  Set the server port (default: 8080)"
  echo "  --http                      Enable HTTP transport (default: true)"
  echo "  --host=HOST                 HTTP host to listen on (default: 127.0.0.1)"
  echo "  --stdio                     Enable stdio transport (default: false)"
  echo "  --sse                       Enable SSE mode for HTTP transport (default: false)"
  echo "  --no-restart                Keep existing server running (use different port)"
  echo "  --version                   Print version information"
  echo ""
  echo "Single Repository Mode Options:"
  echo "  --repo-path=PATH            Path to repository"
  echo ""
  echo "Multi Repository Mode Options:"
  echo "  --repos-dir=PATH            Directory containing repositories"
  echo "  --repo-config=PATH          Path to repository configuration file"

proc main() {.async.} =
  # Setup signal handlers for graceful shutdown
  proc signalHandler() {.noconv.} =
    echo "\nReceived shutdown signal, cleaning up..."
    if globalServerPort > 0:
      cleanupPidFile(globalServerPort)
    quit(0)
  
  setControlCHook(signalHandler)
  
  # Default options for argument parsing
  var
    showHelp = false
    showVersion = false
    noRestart = false

  # Parse basic command line arguments first
  for kind, key, val in getopt():
    case kind
    of cmdShortOption, cmdLongOption:
      case key.toLowerAscii()
      of "h", "help":
        showHelp = true
      of "v", "version":
        showVersion = true
      of "no-restart":
        noRestart = true
    else:
      # Other command line argument types (cmdEnd, cmdArgument) - ignore
      discard

  if showHelp:
    printUsage()
    return

  if showVersion:
    echo "MCP-Jujutsu v0.1.0"
    return

  # Parse mode-specific arguments first to get port configuration
  var tempConfig: core_config.Config
  var isMulti = false
  for kind, key, val in getopt():
    case kind
    of cmdShortOption, cmdLongOption:
      case key.toLowerAscii()
      of "mode":
        if val.toLowerAscii() == "multi" or val.toLowerAscii() == "multirepo":
          isMulti = true
      of "multi", "multi-repo":
        isMulti = true
    else:
      discard
  
  # Get configuration to determine target port
  if isMulti:
    tempConfig = multi_config.parseCommandLine()
  else:
    tempConfig = single_config.parseCommandLine()
  
  # Handle restart functionality - default is to restart existing server on the same port
  if not noRestart:
    if not stopExistingServer(tempConfig.httpPort):
      echo "Note: No existing server found on port ", tempConfig.httpPort, " or could not stop cleanly"

  # Use the already parsed configuration
  var config: core_config.Config = tempConfig
  globalServerPort = config.httpPort  # Store port for signal handler

  if isMulti:
    # Multi-repository mode
    echo "Starting MCP-Jujutsu in multi-repository mode on port ", config.httpPort

    # Create and initialize multi-repo server
    let server = await multi_server.newMcpServer(config)

    # Configure transports
    configureTransportsMulti(server, config)

    # Start server
    await server.baseServer.start()
    
    # Write PID file after successful start
    writePidFile(config.httpPort)
  else:
    # Single-repository mode (default)
    echo "Starting MCP-Jujutsu in single-repository mode on port ", config.httpPort

    # Create and initialize single-repo server
    let server = await single_server.newMcpServer(config)

    # Configure transports
    configureTransportsSingle(server, config)

    # Start server
    await server.baseServer.start()
    
    # Write PID file after successful start
    writePidFile(config.httpPort)

  # Keep the server running
  runForever()

when isMainModule:
  waitFor main()