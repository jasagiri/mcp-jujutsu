## Tests for PID file management

import std/[unittest, os, strutils, osproc]

suite "PID File Management":
  proc getPidFilePath(port: int = 0): string =
    let tempDir = getTempDir()
    if port > 0:
      return tempDir / ("mcp_jujutsu_" & $port & ".pid")
    else:
      return tempDir / "mcp_jujutsu.pid"
  
  proc writePidFile(port: int) =
    let pidFile = getPidFilePath(port)
    let pid = getCurrentProcessId()
    writeFile(pidFile, $pid & ":" & $port)
  
  proc readPidFile(port: int): tuple[pid: int, port: int] =
    let pidFile = getPidFilePath(port)
    if not fileExists(pidFile):
      return (0, 0)
    
    try:
      let content = readFile(pidFile).strip()
      let parts = content.split(":")
      if parts.len >= 2:  # Changed from == 2 to >= 2 to handle extra colons
        result.pid = parseInt(parts[0])
        result.port = parseInt(parts[1])
      else:
        result = (0, 0)
    except:
      result = (0, 0)
  
  proc cleanupPidFile(port: int = 0) =
    let pidFile = getPidFilePath(port)
    try:
      if fileExists(pidFile):
        removeFile(pidFile)
    except:
      discard
  
  setup:
    # Clean up before each test
    for port in 9200..9210:
      cleanupPidFile(port)
  
  teardown:
    # Clean up after each test
    for port in 9200..9210:
      cleanupPidFile(port)
  
  test "Write and Read PID File":
    let testPort = 9201
    writePidFile(testPort)
    
    let (pid, port) = readPidFile(testPort)
    check pid == getCurrentProcessId()
    check port == testPort
    
  test "Read Non-Existent PID File":
    let (pid, port) = readPidFile(9202)
    check pid == 0
    check port == 0
    
  test "Multiple PID Files":
    # Write multiple PID files
    writePidFile(9203)
    writePidFile(9204)
    writePidFile(9205)
    
    # Read them back
    let (pid1, port1) = readPidFile(9203)
    let (pid2, port2) = readPidFile(9204)
    let (pid3, port3) = readPidFile(9205)
    
    check pid1 == getCurrentProcessId()
    check port1 == 9203
    check pid2 == getCurrentProcessId()
    check port2 == 9204
    check pid3 == getCurrentProcessId()
    check port3 == 9205
    
  test "Invalid PID File Content":
    let testPort = 9206
    let pidFile = getPidFilePath(testPort)
    
    # Write invalid content
    writeFile(pidFile, "invalid")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 0
    check port == 0
    
  test "PID File Cleanup":
    let testPort = 9207
    writePidFile(testPort)
    
    let pidFile = getPidFilePath(testPort)
    check fileExists(pidFile)
    
    cleanupPidFile(testPort)
    check not fileExists(pidFile)
    
  test "PID File With Extra Data":
    let testPort = 9208
    let pidFile = getPidFilePath(testPort)
    
    # Write PID file with extra colons
    writeFile(pidFile, "12345:9208:extra:data")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 12345
    check port == 9208
    
  test "Empty PID File":
    let testPort = 9209
    let pidFile = getPidFilePath(testPort)
    
    # Write empty file
    writeFile(pidFile, "")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 0
    check port == 0
    
  test "PID File Path Generation":
    let defaultPath = getPidFilePath(0)
    check defaultPath.contains("mcp_jujutsu.pid")
    check not defaultPath.contains("_0")
    
    let portPath = getPidFilePath(9210)
    check portPath.contains("mcp_jujutsu_9210.pid")