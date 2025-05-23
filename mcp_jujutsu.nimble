# Package
version       = "0.0.0"
author        = "jasagiri"
description   = "A Model Context Protocol (MCP) based system for semantically dividing Jujutsu commits"
license       = "MIT"
srcDir        = "src"
bin           = @["mcp_jujutsu"]
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task build, "Build the package":
  exec "nim c -d:release -o:build/mcp_jujutsu src/mcp_jujutsu.nim"

task test, "Run tests":
  echo "Running core tests..."
  exec "nim c -r tests/core/test_jujutsu.nim"
  exec "nim c -r tests/core/test_mcp_server.nim"
  exec "nim c -r tests/core/test_config.nim"
  exec "nim c -r tests/core/test_mcp_server_extended.nim"
  # テスト統合テストは実際のjjコマンドが必要なためスキップします
  # exec "nim c -r tests/core/test_jujutsu_integration.nim"
  exec "nim c -r tests/core/test_logger.nim"
  
  echo "Running main entry point tests..."
  exec "nim c -r tests/test_mcp_jujutsu.nim"
  
  echo "Running single repository tests..."
  # Fixed regex VM errors
  exec "nim c -r tests/single_repo/test_semantic.nim"
  exec "nim c -r tests/single_repo/test_semantic_analyzer.nim"
  exec "nim c -r tests/single_repo/test_semantic_simple.nim"
  exec "nim c -r tests/single_repo/test_config.nim"
  exec "nim c -r tests/single_repo/test_server.nim"
  exec "nim c -r tests/single_repo/test_semantic_divide.nim"
  
  echo "Running multi repository tests..."
  # Fixed regex VM errors
  exec "nim c -r tests/multi_repo/test_cross_repo.nim"
  exec "nim c -r tests/multi_repo/test_repo_manager.nim"
  exec "nim c -r tests/multi_repo/test_cross_repo_analysis.nim"
  exec "nim c -r tests/multi_repo/test_config.nim"
  exec "nim c -r tests/multi_repo/test_server.nim"
  exec "nim c -r tests/multi_repo/test_manager.nim"
  exec "nim c -r tests/multi_repo/test_multi_repo_tools.nim"
  # エンドツーエンドテストは実際のjjコマンドが必要なためスキップします
  # exec "nim c -r tests/multi_repo/test_end_to_end_commit_division.nim"
  
  echo "Running client tests..."
  exec "nim c -r tests/client/test_client.nim"

task docs, "Generate documentation":
  exec "nim doc --project --outdir=docs src/mcp_jujutsu.nim"

task run, "Run MCP server":
  # Check for --hub flag
  var isHub = false
  var port = "8080"
  
  for i in 2..paramCount():
    let param = paramStr(i)
    if param == "--hub":
      isHub = true
    elif param.startsWith("--port="):
      port = param.split("=")[1]
  
  if isHub:
    echo "Starting in hub mode (multi-repository support) on port " & port
    exec "nim c -o:build/mcp_jujutsu -r src/mcp_jujutsu.nim --hub --port=" & port
  else:
    echo "Starting in server mode (single repository) on port " & port
    exec "nim c -o:build/mcp_jujutsu -r src/mcp_jujutsu.nim --port=" & port

task coverage, "Run tests and generate coverage report":
  echo "Running tests..."
  exec "nimble test"
  
  echo ""
  echo "Generating coverage report..."
  exec "nim c -r scripts/coverage_report.nim"
