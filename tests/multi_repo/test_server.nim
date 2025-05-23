## Tests for multi repository server

import std/[unittest, asyncdispatch, json, tables]
import ../../src/multi_repo/mcp/server
import ../../src/core/config/config

suite "Multi Repository Server Tests":
  test "Multi Repo Server Creation":
    var config = newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "."
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    check server != nil
    check server.baseServer.config.serverMode == MultiRepo

  test "Multi Repo Tool Registration":
    var config = newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "."
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    # Register multi-repo tools
    server.registerMultiRepoTools()
    
    # Check that multi-repo tools are registered
    check server.baseServer.tools.len > 0
    check server.baseServer.tools.hasKey("analyzeMultiRepoCommits")
    check server.baseServer.tools.hasKey("proposeMultiRepoSplit")
    check server.baseServer.tools.hasKey("executeMultiRepoSplit")
    check server.baseServer.tools.hasKey("automateMultiRepoSplit")

  test "Multi Repo Server Initialization":
    var config = newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "."
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    # Register tools before initialization
    server.registerMultiRepoTools()
    
    # Initialize the server
    let initParams = %*{"client": "test-client"}
    discard waitFor server.handleInitialize(initParams)
    
    check server.baseServer.initialized == true

  test "Repository Manager Integration":
    var config = newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "."
    config.repoConfigPath = "repos.json"
    
    let serverFuture = newMcpServer(config)
    let server = waitFor serverFuture
    
    # Check that server has repository manager
    check server.repoManager != nil