## Edge case tests for comprehensive coverage

import std/[unittest, asyncdispatch, os, strutils, json, net, posix]
import ../src/mcp_jujutsu
import ../src/core/mcp/server as base_server
import ../src/single_repo/mcp/server as single_server
import ../src/single_repo/config/config as single_config

suite "HTTP Transport Edge Cases":
  test "Handle Invalid HTTP Method":
    let config = single_config.newConfig()
    let mcpServer = waitFor single_server.newMcpServer(config)
    let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
    
    proc testInvalidMethod() {.async.} =
      let req = Request(
        reqMethod: HttpGet,  # Should only accept POST
        body: "",
        headers: newHttpHeaders()
      )
      
      var responseCode: HttpCode
      
      proc mockRespond(code: HttpCode, body: string, headers: HttpHeaders) {.async.} =
        responseCode = code
      
      req.respond = mockRespond
      
      await transport.handleHttpRequest(req)
      
      check responseCode == Http405
    
    waitFor testInvalidMethod()
    
  test "Handle Missing JSON-RPC Method":
    let config = single_config.newConfig()
    let mcpServer = waitFor single_server.newMcpServer(config)
    let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
    
    proc testMissingMethod() {.async.} =
      let req = Request(
        reqMethod: HttpPost,
        body: $(%*{
          "jsonrpc": "2.0",
          "id": 1
          # Missing "method" field
        }),
        headers: newHttpHeaders()
      )
      
      var responseCode: HttpCode
      
      proc mockRespond(code: HttpCode, body: string, headers: HttpHeaders) {.async.} =
        responseCode = code
      
      req.respond = mockRespond
      
      await transport.handleHttpRequest(req)
      
      check responseCode == Http400
    
    waitFor testMissingMethod()
    
  test "Handle Unknown JSON-RPC Method":
    let config = single_config.newConfig()
    let mcpServer = waitFor single_server.newMcpServer(config)
    let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
    
    proc testUnknownMethod() {.async.} =
      let req = Request(
        reqMethod: HttpPost,
        body: $(%*{
          "jsonrpc": "2.0",
          "method": "unknown/method",
          "id": 1
        }),
        headers: newHttpHeaders()
      )
      
      var responseCode: HttpCode
      var responseBody: string
      
      proc mockRespond(code: HttpCode, body: string, headers: HttpHeaders) {.async.} =
        responseCode = code
        responseBody = body
      
      req.respond = mockRespond
      
      await transport.handleHttpRequest(req)
      
      check responseCode == Http200
      let response = parseJson(responseBody)
      check response.hasKey("error")
      check response["error"]["code"].getInt() == -32601  # Method not found
    
    waitFor testUnknownMethod()
    
  test "Handle tools/call Without Name":
    let config = single_config.newConfig()
    let mcpServer = waitFor single_server.newMcpServer(config)
    let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
    
    proc testToolsCallNoName() {.async.} =
      let req = Request(
        reqMethod: HttpPost,
        body: $(%*{
          "jsonrpc": "2.0",
          "method": "tools/call",
          "params": {
            # Missing "name" field
            "arguments": {}
          },
          "id": 1
        }),
        headers: newHttpHeaders()
      )
      
      var responseBody: string
      
      proc mockRespond(code: HttpCode, body: string, headers: HttpHeaders) {.async.} =
        responseBody = body
      
      req.respond = mockRespond
      
      await transport.handleHttpRequest(req)
      
      let response = parseJson(responseBody)
      check response.hasKey("error")
      check response["error"]["message"].getStr().contains("missing 'name'")
    
    waitFor testToolsCallNoName()
    
  test "Handle Exception During Request":
    let config = single_config.newConfig()
    let mcpServer = waitFor single_server.newMcpServer(config)
    let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
    
    proc testException() {.async.} =
      # Create a request that will cause an exception
      let req = Request(
        reqMethod: HttpPost,
        body: "{ malformed json",
        headers: newHttpHeaders()
      )
      
      var responseCode: HttpCode
      
      proc mockRespond(code: HttpCode, body: string, headers: HttpHeaders) {.async.} =
        responseCode = code
      
      req.respond = mockRespond
      
      await transport.handleHttpRequest(req)
      
      check responseCode == Http400  # Bad request due to invalid JSON
    
    waitFor testException()

suite "Port Management Edge Cases":
  test "Port at Upper Bound":
    # Test with maximum valid port
    check not isPortInUse(65535, "127.0.0.1")
    
  test "Find Available Port - No Ports Available":
    # Test when starting from a high port number
    let port = findAvailablePort(65400, "127.0.0.1")
    check port >= 65400
    check port <= 65500  # Should find something in range
    
  test "Invalid Host Address":
    # Test with invalid host
    check not isPortInUse(8080, "999.999.999.999")

suite "PID File Edge Cases":
  test "PID File With No Colon":
    let testPort = 9100
    let pidFile = getPidFilePath(testPort)
    
    # Write PID file without colon separator
    writeFile(pidFile, "12345")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 0  # Should fail to parse
    check port == 0
    
    cleanupPidFile(testPort)
    
  test "PID File With Multiple Colons":
    let testPort = 9101
    let pidFile = getPidFilePath(testPort)
    
    # Write PID file with multiple colons
    writeFile(pidFile, "12345:9101:extra")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 12345  # Should parse first two parts
    check port == 9101
    
    cleanupPidFile(testPort)
    
  test "PID File With Non-Numeric Content":
    let testPort = 9102
    let pidFile = getPidFilePath(testPort)
    
    # Write PID file with non-numeric content
    writeFile(pidFile, "abc:def")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 0  # Should fail to parse
    check port == 0
    
    cleanupPidFile(testPort)
    
  test "Empty PID File":
    let testPort = 9103
    let pidFile = getPidFilePath(testPort)
    
    # Write empty PID file
    writeFile(pidFile, "")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 0
    check port == 0
    
    cleanupPidFile(testPort)
    
  test "Very Large PID":
    let testPort = 9104
    let pidFile = getPidFilePath(testPort)
    
    # Write PID file with very large PID
    writeFile(pidFile, "999999999:9104")
    
    let (pid, port) = readPidFile(testPort)
    check pid == 999999999
    check port == 9104
    
    cleanupPidFile(testPort)

suite "Process Management Edge Cases":
  test "Kill Signal Error Handling":
    # Test handling of kill signal errors
    when not defined(windows):
      # Try to send signal to non-existent process
      let result = kill(Pid(99999), SIGTERM)
      check result != 0  # Should fail
      
  test "Negative PID Handling":
    check not isProcessRunning(-1)
    check not isProcessRunning(-100)
    
  test "Zero PID Handling":
    check not isProcessRunning(0)

suite "HTTP Server Start Edge Cases":
  test "Start Server - Port Already Failed":
    proc testFailedStart() {.async.} =
      let config = single_config.newConfig()
      let mcpServer = waitFor single_server.newMcpServer(config)
      
      # Create transport with impossible port range
      let transport = newHttpTransport("127.0.0.1", 70000, mcpServer.baseServer)  # Invalid port
      
      await transport.start()
      check not transport.startCalled  # Should fail to start
    
    waitFor testFailedStart()
    
  test "Multiple Transport Stop":
    proc testMultipleStop() {.async.} =
      let config = single_config.newConfig()
      let mcpServer = waitFor single_server.newMcpServer(config)
      let transport = newHttpTransport("127.0.0.1", 8080, mcpServer.baseServer)
      
      # Stop multiple times should be safe
      await transport.stop()
      await transport.stop()
      await transport.stop()
      
      check transport.stopCalled
    
    waitFor testMultipleStop()