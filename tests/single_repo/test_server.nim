## Tests for single repository server

import std/[unittest, asyncdispatch, json, tables]
import ../../src/single_repo/mcp/server
import ../../src/core/config/config

suite "Single Repository Server Tests":
  test "Server Creation":
    var config = newDefaultConfig()
    config.serverMode = SingleRepo
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    check server != nil
    check server.baseServer != nil
    check server.baseServer.config.serverMode == SingleRepo

  test "Tool Registration in Single Repo Mode":
    var config = newDefaultConfig()
    config.serverMode = SingleRepo
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    # Register single repo tools
    server.registerSingleRepoTools()
    
    # Check that single repo tools are registered through base server
    check server.baseServer.tools.len > 0
    check server.baseServer.tools.hasKey("analyzeCommitRange")
    check server.baseServer.tools.hasKey("proposeCommitDivision")
    check server.baseServer.tools.hasKey("executeCommitDivision")

  test "Server Initialization":
    var config = newDefaultConfig()
    config.serverMode = SingleRepo
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    # Register tools before initialization
    server.registerSingleRepoTools()
    
    # Initialize the server
    let initParams = %*{"client": "test-client"}
    discard waitFor server.handleInitialize(initParams)
    
    check server.baseServer.initialized == true

  test "Single Repo Specific Configuration":
    var config = newDefaultConfig()
    config.serverMode = SingleRepo
    config.repoPath = "/custom/repo/path"
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    check server.baseServer.config.repoPath == "/custom/repo/path"