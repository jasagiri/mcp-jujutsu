## Core configuration module
## 
## This module defines the common configuration for both single-repository
## and multi-repository modes.

import std/[os, parseopt, strutils, json]
import parsetoml

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
    useSse*: bool               ## Enable SSE (Server-Sent Events) mode for HTTP transport
    
    # Repository settings
    repoPath*: string           ## Path to repository (single-repo mode)
    reposDir*: string           ## Directory containing repositories (multi-repo mode)
    repoConfigPath*: string     ## Path to repository configuration file (multi-repo mode)
    
    # Diff format settings
    diffFormat*: string         ## Default diff format: "native", "git", "json", "markdown", "html", "custom"
    diffColorize*: bool         ## Enable colored diff output
    diffContextLines*: int      ## Number of context lines in diffs
    diffShowLineNumbers*: bool  ## Show line numbers in diff output
    diffTemplatePath*: string   ## Path to custom diff template file
    
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
    useSse: false,
    
    # Repository settings
    repoPath: getCurrentDir(),
    reposDir: getCurrentDir(),
    repoConfigPath: getCurrentDir() / "repos.toml",
    
    # Diff format settings
    diffFormat: "git",
    diffColorize: false,
    diffContextLines: 3,
    diffShowLineNumbers: false,
    diffTemplatePath: "",
    
    # AI Integration
    aiEndpoint: "https://api.openai.com/v1/chat/completions",
    aiApiKey: "",
    aiModel: "gpt-4"
  )

proc loadConfigFromToml(path: string): Config =
  ## Loads configuration from a TOML file
  result = newDefaultConfig()
  
  let tomlData = parsetoml.parseFile(path)
  
  # General settings
  if tomlData.hasKey("general"):
    let general = tomlData["general"]
    if general.hasKey("mode"):
      let mode = general["mode"].getStr()
      if mode.toLowerAscii() == "multi" or mode.toLowerAscii() == "multirepo":
        result.serverMode = MultiRepo
      else:
        result.serverMode = SingleRepo
    if general.hasKey("server_name"):
      result.serverName = general["server_name"].getStr()
    if general.hasKey("server_port"):
      result.serverPort = general["server_port"].getInt()
    if general.hasKey("log_level"):
      result.logLevel = general["log_level"].getStr()
    if general.hasKey("verbose"):
      result.verbose = general["verbose"].getBool()
  
  # Transport settings
  if tomlData.hasKey("transport"):
    let transport = tomlData["transport"]
    if transport.hasKey("http"):
      result.useHttp = transport["http"].getBool()
    if transport.hasKey("http_host"):
      result.httpHost = transport["http_host"].getStr()
    if transport.hasKey("http_port"):
      result.httpPort = transport["http_port"].getInt()
    if transport.hasKey("stdio"):
      result.useStdio = transport["stdio"].getBool()
  
  # Repository settings
  if tomlData.hasKey("repository"):
    let repo = tomlData["repository"]
    if repo.hasKey("path"):
      result.repoPath = repo["path"].getStr()
    if repo.hasKey("repos_dir"):
      result.reposDir = repo["repos_dir"].getStr()
    if repo.hasKey("config_path"):
      result.repoConfigPath = repo["config_path"].getStr()
  
  # Diff format settings
  if tomlData.hasKey("diff"):
    let diff = tomlData["diff"]
    if diff.hasKey("format"):
      result.diffFormat = diff["format"].getStr()
    if diff.hasKey("colorize"):
      result.diffColorize = diff["colorize"].getBool()
    if diff.hasKey("context_lines"):
      result.diffContextLines = diff["context_lines"].getInt()
    if diff.hasKey("show_line_numbers"):
      result.diffShowLineNumbers = diff["show_line_numbers"].getBool()
    if diff.hasKey("template_path"):
      result.diffTemplatePath = diff["template_path"].getStr()
  
  # AI settings
  if tomlData.hasKey("ai"):
    let ai = tomlData["ai"]
    if ai.hasKey("endpoint"):
      result.aiEndpoint = ai["endpoint"].getStr()
    if ai.hasKey("api_key"):
      result.aiApiKey = ai["api_key"].getStr()
    if ai.hasKey("model"):
      result.aiModel = ai["model"].getStr()

proc loadConfigFromJson(path: string): Config =
  ## Loads configuration from a JSON file
  result = newDefaultConfig()
  
  let jsonData = json.parseFile(path)
  
  # General settings
  if jsonData.hasKey("mode"):
    let mode = jsonData["mode"].getStr()
    if mode.toLowerAscii() == "multi" or mode.toLowerAscii() == "multirepo":
      result.serverMode = MultiRepo
    else:
      result.serverMode = SingleRepo
  if jsonData.hasKey("serverName"):
    result.serverName = jsonData["serverName"].getStr()
  if jsonData.hasKey("serverPort"):
    result.serverPort = jsonData["serverPort"].getInt()
  if jsonData.hasKey("logLevel"):
    result.logLevel = jsonData["logLevel"].getStr()
  if jsonData.hasKey("verbose"):
    result.verbose = jsonData["verbose"].getBool()
  
  # Transport settings
  if jsonData.hasKey("useHttp"):
    result.useHttp = jsonData["useHttp"].getBool()
  if jsonData.hasKey("httpHost"):
    result.httpHost = jsonData["httpHost"].getStr()
  if jsonData.hasKey("httpPort"):
    result.httpPort = jsonData["httpPort"].getInt()
  if jsonData.hasKey("useStdio"):
    result.useStdio = jsonData["useStdio"].getBool()
  
  # Repository settings
  if jsonData.hasKey("repoPath"):
    result.repoPath = jsonData["repoPath"].getStr()
  if jsonData.hasKey("reposDir"):
    result.reposDir = jsonData["reposDir"].getStr()
  if jsonData.hasKey("repoConfigPath"):
    result.repoConfigPath = jsonData["repoConfigPath"].getStr()
  
  # Diff format settings
  if jsonData.hasKey("diffFormat"):
    result.diffFormat = jsonData["diffFormat"].getStr()
  if jsonData.hasKey("diffColorize"):
    result.diffColorize = jsonData["diffColorize"].getBool()
  if jsonData.hasKey("diffContextLines"):
    result.diffContextLines = jsonData["diffContextLines"].getInt()
  if jsonData.hasKey("diffShowLineNumbers"):
    result.diffShowLineNumbers = jsonData["diffShowLineNumbers"].getBool()
  if jsonData.hasKey("diffTemplatePath"):
    result.diffTemplatePath = jsonData["diffTemplatePath"].getStr()
  
  # AI settings
  if jsonData.hasKey("aiEndpoint"):
    result.aiEndpoint = jsonData["aiEndpoint"].getStr()
  if jsonData.hasKey("aiApiKey"):
    result.aiApiKey = jsonData["aiApiKey"].getStr()
  if jsonData.hasKey("aiModel"):
    result.aiModel = jsonData["aiModel"].getStr()

proc loadConfigFile*(path: string): Config =
  ## Loads configuration from a file (supports both TOML and JSON)
  result = newDefaultConfig()
  
  if not fileExists(path):
    return
  
  # Determine file type by extension
  let ext = path.splitFile().ext.toLowerAscii()
  
  try:
    case ext
    of ".toml":
      result = loadConfigFromToml(path)
    of ".json":
      result = loadConfigFromJson(path)
    else:
      # Try TOML first as default, then JSON if that fails
      try:
        result = loadConfigFromToml(path)
      except CatchableError:
        result = loadConfigFromJson(path)
  except CatchableError as e:
    echo "Warning: Failed to load config file: ", e.msg
    result = newDefaultConfig()

proc parseCommandLine*(): Config =
  ## Parses command-line arguments
  result = newDefaultConfig()
  
  # Check for config file in standard locations
  let homeDir = getHomeDir()
  let configLocations = [
    getCurrentDir() / "mcp-jujutsu.toml",
    getCurrentDir() / ".mcp-jujutsu.toml",
    getCurrentDir() / "config.toml",
    getCurrentDir() / ".mcp-jujutsu-config",
    homeDir / ".config/mcp-jujutsu/config.toml",
    homeDir / ".config/mcp-jujutsu/config",
    homeDir / ".mcp-jujutsu.toml",
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
        echo "  --sse                       Enable SSE mode for HTTP transport (default: false)"
        echo "  --repo-path=PATH            Path to repository (for single mode)"
        echo "  --repos-dir=PATH            Directory with repositories (for multi mode)"
        echo "  --repo-config=PATH          Path to repository config (for multi mode)"
        echo "  --ai-endpoint=URL           AI endpoint URL"
        echo "  --ai-key=KEY                AI API key"
        echo "  --ai-model=MODEL            AI model to use (default: gpt-4)"
        echo "  --diff-format=FORMAT        Diff output format: native, git, json, markdown, html, custom"
        echo "  --diff-colorize             Enable colored diff output"
        echo "  --diff-context=NUM          Number of context lines in diffs (default: 3)"
        echo "  --diff-line-numbers         Show line numbers in diff output"
        echo "  --diff-template=PATH        Path to custom diff template file"
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
      of "sse":
        result.useSse = if p.val == "": true else: parseBool(p.val)
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
      of "diff-format":
        result.diffFormat = p.val
      of "diff-colorize":
        result.diffColorize = if p.val == "": true else: parseBool(p.val)
      of "diff-context":
        result.diffContextLines = parseInt(p.val)
      of "diff-line-numbers":
        result.diffShowLineNumbers = if p.val == "": true else: parseBool(p.val)
      of "diff-template":
        result.diffTemplatePath = p.val
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