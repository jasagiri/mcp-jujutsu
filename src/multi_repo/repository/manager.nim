## Repository manager module
##
## This module implements multi-repository management with support for
## dependency-ordered execution and configuration persistence.

import std/[asyncdispatch, json, options, os, strutils, tables]
import parsetoml
import ../../core/repository/jujutsu

type
  Repository* = object
    ## Represents a single repository in a multi-repo setup
    path*: string              ## Absolute or relative path to the repository
    name*: string              ## Unique identifier for the repository
    dependencies*: seq[string] ## List of repository names this one depends on
    
  RepositoryManager* = ref object
    ## Manages multiple repositories and their relationships
    repos*: Table[string, Repository]  ## All managed repositories by name
    rootDir*: string                   ## Root directory containing repositories
    configPath*: string                ## Path to the configuration file

# Forward declarations
proc hasCyclicDependencies(graph: Table[string, seq[string]]): bool

proc newRepositoryManager*(rootDir: string): RepositoryManager =
  ## Creates a new repository manager
  result = RepositoryManager(
    repos: initTable[string, Repository](),
    rootDir: rootDir,
    configPath: ""
  )

proc addRepository*(manager: RepositoryManager, repo: Repository) =
  ## Adds a repository object to the manager
  manager.repos[repo.name] = repo

proc addRepository*(manager: RepositoryManager, name, path: string, dependencies: seq[string] = @[]) =
  ## Adds a repository to the manager
  manager.repos[name] = Repository(
    path: path,
    name: name,
    dependencies: dependencies
  )

proc getRepository*(manager: RepositoryManager, name: string): Option[Repository] =
  ## Gets a repository by name
  if manager.repos.hasKey(name):
    result = some(manager.repos[name])
  else:
    result = none(Repository)

proc getAllRepositories*(manager: RepositoryManager): seq[Repository] =
  ## Gets all repositories
  for repo in manager.repos.values:
    result.add(repo)

proc listRepositories*(manager: RepositoryManager): seq[string] =
  ## Lists all repository names
  for name in manager.repos.keys:
    result.add(name)

proc getDependencyGraph*(manager: RepositoryManager): Table[string, seq[string]] =
  ## Gets the dependency graph for all repositories
  for name, repo in manager.repos:
    result[name] = repo.dependencies

proc hasCyclicDependencies(graph: Table[string, seq[string]]): bool =
  ## Detects if the graph has cyclic dependencies using DFS
  var visited = initTable[string, bool]()
  var recStack = initTable[string, bool]()
  
  # Initialize visit state
  for node in graph.keys:
    visited[node] = false
    recStack[node] = false
  
  # DFS function to detect cycles
  proc isCyclic(node: string): bool =
    if not visited[node]:
      # Mark current node as visited and part of recursion stack
      visited[node] = true
      recStack[node] = true
      
      # Check all dependencies
      if graph.hasKey(node):
        for dep in graph[node]:
          if not visited.hasKey(dep):
            # Skip missing dependencies
            continue
          if not visited[dep] and isCyclic(dep):
            return true
          elif recStack[dep]:
            return true
      
    # Remove node from recursion stack
    recStack[node] = false
    return false
  
  # Check each node
  for node in graph.keys:
    if not visited[node] and isCyclic(node):
      return true
  
  return false

proc getDependencyOrder*(manager: RepositoryManager): seq[string] =
  ## Gets repositories ordered by dependencies (topological sort)
  ## Repositories without dependencies come first, followed by repositories
  ## that depend on them, etc.
  
  # Get dependency graph
  let graph = manager.getDependencyGraph()
  
  # Check for cyclic dependencies
  if hasCyclicDependencies(graph):
    raise newException(ValueError, "Cyclic dependency detected in repository configuration")
  
  # Calculate in-degree for each node (number of dependencies)
  var inDegree = initTable[string, int]()
  for node in graph.keys:
    inDegree[node] = 0
  
  for node, deps in graph:
    for dep in deps:
      if inDegree.hasKey(dep):
        inDegree[dep] += 1
  
  # Initialize queue with nodes that have no dependencies (in-degree = 0)
  var queue = newSeq[string]()
  for node, degree in inDegree:
    if degree == 0:
      queue.add(node)
  
  # Process the queue (topological sort)
  var sortedNodes = newSeq[string]()
  
  while queue.len > 0:
    let node = queue[0]
    queue.delete(0)
    sortedNodes.add(node)
    
    # Reduce in-degree for each dependent node
    if graph.hasKey(node):
      for dependent in graph[node]:
        if inDegree.hasKey(dependent):
          inDegree[dependent] -= 1
          # If dependent has no more dependencies, add to queue
          if inDegree[dependent] == 0:
            queue.add(dependent)
  
  # Return the repositories in dependency order
  result = sortedNodes

proc loadRepositoryConfigFromToml(path: string, rootDir: string): RepositoryManager =
  ## Loads repository configuration from a TOML file
  result = newRepositoryManager(rootDir)
  result.configPath = path
  
  let tomlData = parsetoml.parseFile(path)
  
  if tomlData.hasKey("repositories"):
    let repos = tomlData["repositories"]
    if repos.kind == TomlValueKind.Array:
      for repoToml in repos.getElems():
        var dependencies: seq[string] = @[]
        
        if repoToml.hasKey("dependencies"):
          let deps = repoToml["dependencies"]
          if deps.kind == TomlValueKind.Array:
            for dep in deps.getElems():
              dependencies.add(dep.getStr())
        
        # Use absolute path if relative path is provided
        var repoPath = repoToml["path"].getStr()
        if not repoPath.isAbsolute:
          repoPath = rootDir / repoPath
        
        result.addRepository(
          repoToml["name"].getStr(),
          repoPath,
          dependencies
        )

proc loadRepositoryConfigFromJson(path: string, rootDir: string): RepositoryManager =
  ## Loads repository configuration from a JSON file
  result = newRepositoryManager(rootDir)
  result.configPath = path
  
  let config = parseJson(readFile(path))
  
  if config.hasKey("repositories") and config["repositories"].kind == JArray:
    for repoJson in config["repositories"]:
      var dependencies: seq[string] = @[]
      
      if repoJson.hasKey("dependencies") and repoJson["dependencies"].kind == JArray:
        for dep in repoJson["dependencies"]:
          dependencies.add(dep.getStr)
      
      # Use absolute path if relative path is provided
      var repoPath = repoJson["path"].getStr
      if not repoPath.isAbsolute:
        repoPath = rootDir / repoPath
      
      result.addRepository(
        repoJson["name"].getStr,
        repoPath,
        dependencies
      )

proc loadRepositoryConfig*(path: string): Future[RepositoryManager] {.async.} =
  ## Loads repository configuration from a file (supports TOML and JSON)
  let rootDir = path.parentDir
  result = newRepositoryManager(rootDir)
  result.configPath = path
  
  if not fileExists(path):
    return result
  
  # Determine file type by extension
  let ext = path.splitFile().ext.toLowerAscii()
  
  try:
    case ext
    of ".toml":
      result = loadRepositoryConfigFromToml(path, rootDir)
    of ".json":
      result = loadRepositoryConfigFromJson(path, rootDir)
    else:
      # Try TOML first as default, then JSON if that fails
      try:
        result = loadRepositoryConfigFromToml(path, rootDir)
      except CatchableError:
        result = loadRepositoryConfigFromJson(path, rootDir)
  except Exception as e:
    echo "Error loading repository configuration: " & e.msg
    # Still return empty manager on error, but now with proper logging

proc saveConfigAsToml(manager: RepositoryManager, path: string): bool =
  ## Saves repository configuration as TOML
  try:
    var tomlStr = ""
    
    for name, repo in manager.repos:
      tomlStr.add("[[repositories]]\n")
      tomlStr.add("name = \"" & repo.name & "\"\n")
      tomlStr.add("path = \"" & repo.path & "\"\n")
      
      if repo.dependencies.len > 0:
        tomlStr.add("dependencies = [")
        for i, dep in repo.dependencies:
          if i > 0:
            tomlStr.add(", ")
          tomlStr.add("\"" & dep & "\"")
        tomlStr.add("]\n")
      
      tomlStr.add("\n")
    
    writeFile(path, tomlStr)
    return true
  except Exception as e:
    echo "Error saving TOML configuration: " & e.msg
    return false

proc saveConfigAsJson(manager: RepositoryManager, path: string): bool =
  ## Saves repository configuration as JSON
  try:
    # Create JSON representation
    var repositoriesArray = newJArray()
    
    for name, repo in manager.repos:
      var repoJson = %*{
        "name": repo.name,
        "path": repo.path
      }
      
      if repo.dependencies.len > 0:
        var depsArray = newJArray()
        for dep in repo.dependencies:
          depsArray.add(%dep)
        repoJson["dependencies"] = depsArray
      
      repositoriesArray.add(repoJson)
    
    let configJson = %*{
      "repositories": repositoriesArray
    }
    
    # Write to file
    writeFile(path, pretty(configJson))
    return true
  except Exception as e:
    echo "Error saving JSON configuration: " & e.msg
    return false

proc saveConfig*(manager: RepositoryManager, path: string = ""): Future[bool] {.async.} =
  ## Saves repository configuration to a file (supports TOML and JSON)
  ## Returns true if successful, false otherwise
  let configPath = if path != "": path else: manager.configPath
  
  if configPath == "":
    echo "Error: No configuration file path specified"
    return false
  
  try:
    # Create parent directory if it doesn't exist
    let parentDir = configPath.parentDir
    if not dirExists(parentDir):
      createDir(parentDir)
    
    # Determine file type by extension
    let ext = configPath.splitFile().ext.toLowerAscii()
    
    case ext
    of ".toml":
      return saveConfigAsToml(manager, configPath)
    of ".json":
      return saveConfigAsJson(manager, configPath)
    else:
      # Default to TOML
      return saveConfigAsToml(manager, configPath)
      
  except Exception as e:
    echo "Error saving repository configuration: " & e.msg
    return false

proc validateRepository*(manager: RepositoryManager, name: string): Future[bool] {.async.} =
  ## Validates that a repository exists and is a valid Jujutsu repository
  let repoOpt = manager.getRepository(name)
  if repoOpt.isNone:
    return false
  
  let repo = repoOpt.get
  
  # Check that the repository exists
  if not dirExists(repo.path):
    return false
  
  # Check that it's a valid Jujutsu repository
  try:
    let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
    return true
  except:
    return false

proc validateDependencies*(manager: RepositoryManager): Future[bool] {.async.} =
  ## Validates that all repository dependencies exist
  for name, repo in manager.repos:
    for dep in repo.dependencies:
      if not manager.repos.hasKey(dep):
        return false
  
  # Check for cyclic dependencies
  try:
    discard manager.getDependencyOrder()
    return true
  except ValueError:
    return false

proc validateAll*(manager: RepositoryManager): Future[Table[string, bool]] {.async.} =
  ## Validates all repositories and returns status for each
  var results = initTable[string, bool]()
  
  for name in manager.repos.keys:
    results[name] = await manager.validateRepository(name)
  
  return results