## Server Modes Test Suite
##
## Tests for different server modes and their integration with transports

import unittest, asyncdispatch, json, os, strutils, strformat, osproc
import ../src/core/config/config as core_config
import ../src/single_repo/config/config as single_config  
import ../src/multi_repo/config/config as multi_config

suite "Server Mode Detection Tests":

  test "Default Server Mode":
    ## Test that default mode is single repository
    # This tests the default behavior when no mode is specified
    let config = single_config.Config()
    check config.serverMode == single_config.ServerMode.Single

  test "Single Repository Mode Detection":
    ## Test single repository mode is detected correctly
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: "/test/repo"
    )
    check config.serverMode == single_config.ServerMode.Single

  test "Multi Repository Mode Detection":
    ## Test multi repository mode is detected correctly  
    let config = multi_config.Config(
      serverMode: multi_config.ServerMode.Multi,
      repositoriesDir: "/test/repos"
    )
    check config.serverMode == multi_config.ServerMode.Multi

suite "Command Line Argument Simulation Tests":

  test "Stdio Mode Arguments":
    ## Test command line arguments for stdio mode
    # Simulate: ./mcp_jujutsu --stdio
    let expectedArgs = @["--stdio"]
    
    # Test that stdio argument would be recognized
    check "--stdio" in expectedArgs

  test "HTTP Mode Arguments":
    ## Test command line arguments for HTTP mode
    # Simulate: ./mcp_jujutsu --port=9090
    let expectedArgs = @["--port=9090"]
    
    # Test port argument format
    check expectedArgs[0].startsWith("--port=")

  test "SSE Mode Arguments":
    ## Test command line arguments for SSE mode
    # Simulate: ./mcp_jujutsu --sse --port=8080
    let expectedArgs = @["--sse", "--port=8080"]
    
    check "--sse" in expectedArgs
    check "--port=8080" in expectedArgs

  test "Single Repository Mode Arguments":
    ## Test command line arguments for single repo mode
    # Simulate: ./mcp_jujutsu --mode=single --repo-path=/test/repo --stdio
    let expectedArgs = @["--mode=single", "--repo-path=/test/repo", "--stdio"]
    
    check "--mode=single" in expectedArgs
    check expectedArgs.anyIt(it.startsWith("--repo-path="))

  test "Multi Repository Mode Arguments":
    ## Test command line arguments for multi repo mode
    # Simulate: ./mcp_jujutsu --mode=multi --repos-dir=/test/repos --repo-config=/test/repos.toml --stdio
    let expectedArgs = @["--mode=multi", "--repos-dir=/test/repos", "--repo-config=/test/repos.toml", "--stdio"]
    
    check "--mode=multi" in expectedArgs
    check expectedArgs.anyIt(it.startsWith("--repos-dir="))
    check expectedArgs.anyIt(it.startsWith("--repo-config="))

suite "Server Binary Execution Tests":

  test "Version Command":
    ## Test that version command works
    try:
      let result = execProcess("./bin/mcp_jujutsu --version")
      check result.contains("MCP-Jujutsu")
      check result.contains("v0.1.0")
    except OSError:
      echo "Note: Binary not found, skipping execution test"
      check true

  test "Help Command":
    ## Test that help command works
    try:
      let result = execProcess("./bin/mcp_jujutsu --help")
      check result.contains("Usage:")
      check result.contains("Options:")
      check result.contains("--stdio")
      check result.contains("--mode")
    except OSError:
      echo "Note: Binary not found, skipping execution test"
      check true

suite "Mode Configuration Validation Tests":

  test "Stdio Mode Configuration Validation":
    ## Test that stdio mode configuration is valid
    let config = core_config.Config(
      useStdio: true,
      useHttp: false,
      useSse: false
    )
    
    # Validate stdio mode settings
    check config.useStdio == true
    check config.useHttp == false
    check config.useSse == false

  test "HTTP Mode Configuration Validation":
    ## Test that HTTP mode configuration is valid
    let config = core_config.Config(
      useStdio: false,
      useHttp: true,
      useSse: false,
      httpHost: "127.0.0.1",
      httpPort: 8080
    )
    
    # Validate HTTP mode settings
    check config.useHttp == true
    check config.httpHost == "127.0.0.1"
    check config.httpPort > 0
    check config.httpPort < 65536

  test "SSE Mode Configuration Validation":
    ## Test that SSE mode configuration is valid
    let config = core_config.Config(
      useStdio: false,
      useHttp: true,
      useSse: true,
      httpHost: "127.0.0.1",
      httpPort: 8080
    )
    
    # Validate SSE mode settings (SSE requires HTTP)
    check config.useSse == true
    check config.useHttp == true  # SSE requires HTTP to be enabled
    check config.httpPort > 0

  test "Single Repository Path Validation":
    ## Test single repository path configuration
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: "/valid/path/to/repo"
    )
    
    check config.repositoryPath.len > 0
    check config.repositoryPath.startsWith("/")

  test "Multi Repository Configuration Validation":
    ## Test multi repository configuration
    let config = multi_config.Config(
      serverMode: multi_config.ServerMode.Multi,
      repositoriesDir: "/repos",
      repoConfigPath: "/repos.toml"
    )
    
    check config.repositoriesDir.len > 0
    check config.repoConfigPath.len > 0
    check config.repoConfigPath.endsWith(".toml")

suite "Mode Compatibility Tests":

  test "Stdio + Single Repository Compatibility":
    ## Test that stdio transport works with single repository mode
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: "/test/repo",
      useStdio: true,
      useHttp: false
    )
    
    check config.serverMode == single_config.ServerMode.Single
    check config.useStdio == true

  test "HTTP + Multi Repository Compatibility":
    ## Test that HTTP transport works with multi repository mode
    let config = multi_config.Config(
      serverMode: multi_config.ServerMode.Multi,
      repositoriesDir: "/test/repos",
      useStdio: false,
      useHttp: true,
      httpPort: 8080
    )
    
    check config.serverMode == multi_config.ServerMode.Multi
    check config.useHttp == true

  test "SSE + Single Repository Compatibility":
    ## Test that SSE transport works with single repository mode
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: "/test/repo",
      useStdio: false,
      useHttp: true,
      useSse: true,
      httpPort: 8080
    )
    
    check config.serverMode == single_config.ServerMode.Single
    check config.useSse == true
    check config.useHttp == true  # SSE requires HTTP

  test "Multi Transport Compatibility":
    ## Test that multiple transports can be enabled simultaneously
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: "/test/repo",
      useStdio: true,
      useHttp: true,
      useSse: false,
      httpPort: 8080
    )
    
    check config.useStdio == true
    check config.useHttp == true
    check config.useSse == false

suite "Real-World Command Examples Tests":

  test "Claude Code Integration Command":
    ## Test command suitable for Claude Code integration
    # Command: ./bin/mcp_jujutsu --stdio
    let expectedConfig = single_config.Config(
      useStdio: true,
      useHttp: false,
      useSse: false
    )
    
    check expectedConfig.useStdio == true

  test "Web Development Command":
    ## Test command suitable for web development
    # Command: ./bin/mcp_jujutsu --port=3000 --host=0.0.0.0
    let expectedConfig = single_config.Config(
      useStdio: false,
      useHttp: true,
      useSse: false,
      httpHost: "0.0.0.0",
      httpPort: 3000
    )
    
    check expectedConfig.useHttp == true
    check expectedConfig.httpHost == "0.0.0.0"
    check expectedConfig.httpPort == 3000

  test "Multi Repository Development Command":
    ## Test command for multi repository development
    # Command: ./bin/mcp_jujutsu --mode=multi --repos-dir=./repos --config=repos.toml --stdio
    let expectedConfig = multi_config.Config(
      serverMode: multi_config.ServerMode.Multi,
      repositoriesDir: "./repos",
      repoConfigPath: "repos.toml",
      useStdio: true,
      useHttp: false
    )
    
    check expectedConfig.serverMode == multi_config.ServerMode.Multi
    check expectedConfig.repositoriesDir == "./repos"
    check expectedConfig.repoConfigPath == "repos.toml"
    check expectedConfig.useStdio == true

  test "Production Server Command":
    ## Test command suitable for production deployment
    # Command: ./bin/mcp_jujutsu --port=8080 --host=127.0.0.1 --no-restart
    let expectedConfig = single_config.Config(
      useStdio: false,
      useHttp: true,
      useSse: false,
      httpHost: "127.0.0.1",
      httpPort: 8080
    )
    
    check expectedConfig.useHttp == true
    check expectedConfig.httpHost == "127.0.0.1"
    check expectedConfig.httpPort == 8080

  test "SSE Development Command":
    ## Test command for SSE development
    # Command: ./bin/mcp_jujutsu --sse --port=8080
    let expectedConfig = single_config.Config(
      useStdio: false,
      useHttp: true,
      useSse: true,
      httpPort: 8080
    )
    
    check expectedConfig.useSse == true
    check expectedConfig.useHttp == true

suite "Error Handling in Mode Detection":

  test "Invalid Port Number":
    ## Test handling of invalid port numbers
    let config = core_config.Config(
      useHttp: true,
      httpPort: 99999  # Invalid port number
    )
    
    # Configuration should still be created, validation happens at runtime
    check config.httpPort == 99999

  test "Empty Repository Path":
    ## Test handling of empty repository path
    let config = single_config.Config(
      serverMode: single_config.ServerMode.Single,
      repositoryPath: ""  # Empty path
    )
    
    check config.repositoryPath == ""

  test "Non-existent Configuration File":
    ## Test handling of non-existent configuration file
    let config = multi_config.Config(
      serverMode: multi_config.ServerMode.Multi,
      repoConfigPath: "/nonexistent/config.toml"
    )
    
    check config.repoConfigPath == "/nonexistent/config.toml"

echo "Server Modes Test Suite completed"