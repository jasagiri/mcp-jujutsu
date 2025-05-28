#!/usr/bin/env nim

import std/[asyncdispatch, json, osproc, streams, strutils]

proc formatJsonRpcMessage(msg: JsonNode): string =
  ## Format a JSON-RPC message with proper headers for stdio transport
  let content = $msg
  result = "Content-Length: " & $content.len & "\r\n\r\n" & content

proc parseJsonRpcMessage(input: Stream): (bool, JsonNode) =
  ## Parse a JSON-RPC message from stdio
  var contentLength = -1
  
  # Read headers
  while true:
    let line = input.readLine()
    if line == "":
      break
    if line.startsWith("Content-Length:"):
      let parts = line.split(":")
      if parts.len == 2:
        contentLength = parseInt(parts[1].strip())
  
  if contentLength == -1:
    return (false, newJNull())
  
  # Read content
  let content = input.readStr(contentLength)
  try:
    return (true, parseJson(content))
  except:
    return (false, newJNull())

proc testMcpServer() {.async.} =
  echo "Testing MCP Server with proper JSON-RPC protocol..."
  
  # Build the requests
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
  
  let toolsListRequest = %*{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 2
  }
  
  # Start the MCP server with stdio transport
  echo "Starting MCP server..."
  let process = startProcess("./mcp_jujutsu", args = ["--stdio"], options = {poUsePath})
  
  # Give server time to start
  await sleepAsync(1000)
  
  # Get input/output streams
  let input = process.inputStream
  let output = process.outputStream
  let error = process.errorStream
  
  # Read any startup messages from stderr
  echo "\nServer startup messages:"
  for i in 0..5:
    if not error.atEnd:
      echo "STDERR: ", error.readLine()
    else:
      break
  
  # Send initialize request
  echo "\nSending initialize request..."
  let initMsg = formatJsonRpcMessage(initRequest)
  input.write(initMsg)
  input.flush()
  
  # Wait a bit for response
  await sleepAsync(500)
  
  # Try to read response
  echo "\nReading response..."
  let (success, response) = parseJsonRpcMessage(output)
  
  if success:
    echo "✅ Received valid JSON-RPC response:"
    echo response.pretty()
    
    # Check if it's a valid MCP response
    if response.hasKey("jsonrpc") and response["jsonrpc"].getStr() == "2.0":
      if response.hasKey("result"):
        echo "\n✅ Server responded correctly with MCP protocol!"
        
        # Send tools list request
        echo "\nSending tools/list request..."
        let toolsMsg = formatJsonRpcMessage(toolsListRequest)
        input.write(toolsMsg)
        input.flush()
        
        await sleepAsync(500)
        
        let (success2, response2) = parseJsonRpcMessage(output)
        if success2:
          echo "✅ Received tools list response:"
          echo response2.pretty()
      elif response.hasKey("error"):
        echo "\n❌ Server returned an error:", response["error"].pretty()
    else:
      echo "\n⚠️  Response is not valid JSON-RPC 2.0"
  else:
    echo "\n❌ Failed to parse response as JSON-RPC message"
    
    # Try to read raw output
    echo "\nRaw output from server:"
    for i in 0..10:
      if not output.atEnd:
        echo output.readLine()
      else:
        break
  
  # Check for any error messages
  echo "\nChecking for error messages..."
  for i in 0..5:
    if not error.atEnd:
      echo "STDERR: ", error.readLine()
    else:
      break
  
  # Clean up
  process.terminate()
  process.close()

when isMainModule:
  waitFor testMcpServer()