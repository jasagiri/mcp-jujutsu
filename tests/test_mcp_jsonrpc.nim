## Simple MCP JSON-RPC tests

import unittest, json

suite "MCP JSON-RPC Tests":
  
  test "JSON-RPC Message Format":
    ## Test basic JSON-RPC message structure
    let msg = %*{
      "jsonrpc": "2.0",
      "method": "initialize",
      "id": 1,
      "params": {}
    }
    
    check msg["jsonrpc"].getStr() == "2.0"
    check msg["method"].getStr() == "initialize"
    check msg["id"].getInt() == 1
    check msg.hasKey("params")
    
  test "JSON-RPC Response Format":
    ## Test JSON-RPC response structure
    let response = %*{
      "jsonrpc": "2.0",
      "result": {
        "capabilities": {}
      },
      "id": 1
    }
    
    check response["jsonrpc"].getStr() == "2.0"
    check response.hasKey("result")
    check response["id"].getInt() == 1
    
  test "JSON-RPC Error Format":
    ## Test JSON-RPC error structure
    let error = %*{
      "jsonrpc": "2.0",
      "error": {
        "code": -32600,
        "message": "Invalid Request"
      },
      "id": 1
    }
    
    check error["jsonrpc"].getStr() == "2.0"
    check error.hasKey("error")
    check error["error"]["code"].getInt() == -32600

echo "✅ MCP JSON-RPC tests completed"