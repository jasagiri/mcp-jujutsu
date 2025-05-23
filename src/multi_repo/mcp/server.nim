## Multi repository MCP server
##
## This module implements the MCP server for multi repository mode using composition.

import std/[asyncdispatch, json, options, strutils, tables]
import ../../core/config/config
import ../../core/mcp/server as base_server
import ../../core/repository/jujutsu
import ../repository/manager
import ../analyzer/cross_repo
import ../tools/multi_repo

type
  MultiRepoServer* = ref object
    # Composition: contains a base server instead of inheriting from it
    baseServer*: base_server.McpServer
    repoManager*: RepositoryManager

proc newMcpServer*(config: Config): Future[MultiRepoServer] {.async.} =
  ## Creates a new multi repository MCP server
  result = MultiRepoServer(
    baseServer: base_server.newMcpServer(config)
  )
  
  # Initialize repository manager
  try:
    result.repoManager = await loadRepositoryConfig(config.repoConfigPath)
  except:
    # Default empty repository manager
    result.repoManager = newRepositoryManager(config.reposDir)

# Delegate common methods to the base server
proc registerTool*(server: MultiRepoServer, name: string, handler: base_server.ToolHandler) =
  ## Delegates tool registration to the base server
  server.baseServer.registerTool(name, handler)

proc registerResourceType*(server: MultiRepoServer, resourceType: string, handler: base_server.ResourceHandler) =
  ## Delegates resource registration to the base server
  server.baseServer.registerResourceType(resourceType, handler)

proc addTransport*(server: MultiRepoServer, transport: base_server.Transport) =
  ## Delegates transport addition to the base server
  server.baseServer.addTransport(transport)

# Multi repository specific methods
proc registerMultiRepoTools*(server: MultiRepoServer) =
  ## Registers multi repository tools
  server.registerTool("analyzeMultiRepoCommits", multi_repo.analyzeMultiRepoCommitsTool)
  server.registerTool("proposeMultiRepoSplit", multi_repo.proposeMultiRepoSplitTool)
  server.registerTool("executeMultiRepoSplit", multi_repo.executeMultiRepoSplitTool)
  server.registerTool("automateMultiRepoSplit", multi_repo.automateMultiRepoSplitTool)

proc createRepoGroupHandler(server: MultiRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    if not params.hasKey("repositories"):
      return %*{"error": "Missing 'repositories' parameter"}
    
    var reposList: seq[JsonNode] = @[]
    var validatedRepos: seq[JsonNode] = @[]
    
    # Process each repository in the list
    for repoNode in params["repositories"]:
      reposList.add(repoNode)
      
      # Validate repository if it has a name
      if repoNode.hasKey("name"):
        let repoName = repoNode["name"].getStr
        
        try:
          let isValid = await server.repoManager.validateRepository(repoName)
          if isValid:
            # Get repository info
            let repoOpt = server.repoManager.getRepository(repoName)
            if repoOpt.isSome:
              let repo = repoOpt.get
              validatedRepos.add(%*{
                "name": repo.name,
                "path": repo.path,
                "status": "valid"
              })
            else:
              validatedRepos.add(%*{
                "name": repoName,
                "status": "unknown"
              })
          else:
            validatedRepos.add(%*{
              "name": repoName,
              "status": "invalid"
            })
        except Exception as e:
          validatedRepos.add(%*{
            "name": repoName,
            "status": "error",
            "error": e.msg
          })
    
    return %*{
      "id": id,
      "type": "repoGroup",
      "repositories": reposList,
      "validated": validatedRepos,
      "status": "created"
    }

proc createRepoCommitHandler(server: MultiRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    if not params.hasKey("repoId") or not params.hasKey("commitId"):
      return %*{"error": "Missing required parameters"}
    
    let repoId = params["repoId"].getStr
    let commitId = params["commitId"].getStr
    
    # Get the repository from the manager
    let repoOpt = server.repoManager.getRepository(repoId)
    if repoOpt.isNone:
      return %*{"error": "Repository not found: " & repoId}
    
    let repo = repoOpt.get
    
    # Try to get commit info from the repository
    try:
      let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
      let commitInfo = await jjRepo.getCommitInfo(commitId)
      
      # Get the files modified in this commit
      let files = await jjRepo.getCommitFiles(commitId)
      var filesJson = newJArray()
      for file in files:
        filesJson.add(%*file)
      
      return %*{
        "id": id,
        "type": "repoCommit",
        "repoId": repoId,
        "commitId": commitId,
        "author": commitInfo.author,
        "timestamp": commitInfo.timestamp,
        "message": commitInfo.message,
        "files": filesJson,
        "status": "complete"
      }
    except Exception as e:
      return %*{
        "error": "Failed to get commit info: " & e.msg
      }
    

proc createCrossRepoDiffHandler(server: MultiRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    if not params.hasKey("repoGroupId") or not params.hasKey("commitRange"):
      return %*{"error": "Missing required parameters"}
    
    let repoGroupId = params["repoGroupId"].getStr
    let commitRange = params["commitRange"].getStr
    
    # In a full implementation, we would:
    # 1. Retrieve the repository group resource
    # 2. For each repository, get the diff for the given commit range
    # 3. Analyze the cross-repo dependencies
    
    # For now, create a simplified response with mock data
    var changesJson = %*{}
    var reposJson = newJArray()
    
    # Add a couple of mock repositories to the response
    reposJson.add(%*{"name": "repo1", "path": "/path/to/repo1"})
    reposJson.add(%*{"name": "repo2", "path": "/path/to/repo2"})
    
    # Add mock changes
    changesJson["repo1"] = %*[
      {
        "path": "src/feature.nim",
        "changeType": "add",
        "diff": "+import repo2/module"
      }
    ]
    changesJson["repo2"] = %*[
      {
        "path": "src/module.nim",
        "changeType": "modify",
        "diff": "+proc newAPI() =\n-proc oldAPI() ="
      }
    ]
    
    return %*{
      "id": id,
      "type": "crossRepoDiff",
      "repoGroupId": repoGroupId,
      "commitRange": commitRange,
      "repositories": reposJson,
      "changes": changesJson,
      "status": "complete"
    }

proc createDependencyGraphHandler(server: MultiRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    # Get the dependency graph from the repository manager
    let dependencyGraph = server.repoManager.getDependencyGraph()
    
    # Convert to JSON
    var graphJson = %*{}
    for repo, deps in dependencyGraph:
      var depsJson = newJArray()
      for dep in deps:
        depsJson.add(%*dep)
      graphJson[repo] = depsJson
    
    # Check if we need to validate dependencies
    var isValid = true
    if params.hasKey("validate") and params["validate"].getBool():
      isValid = await server.repoManager.validateDependencies()
    
    return %*{
      "id": id,
      "type": "dependencyGraph",
      "graph": graphJson,
      "isValid": isValid,
      "status": "complete"
    }

proc createCrossDependencyAnalysisHandler(server: MultiRepoServer): base_server.ResourceHandler =
  result = proc(id: string, params: JsonNode): Future[JsonNode] {.async.} =
    if not params.hasKey("diffId"):
      return %*{"error": "Missing required 'diffId' parameter"}
    
    let diffId = params["diffId"].getStr
    
    # In a full implementation, would retrieve the cross-repo diff resource
    # and analyze the dependencies between repositories
    
    # For now, return a simplified mock analysis
    let dependenciesJson = newJArray()
    dependenciesJson.add(%*{
      "source": "repo1",
      "target": "repo2",
      "type": "import",
      "confidence": 0.95,
      "locations": [
        {"file": "src/feature.nim", "line": 5}
      ]
    })
    
    dependenciesJson.add(%*{
      "source": "repo2",
      "target": "repo1",
      "type": "reference",
      "confidence": 0.75,
      "locations": [
        {"file": "README.md", "line": 12}
      ]
    })
    
    return %*{
      "id": id,
      "type": "crossDependencyAnalysis",
      "diffId": diffId,
      "dependencies": dependenciesJson,
      "status": "complete"
    }

proc registerMultiRepoResources*(server: MultiRepoServer) =
  ## Registers multi repository resource types
  server.registerResourceType("repoGroup", createRepoGroupHandler(server))
  server.registerResourceType("repoCommit", createRepoCommitHandler(server))
  server.registerResourceType("crossRepoDiff", createCrossRepoDiffHandler(server))
  server.registerResourceType("dependencyGraph", createDependencyGraphHandler(server))
  server.registerResourceType("crossDependencyAnalysis", createCrossDependencyAnalysisHandler(server))

# Delegated MCP protocol methods
proc handleInitialize*(server: MultiRepoServer, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates initialize handling to the base server
  return await server.baseServer.handleInitialize(params)

proc handleShutdown*(server: MultiRepoServer): Future[void] {.async.} =
  ## Delegates shutdown handling to the base server
  await server.baseServer.handleShutdown()

proc handleToolCall*(server: MultiRepoServer, toolName: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates tool call handling to the base server
  return await server.baseServer.handleToolCall(toolName, params)

proc handleResourceRequest*(server: MultiRepoServer, resourceType: string, id: string, params: JsonNode): Future[JsonNode] {.async.} =
  ## Delegates resource request handling to the base server
  return await server.baseServer.handleResourceRequest(resourceType, id, params)

proc start*(server: MultiRepoServer): Future[void] {.async.} =
  ## Starts the multi repository server
  # Register multi repository components
  server.registerMultiRepoTools()
  server.registerMultiRepoResources()
  
  # Start the base server
  await server.baseServer.start()