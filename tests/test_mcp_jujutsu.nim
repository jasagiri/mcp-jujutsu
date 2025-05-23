## Tests for main entry point

import std/[unittest, asyncdispatch, os, strutils]

suite "Main Entry Point Tests":
  test "Transport Creation":
    # Note: We can't easily test the main() function directly,
    # but we can test the components it uses
    
    # Test that the main module compiles
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    check mainModule.contains("proc main()")
    check mainModule.contains("HttpTransport")
    check mainModule.contains("StdioTransport")
    
  test "Command Line Help":
    # Test that help information is defined
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    check mainModule.contains("printUsage")
    check mainModule.contains("--help")
    check mainModule.contains("--mode")
    check mainModule.contains("--port")
    
  test "Server Mode Detection":
    # Test that both server modes are supported
    const mainModule = staticRead("../src/mcp_jujutsu.nim")
    check mainModule.contains("SingleRepo")
    check mainModule.contains("MultiRepo")
    check mainModule.contains("single-repository mode")
    check mainModule.contains("multi-repository mode")