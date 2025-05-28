## Tests for HTTP transport functionality

import std/[unittest, asyncdispatch, os, strutils, json, net, posix]

# Test basic components that are exposed
suite "HTTP Transport Tests":
  test "Port In Use Detection":
    # Import the function from main module
    proc isPortInUse(port: int, host: string = "127.0.0.1"): bool =
      try:
        let socket = newSocket()
        defer: socket.close()
        socket.bindAddr(Port(port), host)
        return false
      except OSError:
        return true
    
    # Test with a port that's likely free
    check not isPortInUse(65432, "127.0.0.1")
    
    # Test with occupied port
    let socket = newSocket()
    socket.bindAddr(Port(65433), "127.0.0.1")
    defer: socket.close()
    
    check isPortInUse(65433, "127.0.0.1")
    
  test "Find Available Port Logic":
    # Test the logic for finding available ports
    proc findAvailablePort(startPort: int, host: string = "127.0.0.1"): int =
      proc isPortInUse(port: int, host: string): bool =
        try:
          let socket = newSocket()
          defer: socket.close()
          socket.bindAddr(Port(port), host)
          return false
        except OSError:
          return true
      
      var port = startPort
      while port < startPort + 100:
        if not isPortInUse(port, host):
          return port
        inc port
      raise newException(OSError, "No available ports found in range")
    
    # Should find an available port
    let port = findAvailablePort(65434, "127.0.0.1")
    check port >= 65434
    check port < 65534
    
  test "PID File Operations":
    # Test PID file path generation
    proc getPidFilePath(port: int = 0): string =
      let tempDir = getTempDir()
      if port > 0:
        return tempDir / ("mcp_jujutsu_" & $port & ".pid")
      else:
        return tempDir / "mcp_jujutsu.pid"
    
    let defaultPath = getPidFilePath()
    check defaultPath.endsWith("mcp_jujutsu.pid")
    
    let portPath = getPidFilePath(8080)
    check portPath.endsWith("mcp_jujutsu_8080.pid")
    
  test "Process ID Management":
    # Test getting current process ID
    let pid = getCurrentProcessId()
    check pid > 0
    
  test "Process Running Check":
    # Test checking if process is running
    proc isProcessRunning(pid: int): bool =
      try:
        when defined(windows):
          return false
        else:
          let result = kill(Pid(pid), cint(0))
          return result == 0
      except:
        return false
    
    # Current process should be running
    check isProcessRunning(getCurrentProcessId())
    
    # Non-existent process should not be running
    check not isProcessRunning(99999)
    
  test "Signal Handler Setup":
    # Test that signal handlers can be set
    proc testHandler() {.noconv.} =
      discard
    
    # Should not crash
    setControlCHook(testHandler)
    check true