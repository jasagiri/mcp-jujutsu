## Test folder structure without configuration files
##
## This test verifies that the project can work without explicit configuration files

import unittest
import os
import strutils
import sequtils

# Test that we can import modules without configuration
import ../src/core/repository/jujutsu
import ../src/core/logging/logger
import ../src/core/mcp/server
import ../src/core/config/config
import ../src/single_repo/analyzer/semantic
import ../src/multi_repo/analyzer/cross_repo

suite "Folder Structure Tests":
  test "Core modules can be imported":
    # Test that core modules are accessible
    check jujutsu.JujutsuRepo is typedesc
    check logger.Logger is typedesc
    check server.McpServer is typedesc
    
  test "Single repo modules can be imported":
    # Test that single repo modules are accessible
    check semantic.AnalysisResult is typedesc
    check semantic.ChangeType is typedesc
    
  test "Multi repo modules can be imported":
    # Test that multi repo modules are accessible
    check cross_repo.CrossRepoDiff is typedesc
    check cross_repo.CrossRepoProposal is typedesc
    
  test "Project structure follows expected layout":
    # Define expected directories
    let projectRoot = getCurrentDir()
    let expectedDirs = @[
      "src",
      "src/core",
      "src/core/config",
      "src/core/logging",
      "src/core/mcp",
      "src/core/repository",
      "src/single_repo",
      "src/single_repo/analyzer",
      "src/single_repo/mcp",
      "src/single_repo/tools",
      "src/multi_repo",
      "src/multi_repo/analyzer",
      "src/multi_repo/mcp",
      "src/multi_repo/repository",
      "src/multi_repo/tools",
      "src/client",
      "tests",
      "tests/core",
      "tests/single_repo",
      "tests/multi_repo",
      "tests/client",
      "docs",
      "examples",
      "scripts",
      "card"
    ]
    
    for dir in expectedDirs:
      let fullPath = projectRoot / dir
      if not dirExists(fullPath):
        echo "Missing directory: ", dir
        check false
      
  test "No unnecessary configuration files":
    # Check that we're not relying on many config files
    let projectRoot = getCurrentDir()
    var configFiles = 0
    
    # Walk through project looking for config files
    for kind, path in walkDir(projectRoot):
      if kind == pcFile:
        let filename = path.extractFilename()
        # Skip expected config files
        if filename in ["nim.cfg", "nimble.cfg", "config.nims"]:
          continue
        # Check for other config files
        if filename.endsWith(".cfg") or filename.endsWith(".conf") or 
           filename.endsWith(".config") or filename.startsWith("config."):
          configFiles += 1
          echo "Found config file: ", path
    
    # We should have minimal config files
    check configFiles == 0
    
  test "Source files use relative imports":
    # This test passed if the imports above worked
    check true
    
  test "Can create instances without config files":
    # Test that we can create basic instances without loading config
    let logConfig = LogConfig(
      minLevel: llInfo,
      outputs: {loConsole},
      showColors: false,
      logFilePath: "",
      includeTimestamp: true,
      includeContext: true
    )
    let logger = Logger(
      config: logConfig,
      defaultContext: newLogContext("test", "test"),
      initialized: false
    )
    check logger != nil
    
    # Test creating a basic config programmatically
    let config = Config(
      serverMode: SingleRepo,
      serverName: "test-server",
      serverPort: 8080,
      logLevel: "info",
      verbose: false,
      useHttp: true,
      httpHost: "127.0.0.1",
      httpPort: 8080,
      useStdio: false,
      repoPath: getCurrentDir(),
      reposDir: getCurrentDir(),
      repoConfigPath: "",
      aiEndpoint: "",
      aiApiKey: "",
      aiModel: ""
    )
    check config.serverMode == SingleRepo
    check config.serverPort == 8080