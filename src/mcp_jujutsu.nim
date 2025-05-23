## MCP-Jujutsu - Main Entry Point
##
## This module provides the main entry point for the MCP-Jujutsu server,
## which can run in either single-repository mode or multi-repository mode.

import std/[asyncdispatch, json, os, parseopt, strutils, tables]

# Core components
import core/config/config as core_config
import core/mcp/server as base_server
import core/repository/jujutsu

# Single repository mode components
import single_repo/config/config as single_config
import single_repo/mcp/server as single_server
import single_repo/analyzer/semantic
import single_repo/tools/semantic_divide

# Multi repository mode components
import multi_repo/config/config as multi_config
import multi_repo/mcp/server as multi_server
import multi_repo/repository/manager
import multi_repo/analyzer/cross_repo
import multi_repo/tools/multi_repo

# HTTP Transport - Common for both modes
type
  HttpTransport* = ref object of base_server.Transport
    host*: string
    port*: int

proc newHttpTransport*(host: string, port: int): HttpTransport =
  result = HttpTransport(
    host: host,
    port: port,
    startCalled: false,
    stopCalled: false
  )

method start*(transport: HttpTransport): Future[void] =
  echo "Starting HTTP transport on ", transport.host, ":", transport.port
  transport.startCalled = true
  return newFuture[void]()

method stop*(transport: HttpTransport): Future[void] =
  echo "Stopping HTTP transport"
  transport.stopCalled = true
  return newFuture[void]()

# Stdio Transport - Common for both modes
type
  StdioTransport* = ref object of base_server.Transport

proc newStdioTransport*(): StdioTransport =
  result = StdioTransport(
    startCalled: false,
    stopCalled: false
  )

method start*(transport: StdioTransport): Future[void] =
  echo "Starting stdio transport"
  transport.startCalled = true
  return newFuture[void]()

method stop*(transport: StdioTransport): Future[void] =
  echo "Stopping stdio transport"
  transport.stopCalled = true
  return newFuture[void]()

proc configureTransportsSingle(server: single_server.SingleRepoServer, config: core_config.Config) =
  ## Configures transports for single repository server
  if config.useHttp:
    let httpTransport = newHttpTransport(config.httpHost, config.httpPort)
    server.addTransport(httpTransport)
    echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort

  if config.useStdio:
    let stdioTransport = newStdioTransport()
    server.addTransport(stdioTransport)
    echo "MCP-Jujutsu server ready on stdio"

proc configureTransportsMulti(server: multi_server.MultiRepoServer, config: core_config.Config) =
  ## Configures transports for multi repository server
  if config.useHttp:
    let httpTransport = newHttpTransport(config.httpHost, config.httpPort)
    server.addTransport(httpTransport)
    echo "MCP-Jujutsu server listening on http://", config.httpHost, ":", config.httpPort

  if config.useStdio:
    let stdioTransport = newStdioTransport()
    server.addTransport(stdioTransport)
    echo "MCP-Jujutsu server ready on stdio"

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
  echo "  --version                   Print version information"
  echo ""
  echo "Single Repository Mode Options:"
  echo "  --repo-path=PATH            Path to repository"
  echo ""
  echo "Multi Repository Mode Options:"
  echo "  --repos-dir=PATH            Directory containing repositories"
  echo "  --repo-config=PATH          Path to repository configuration file"

proc main() {.async.} =
  # Default options for argument parsing
  var
    showHelp = false
    showVersion = false

  # Parse basic command line arguments first
  for kind, key, val in getopt():
    case kind
    of cmdShortOption, cmdLongOption:
      case key.toLowerAscii()
      of "h", "help":
        showHelp = true
      of "v", "version":
        showVersion = true
    else:
      # Other command line argument types (cmdEnd, cmdArgument) - ignore
      discard

  if showHelp:
    printUsage()
    return

  if showVersion:
    echo "MCP-Jujutsu v0.1.0"
    return

  # Parse mode-specific arguments and create appropriate configuration
  var config: core_config.Config

  # Check if mode is explicitly specified
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
      # Other command line argument types (cmdEnd, cmdArgument) - ignore
      discard

  if isMulti:
    # Multi-repository mode
    echo "Starting MCP-Jujutsu in multi-repository mode"
    config = multi_config.parseCommandLine()

    # Create and initialize multi-repo server
    let server = await multi_server.newMcpServer(config)

    # Configure transports
    configureTransportsMulti(server, config)

    # Start server
    await server.start()
  else:
    # Single-repository mode (default)
    echo "Starting MCP-Jujutsu in single-repository mode"
    config = single_config.parseCommandLine()

    # Create and initialize single-repo server
    let server = await single_server.newMcpServer(config)

    # Configure transports
    configureTransportsSingle(server, config)

    # Start server
    await server.start()

  # Keep the server running
  runForever()

when isMainModule:
  waitFor main()