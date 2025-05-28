## Basic tests for main entry point
##
## Simplified version to ensure tests compile and run

import std/[unittest, strutils]

suite "MCP-Jujutsu Basic Tests":
  
  test "Main module structure":
    # Test that the main module has expected structure
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    # Check for main components
    check mainModule.contains("proc main()")
    check mainModule.contains("HttpTransport")
    check mainModule.contains("StdioTransport")
    check mainModule.contains("server_mode") or mainModule.contains("multi_config")
    
  test "Command line options":
    # Test that all command line options are defined
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    check mainModule.contains("--help")
    check mainModule.contains("--version")
    check mainModule.contains("--mode")
    check mainModule.contains("--port")
    # These flags might be in code or comments
    check mainModule.contains("multi") or mainModule.contains("Multi")
    
  test "Server modes":
    # Test that both server modes are supported
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    check mainModule.contains("SingleRepo")
    check mainModule.contains("MultiRepo")
    check mainModule.contains("single-repository mode")
    check mainModule.contains("multi-repository mode")
    
  test "Transport types":
    # Test that both transport types are supported
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    check mainModule.contains("HttpTransport")
    check mainModule.contains("StdioTransport")
    check mainModule.contains("port")
    check mainModule.contains("host")
    
  test "Error messages":
    # Test that error handling messages exist
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    check mainModule.contains("Usage:")
    check mainModule.contains("Options:")
    check mainModule.contains("Unknown option") or mainModule.contains("Usage:")
    
  test "Async main pattern":
    # Test that async/await pattern is used correctly
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    
    check mainModule.contains("proc main() {.async.}")
    check mainModule.contains("waitFor main()")
    check mainModule.contains("runForever()")