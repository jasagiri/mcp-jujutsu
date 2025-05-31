## Logging module for MCP-Jujutsu
##
## This module provides a structured logging system for the MCP-Jujutsu project.
## It offers configurable log levels, contextual information, and various output options.

import std/[times, strutils, tables, options, terminal, os, json]
import ../config/config

type
  LogLevel* = enum
    ## Log levels from least to most severe
    llTrace = "TRACE"
    llDebug = "DEBUG"
    llInfo = "INFO"
    llWarning = "WARN"
    llError = "ERROR"
    llFatal = "FATAL"
  
  LoggerOutput* = enum
    ## Logger output targets
    loConsole   # Output to console
    loFile      # Output to file
  
  LogContext* = ref object
    ## Context information for a log message
    component*: string           # Component name (e.g., "repository", "analyzer", "server")
    operation*: string           # Operation being performed
    sessionId*: Option[string]   # Session ID for request tracking
    requestId*: Option[string]   # Request ID for more granular tracking
    metadata*: Table[string, string] # Additional metadata
  
  LogConfig* = object
    ## Configuration for the logger
    minLevel*: LogLevel          # Minimum level to log
    outputs*: set[LoggerOutput]  # Where to output logs
    showColors*: bool            # Whether to use colors in console output
    logFilePath*: string         # Path to log file when using file output
    includeTimestamp*: bool      # Whether to include timestamps
    includeContext*: bool        # Whether to include context information
  
  Logger* = ref object
    ## Main logger object
    config*: LogConfig
    defaultContext*: LogContext
    logFile*: File
    initialized*: bool

proc newLogContext*(component: string = "", operation: string = ""): LogContext =
  ## Creates a new log context
  result = LogContext(
    component: component,
    operation: operation,
    sessionId: none(string),
    requestId: none(string),
    metadata: initTable[string, string]()
  )

proc withComponent*(ctx: LogContext, component: string): LogContext =
  ## Returns a copy of the context with a new component
  result = LogContext(
    component: component,
    operation: ctx.operation,
    sessionId: ctx.sessionId,
    requestId: ctx.requestId,
    metadata: ctx.metadata
  )

proc withOperation*(ctx: LogContext, operation: string): LogContext =
  ## Returns a copy of the context with a new operation
  result = LogContext(
    component: ctx.component,
    operation: operation,
    sessionId: ctx.sessionId,
    requestId: ctx.requestId,
    metadata: ctx.metadata
  )

proc withSessionId*(ctx: LogContext, sessionId: string): LogContext =
  ## Returns a copy of the context with a session ID
  result = LogContext(
    component: ctx.component,
    operation: ctx.operation,
    sessionId: some(sessionId),
    requestId: ctx.requestId,
    metadata: ctx.metadata
  )

proc withRequestId*(ctx: LogContext, requestId: string): LogContext =
  ## Returns a copy of the context with a request ID
  result = LogContext(
    component: ctx.component,
    operation: ctx.operation,
    sessionId: ctx.sessionId,
    requestId: some(requestId),
    metadata: ctx.metadata
  )

proc withMetadata*(ctx: LogContext, key: string, value: string): LogContext =
  ## Returns a copy of the context with additional metadata
  result = LogContext(
    component: ctx.component,
    operation: ctx.operation,
    sessionId: ctx.sessionId,
    requestId: ctx.requestId,
    metadata: ctx.metadata
  )
  result.metadata[key] = value

proc newLogger*(config: LogConfig): Logger =
  ## Creates a new logger with the given configuration
  result = Logger(
    config: config,
    defaultContext: newLogContext(),
    initialized: false
  )

proc newDefaultLogger*(): Logger =
  ## Creates a new logger with default configuration
  let config = LogConfig(
    minLevel: llInfo,
    outputs: {loConsole},
    showColors: true,
    logFilePath: getCurrentDir() / "logs" / "mcp_jujutsu.log",
    includeTimestamp: true,
    includeContext: true
  )
  result = newLogger(config)

proc init*(logger: Logger) {.gcsafe.} =
  ## Initializes the logger
  if logger.initialized:
    return
  
  # If file output is enabled, initialize the log file
  if loFile in logger.config.outputs:
    # Ensure directory exists
    let logDir = parentDir(logger.config.logFilePath)
    if not dirExists(logDir):
      createDir(logDir)
    
    # Open the log file
    logger.logFile = open(logger.config.logFilePath, fmAppend)
  
  logger.initialized = true

proc close*(logger: Logger) {.gcsafe.} =
  ## Closes the logger and any open resources
  if not logger.initialized:
    return
  
  if loFile in logger.config.outputs:
    close(logger.logFile)
  
  logger.initialized = false

proc setDefaultContext*(logger: Logger, context: LogContext) =
  ## Sets the default context for the logger
  logger.defaultContext = context

proc formatTimestamp*(): string {.gcsafe.} =
  ## Formats the current time for logging
  return $now().format("yyyy-MM-dd HH:mm:ss")

proc formatContext*(ctx: LogContext): string {.gcsafe.} =
  ## Formats context information for logging
  var parts: seq[string] = @[]
  
  if ctx.component != "":
    parts.add("component=" & ctx.component)
  
  if ctx.operation != "":
    parts.add("operation=" & ctx.operation)
  
  if ctx.sessionId.isSome:
    parts.add("session=" & ctx.sessionId.get)
  
  if ctx.requestId.isSome:
    parts.add("request=" & ctx.requestId.get)
  
  for key, value in ctx.metadata:
    parts.add(key & "=" & value)
  
  return parts.join(" ")

proc getLevelColor*(level: LogLevel): ForegroundColor {.gcsafe.} =
  ## Gets the terminal color for a log level
  case level
  of llTrace: return fgWhite
  of llDebug: return fgBlue
  of llInfo: return fgGreen
  of llWarning: return fgYellow
  of llError: return fgRed
  of llFatal: return fgMagenta

proc log*(logger: Logger, level: LogLevel, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a message with the given level and context
  if not logger.initialized:
    logger.init()
  
  # Skip if below minimum level
  if level.ord < logger.config.minLevel.ord:
    return
  
  # Use provided context or default
  let ctx = if context == nil: logger.defaultContext else: context
  
  # Build log message
  var parts: seq[string] = @[]
  
  # Add timestamp if configured
  if logger.config.includeTimestamp:
    parts.add(formatTimestamp())
  
  # Add level
  parts.add($level)
  
  # Add context if configured
  if logger.config.includeContext:
    let contextStr = formatContext(ctx)
    if contextStr != "":
      parts.add(contextStr)
  
  # Add message
  parts.add(message)
  
  let logMessage = parts.join(" | ")
  
  # Output to console if configured
  if loConsole in logger.config.outputs:
    if logger.config.showColors:
      let colorCode = getLevelColor(level)
      styledWrite(stdout, colorCode, logMessage & "\n")
    else:
      echo logMessage
  
  # Output to file if configured
  if loFile in logger.config.outputs:
    logger.logFile.writeLine(logMessage)
    logger.logFile.flushFile()

proc trace*(logger: Logger, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a trace message
  logger.log(llTrace, message, context)

proc debug*(logger: Logger, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a debug message
  logger.log(llDebug, message, context)

proc info*(logger: Logger, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs an info message
  logger.log(llInfo, message, context)

proc warn*(logger: Logger, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a warning message
  logger.log(llWarning, message, context)

proc error*(logger: Logger, message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs an error message
  logger.log(llError, message, context)

proc fatal*(logger: Logger, message: string, context: LogContext = nil) =
  ## Logs a fatal message
  logger.log(llFatal, message, context)

# Exception handling helpers

proc logException*(logger: Logger, e: ref Exception, message: string = "", context: LogContext = nil) {.gcsafe.} =
  ## Logs an exception with additional context
  var fullMessage = if message == "": "Exception occurred" else: message
  fullMessage &= ": " & e.msg & " [" & $e.name & "]"
  
  if e.getStackTrace().len > 0:
    fullMessage &= "\nStack trace:\n" & e.getStackTrace()
  
  logger.error(fullMessage, context)

# Global logger instance
var globalLogger* {.threadvar.}: Logger
globalLogger = newDefaultLogger()

# Global logger functions
proc trace*(message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a trace message using the global logger
  globalLogger.trace(message, context)

proc debug*(message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a debug message using the global logger
  globalLogger.debug(message, context)

proc info*(message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs an info message using the global logger
  globalLogger.info(message, context)

proc warn*(message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs a warning message using the global logger
  globalLogger.warn(message, context)

proc error*(message: string, context: LogContext = nil) {.gcsafe.} =
  ## Logs an error message using the global logger
  globalLogger.error(message, context)

proc fatal*(message: string, context: LogContext = nil) =
  ## Logs a fatal message using the global logger
  globalLogger.fatal(message, context)

proc logException*(e: ref Exception, message: string = "", context: LogContext = nil) {.gcsafe.} =
  ## Logs an exception using the global logger
  globalLogger.logException(e, message, context)

# Configuration helpers

proc configureFromFile*(logger: Logger, configPath: string): bool =
  ## Configures the logger from a configuration file
  try:
    let jsonString = readFile(configPath)
    let jsonConfig = parseJson(jsonString)
    
    # Parse minimum log level
    if jsonConfig.hasKey("logLevel"):
      let levelStr = jsonConfig["logLevel"].getStr()
      for level in LogLevel:
        if $level == levelStr:
          logger.config.minLevel = level
          break
    
    # Parse outputs
    if jsonConfig.hasKey("logOutputs"):
      var outputs: set[LoggerOutput] = {}
      for outputStr in jsonConfig["logOutputs"]:
        if outputStr.getStr() == "console":
          outputs.incl(loConsole)
        elif outputStr.getStr() == "file":
          outputs.incl(loFile)
      
      logger.config.outputs = outputs
    
    # Parse other options
    if jsonConfig.hasKey("showColors"):
      logger.config.showColors = jsonConfig["showColors"].getBool()
    
    if jsonConfig.hasKey("logFilePath"):
      logger.config.logFilePath = jsonConfig["logFilePath"].getStr()
    
    if jsonConfig.hasKey("includeTimestamp"):
      logger.config.includeTimestamp = jsonConfig["includeTimestamp"].getBool()
    
    if jsonConfig.hasKey("includeContext"):
      logger.config.includeContext = jsonConfig["includeContext"].getBool()
    
    # Re-initialize if already initialized
    if logger.initialized:
      logger.close()
      logger.init()
    
    return true
  except CatchableError as e:
    echo "Error configuring logger from file: ", e.msg
    return false

proc configureFromConfig*(logger: Logger, config: Config): bool =
  ## Configures the logger from the MCP configuration
  try:
    # Set log level from config
    for level in LogLevel:
      if $level == config.logLevel.toUpperAscii():
        logger.config.minLevel = level
        break
    
    # Set outputs based on verbosity
    if config.verbose:
      logger.config.outputs = {loConsole, loFile}
    else:
      logger.config.outputs = {loConsole}
    
    # Set up other settings based on config
    logger.config.showColors = true  # Default to true
    
    # Construct log file path in standard location
    let logDir = getCurrentDir() / "logs"
    if not dirExists(logDir):
      createDir(logDir)
    
    logger.config.logFilePath = logDir / "mcp_jujutsu.log"
    
    # Always include timestamps and context
    logger.config.includeTimestamp = true
    logger.config.includeContext = true
    
    # Re-initialize if already initialized
    if logger.initialized:
      logger.close()
      logger.init()
    
    return true
  except CatchableError as e:
    echo "Error configuring logger from config: ", e.msg
    return false