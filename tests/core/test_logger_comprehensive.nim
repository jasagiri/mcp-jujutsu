import unittest
import std/[os, tempfiles, json, strutils, sequtils, tables, options, terminal, times]
import ../../src/core/logging/logger
import ../../src/core/config/config

suite "Logger Comprehensive Tests":
  
  suite "LogContext Tests":
    test "newLogContext creates empty context":
      let ctx = newLogContext()
      check ctx.component == ""
      check ctx.operation == ""
      check ctx.sessionId.isNone
      check ctx.requestId.isNone
      check ctx.metadata.len == 0
    
    test "newLogContext with parameters":
      let ctx = newLogContext("test-component", "test-operation")
      check ctx.component == "test-component"
      check ctx.operation == "test-operation"
      check ctx.sessionId.isNone
      check ctx.requestId.isNone
      check ctx.metadata.len == 0
    
    test "withComponent creates new context":
      let ctx1 = newLogContext("comp1", "op1")
      let ctx2 = ctx1.withComponent("comp2")
      check ctx1.component == "comp1"
      check ctx2.component == "comp2"
      check ctx2.operation == "op1"
    
    test "withOperation creates new context":
      let ctx1 = newLogContext("comp1", "op1")
      let ctx2 = ctx1.withOperation("op2")
      check ctx1.operation == "op1"
      check ctx2.operation == "op2"
      check ctx2.component == "comp1"
    
    test "withSessionId creates new context":
      let ctx1 = newLogContext()
      let ctx2 = ctx1.withSessionId("session123")
      check ctx1.sessionId.isNone
      check ctx2.sessionId.isSome
      check ctx2.sessionId.get == "session123"
    
    test "withRequestId creates new context":
      let ctx1 = newLogContext()
      let ctx2 = ctx1.withRequestId("request456")
      check ctx1.requestId.isNone
      check ctx2.requestId.isSome
      check ctx2.requestId.get == "request456"
    
    test "withMetadata creates new context with metadata":
      let ctx1 = newLogContext()
      let ctx2 = ctx1.withMetadata("key1", "value1")
      let ctx3 = ctx2.withMetadata("key2", "value2")
      check ctx1.metadata.len == 0
      check ctx2.metadata.len == 1
      check ctx2.metadata["key1"] == "value1"
      check ctx3.metadata.len == 2
      check ctx3.metadata["key1"] == "value1"
      check ctx3.metadata["key2"] == "value2"
    
    test "formatContext empty context":
      let ctx = newLogContext()
      check formatContext(ctx) == ""
    
    test "formatContext full context":
      let ctx = newLogContext("comp", "op")
        .withSessionId("sess123")
        .withRequestId("req456")
        .withMetadata("user", "alice")
        .withMetadata("action", "create")
      let formatted = formatContext(ctx)
      check "component=comp" in formatted
      check "operation=op" in formatted
      check "session=sess123" in formatted
      check "request=req456" in formatted
      check "user=alice" in formatted
      check "action=create" in formatted

  suite "Logger Creation and Configuration":
    test "newLogger creates logger with config":
      let config = LogConfig(
        minLevel: llDebug,
        outputs: {loConsole},
        showColors: false,
        logFilePath: "test.log",
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      check logger.config.minLevel == llDebug
      check logger.config.outputs == {loConsole}
      check logger.config.showColors == false
      check logger.config.logFilePath == "test.log"
      check logger.config.includeTimestamp == false
      check logger.config.includeContext == false
      check not logger.initialized
    
    test "newDefaultLogger creates logger with defaults":
      let logger = newDefaultLogger()
      check logger.config.minLevel == llInfo
      check logger.config.outputs == {loConsole}
      check logger.config.showColors == true
      check logger.config.includeTimestamp == true
      check logger.config.includeContext == true
      check not logger.initialized
    
    test "setDefaultContext updates context":
      let logger = newDefaultLogger()
      let ctx = newLogContext("test", "op")
      logger.setDefaultContext(ctx)
      check logger.defaultContext.component == "test"
      check logger.defaultContext.operation == "op"

  suite "Logger Initialization and Cleanup":
    test "init creates log file and directory":
      let tempDir = getTempDir() / "logger_test_" & $epochTime().int
      let logPath = tempDir / "test.log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: logPath,
        includeTimestamp: true,
        includeContext: true
      )
      let logger = newLogger(config)
      
      check not dirExists(tempDir)
      logger.init()
      check dirExists(tempDir)
      check logger.initialized
      
      # Write something to ensure file is created
      logger.log(llInfo, "test")
      check fileExists(logPath)
      
      logger.close()
      removeDir(tempDir)
    
    test "init is idempotent":
      let logger = newDefaultLogger()
      logger.init()
      check logger.initialized
      logger.init()  # Should not crash
      check logger.initialized
      logger.close()
    
    test "close releases resources":
      let tempDir = getTempDir() / "logger_test_" & $epochTime().int
      let logPath = tempDir / "test.log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: logPath,
        includeTimestamp: true,
        includeContext: true
      )
      let logger = newLogger(config)
      
      logger.init()
      check logger.initialized
      logger.close()
      check not logger.initialized
      
      if dirExists(tempDir):
        removeDir(tempDir)
    
    test "close is idempotent":
      let logger = newDefaultLogger()
      logger.close()  # Should not crash when not initialized
      logger.init()
      logger.close()
      logger.close()  # Should not crash

  suite "Log Level Tests":
    test "log levels filter correctly":
      let tempFile = getTempDir() / "test_levels_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llWarning,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.trace("trace msg")
      logger.debug("debug msg")
      logger.info("info msg")
      logger.warn("warn msg")
      logger.error("error msg")
      logger.fatal("fatal msg")
      
      logger.close()
      
      let content = readFile(tempFile)
      check "trace msg" notin content
      check "debug msg" notin content
      check "info msg" notin content
      check "WARN | warn msg" in content
      check "ERROR | error msg" in content
      check "FATAL | fatal msg" in content
      
      removeFile(tempFile)
    
    test "all log levels work when minLevel is trace":
      let tempFile = getTempDir() / "test_all_levels_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llTrace,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.trace("trace msg")
      logger.debug("debug msg")
      logger.info("info msg")
      logger.warn("warn msg")
      logger.error("error msg")
      logger.fatal("fatal msg")
      
      logger.close()
      
      let content = readFile(tempFile)
      check "TRACE | trace msg" in content
      check "DEBUG | debug msg" in content
      check "INFO | info msg" in content
      check "WARN | warn msg" in content
      check "ERROR | error msg" in content
      check "FATAL | fatal msg" in content
      
      removeFile(tempFile)

  suite "Log Formatting Tests":
    test "formatTimestamp returns valid timestamp":
      let ts = formatTimestamp()
      # Should be in format: yyyy-MM-dd HH:mm:ss
      check ts.len > 0
      check ts.count('-') == 2
      check ts.count(':') == 2
      check ts.count(' ') == 1
    
    test "getLevelColor returns correct colors":
      check getLevelColor(llTrace) == fgWhite
      check getLevelColor(llDebug) == fgBlue
      check getLevelColor(llInfo) == fgGreen
      check getLevelColor(llWarning) == fgYellow
      check getLevelColor(llError) == fgRed
      check getLevelColor(llFatal) == fgMagenta
    
    test "log with timestamp":
      let tempFile = getTempDir() / "test_timestamp_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: true,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.info("test message")
      logger.close()
      
      let content = readFile(tempFile)
      # Should contain timestamp pattern
      check content.count('-') >= 2
      check content.count(':') >= 2
      check "INFO | test message" in content
      
      removeFile(tempFile)
    
    test "log with context":
      let tempFile = getTempDir() / "test_context_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: true
      )
      let logger = newLogger(config)
      
      let ctx = newLogContext("mycomp", "myop")
        .withSessionId("sess123")
        .withMetadata("user", "bob")
      
      logger.info("test message", ctx)
      logger.close()
      
      let content = readFile(tempFile)
      check "component=mycomp" in content
      check "operation=myop" in content
      check "session=sess123" in content
      check "user=bob" in content
      check "test message" in content
      
      removeFile(tempFile)

  suite "Exception Logging Tests":
    test "logException with default message":
      let tempFile = getTempDir() / "test_exception_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      try:
        raise newException(ValueError, "Test error")
      except ValueError as e:
        logger.logException(e)
      
      logger.close()
      
      let content = readFile(tempFile)
      check "ERROR | Exception occurred: Test error [ValueError]" in content
      
      removeFile(tempFile)
    
    test "logException with custom message":
      let tempFile = getTempDir() / "test_exception_custom_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      try:
        raise newException(IOError, "Disk full")
      except IOError as e:
        logger.logException(e, "Failed to write file")
      
      logger.close()
      
      let content = readFile(tempFile)
      check "ERROR | Failed to write file: Disk full [IOError]" in content
      
      removeFile(tempFile)
    
    test "logException with context":
      let tempFile = getTempDir() / "test_exception_ctx_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: true
      )
      let logger = newLogger(config)
      
      let ctx = newLogContext("error-handler", "process")
      
      try:
        raise newException(OSError, "Permission denied")
      except OSError as e:
        logger.logException(e, "Cannot access file", ctx)
      
      logger.close()
      
      let content = readFile(tempFile)
      check "component=error-handler" in content
      check "operation=process" in content
      check "Cannot access file: Permission denied [OSError]" in content
      
      removeFile(tempFile)

  suite "Configuration Tests":
    test "configureFromFile with valid JSON":
      let tempConfig = getTempDir() / "logger_config_" & $epochTime().int & ".json"
      let tempLog = getTempDir() / "custom_" & $epochTime().int & ".log"
      
      let configJson = %* {
        "logLevel": "DEBUG",
        "logOutputs": ["console", "file"],
        "showColors": false,
        "logFilePath": tempLog,
        "includeTimestamp": false,
        "includeContext": true
      }
      
      writeFile(tempConfig, $configJson)
      
      let logger = newDefaultLogger()
      check logger.configureFromFile(tempConfig)
      
      check logger.config.minLevel == llDebug
      check logger.config.outputs == {loConsole, loFile}
      check logger.config.showColors == false
      check logger.config.logFilePath == tempLog
      check logger.config.includeTimestamp == false
      check logger.config.includeContext == true
      
      logger.close()
      removeFile(tempConfig)
    
    test "configureFromFile with invalid JSON":
      let tempConfig = getTempDir() / "bad_config_" & $epochTime().int & ".json"
      writeFile(tempConfig, "{ invalid json")
      
      let logger = newDefaultLogger()
      check not logger.configureFromFile(tempConfig)
      
      removeFile(tempConfig)
    
    test "configureFromFile with missing file":
      let logger = newDefaultLogger()
      check not logger.configureFromFile("/nonexistent/config.json")
    
    test "configureFromFile reinitializes logger":
      let tempLog1 = getTempDir() / "log1_" & $epochTime().int & ".log"
      let tempLog2 = getTempDir() / "log2_" & $epochTime().int & ".log"
      let tempConfig = getTempDir() / "reconfig_" & $epochTime().int & ".json"
      
      let logger = newLogger(LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempLog1,
        includeTimestamp: false,
        includeContext: false
      ))
      
      logger.init()
      logger.info("message 1")
      
      let configJson = %* {
        "logLevel": "DEBUG",
        "logOutputs": ["file"],
        "logFilePath": tempLog2
      }
      writeFile(tempConfig, $configJson)
      
      check logger.configureFromFile(tempConfig)
      logger.debug("message 2")
      
      logger.close()
      
      check readFile(tempLog1) == "INFO | message 1\n"
      check readFile(tempLog2) == "DEBUG | message 2\n"
      
      removeFile(tempLog1)
      removeFile(tempLog2)
      removeFile(tempConfig)
    
    test "configureFromConfig":
      let tempLog = getTempDir() / "config_log_" & $epochTime().int & ".log"
      
      var config = Config()
      config.logLevel = "error"
      config.verbose = true
      
      let logger = newDefaultLogger()
      check logger.configureFromConfig(config)
      
      check logger.config.minLevel == llError
      check logger.config.outputs == {loConsole, loFile}
      check logger.config.showColors == true
      check logger.config.includeTimestamp == true
      check logger.config.includeContext == true
      
      logger.close()
    
    test "configureFromConfig non-verbose":
      var config = Config()
      config.logLevel = "debug"
      config.verbose = false
      
      let logger = newDefaultLogger()
      check logger.configureFromConfig(config)
      
      check logger.config.minLevel == llDebug
      check logger.config.outputs == {loConsole}
      
      logger.close()

  suite "Global Logger Tests":
    test "global logger functions work":
      # Save original global logger
      let originalLogger = globalLogger
      
      let tempFile = getTempDir() / "global_" & $epochTime().int & ".log"
      globalLogger = newLogger(LogConfig(
        minLevel: llTrace,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      ))
      
      trace("global trace")
      debug("global debug")
      info("global info")
      warn("global warn")
      error("global error")
      fatal("global fatal")
      
      try:
        raise newException(ValueError, "global error")
      except ValueError as e:
        logException(e, "global exception")
      
      globalLogger.close()
      
      let content = readFile(tempFile)
      check "TRACE | global trace" in content
      check "DEBUG | global debug" in content
      check "INFO | global info" in content
      check "WARN | global warn" in content
      check "ERROR | global error" in content
      check "FATAL | global fatal" in content
      check "global exception: global error [ValueError]" in content
      
      removeFile(tempFile)
      
      # Restore original logger
      globalLogger = originalLogger

  suite "Concurrent Logging Tests":
    test "multiple logs in sequence":
      let tempFile = getTempDir() / "concurrent_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      for i in 0..9:
        logger.info("Message " & $i)
      
      logger.close()
      
      let content = readFile(tempFile)
      for i in 0..9:
        check ("INFO | Message " & $i) in content
      
      removeFile(tempFile)

  suite "Edge Cases and Error Handling":
    test "log with nil context uses default":
      let tempFile = getTempDir() / "nil_context_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: true
      )
      let logger = newLogger(config)
      
      let defaultCtx = newLogContext("default", "op")
      logger.setDefaultContext(defaultCtx)
      
      logger.info("test", nil)
      logger.close()
      
      let content = readFile(tempFile)
      check "component=default" in content
      check "operation=op" in content
      
      removeFile(tempFile)
    
    test "empty log message":
      let tempFile = getTempDir() / "empty_msg_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.info("")
      logger.close()
      
      let content = readFile(tempFile)
      check content == "INFO | \n"
      
      removeFile(tempFile)
    
    test "very long log message":
      let tempFile = getTempDir() / "long_msg_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      let longMsg = "x".repeat(10000)
      logger.info(longMsg)
      logger.close()
      
      let content = readFile(tempFile)
      check ("INFO | " & longMsg) in content
      
      removeFile(tempFile)
    
    test "special characters in log message":
      let tempFile = getTempDir() / "special_chars_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.info("Special: \n\t\r\"'\\|")
      logger.close()
      
      let content = readFile(tempFile)
      check "Special: \n\t\r\"'\\|" in content
      
      removeFile(tempFile)
    
    test "console output with colors disabled":
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loConsole},
        showColors: false,
        logFilePath: "",
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      # This should not crash - just testing it runs
      logger.info("Console message without colors")
      logger.close()
    
    test "console output with colors enabled":
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loConsole},
        showColors: true,
        logFilePath: "",
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      # This should not crash - just testing it runs
      logger.info("Console message with colors")
      logger.close()
    
    test "auto-initialization on first log":
      let tempFile = getTempDir() / "auto_init_" & $epochTime().int & ".log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      check not logger.initialized
      logger.info("auto init test")
      check logger.initialized
      
      logger.close()
      
      let content = readFile(tempFile)
      check "INFO | auto init test" in content
      
      removeFile(tempFile)

  suite "File Rotation and Permissions":
    test "append to existing log file":
      let tempFile = getTempDir() / "append_" & $epochTime().int & ".log"
      
      # Write initial content
      writeFile(tempFile, "Previous content\n")
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: tempFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.info("New message")
      logger.close()
      
      let content = readFile(tempFile)
      check "Previous content" in content
      check "INFO | New message" in content
      
      removeFile(tempFile)
    
    test "create nested directories":
      let tempDir = getTempDir() / "nested_" & $epochTime().int
      let deepPath = tempDir / "level1" / "level2" / "level3"
      let logFile = deepPath / "test.log"
      
      let config = LogConfig(
        minLevel: llInfo,
        outputs: {loFile},
        showColors: false,
        logFilePath: logFile,
        includeTimestamp: false,
        includeContext: false
      )
      let logger = newLogger(config)
      
      logger.info("Nested directory test")
      logger.close()
      
      check fileExists(logFile)
      let content = readFile(logFile)
      check "INFO | Nested directory test" in content
      
      removeDir(tempDir)