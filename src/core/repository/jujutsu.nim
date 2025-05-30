## Core Jujutsu repository module
##
## This module provides common functionality for interacting with Jujutsu repositories.

import std/[asyncdispatch, json, options, os, osproc, strutils, times, sequtils]
import ../logging/logger
import jujutsu_version
export jujutsu_version.quoteShellArg

type
  JujutsuRepo* = ref object
    path*: string
    isInitialized*: bool
  
  FileDiff* = object
    path*: string
    changeType*: string  # "add", "modify", "delete", etc.
    diff*: string        # Actual diff content
  
  CommitInfo* = object
    id*: string
    author*: string
    timestamp*: string
    message*: string
  
  DiffResult* = object
    commitRange*: string
    files*: seq[FileDiff]
    stats*: JsonNode

proc execCommand(cmd: string, workDir: string = ""): Future[tuple[output: string, exitCode: int]] {.async.} =
  ## Executes a command and returns the output and exit code
  let actualWorkDir = if workDir == "": getCurrentDir() else: workDir
  
  # Use execCmdEx for simpler async command execution
  let (output, exitCode) = execCmdEx(cmd, workingDir = actualWorkDir)
  return (output: output, exitCode: exitCode)

proc initJujutsuRepo*(path: string, initIfNotExists: bool = false): Future[JujutsuRepo] {.async, gcsafe.} =
  ## Initializes a connection to a Jujutsu repository
  result = JujutsuRepo(
    path: path,
    isInitialized: false
  )
  
  # Check if the path exists and is a directory
  if not dirExists(path):
    if initIfNotExists:
      # Create directory if it doesn't exist
      createDir(path)
    else:
      let ctx = newLogContext("repository", "init")
        .withMetadata("path", path)
      
      let errMsg = "Repository path does not exist: " & path
      error(errMsg, ctx)
      raise newException(IOError, errMsg)
  
  # Check if it's a Jujutsu repository by looking for the .jj directory
  let jjDir = path / ".jj"
  if not dirExists(jjDir):
    if initIfNotExists:
      # Initialize a new Jujutsu repository
      let cmd = "jj git init"
      let (output, exitCode) = await execCommand(cmd, path)
      
      if exitCode != 0:
        let ctx = newLogContext("repository", "init")
          .withMetadata("path", path)
        
        let errMsg = "Failed to initialize Jujutsu repository: " & output
        error(errMsg, ctx)
        raise newException(IOError, errMsg)
    else:
      let ctx = newLogContext("repository", "init")
        .withMetadata("path", path)
      
      let errMsg = "Not a Jujutsu repository: " & path
      error(errMsg, ctx)
      raise newException(IOError, errMsg)
  
  result.isInitialized = true

proc getDiffForCommitRange*(repo: JujutsuRepo, commitRange: string): Future[DiffResult] {.async, gcsafe.} =
  ## Gets the diff for a commit range
  let commands = await getJujutsuCommands()
  
  # Build version-appropriate diff command
  let cmd = if ".." in commitRange:
    let parts = commitRange.split("..")
    if parts.len == 2:
      commands.diffCommand & " --from " & quoteShellArg(parts[0]) & " --to " & quoteShellArg(parts[1])
    else:
      commands.diffCommand & " -r " & quoteShellArg(commitRange)
  else:
    commands.diffCommand & " -r " & quoteShellArg(commitRange)
  
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    let ctx = newLogContext("repository", "getDiff")
      .withMetadata("path", repo.path)
      .withMetadata("commitRange", commitRange)
      .withMetadata("exitCode", $exitCode)
    
    let errMsg = "Failed to get diff: " & output
    error(errMsg, ctx)
    raise newException(IOError, errMsg)
  
  var files: seq[FileDiff] = @[]
  var currentFile = ""
  var currentDiff = ""
  var currentType = ""
  
  # Parse the diff output
  for line in output.splitLines():
    if line.startsWith("diff "):
      # Save previous file if any
      if currentFile != "":
        files.add(FileDiff(
          path: currentFile,
          changeType: currentType,
          diff: currentDiff
        ))
      
      # Start new file
      let parts = line.split(' ')
      if parts.len >= 4:
        currentFile = parts[3].replace("b/", "")
        currentDiff = line & "\n"
        
        # Determine change type
        if "/dev/null" in parts[2]:
          currentType = "add"
        elif "/dev/null" in parts[3]:
          currentType = "delete"
        else:
          currentType = "modify"
    else:
      # Continue current diff
      currentDiff.add(line & "\n")
  
  # Add last file
  if currentFile != "":
    files.add(FileDiff(
      path: currentFile,
      changeType: currentType,
      diff: currentDiff
    ))
  
  # Calculate stats
  var stats = %*{
    "files": files.len,
    "additions": 0,
    "deletions": 0
  }
  
  var additions = 0
  var deletions = 0
  
  for file in files:
    for line in file.diff.splitLines():
      if line.startsWith("+") and not line.startsWith("+++"):
        additions += 1
      elif line.startsWith("-") and not line.startsWith("---"):
        deletions += 1
  
  stats["additions"] = %additions
  stats["deletions"] = %deletions
  
  return DiffResult(
    commitRange: commitRange,
    files: files,
    stats: stats
  )

proc createCommit*(repo: JujutsuRepo, message: string, changes: seq[tuple[path: string, content: string]]): Future[string] {.async, gcsafe.} =
  ## Creates a commit with the specified changes
  let commands = await getJujutsuCommands()
  let capabilities = getJujutsuCapabilities(commands.version)
  
  # First write the changes to the working directory
  for change in changes:
    let filePath = repo.path / change.path
    let fileDir = parentDir(filePath)
    
    # Ensure directory exists
    if not dirExists(fileDir):
      createDir(fileDir)
    
    # Write the file
    writeFile(filePath, change.content)
  
  # Add files if version doesn't support auto-tracking
  if not capabilities.hasAutoTracking:
    let addCmd = buildAddCommand(commands, changes.mapIt(it.path))
    if addCmd != "":
      let (addOutput, addCode) = await execCommand(addCmd, repo.path)
      if addCode != 0:
        raise newException(IOError, "Failed to add files: " & addOutput)
  
  # Get the current commit ID before making changes
  let currentIdCmd = buildLogCommand(commands, "@", "commit_id.short()")
  let (currentIdOutput, currentIdCode) = await execCommand(currentIdCmd, repo.path)
  
  if currentIdCode != 0:
    raise newException(IOError, "Failed to get current commit ID: " & currentIdOutput)
  
  let currentId = currentIdOutput.strip()
  
  # Describe the current change with the message
  let descCmd = "jj describe -m " & quoteShellArg(message)
  let (descOutput, exitCode) = await execCommand(descCmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to describe commit: " & descOutput)
  
  # Return the commit ID we just created (the one with our message)
  return currentId

proc getCommitInfo*(repo: JujutsuRepo, commitId: string): Future[CommitInfo] {.async, gcsafe.} =
  ## Gets information about a specific commit
  let cmd = "jj show -r " & quoteShellArg(commitId)
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to get commit info: " & output)
  
  var result = CommitInfo(
    id: commitId,
    author: "",
    timestamp: "",
    message: ""
  )
  
  # Parse the output
  var inDescription = false
  for line in output.splitLines():
    if line.startsWith("Author:"):
      result.author = line["Author:".len..^1].strip()
    elif line.startsWith("Date:"):
      result.timestamp = line["Date:".len..^1].strip()
    elif line.startsWith("Description:"):
      inDescription = true
    elif inDescription and not line.startsWith(" "):
      inDescription = false
    elif inDescription:
      if result.message != "":
        result.message.add("\n")
      result.message.add(line.strip())
  
  return result

proc getStatus*(repo: JujutsuRepo): Future[JsonNode] {.async, gcsafe.} =
  ## Gets the current status of the repository
  let cmd = "jj status --json"
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to get repository status: " & output)
  
  try:
    let statusJson = parseJson(output)
    return statusJson
  except JsonParsingError:
    raise newException(IOError, "Failed to parse status output: " & output)

proc listBranches*(repo: JujutsuRepo): Future[seq[string]] {.async, gcsafe.} =
  ## Lists all branches in the repository
  let cmd = "jj branch list"
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to list branches: " & output)
  
  var branches: seq[string] = @[]
  for line in output.splitLines():
    if line.strip() != "":
      branches.add(line.strip())
  
  return branches

proc createBranch*(repo: JujutsuRepo, name: string, fromCommit: string = "@"): Future[string] {.async, gcsafe.} =
  ## Creates a new branch
  let cmd = "jj branch create " & quoteShellArg(name) & " -r " & quoteShellArg(fromCommit)
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to create branch: " & output)
  
  return name

proc switchBranch*(repo: JujutsuRepo, name: string): Future[void] {.async, gcsafe.} =
  ## Switches to a branch
  let cmd = "jj new -r " & quoteShellArg(name)
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to switch branch: " & output)

proc getCommitHistory*(repo: JujutsuRepo, limit: int = 10, branch: string = "@"): Future[seq[CommitInfo]] {.async, gcsafe.} =
  ## Gets the commit history
  let cmd = "jj log --no-graph -r " & quoteShellArg(branch) & " -n " & $limit
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to get commit history: " & output)
  
  var commits: seq[CommitInfo] = @[]
  var currentCommit: Option[CommitInfo] = none(CommitInfo)
  
  for line in output.splitLines():
    if line.startsWith("commit "):
      # Start a new commit
      if currentCommit.isSome:
        commits.add(currentCommit.get)
      
      let parts = line.split(' ')
      if parts.len >= 2:
        currentCommit = some(CommitInfo(
          id: parts[1],
          author: "",
          timestamp: "",
          message: ""
        ))
    elif line.startsWith("Author:") and currentCommit.isSome:
      var commit = currentCommit.get
      commit.author = line["Author:".len..^1].strip()
      currentCommit = some(commit)
    elif line.startsWith("Date:") and currentCommit.isSome:
      var commit = currentCommit.get
      commit.timestamp = line["Date:".len..^1].strip()
      currentCommit = some(commit)
    elif line.strip() != "" and currentCommit.isSome and currentCommit.get.message == "":
      var commit = currentCommit.get
      commit.message = line.strip()
      currentCommit = some(commit)
  
  # Add the last commit
  if currentCommit.isSome:
    commits.add(currentCommit.get)
  
  return commits

proc compareCommits*(repo: JujutsuRepo, commit1: string, commit2: string): Future[DiffResult] {.async, gcsafe.} =
  ## Compares two commits
  return await getDiffForCommitRange(repo, commit1 & ".." & commit2)

proc getCommitFiles*(repo: JujutsuRepo, commitId: string): Future[seq[string]] {.async, gcsafe.} =
  ## Gets the list of files modified in a commit
  let cmd = "jj files -r " & quoteShellArg(commitId)
  let (output, exitCode) = await execCommand(cmd, repo.path)
  
  if exitCode != 0:
    raise newException(IOError, "Failed to get commit files: " & output)
  
  var files: seq[string] = @[]
  for line in output.splitLines():
    if line.strip() != "":
      files.add(line.strip())
  
  return files