## Tests for core configuration module

import std/[unittest, os, tables, strutils]
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
    check config.repoConfigPath == getCurrentDir() / "repos.toml"  # Default path
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
  
  test "TOML Configuration Loading":
    # Create a temporary TOML config file
    let tempDir = getTempDir()
    let configPath = tempDir / "test-config.toml"
    
    let tomlContent = """
[general]
mode = "multi"
server_name = "Test Server"
server_port = 9999
log_level = "debug"
verbose = true

[transport]
http = false
http_host = "0.0.0.0"
http_port = 8888
stdio = true

[repository]
path = "/test/repo"
repos_dir = "/test/repos"
config_path = "/test/repos.toml"

[ai]
endpoint = "https://test.api.com"
api_key = "test-key"
model = "test-model"
"""
    
    writeFile(configPath, tomlContent)
    
    try:
      let config = loadConfigFile(configPath)
      
      # Verify loaded values
      check config.serverMode == MultiRepo
      check config.serverName == "Test Server"
      check config.serverPort == 9999
      check config.logLevel == "debug"
      check config.verbose == true
      check config.useHttp == false
      check config.httpHost == "0.0.0.0"
      check config.httpPort == 8888
      check config.useStdio == true
      check config.repoPath == "/test/repo"
      check config.reposDir == "/test/repos"
      check config.repoConfigPath == "/test/repos.toml"
      check config.aiEndpoint == "https://test.api.com"
      check config.aiApiKey == "test-key"
      check config.aiModel == "test-model"
    finally:
      removeFile(configPath)
  
  test "JSON Configuration Loading":
    # Create a temporary JSON config file
    let tempDir = getTempDir()
    let configPath = tempDir / "test-config.json"
    
    let jsonContent = """
{
  "mode": "single",
  "serverName": "JSON Server",
  "serverPort": 7777,
  "logLevel": "warn",
  "verbose": false,
  "useHttp": true,
  "httpHost": "localhost",
  "httpPort": 7777,
  "useStdio": false,
  "repoPath": "/json/repo",
  "reposDir": "/json/repos",
  "repoConfigPath": "/json/repos.json",
  "aiEndpoint": "https://json.api.com",
  "aiApiKey": "json-key",
  "aiModel": "json-model"
}
"""
    
    writeFile(configPath, jsonContent)
    
    try:
      let config = loadConfigFile(configPath)
      
      # Verify loaded values
      check config.serverMode == SingleRepo
      check config.serverName == "JSON Server"
      check config.serverPort == 7777
      check config.logLevel == "warn"
      check config.verbose == false
      check config.useHttp == true
      check config.httpHost == "localhost"
      check config.httpPort == 7777
      check config.useStdio == false
      check config.repoPath == "/json/repo"
      check config.reposDir == "/json/repos"
      check config.repoConfigPath == "/json/repos.json"
      check config.aiEndpoint == "https://json.api.com"
      check config.aiApiKey == "json-key"
      check config.aiModel == "json-model"
    finally:
      removeFile(configPath)
  
  test "Auto-detect Configuration Format":
    # Test loading without extension - should try TOML first
    let tempDir = getTempDir()
    let configPath = tempDir / "test-config"
    
    let tomlContent = """
[general]
mode = "multi"
server_name = "Auto Detect"
"""
    
    writeFile(configPath, tomlContent)
    
    try:
      let config = loadConfigFile(configPath)
      check config.serverMode == MultiRepo
      check config.serverName == "Auto Detect"
    finally:
      removeFile(configPath)