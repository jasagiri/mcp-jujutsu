## Single repository MCP server
##
## This module implements the MCP server for single repository mode using composition.

import std/[asyncdispatch, json, options, strutils, tables, sets, sequtils]
import ../../core/config/config
import ../../core/mcp/server as base_server
import ../../core/repository/jujutsu
import ../tools/semantic_divide
import ../analyzer/semantic

type
  SingleRepoServer* = ref object
    # Composition: contains a base server instead of inheriting from it
    baseServer*: base_server.McpServer
    jjRepo*: jujutsu.JujutsuRepo

proc newMcpServer*(config: Config): Future[SingleRepoServer] {.async.} =
  ## Creates a new single repository MCP server
  result = SingleRepoServer(
    baseServer: base_server.newMcpServer(config)
  )
  
  # Initialize repository connection
  try:
    result.jjRepo = await jujutsu.initJujutsuRepo(config.repoPath)
  except Exception as e:
    # Repository will be initialized later or on-demand
    echo "Warning: Could not initialize repository at " & config.repoPath & ": " & e.msg
    # Will attempt to connect to repository when needed

# Delegate common methods to the base server
proc registerTool*(server: SingleRepoServer, name: string, handler: base_server.ToolHandler) =
  ## Delegates tool registration to the base server
  server.baseServer.registerTool(name, handler)

proc registerResourceType*(server: SingleRepoServer, resourceType: string, handler: base_server.ResourceHandler) =
  ## Delegates resource registration to the base server
  server.baseServer.registerResourceType(resourceType, handler)

proc addTransport*(server: SingleRepoServer, transport: base_server.Transport) =
  ## Delegates transport addition to the base server
  server.baseServer.addTransport(transport)

# Single repository specific methods
proc registerSingleRepoTools*(server: SingleRepoServer) =
  ## Registers single repository tools
  server.registerTool("analyzeCommitRange", semantic_divide.analyzeCommitRangeTool)
  server.registerTool("proposeCommitDivision", semantic_divide.proposeCommitDivisionTool)
  server.registerTool("executeCommitDivision", semantic_divide.executeCommitDivisionTool)
  server.registerTool("automateCommitDivision", semantic_divide.automateCommitDivisionTool)

proc createJujutsuRepoHandler(): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    var repoPath = params["path"].getStr
    
    try:
      let repo = await jujutsu.initJujutsuRepo(repoPath)
      return %*{
        "id": id,
        "type": "jujutsuRepo",
        "path": repoPath,
        "status": "initialized"
      }
    except Exception as e:
      return %*{
        "error": {
          "code": -32000,
          "message": "Failed to initialize repository: " & e.msg
        }
      }

proc createCommitDiffHandler(server: SingleRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    if not params.hasKey("commitRange"):
      return %*{"error": "Missing required 'commitRange' parameter"}
    
    let commitRange = params["commitRange"].getStr
    
    # Ensure we have a repository connection
    if server.jjRepo == nil:
      try:
        if params.hasKey("repoPath"):
          server.jjRepo = await jujutsu.initJujutsuRepo(params["repoPath"].getStr)
        else:
          return %*{"error": "No repository connection and no 'repoPath' provided"}
      except Exception as e:
        return %*{"error": "Failed to initialize repository: " & e.msg}
    
    # Get actual diff from the repository
    try:
      let diffResult = await server.jjRepo.getDiffForCommitRange(commitRange)
      
      # Convert to resource response
      var filesJson = newJArray()
      for file in diffResult.files:
        filesJson.add(%*{
          "path": file.path,
          "changeType": file.changeType,
          "diff": file.diff
        })
      
      return %*{
        "id": id,
        "type": "commitDiff",
        "commitRange": commitRange,
        "files": filesJson,
        "stats": diffResult.stats,
        "status": "complete"
      }
    except Exception as e:
      return %*{"error": "Failed to get diff: " & e.msg}
    

proc createCommitAnalysisHandler(server: SingleRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    # Validate parameters
    if not params.hasKey("diffId") and not params.hasKey("commitRange"):
      return %*{"error": "Missing required parameters. Either 'diffId' or 'commitRange' must be provided"}
    
    var diffResult: jujutsu.DiffResult
    
    # Get diff information from either diffId or commitRange
    if params.hasKey("diffId"):
      let diffId = params["diffId"].getStr
      
      # Check if we have a stored diff for this ID
      # In a real implementation, retrieve from storage
      # For now, we'll create a simplified diff
      diffResult = jujutsu.DiffResult(
        commitRange: "HEAD~1..HEAD",
        files: @[] # We'll fetch the actual files below
      )
    elif params.hasKey("commitRange"):
      let commitRange = params["commitRange"].getStr
      
      try:
        # Get actual diff data from repository 
        diffResult = await server.jjRepo.getDiffForCommitRange(commitRange)
      except Exception as e:
        return %*{"error": "Failed to get diff for commit range: " & e.msg}
    
    # If no files were found, return an empty analysis
    if diffResult.files.len == 0:
      return %*{
        "id": id,
        "type": "commitAnalysis",
        "diffId": if params.hasKey("diffId"): params["diffId"].getStr else: "",
        "commitRange": if params.hasKey("commitRange"): params["commitRange"].getStr else: "",
        "analysis": %*{
          "semanticUnits": [],
          "overallConfidence": 0.0
        },
        "status": "complete"
      }
    
    # Perform semantic analysis
    try:
      # Get patterns from semantic analyzer  
      let patterns = await semantic.identifySemanticBoundaries(diffResult)
      let analysis = await semantic.analyzeChanges(diffResult)
      
      # Convert patterns to semantic units for response
      var semanticUnits = newJArray()
      var totalConfidence = 0.0
      
      for pattern in patterns:
        var files = newJArray()
        
        for filePath in pattern.files:
          var reason = "Part of " & pattern.pattern
          
          # Add more specific reasons based on keywords
          if pattern.keywords.len > 0:
            let keywords = toSeq(pattern.keywords)
            if keywords.len > 3:
              reason &= " with related components: " & keywords[0..2].join(", ")
          
          files.add(%*{
            "path": filePath,
            "reason": reason
          })
        
        # Convert change type to type string
        var typeStr = "chore"
        case pattern.changeType
        of semantic.ctFeature:
          typeStr = "feat"
        of semantic.ctBugfix:
          typeStr = "fix"
        of semantic.ctRefactor:
          typeStr = "refactor"
        of semantic.ctDocs:
          typeStr = "docs"
        of semantic.ctTests:
          typeStr = "test"
        of semantic.ctStyle:
          typeStr = "style"
        of semantic.ctPerformance:
          typeStr = "perf"
        of semantic.ctChore:
          typeStr = "chore"
        
        semanticUnits.add(%*{
          "name": pattern.pattern,
          "type": typeStr,
          "files": files,
          "confidence": pattern.confidence,
          "keywords": toSeq(pattern.keywords)
        })
        
        totalConfidence += pattern.confidence
      
      # Calculate overall confidence
      let overallConfidence = if patterns.len > 0: totalConfidence / patterns.len.float else: 0.0
      
      # Create final analysis result
      let analysisResult = %*{
        "semanticUnits": semanticUnits,
        "overallConfidence": overallConfidence,
        "stats": {
          "additions": analysis.additions,
          "deletions": analysis.deletions,
          "totalFiles": analysis.files.len,
          "fileTypes": analysis.fileTypes,
          "changeTypes": analysis.changeTypes,
          "codePatterns": analysis.codePatterns
        }
      }
      
      return %*{
        "id": id,
        "type": "commitAnalysis",
        "diffId": if params.hasKey("diffId"): params["diffId"].getStr else: "",
        "commitRange": if params.hasKey("commitRange"): params["commitRange"].getStr else: "",
        "analysis": analysisResult,
        "status": "complete"
      }
    except Exception as e:
      return %*{"error": "Failed to perform semantic analysis: " & e.msg}

proc createCommitHistoryHandler(server: SingleRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    # Default values
    var limit = 10
    var branch = "@"
    
    # Override with params if provided
    if params.hasKey("limit") and params["limit"].kind == JInt:
      limit = params["limit"].getInt
    
    if params.hasKey("branch") and params["branch"].kind == JString:
      branch = params["branch"].getStr
      
    # Ensure we have a repository connection
    if server.jjRepo == nil:
      try:
        if params.hasKey("repoPath"):
          server.jjRepo = await jujutsu.initJujutsuRepo(params["repoPath"].getStr)
        else:
          return %*{"error": "No repository connection and no 'repoPath' provided"}
      except Exception as e:
        return %*{"error": "Failed to initialize repository: " & e.msg}
    
    # Get commit history
    try:
      let commits = await server.jjRepo.getCommitHistory(limit, branch)
      
      # Convert to resource response
      var commitsJson = newJArray()
      for commit in commits:
        commitsJson.add(%*{
          "id": commit.id,
          "author": commit.author,
          "timestamp": commit.timestamp,
          "message": commit.message
        })
      
      return %*{
        "id": id,
        "type": "commitHistory",
        "branch": branch,
        "limit": limit,
        "commits": commitsJson,
        "status": "complete"
      }
    except Exception as e:
      return %*{"error": "Failed to get commit history: " & e.msg}

proc registerSingleRepoResources*(server: SingleRepoServer) =
  ## Registers single repository resource types
  server.registerResourceType("jujutsuRepo", createJujutsuRepoHandler())
  server.registerResourceType("commitDiff", createCommitDiffHandler(server))
  server.registerResourceType("commitAnalysis", createCommitAnalysisHandler(server))
  server.registerResourceType("commitHistory", createCommitHistoryHandler(server))

# Delegated MCP protocol methods
proc handleInitialize*(server: SingleRepoServer, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates initialize handling to the base server
  return await server.baseServer.handleInitialize(params)

proc handleShutdown*(server: SingleRepoServer): Future[void] {.async.} =
  ## Delegates shutdown handling to the base server
  await server.baseServer.handleShutdown()

proc handleToolCall*(server: SingleRepoServer, toolName: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates tool call handling to the base server
  return await server.baseServer.handleToolCall(toolName, params)

proc handleResourceRequest*(server: SingleRepoServer, resourceType: string, id: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates resource request handling to the base server
  return await server.baseServer.handleResourceRequest(resourceType, id, params)

proc start*(server: SingleRepoServer): Future[void] {.async.} =
  ## Starts the single repository server
  # Register single repository components
  server.registerSingleRepoTools()
  server.registerSingleRepoResources()
  
  # Start the base server
  await server.baseServer.start()