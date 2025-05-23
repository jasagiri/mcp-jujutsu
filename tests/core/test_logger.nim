## Tests for the logger module
##
## This module tests the logging functionality.

import unittest, os, strutils, tables, options
import ../../src/core/logging/logger

suite "Logger Tests":
  
  setup:
    # Create a test directory for log files
    let testLogDir = getTempDir() / "mcp_jujutsu_log_test"
    if not dirExists(testLogDir):
      createDir(testLogDir)
    
    let testLogPath = testLogDir / "test.log"
    if fileExists(testLogPath):
      removeFile(testLogPath)
  
  teardown:
    # Clean up test directory
    let testLogDir = getTempDir() / "mcp_jujutsu_log_test"
    if dirExists(testLogDir):
      removeDir(testLogDir)
  
  test "Log Level Enums":
    # Test log level ordering
    check(llTrace.ord < llDebug.ord)
    check(llDebug.ord < llInfo.ord)
    check(llInfo.ord < llWarning.ord)
    check(llWarning.ord < llError.ord)
    check(llError.ord < llFatal.ord)
  
  test "Log Context Creation":
    # Test basic context creation
    let ctx = newLogContext("test-component", "test-operation")
    check(ctx.component == "test-component")
    check(ctx.operation == "test-operation")
    check(ctx.sessionId.isNone)
    check(ctx.requestId.isNone)
    check(ctx.metadata.len == 0)
    
    # Test context modifications
    let ctx2 = ctx.withComponent("new-component")
    check(ctx2.component == "new-component")
    check(ctx2.operation == "test-operation")
    
    let ctx3 = ctx.withOperation("new-operation")
    check(ctx3.component == "test-component")
    check(ctx3.operation == "new-operation")
    
    let ctx4 = ctx.withSessionId("session-123")
    check(ctx4.sessionId.isSome)
    check(ctx4.sessionId.get() == "session-123")
    
    let ctx5 = ctx.withRequestId("request-456")
    check(ctx5.requestId.isSome)
    check(ctx5.requestId.get() == "request-456")
    
    let ctx6 = ctx.withMetadata("key1", "value1")
    check(ctx6.metadata.hasKey("key1"))
    check(ctx6.metadata["key1"] == "value1")
    
    # Test chaining
    let ctx7 = ctx.withComponent("comp")
                 .withOperation("op")
                 .withSessionId("sid")
                 .withRequestId("rid")
                 .withMetadata("k1", "v1")
                 .withMetadata("k2", "v2")
    
    check(ctx7.component == "comp")
    check(ctx7.operation == "op")
    check(ctx7.sessionId.isSome and ctx7.sessionId.get() == "sid")
    check(ctx7.requestId.isSome and ctx7.requestId.get() == "rid")
    check(ctx7.metadata.hasKey("k1") and ctx7.metadata["k1"] == "v1")
    check(ctx7.metadata.hasKey("k2") and ctx7.metadata["k2"] == "v2")
  
  test "Basic Logger Creation":
    # Test default logger creation
    let logger = newDefaultLogger()
    check(logger.initialized == false)
    check(logger.config.minLevel == llInfo)
    check(logger.config.outputs == {loConsole})
    check(logger.config.showColors == true)
    check(logger.config.includeTimestamp == true)
    check(logger.config.includeContext == true)
    
    # Test custom logger creation
    let customConfig = LogConfig(
      minLevel: llDebug,
      outputs: {loConsole, loFile},
      showColors: false,
      logFilePath: getTempDir() / "mcp_jujutsu_log_test" / "custom.log",
      includeTimestamp: false,
      includeContext: false
    )
    let customLogger = newLogger(customConfig)
    
    check(customLogger.initialized == false)
    check(customLogger.config.minLevel == llDebug)
    check(customLogger.config.outputs == {loConsole, loFile})
    check(customLogger.config.showColors == false)
    check(customLogger.config.logFilePath == getTempDir() / "mcp_jujutsu_log_test" / "custom.log")
    check(customLogger.config.includeTimestamp == false)
    check(customLogger.config.includeContext == false)
  
  test "Logger Initialization and Closing":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "init_test.log"
    let config = LogConfig(
      minLevel: llInfo,
      outputs: {loFile},
      showColors: true,
      logFilePath: logPath,
      includeTimestamp: true,
      includeContext: true
    )
    
    var logger = newLogger(config)
    check(logger.initialized == false)
    
    # Initialize
    logger.init()
    check(logger.initialized == true)
    check(fileExists(logPath))
    
    # Close
    logger.close()
    check(logger.initialized == false)
  
  test "File Logging":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "file_test.log"
    let config = LogConfig(
      minLevel: llTrace, # Log everything for testing
      outputs: {loFile},
      showColors: false,
      logFilePath: logPath,
      includeTimestamp: false, # For easier testing
      includeContext: false    # For easier testing
    )
    
    var logger = newLogger(config)
    logger.init()
    
    # Log at different levels
    logger.trace("Trace message")
    logger.debug("Debug message")
    logger.info("Info message")
    logger.warn("Warning message")
    logger.error("Error message")
    logger.fatal("Fatal message")
    
    # Check file contents
    logger.close() # Close to flush all content
    
    let logContents = readFile(logPath)
    let lines = logContents.splitLines()
    
    check(lines[0] == "TRACE | Trace message")
    check(lines[1] == "DEBUG | Debug message")
    check(lines[2] == "INFO | Info message")
    check(lines[3] == "WARN | Warning message")
    check(lines[4] == "ERROR | Error message")
    check(lines[5] == "FATAL | Fatal message")
  
  test "Log Level Filtering":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "filter_test.log"
    let config = LogConfig(
      minLevel: llWarning, # Only log warnings and above
      outputs: {loFile},
      showColors: false,
      logFilePath: logPath,
      includeTimestamp: false,
      includeContext: false
    )
    
    var logger = newLogger(config)
    logger.init()
    
    # Log at different levels
    logger.trace("Trace message")
    logger.debug("Debug message")
    logger.info("Info message")
    logger.warn("Warning message")
    logger.error("Error message")
    logger.fatal("Fatal message")
    
    # Check file contents
    logger.close()
    
    let logContents = readFile(logPath)
    let lines = logContents.splitLines()
    
    # Should only have 3 lines (warning, error, fatal)
    check(lines.len >= 3)
    check(lines[0] == "WARN | Warning message")
    check(lines[1] == "ERROR | Error message")
    check(lines[2] == "FATAL | Fatal message")
  
  test "Context Logging":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "context_test.log"
    let config = LogConfig(
      minLevel: llInfo,
      outputs: {loFile},
      showColors: false,
      logFilePath: logPath,
      includeTimestamp: false,
      includeContext: true
    )
    
    var logger = newLogger(config)
    logger.init()
    
    # Create a context
    let ctx = newLogContext("test-component", "test-operation")
      .withSessionId("session-123")
      .withRequestId("request-456")
      .withMetadata("user", "testuser")
    
    # Log with context
    logger.info("Info with context", ctx)
    
    # Check file contents
    logger.close()
    
    let logContents = readFile(logPath)
    let lines = logContents.splitLines()
    
    # Context should be included
    check(lines[0].contains("component=test-component"))
    check(lines[0].contains("operation=test-operation"))
    check(lines[0].contains("session=session-123"))
    check(lines[0].contains("request=request-456"))
    check(lines[0].contains("user=testuser"))
    check(lines[0].contains("Info with context"))
  
  test "Default Context":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "default_context_test.log"
    let config = LogConfig(
      minLevel: llInfo,
      outputs: {loFile},
      showColors: false,
      logFilePath: logPath,
      includeTimestamp: false,
      includeContext: true
    )
    
    var logger = newLogger(config)
    
    # Set a default context
    let defaultCtx = newLogContext("default-component", "default-operation")
    logger.setDefaultContext(defaultCtx)
    
    logger.init()
    
    # Log without explicit context
    logger.info("Info with default context")
    
    # Log with explicit context
    let explicitCtx = newLogContext("explicit-component", "explicit-operation")
    logger.info("Info with explicit context", explicitCtx)
    
    # Check file contents
    logger.close()
    
    let logContents = readFile(logPath)
    let lines = logContents.splitLines()
    
    # Default context should be used
    check(lines[0].contains("component=default-component"))
    check(lines[0].contains("operation=default-operation"))
    
    # Explicit context should override default
    check(lines[1].contains("component=explicit-component"))
    check(lines[1].contains("operation=explicit-operation"))
  
  test "Exception Logging":
    let logPath = getTempDir() / "mcp_jujutsu_log_test" / "exception_test.log"
    let config = LogConfig(
      minLevel: llInfo,
      outputs: {loFile},
      showColors: false,
      logFilePath: logPath,
      includeTimestamp: false,
      includeContext: false
    )
    
    var logger = newLogger(config)
    logger.init()
    
    # Create an exception
    var exception: ref Exception
    try:
      raise newException(ValueError, "Test exception")
    except ValueError as e:
      exception = e
    
    # Log the exception
    logger.logException(exception, "Error during operation")
    
    # Check file contents
    logger.close()
    
    let logContents = readFile(logPath)
    
    # Exception details should be included
    check(logContents.contains("Error during operation"))
    check(logContents.contains("Test exception"))
    check(logContents.contains("ValueError"))
  
  test "Global Logger":
    # The global logger is preset to console output
    # So just test that it doesn't crash
    trace("Global trace message")
    debug("Global debug message")
    info("Global info message")
    warn("Global warning message")
    error("Global error message")
    
    # Don't call fatal as it might exit the process in some implementations
    
    # Also test with context
    let ctx = newLogContext("global-test", "test-operation")
    info("Global info with context", ctx)
    
    # Test exception logging
    var exception: ref Exception
    try:
      raise newException(ValueError, "Global test exception")
    except ValueError as e:
      exception = e
    
    logException(exception, "Global exception test")