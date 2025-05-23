## Multi-repository tools module
##
## This module implements multi-repository tools for MCP.

import std/[asyncdispatch, json, options, sets, strutils, tables, os]
import ../repository/manager as repo_manager
import ../analyzer/cross_repo
import ../../core/repository/jujutsu
import ../../core/logging/logger

# Import types from cross_repo
type
  CommitInfo = cross_repo.CommitInfo
  FileChange = cross_repo.FileChange

proc analyzeMultiRepoCommitsTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## Analyzes commits across multiple repositories
  # Extract parameters
  let repoPath = if params.hasKey("reposDir"): params["reposDir"].getStr else: getCurrentDir()
  let configPath = if params.hasKey("configPath"): params["configPath"].getStr else: repoPath / "repos.json"
  let commitRange = params["commitRange"].getStr
  var repoNames: seq[string] = @[]
  
  if params.hasKey("repositories") and params["repositories"].kind == JArray:
    for repoJson in params["repositories"]:
      repoNames.add(repoJson["name"].getStr)
  
  # Create a context for logging
  let ctx = newLogContext("multi-repo", "analyzeMultiRepoCommits")
    .withMetadata("repoPath", repoPath)
    .withMetadata("configPath", configPath)
    .withMetadata("commitRange", commitRange)

  debug("Loading repository configuration", ctx)
  
  # Load repository manager
  let manager = try:
    await loadRepositoryConfig(configPath)
  except Exception as e:
    logException(e, "Failed to load repository configuration", ctx)
    return %*{
      "error": {
        "code": -32603,
        "message": "Failed to load repository configuration: " & e.msg
      }
    }
  
  # If no repositories specified, use all
  if repoNames.len == 0:
    debug("No repositories specified, using all repositories", ctx)
    for repoName in manager.repos.keys:
      repoNames.add(repoName)
  
  let analysisCtx = ctx.withMetadata("repositories", $repoNames.len)
  info("Analyzing repositories: " & repoNames.join(", "), analysisCtx)
  
  # Analyze repositories
  let diff = try:
    await analyzeCrossRepoChanges(manager, repoNames, commitRange)
  except Exception as e:
    logException(e, "Failed to analyze repositories", analysisCtx)
    return %*{
      "error": {
        "code": -32603,
        "message": "Failed to analyze repositories: " & e.msg
      }
    }
  
  debug("Identifying cross-repository dependencies", analysisCtx)
  
  # Analyze dependencies
  let dependencies = try:
    await identifyCrossRepoDependencies(diff)
  except Exception as e:
    logException(e, "Failed to identify dependencies", analysisCtx)
    return %*{
      "error": {
        "code": -32603,
        "message": "Failed to identify dependencies: " & e.msg
      }
    }
  
  # Prepare response
  debug("Preparing analysis response", ctx)
  
  var result = %*{
    "analysis": {
      "repositories": [],
      "dependencies": []
    }
  }
  
  try:
    # Add repository data
    for repoName, files in diff.changes:
      var stats = %*{
        "name": repoName,
        "changes": {
          "files": files.len,
          "additions": 0,
          "deletions": 0
        }
      }
      
      # Count additions and deletions
      var additions = 0
      var deletions = 0
      
      for file in files:
        for line in file.diff.splitLines():
          if line.startsWith("+") and not line.startsWith("+++"):
            additions += 1
          elif line.startsWith("-") and not line.startsWith("---"):
            deletions += 1
      
      stats["changes"]["additions"] = %additions
      stats["changes"]["deletions"] = %deletions
      
      result["analysis"]["repositories"].add(stats)
    
    # Add dependency data
    for dependency in dependencies:
      result["analysis"]["dependencies"].add(%*{
        "source": dependency.source,
        "target": dependency.target,
        "type": dependency.dependencyType,
        "confidence": dependency.confidence
      })
    
    info("Analysis completed successfully", ctx
      .withMetadata("repositoryCount", $diff.changes.len)
      .withMetadata("dependencyCount", $dependencies.len))
  except Exception as e:
    logException(e, "Error preparing analysis response", ctx)
    return %*{
      "error": {
        "code": -32603,
        "message": "Error preparing analysis response: " & e.msg
      }
    }
  
  return result

proc proposeMultiRepoSplitTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## Proposes a multi-repository split of commits
  # Extract parameters
  let repoPath = if params.hasKey("reposDir"): params["reposDir"].getStr else: getCurrentDir()
  let configPath = if params.hasKey("configPath"): params["configPath"].getStr else: repoPath / "repos.json"
  let commitRange = params["commitRange"].getStr
  var repoNames: seq[string] = @[]
  
  if params.hasKey("repositories") and params["repositories"].kind == JArray:
    for repoJson in params["repositories"]:
      repoNames.add(repoJson["name"].getStr)
  
  # Load repository manager
  let manager = await loadRepositoryConfig(configPath)
  
  # If no repositories specified, use all
  if repoNames.len == 0:
    for repoName in manager.repos.keys:
      repoNames.add(repoName)
  
  # Analyze repositories
  let diff = await analyzeCrossRepoChanges(manager, repoNames, commitRange)
  
  # Generate proposal
  let proposal = await generateCrossRepoProposal(diff, manager)
  
  # Prepare response
  var result = %*{
    "proposal": {
      "commitGroups": []
    }
  }
  
  # Add commit groups
  for group in proposal.commitGroups:
    var groupJson = %*{
      "name": group.name,
      "description": group.description,
      "commits": []
    }
    
    for commit in group.commits:
      var commitJson = %*{
        "repository": commit.repository,
        "message": commit.message,
        "changes": []
      }
      
      for change in commit.changes:
        commitJson["changes"].add(%*{
          "path": change.path,
          "changeType": change.changeType
        })
      
      groupJson["commits"].add(commitJson)
    
    result["proposal"]["commitGroups"].add(groupJson)
  
  return result

proc executeMultiRepoSplitTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## Executes a multi-repository split of commits
  # Extract parameters
  let repoPath = if params.hasKey("reposDir"): params["reposDir"].getStr else: getCurrentDir()
  let configPath = if params.hasKey("configPath"): params["configPath"].getStr else: repoPath / "repos.json"
  let proposal = params["proposal"]
  
  # Load repository manager
  let manager = await loadRepositoryConfig(configPath)
  
  # Validate proposal structure
  if not proposal.hasKey("commitGroups"):
    return %*{
      "error": {
        "code": -32602,
        "message": "Invalid proposal format: missing commitGroups"
      }
    }
  
  # Get dependency order
  let repoOrder = repo_manager.getDependencyOrder(manager)
  
  # Execute the division
  var commitIds = initTable[string, seq[string]]()
  var error: Option[string] = none(string)
  
  try:
    # Process each group
    for groupJson in proposal["commitGroups"]:
      var groupCommits = initTable[string, JsonNode]()
      
      # Group commits by repository
      for commitJson in groupJson["commits"]:
        let repoName = commitJson["repository"].getStr
        groupCommits[repoName] = commitJson
      
      # Execute commits in dependency order
      for repoName in repoOrder:
        if not groupCommits.hasKey(repoName):
          continue
        
        let commitJson = groupCommits[repoName]
        let repoOpt = manager.getRepository(repoName)
        
        if repoOpt.isNone:
          continue
        
        let repo = repoOpt.get
        let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
        
        let message = commitJson["message"].getStr
        var changes = newSeq[(string, string)]()
        
        for changeJson in commitJson["changes"]:
          changes.add((
            changeJson["path"].getStr,
            ""  # Real implementation would need actual file content
          ))
        
        let commitId = await jjRepo.createCommit(message, changes)
        
        if not commitIds.hasKey(repoName):
          commitIds[repoName] = @[]
        
        commitIds[repoName].add(commitId)
  except Exception as e:
    error = some(e.msg)
  
  # Prepare response
  if error.isSome:
    return %*{
      "error": {
        "code": -32000,
        "message": "Error executing division: " & error.get
      }
    }
  else:
    var result = %*{
      "result": {
        "success": true,
        "commitGroups": []
      }
    }
    
    for idx, groupJson in proposal["commitGroups"].getElems():
      var groupResultJson = %*{
        "name": groupJson["name"],
        "commits": []
      }
      
      for commitJson in groupJson["commits"]:
        let repoName = commitJson["repository"].getStr
        
        if commitIds.hasKey(repoName) and commitIds[repoName].len > idx:
          groupResultJson["commits"].add(%*{
            "repository": repoName,
            "commitId": commitIds[repoName][idx],
            "message": commitJson["message"]
          })
      
      result["result"]["commitGroups"].add(groupResultJson)
    
    return result

proc automateMultiRepoSplitTool*(params: JsonNode): Future[JsonNode] {.async.} =
  ## Automates the entire multi-repository split process
  # Extract parameters
  let repoPath = if params.hasKey("reposDir"): params["reposDir"].getStr else: getCurrentDir()
  let configPath = if params.hasKey("configPath"): params["configPath"].getStr else: repoPath / "repos.json"
  let commitRange = params["commitRange"].getStr
  var repoNames: seq[string] = @[]
  
  if params.hasKey("repositories") and params["repositories"].kind == JArray:
    for repoJson in params["repositories"]:
      repoNames.add(repoJson["name"].getStr)
  
  # Load repository manager
  let manager = await loadRepositoryConfig(configPath)
  
  # If no repositories specified, use all
  if repoNames.len == 0:
    for repoName in manager.repos.keys:
      repoNames.add(repoName)
  
  # Analyze repositories
  let diff = await analyzeCrossRepoChanges(manager, repoNames, commitRange)
  
  # Generate proposal
  let proposal = await generateCrossRepoProposal(diff, manager)
  
  # Get dependency order
  let repoOrder = repo_manager.getDependencyOrder(manager)
  
  # Execute the division
  var commitIds = initTable[string, seq[string]]()
  var error: Option[string] = none(string)
  
  try:
    # Process each group
    for groupIdx, group in proposal.commitGroups:
      var commitsByRepo = initTable[string, CommitInfo]()
      
      for commit in group.commits:
        commitsByRepo[commit.repository] = commit
      
      # Execute commits in dependency order
      for repoName in repoOrder:
        if not commitsByRepo.hasKey(repoName):
          continue
        
        let commit = commitsByRepo[repoName]
        let repoOpt = manager.getRepository(repoName)
        
        if repoOpt.isNone:
          continue
        
        let repo = repoOpt.get
        let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
        
        var changes = newSeq[(string, string)]()
        
        for change in commit.changes:
          changes.add((change.path, ""))  # Real implementation would extract content
        
        let commitId = await jjRepo.createCommit(commit.message, changes)
        
        if not commitIds.hasKey(repoName):
          commitIds[repoName] = @[]
        
        commitIds[repoName].add(commitId)
  except Exception as e:
    error = some(e.msg)
  
  # Prepare response
  if error.isSome:
    return %*{
      "error": {
        "code": -32000,
        "message": "Error executing automated division: " & error.get
      }
    }
  else:
    var result = %*{
      "result": {
        "success": true,
        "commitGroups": [],
        "analysis": {
          "dependencies": []
        }
      }
    }
    
    # Add commit groups to result
    for groupIdx, group in proposal.commitGroups:
      var groupJson = %*{
        "name": group.name,
        "commits": []
      }
      
      for commit in group.commits:
        if commitIds.hasKey(commit.repository) and commitIds[commit.repository].len > groupIdx:
          groupJson["commits"].add(%*{
            "repository": commit.repository,
            "commitId": commitIds[commit.repository][groupIdx],
            "message": commit.message
          })
      
      result["result"]["commitGroups"].add(groupJson)
    
    # Add dependency analysis
    let dependencies = await identifyCrossRepoDependencies(diff)
    
    for dependency in dependencies:
      result["result"]["analysis"]["dependencies"].add(%*{
        "source": dependency.source,
        "target": dependency.target,
        "type": dependency.dependencyType
      })
    
    return result