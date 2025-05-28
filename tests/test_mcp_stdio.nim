#!/usr/bin/env nim

import std/[asyncdispatch, json, osproc, streams, strutils]

# MCP Initialize request
let initRequest = %*{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {
      "name": "test-client",
      "version": "1.0.0"
    }
  },
  "id": 1
}

proc testMcpServer() {.async.} =
  echo "Testing MCP Server with stdio transport..."
  
  # Start the MCP server with stdio transport
  let process = startProcess("./mcp_jujutsu", args = ["--stdio"], options = {poUsePath, poStdErrToStdOut})
  
  # Give server time to start
  await sleepAsync(1000)
  
  # Get input/output streams
  let input = process.inputStream
  let output = process.outputStream
  
  # Send initialize request
  let requestStr = $initRequest & "\n"
  echo "Sending initialize request:"
  echo requestStr
  
  input.write(requestStr)
  input.flush()
  
  # Read response
  echo "\nWaiting for response..."
  var response = ""
  
  # Read with timeout
  for i in 0..10:
    if output.atEnd:
      await sleepAsync(100)
    else:
      response = output.readLine()
      break
  
  if response.len > 0:
    echo "Received response:"
    echo response
    
    # Try to parse as JSON
    try:
      let jsonResponse = parseJson(response)
      echo "\nParsed response:"
      echo jsonResponse.pretty()
      
      # Check if it's a valid MCP response
      if jsonResponse.hasKey("jsonrpc") and jsonResponse["jsonrpc"].getStr() == "2.0":
        if jsonResponse.hasKey("result"):
          echo "\n✅ Server responded correctly with MCP protocol!"
          echo "Server info:", jsonResponse["result"].pretty()
        elif jsonResponse.hasKey("error"):
          echo "\n❌ Server returned an error:", jsonResponse["error"].pretty()
        else:
          echo "\n⚠️  Unexpected response format"
    except:
      echo "\n❌ Failed to parse response as JSON"
  else:
    echo "\n❌ No response received from server"
  
  # Clean up
  process.terminate()
  process.close()

when isMainModule:
  waitFor testMcpServer()