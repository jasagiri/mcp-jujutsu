## Tests for core configuration module

import std/[unittest, os, tables]
import ../../src/core/config/config

suite "Core Configuration Tests":
  test "Default Configuration":
    let config = newDefaultConfig()
    
    # Check default values
    check config.serverMode == SingleRepo
    check config.serverName == "MCP-Jujutsu"
    check config.serverPort == 8080
    check config.logLevel == "info"
    check config.verbose == false
    check config.useHttp == true
    check config.httpHost == "127.0.0.1"
    check config.httpPort == 8080
    check config.useStdio == false
    check config.repoPath == getCurrentDir()
    check config.reposDir == getCurrentDir()  # Default is current dir
    check config.repoConfigPath == getCurrentDir() / "repos.json"  # Default path
    check config.aiEndpoint == "https://api.openai.com/v1/chat/completions"  # Default endpoint
    check config.aiApiKey == ""
    check config.aiModel == "gpt-4"

  test "Server Mode Enum":
    # Test enum values
    check $SingleRepo == "SingleRepo"
    check $MultiRepo == "MultiRepo"
    
    # Test enum conversion
    var mode: ServerMode
    mode = SingleRepo
    check mode == SingleRepo
    mode = MultiRepo
    check mode == MultiRepo

  test "Config Modification":
    var config = newDefaultConfig()
    
    # Modify values
    config.serverMode = MultiRepo
    config.serverPort = 9090
    config.logLevel = "debug"
    config.verbose = true
    config.httpPort = 9090
    config.repoPath = "/custom/path"
    
    # Verify modifications
    check config.serverMode == MultiRepo
    check config.serverPort == 9090
    check config.logLevel == "debug"
    check config.verbose == true
    check config.httpPort == 9090
    check config.repoPath == "/custom/path"

  test "Multi-Repo Configuration":
    var config = newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "/repos"
    config.repoConfigPath = "/repos/config.json"
    
    check config.serverMode == MultiRepo
    check config.reposDir == "/repos"
    check config.repoConfigPath == "/repos/config.json"

  test "AI Configuration":
    var config = newDefaultConfig()
    config.aiEndpoint = "https://api.example.com"
    config.aiApiKey = "test-key-123"
    config.aiModel = "claude-3"
    
    check config.aiEndpoint == "https://api.example.com"
    check config.aiApiKey == "test-key-123"
    check config.aiModel == "claude-3"

  test "Transport Configuration":
    var config = newDefaultConfig()
    
    # Test HTTP transport config
    config.useHttp = false
    config.httpHost = "0.0.0.0"
    config.httpPort = 3000
    
    check config.useHttp == false
    check config.httpHost == "0.0.0.0"
    check config.httpPort == 3000
    
    # Test stdio transport config
    config.useStdio = true
    check config.useStdio == true