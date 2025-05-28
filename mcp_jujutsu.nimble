# Package
version       = "0.0.0"
author        = "jasagiri"
description   = "A Model Context Protocol (MCP) based system for semantically dividing Jujutsu commits"
license       = "MIT"
srcDir        = "src"
bin           = @["mcp_jujutsu"]
binDir        = "bin"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.0"
requires "parsetoml >= 0.7.0"

# Use local packages from our workspace
# TODO: Use these once packages are published
# requires "nimtestkit >= 0.1.0"
# requires "nimconfigkit >= 0.1.0"

# Tasks
task build, "Build the package":
  exec "nim c -d:release -o:bin/mcp_jujutsu src/mcp_jujutsu.nim"

task test, "Run all tests":
  echo "Running tests..."
  exec "nim c -r --path:src tests/test_runner.nim"

task testQuick, "Run quick tests (core + client only)":
  echo "Running quick tests..."
  exec "nimtestkit run --profile=quick"

task testFull, "Run all tests including integration":
  echo "Running full test suite..."
  exec "nimtestkit run --profile=full"

task testCore, "Run core tests only":
  echo "Running core tests..."
  exec "nimtestkit run --category=core"

task testSingle, "Run single repository tests":
  echo "Running single repository tests..."
  exec "nimtestkit run --category=single_repo"

task testMulti, "Run multi repository tests":
  echo "Running multi repository tests..."
  exec "nimtestkit run --category=multi_repo"

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
    exec "nim c -o:bin/mcp_jujutsu -r src/mcp_jujutsu.nim --hub --port=" & port
  else:
    echo "Starting in server mode (single repository) on port " & port
    exec "nim c -o:bin/mcp_jujutsu -r src/mcp_jujutsu.nim --port=" & port

task coverage, "Run tests and generate coverage report":
  echo "Running tests with coverage..."
  exec "./scripts/run_coverage.sh"

task clean, "Clean build artifacts":
  exec "rm -rf build/"
  exec "rm -rf nimcache/"
  exec "rm -rf coverage/"
  exec "rm -rf htmldocs/"
  echo "Build artifacts cleaned"

task debug, "Build debug version":
  echo "Building debug version..."
  exec "nim c -o:bin/mcp_jujutsu src/mcp_jujutsu.nim"

task release, "Build release version":
  echo "Building release version..."
  exec "nim c -d:release -o:bin/mcp_jujutsu src/mcp_jujutsu.nim"

task install, "Install dependencies":
  echo "Installing dependencies..."
  exec "nimble install -d"

task guard, "Run tests in watch mode":
  echo "Starting test guard..."
  exec "nimtestkit guard"

task generate, "Generate tests for new modules":
  echo "Generating tests..."
  exec "nimtestkit generate"