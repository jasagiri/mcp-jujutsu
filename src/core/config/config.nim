## Core configuration module
## 
## This module defines the common configuration for both single-repository
## and multi-repository modes.

import std/[os, parseopt, strutils, tables]

type
  ServerMode* = enum
    ## Server operation mode
    SingleRepo,  ## Single repository mode - operates on one repository
    MultiRepo    ## Multi-repository mode - handles multiple repositories

  Config* = object
    ## Main configuration object for MCP-Jujutsu server
    # General settings
    serverMode*: ServerMode     ## Mode of operation (single or multi repository)
    serverName*: string         ## Server name for identification
    serverPort*: int            ## Port to run the server on
    logLevel*: string           ## Logging level: "debug", "info", "warn", "error"
    verbose*: bool              ## Enable verbose output
    
    # MCP transport configuration
    useHttp*: bool              ## Enable HTTP transport
    httpHost*: string           ## HTTP host to bind to (e.g., "127.0.0.1")
    httpPort*: int              ## HTTP port to listen on
    useStdio*: bool             ## Enable stdio transport for CLI integration
    
    # Repository settings
    repoPath*: string           ## Path to repository (single-repo mode)
    reposDir*: string           ## Directory containing repositories (multi-repo mode)
    repoConfigPath*: string     ## Path to repository configuration file (multi-repo mode)
    
    # AI Integration (reserved for future use)
    aiEndpoint*: string         ## URL for AI model API endpoint
    aiApiKey*: string           ## API key for AI service authentication
    aiModel*: string            ## AI model identifier for semantic analysis

proc newDefaultConfig*(): Config =
  ## Creates a new configuration with default values
  result = Config(
    # General settings
    serverMode: SingleRepo,
    serverName: "MCP-Jujutsu",
    serverPort: 8080,
    logLevel: "info",
    verbose: false,
    
    # MCP transport
    useHttp: true,
    httpHost: "127.0.0.1",
    httpPort: 8080,
    useStdio: false,
    
    # Repository settings
    repoPath: getCurrentDir(),
    reposDir: getCurrentDir(),
    repoConfigPath: getCurrentDir() / "repos.json",
    
    # AI Integration
    aiEndpoint: "https://api.openai.com/v1/chat/completions",
    aiApiKey: "",
    aiModel: "gpt-4"
  )

proc loadConfigFile*(path: string): Config =
  ## Loads configuration from a file
  result = newDefaultConfig()
  
  if not fileExists(path):
    return
  
  # Simple config file parsing
  for line in lines(path):
    let trimmedLine = line.strip()
    if trimmedLine.len == 0 or trimmedLine.startsWith("#"):
      continue
    
    let parts = trimmedLine.split('=', 1)
    if parts.len != 2:
      continue
    
    let key = parts[0].strip().toLowerAscii()
    let value = parts[1].strip()
    
    case key
    of "mode":
      if value.toLowerAscii() == "multi" or value.toLowerAscii() == "multirepo":
        result.serverMode = MultiRepo
      else:
        result.serverMode = SingleRepo
    of "servername": result.serverName = value
    of "serverport": result.serverPort = parseInt(value)
    of "loglevel": result.logLevel = value
    of "verbose": result.verbose = parseBool(value)
    of "http": result.useHttp = parseBool(value)
    of "httphost": result.httpHost = value
    of "httpport": result.httpPort = parseInt(value)
    of "stdio": result.useStdio = parseBool(value)
    of "repopath": result.repoPath = value
    of "reposdir": result.reposDir = value
    of "repoconfigpath": result.repoConfigPath = value
    of "aiendpoint": result.aiEndpoint = value
    of "aiapikey": result.aiApiKey = value
    of "aimodel": result.aiModel = value

proc parseCommandLine*(): Config =
  ## Parses command-line arguments
  result = newDefaultConfig()
  
  # Check for config file in standard locations
  let homeDir = getHomeDir()
  let configLocations = [
    getCurrentDir() / ".mcp-jujutsu-config",
    homeDir / ".config/mcp-jujutsu/config",
    homeDir / ".mcp-jujutsu-config"
  ]
  
  for configPath in configLocations:
    if fileExists(configPath):
      result = loadConfigFile(configPath)
      break
  
  # Parse command-line arguments
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "h", "help":
        echo "MCP-Jujutsu - Semantic Commit Division Server"
        echo "Usage: mcp_jujutsu [options]"
        echo "Options:"
        echo "  -h, --help                  Show this help message"
        echo "  --mode=MODE                 Server mode: single (default) or multi"
        echo "  --port=NUM                  Set the server port (default: 8080)"
        echo "  --http                      Enable HTTP transport (default: true)"
        echo "  --host=HOST                 HTTP host to listen on (default: 127.0.0.1)"
        echo "  --stdio                     Enable stdio transport (default: false)"
        echo "  --repo-path=PATH            Path to repository (for single mode)"
        echo "  --repos-dir=PATH            Directory with repositories (for multi mode)"
        echo "  --repo-config=PATH          Path to repository config (for multi mode)"
        echo "  --ai-endpoint=URL           AI endpoint URL"
        echo "  --ai-key=KEY                AI API key"
        echo "  --ai-model=MODEL            AI model to use (default: gpt-4)"
        echo "  --log-level=LEVEL           Log level (default: info)"
        echo "  --verbose                   Enable verbose output"
        quit(0)
      of "mode":
        if p.val.toLowerAscii() == "multi" or p.val.toLowerAscii() == "multirepo":
          result.serverMode = MultiRepo
        else:
          result.serverMode = SingleRepo
      of "port":
        result.serverPort = parseInt(p.val)
        result.httpPort = parseInt(p.val) # also update httpPort for consistency
      of "http":
        result.useHttp = if p.val == "": true else: parseBool(p.val)
      of "host":
        result.httpHost = p.val
      of "stdio":
        result.useStdio = if p.val == "": true else: parseBool(p.val)
      of "repo-path":
        result.repoPath = p.val
      of "repos-dir":
        result.reposDir = p.val
      of "repo-config":
        result.repoConfigPath = p.val
      of "ai-endpoint":
        result.aiEndpoint = p.val
      of "ai-key":
        result.aiApiKey = p.val
      of "ai-model":
        result.aiModel = p.val
      of "log-level":
        result.logLevel = p.val
      of "verbose":
        result.verbose = if p.val == "": true else: parseBool(p.val)
    of cmdArgument:
      # TODO: For future implementation - handle positional arguments like repository path
      # Currently, no positional arguments are supported
      let arg = p.key
      echo "Note: Positional argument '" & arg & "' ignored - use --repo-path instead"

  # Ensure at least one transport is enabled
  if not result.useHttp and not result.useStdio:
    result.useHttp = true