## MCP Client for Semantic Divide Jujutsu Tool
##
## This module provides a client implementation for connecting to the MCP server
## for semantic commit division in Jujutsu repositories.

import std/[asyncdispatch, httpclient, json, options, os, strutils, uri]

type
  McpClient* = ref object
    ## Client for interacting with MCP-Jujutsu server
    baseUrl*: string           ## Base URL of the MCP server
    httpClient*: AsyncHttpClient  ## HTTP client for making requests
    
  McpError* = object of CatchableError
    ## Exception raised when MCP operations fail

proc newMcpClient*(baseUrl: string = "http://localhost:8080/mcp"): McpClient =
  ## Creates a new MCP client connected to the specified endpoint
  result = McpClient(
    baseUrl: baseUrl,
    httpClient: newAsyncHttpClient()
  )

proc callTool*(client: McpClient, methodName: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Calls an MCP tool method with the given parameters
  let payload = %*{
    "jsonrpc": "2.0",
    "method": methodName,
    "params": params,
    "id": 1
  }
  
  let headers = newHttpHeaders([
    ("Content-Type", "application/json")
  ])
  
  try:
    let response = await client.httpClient.request(
      client.baseUrl,
      httpMethod = HttpPost,
      body = $payload,
      headers = headers
    )
    
    let responseBody = await response.body
    let jsonResponse = parseJson(responseBody)
    
    if jsonResponse.hasKey("error"):
      let errorObj = jsonResponse["error"]
      raise newException(McpError, errorObj["message"].getStr())
    
    return jsonResponse["result"]
  except Exception as e:
    raise newException(McpError, "Error calling MCP tool: " & e.msg)

proc analyzeCommitRange*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
  ## Analyzes a commit range to identify logical boundaries
  let params = %*{
    "repoPath": repoPath,
    "commitRange": commitRange
  }
  
  return await client.callTool("analyzeCommitRange", params)

proc proposeCommitDivision*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
  ## Proposes a semantic division of a commit range
  let params = %*{
    "repoPath": repoPath,
    "commitRange": commitRange
  }
  
  return await client.callTool("proposeCommitDivision", params)

proc executeCommitDivision*(client: McpClient, repoPath: string, proposal: JsonNode): Future[JsonNode] {.async.} =
  ## Executes a commit division based on a proposal
  let params = %*{
    "repoPath": repoPath,
    "proposal": proposal
  }
  
  return await client.callTool("executeCommitDivision", params)

proc automateCommitDivision*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
  ## Automates the entire commit division process
  let params = %*{
    "repoPath": repoPath,
    "commitRange": commitRange
  }
  
  return await client.callTool("automateCommitDivision", params)