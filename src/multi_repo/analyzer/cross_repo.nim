## Cross-repository analysis module
##
## This module implements advanced cross-repository analysis functionality
## including dependency detection, semantic grouping, and coordinated commit proposals.

import std/[asyncdispatch, json, options, sets, strutils, tables, hashes, sequtils, algorithm]
import ../repository/manager
import ../../core/repository/jujutsu
import ../../single_repo/analyzer/semantic as single_semantic
import ../../core/logging/logger

type
  FileChange* = object
    ## Represents a file change in a cross-repository context
    path*: string         ## File path relative to repository root
    changeType*: string   ## Type of change: "add", "modify", "delete"
    diff*: string         ## The actual diff content
    repository*: string   ## Repository name for cross-repo context

  CrossRepoDiff* = object
    ## Contains diff information across multiple repositories
    repositories*: seq[Repository]                    ## List of repositories involved
    changes*: Table[string, seq[jujutsu.FileDiff]]   ## Changes grouped by repository name
    
  CrossRepoProposal* = object
    ## Proposal for splitting commits across multiple repositories
    originalCommitIds*: Table[string, string]  ## Original commit IDs by repository
    targetCommitIds*: Table[string, string]    ## Target commit IDs by repository
    commitGroups*: seq[CommitGroup]            ## Proposed commit groups
    confidenceScore*: float                    ## Overall confidence in the proposal
    
  CommitGroup* = object
    ## A group of related commits across repositories
    name*: string               ## Group identifier
    description*: string        ## Human-readable description
    commits*: seq[CommitInfo]   ## Commits in this group
    groupType*: CommitGroupType ## Type of grouping applied
    changeType*: ChangeType     ## Dominant change type
    confidence*: float          ## Confidence score for this group
    keywords*: seq[string]      ## Extracted keywords
    
  CommitInfo* = object
    ## Information about a single commit in a multi-repo context
    repository*: string         ## Repository name
    message*: string            ## Commit message
    changes*: seq[FileChange]   ## File changes in this commit
    changeType*: ChangeType     ## Type of change
    keywords*: seq[string]      ## Keywords extracted from changes
    
  DependencyRelation* = object
    ## Represents a dependency between repositories
    source*: string        ## Source repository name
    target*: string        ## Target repository name
    sourceFile*: string    ## File in source repo that contains the dependency
    targetFile*: string    ## File in target repo being depended on (if known)
    dependencyType*: string ## Type: "import", "reference", "api", etc.
    confidence*: float   # Confidence score of the dependency detection
    
  CommitGroupType* = enum
    cgtFeature,      # Feature-related changes across repositories
    cgtBugfix,       # Bug fixes across repositories
    cgtRefactor,     # Refactoring across repositories
    cgtDependency,   # Changes driven by dependencies between repositories
    cgtFileType,     # Changes grouped by file type across repositories
    cgtDirectory,    # Changes grouped by directory structure across repositories
    cgtComponent,    # Changes grouped by component/module across repositories
    cgtMixed         # Mixed changes that don't fit other categories
    
  ChangeType* = single_semantic.ChangeType
  
  CrossRepoDependencyGraph* = Table[string, HashSet[string]]
  
  # Configuration for cross-repo analysis
  CrossRepoAnalysisConfig* = object
    groupByFileType*: bool      # Group changes by file type across repositories
    groupByDirectory*: bool     # Group changes by directory across repositories
    groupByDependency*: bool    # Group changes by repository dependencies
    groupBySemantics*: bool     # Group changes by semantic meaning
    maxGroupSize*: int          # Maximum number of files in a group
    minConfidence*: float       # Minimum confidence for including a change
    dependencyDetection*: bool  # Enable dependency detection
    
# Pattern definitions for dependency detection (using simple string patterns)
const dependencyPatterns = [
  (pattern: "import ", dependencyType: "import", confidence: 0.9),
  (pattern: "from ", dependencyType: "import", confidence: 0.9),
  (pattern: "require", dependencyType: "require", confidence: 0.8),
  (pattern: "depend", dependencyType: "dependency", confidence: 0.7),
  (pattern: "include", dependencyType: "include", confidence: 0.7),
  (pattern: "use ", dependencyType: "import", confidence: 0.7)
]

proc newDefaultAnalysisConfig*(): CrossRepoAnalysisConfig =
  ## Creates a new configuration with default values
  result = CrossRepoAnalysisConfig(
    groupByFileType: true,
    groupByDirectory: true,
    groupByDependency: true,
    groupBySemantics: true,
    maxGroupSize: 20,
    minConfidence: 0.7,
    dependencyDetection: true
  )

proc detectDependencies*(diff: CrossRepoDiff): seq[DependencyRelation] =
  ## Detects dependencies between repositories using pattern matching and semantic analysis
  ## This is the simple detection version that works synchronously for testing
  var result: seq[DependencyRelation] = @[]

  # Extract repository names for easier matching
  var repoNames = newSeq[string]()
  for repo in diff.repositories:
    repoNames.add(repo.name)
  
  # Check all repositories and files for dependencies
  for sourceRepo, files in diff.changes:
    for file in files:
      # Look for patterns indicating dependencies
      var fileLines = file.diff.splitLines()
      
      for line in fileLines:
        # Skip diff metadata lines
        if line.startsWith("+++") or line.startsWith("---") or line.startsWith("@@"):
          continue
          
        # Extract content from diff lines
        var contentLine = line
        if line.startsWith("+") or line.startsWith("-"):
          contentLine = line[1..^1]
          
        # Check for repo name references in the content
        for targetRepo in repoNames:
          if sourceRepo == targetRepo:
            continue
            
          if contentLine.contains(targetRepo):
            # Found a reference to another repository
            result.add(DependencyRelation(
              source: sourceRepo,
              target: targetRepo,
              sourceFile: file.path,
              targetFile: "", # Unknown in simple detection
              dependencyType: "reference",
              confidence: 0.7
            ))
            
          # Check using simple string patterns for dependency detection
          for (pattern, depType, conf) in dependencyPatterns:
            if contentLine.contains(pattern):
              # Simple heuristic: if the line contains both the pattern and target repo name
              if contentLine.contains(targetRepo):
                result.add(DependencyRelation(
                  source: sourceRepo,
                  target: targetRepo,
                  sourceFile: file.path,
                  targetFile: "", # Unknown from just pattern matching
                  dependencyType: depType,
                  confidence: conf
                ))
  
  return result

proc identifyCrossRepoDependencies*(diff: CrossRepoDiff): Future[seq[DependencyRelation]] {.async.} =
  ## Identifies dependencies between repositories based on changes with advanced detection
  var result: seq[DependencyRelation] = @[]
  
  # First use the simple detection for basic dependencies
  let basicDependencies = detectDependencies(diff)
  for dep in basicDependencies:
    result.add(dep)
  
  # Extract repository names for easier matching
  var repoNames = newSeq[string]()
  for repo in diff.repositories:
    repoNames.add(repo.name)
  
  # Build a map of files by extension across repositories
  var filesByExtension = initTable[string, Table[string, seq[string]]]()
  
  for repoName, files in diff.changes:
    for file in files:
      let fileExt = if file.path.contains("."): file.path.rsplit(".", 1)[1] else: "none"
      
      if not filesByExtension.hasKey(fileExt):
        filesByExtension[fileExt] = initTable[string, seq[string]]()
      
      if not filesByExtension[fileExt].hasKey(repoName):
        filesByExtension[fileExt][repoName] = @[]
      
      filesByExtension[fileExt][repoName].add(file.path)
  
  # Look for files with similar names across repositories
  # This helps detect potential API dependencies
  for ext, repoFiles in filesByExtension:
    if repoFiles.len > 1: # More than one repo has this file type
      # For each repository pair, check for similar file names
      let repos = toSeq(repoFiles.keys)
      
      for i in 0..<repos.len:
        let sourceRepo = repos[i]
        
        for j in 0..<repos.len:
          if i == j:
            continue
            
          let targetRepo = repos[j]
          
          # Compare filenames (without path) for similarity
          for sourceFilePath in repoFiles[sourceRepo]:
            let sourceFileName = if sourceFilePath.contains("/"): sourceFilePath.rsplit("/", 1)[1] else: sourceFilePath
            
            for targetFilePath in repoFiles[targetRepo]:
              let targetFileName = if targetFilePath.contains("/"): targetFilePath.rsplit("/", 1)[1] else: targetFilePath
              
              # Check for exact name match or if one contains the other
              if sourceFileName == targetFileName or
                 sourceFileName.contains(targetFileName) or
                 targetFileName.contains(sourceFileName):
                
                # Found a potential dependency through similar filenames
                result.add(DependencyRelation(
                  source: sourceRepo,
                  target: targetRepo,
                  sourceFile: sourceFilePath,
                  targetFile: targetFilePath,
                  dependencyType: "api",
                  confidence: 0.6
                ))
  
  # Advanced: Look for import statements and API usage patterns
  # We'll look for shared semantic elements across repositories
  var keywordsByRepo = initTable[string, HashSet[string]]()
  
  for repoName, files in diff.changes:
    var allKeywords = initHashSet[string]()
    
    for file in files:
      # Use the same keyword extraction as in semantic analyzer
      let keywords = single_semantic.extractKeywords(file.diff)
      for keyword in keywords:
        allKeywords.incl(keyword)
    
    keywordsByRepo[repoName] = allKeywords
  
  # Compare keywords across repositories to find potential dependencies
  for sourceRepo, sourceKeywords in keywordsByRepo:
    for targetRepo, targetKeywords in keywordsByRepo:
      if sourceRepo == targetRepo:
        continue
      
      # Calculate similarity score
      let intersection = sourceKeywords.intersection(targetKeywords)
      
      # If there are significant shared keywords, add a potential dependency
      if intersection.len >= 3:
        # The more shared keywords, the higher the confidence
        let confidence = min(0.5 + (intersection.len.float / 10.0), 0.9)
        
        result.add(DependencyRelation(
          source: sourceRepo,
          target: targetRepo,
          sourceFile: "", # Can't determine from just keywords
          targetFile: "", # Can't determine from just keywords
          dependencyType: "semantic",
          confidence: confidence
        ))
  
  return result

proc buildDependencyGraph*(dependencies: seq[DependencyRelation]): CrossRepoDependencyGraph =
  ## Builds a dependency graph from the identified dependencies
  var graph = initTable[string, HashSet[string]]()
  
  for dependency in dependencies:
    # Skip low confidence dependencies
    if dependency.confidence < 0.6:
      continue
      
    # Add entry for source repository if it doesn't exist
    if not graph.hasKey(dependency.source):
      graph[dependency.source] = initHashSet[string]()
    
    # Add the dependency
    graph[dependency.source].incl(dependency.target)
  
  return graph

proc analyzeFilesAcrossRepos*(diff: CrossRepoDiff): Table[string, Table[string, seq[jujutsu.FileDiff]]] =
  ## Groups files by type across repositories
  var result = initTable[string, Table[string, seq[jujutsu.FileDiff]]]()
  
  for repoName, files in diff.changes:
    for file in files:
      let fileExt = if file.path.contains("."): file.path.rsplit(".", 1)[1] else: "none"
      
      if not result.hasKey(fileExt):
        result[fileExt] = initTable[string, seq[jujutsu.FileDiff]]()
      
      if not result[fileExt].hasKey(repoName):
        result[fileExt][repoName] = @[]
      
      result[fileExt][repoName].add(file)
  
  return result

proc analyzeDirectoriesAcrossRepos*(diff: CrossRepoDiff): Table[string, Table[string, seq[jujutsu.FileDiff]]] =
  ## Groups files by directory structure across repositories
  var result = initTable[string, Table[string, seq[jujutsu.FileDiff]]]()
  
  for repoName, files in diff.changes:
    for file in files:
      let dirPath = if file.path.contains("/"): file.path.rsplit("/", 1)[0] else: "root"
      let dirName = if dirPath.contains("/"): dirPath.rsplit("/", 1)[1] else: dirPath
      
      if not result.hasKey(dirName):
        result[dirName] = initTable[string, seq[jujutsu.FileDiff]]()
      
      if not result[dirName].hasKey(repoName):
        result[dirName][repoName] = @[]
      
      result[dirName][repoName].add(file)
  
  return result

proc analyzeSemanticsAcrossRepos*(diff: CrossRepoDiff): Table[ChangeType, Table[string, seq[jujutsu.FileDiff]]] =
  ## Groups files by semantic meaning across repositories
  var result = initTable[ChangeType, Table[string, seq[jujutsu.FileDiff]]]()
  
  # Initialize all change types
  for ct in ChangeType:
    result[ct] = initTable[string, seq[jujutsu.FileDiff]]()
  
  for repoName, files in diff.changes:
    # Skip empty file lists
    if files.len == 0:
      continue
    
    # Group files by change type
    var filesByType = initTable[ChangeType, seq[jujutsu.FileDiff]]()
    
    for file in files:
      # Create temporary diffResult to analyze with single-repo semantic analyzer
      let tempDiff = jujutsu.DiffResult(
        commitRange: "HEAD~1..HEAD",
        files: @[file]
      )
      
      # Detect change type for this file
      let changeType = single_semantic.detectChangeType(file.diff)
      
      if not filesByType.hasKey(changeType):
        filesByType[changeType] = @[]
      
      filesByType[changeType].add(file)
    
    # Add grouped files to the result
    for changeType, typeFiles in filesByType:
      if not result[changeType].hasKey(repoName):
        result[changeType][repoName] = @[]
      
      for file in typeFiles:
        result[changeType][repoName].add(file)
  
  return result

proc analyzeDependencyBasedChanges(
  diff: CrossRepoDiff,
  dependencies: seq[DependencyRelation]
): Table[string, Table[string, seq[jujutsu.FileDiff]]] =
  ## Groups files by dependency relationships across repositories
  var result = initTable[string, Table[string, seq[jujutsu.FileDiff]]]()
  
  # Create groups based on dependencies
  for dependency in dependencies:
    # Skip low confidence dependencies
    if dependency.confidence < 0.7:
      continue
    
    let groupName = dependency.source & " => " & dependency.target
    
    if not result.hasKey(groupName):
      result[groupName] = initTable[string, seq[jujutsu.FileDiff]]()
    
    # Add source repository files
    if diff.changes.hasKey(dependency.source):
      if not result[groupName].hasKey(dependency.source):
        result[groupName][dependency.source] = @[]
      
      # If we know the specific file that has the dependency
      if dependency.sourceFile != "":
        # Find just that file
        for file in diff.changes[dependency.source]:
          if file.path == dependency.sourceFile:
            result[groupName][dependency.source].add(file)
            break
      else:
        # Add all files from the source repository
        for file in diff.changes[dependency.source]:
          result[groupName][dependency.source].add(file)
    
    # Add target repository files
    if diff.changes.hasKey(dependency.target):
      if not result[groupName].hasKey(dependency.target):
        result[groupName][dependency.target] = @[]
      
      # If we know the specific target file
      if dependency.targetFile != "":
        # Find just that file
        for file in diff.changes[dependency.target]:
          if file.path == dependency.targetFile:
            result[groupName][dependency.target].add(file)
            break
      else:
        # Add all files from the target repository
        for file in diff.changes[dependency.target]:
          result[groupName][dependency.target].add(file)
  
  return result

proc analyzeCrossRepoChanges*(manager: RepositoryManager, repoNames: seq[string], commitRange: string): Future[CrossRepoDiff] {.async.} =
  ## Analyzes changes across multiple repositories
  var result = CrossRepoDiff(
    repositories: @[],
    changes: initTable[string, seq[jujutsu.FileDiff]]()
  )
  
  for repoName in repoNames:
    let repoOpt = manager.getRepository(repoName)
    if repoOpt.isNone:
      continue
    
    let repo = repoOpt.get
    result.repositories.add(repo)
    
    try:
      # Initialize jujutsu repo
      let jjRepo = await jujutsu.initJujutsuRepo(repo.path)
      
      # Get diff for commit range
      let diffResult = await jjRepo.getDiffForCommitRange(commitRange)
      
      # Add changes to result
      result.changes[repoName] = diffResult.files
    except Exception as e:
      # Skip repositories with errors but provide empty array for consistency
      result.changes[repoName] = @[]
      
      let ctx = newLogContext("cross-repo", "analyzeCrossRepoChanges")
        .withMetadata("repository", repoName)
        .withMetadata("path", repo.path)
        .withMetadata("commitRange", commitRange)
      
      logException(e, "Error analyzing repository " & repoName, ctx)
  
  return result

proc convertToFileChanges(
  repoName: string,
  files: seq[jujutsu.FileDiff]
): seq[FileChange] =
  ## Converts Jujutsu FileDiff objects to FileChange objects
  for file in files:
    result.add(FileChange(
      path: file.path,
      changeType: file.changeType,
      diff: file.diff,
      repository: repoName
    ))

proc createCommitInfo(
  repoName: string,
  files: seq[jujutsu.FileDiff],
  changeType: ChangeType,
  messagePrefix: string = ""
): CommitInfo =
  ## Creates a CommitInfo object for a repository
  # Extract keywords from all files
  var allKeywords = initHashSet[string]()
  for file in files:
    let keywords = single_semantic.extractKeywords(file.diff)
    for keyword in keywords:
      allKeywords.incl(keyword)
  
  # Generate message based on change type and keywords
  var message = ""
  case changeType
  of ChangeType.ctFeature:
    message = "feat"
  of ChangeType.ctBugfix:
    message = "fix"
  of ChangeType.ctRefactor:
    message = "refactor"
  of ChangeType.ctDocs:
    message = "docs"
  of ChangeType.ctTests:
    message = "test"
  of ChangeType.ctChore:
    message = "chore"
  of ChangeType.ctStyle:
    message = "style"
  of ChangeType.ctPerformance:
    message = "perf"
  
  # Add scope if all files are in same directory
  var commonDir = ""
  var allSameDir = true
  
  for file in files:
    let dirPath = if file.path.contains("/"): file.path.rsplit("/", 1)[0] else: ""
    if commonDir == "":
      commonDir = dirPath
    elif commonDir != dirPath:
      allSameDir = false
      break
  
  if allSameDir and commonDir != "":
    let dirName = if commonDir.contains("/"): commonDir.rsplit("/", 1)[1] else: commonDir
    message &= "(" & dirName & ")"
  
  # Add descriptive message
  if messagePrefix != "":
    message &= ": " & messagePrefix
  else:
    # Generate a message based on the file content
    var description = ""
    
    # Use up to 3 keywords for the description
    let keywordsList = toSeq(allKeywords)
    if keywordsList.len > 0:
      let keywordsToUse = min(keywordsList.len, 3)
      description = keywordsList[0..<keywordsToUse].join(", ")
    
    if description != "":
      message &= ": update " & description
    else:
      # Fall back to a generic description based on change type
      case changeType
      of ChangeType.ctFeature:
        message &= ": add new functionality"
      of ChangeType.ctBugfix:
        message &= ": fix issues"
      of ChangeType.ctRefactor:
        message &= ": improve code structure"
      of ChangeType.ctDocs:
        message &= ": update documentation"
      of ChangeType.ctTests:
        message &= ": update tests"
      of ChangeType.ctChore:
        message &= ": maintenance updates"
      of ChangeType.ctStyle:
        message &= ": improve code style"
      of ChangeType.ctPerformance:
        message &= ": improve performance"
  
  # Create FileChange objects for all files
  var changes = newSeq[FileChange]()
  for file in files:
    changes.add(FileChange(
      path: file.path,
      changeType: file.changeType,
      diff: file.diff,
      repository: repoName
    ))
  
  # Return the CommitInfo
  return CommitInfo(
    repository: repoName,
    message: message,
    changes: changes,
    changeType: changeType,
    keywords: toSeq(allKeywords)
  )

proc generateCrossRepoProposal*(diff: CrossRepoDiff, manager: RepositoryManager, config: CrossRepoAnalysisConfig = newDefaultAnalysisConfig()): Future[CrossRepoProposal] {.async.} =
  ## Generates a semantic cross-repository proposal for commit division
  var proposal = CrossRepoProposal(
    originalCommitIds: initTable[string, string](),
    targetCommitIds: initTable[string, string](),
    commitGroups: @[],
    confidenceScore: 0.0
  )
  
  # Skip processing if no repositories or no changes
  if diff.repositories.len == 0:
    return proposal
  
  # Initialize commit IDs
  for repo in diff.repositories:
    # For real IDs, we'd actually extract these from the commitRange
    proposal.originalCommitIds[repo.name] = "HEAD~1"
    proposal.targetCommitIds[repo.name] = "HEAD"
  
  # Get dependencies between repositories
  let dependencies = await identifyCrossRepoDependencies(diff)
  let dependencyGraph = buildDependencyGraph(dependencies)
  
  # Total confidence score for averaging later
  var totalConfidence = 0.0
  var groupCount = 0
  
  # 1. First, create groups based on semantic meaning if enabled
  if config.groupBySemantics:
    let semanticGroups = analyzeSemanticsAcrossRepos(diff)
    
    for changeType, repoFiles in semanticGroups:
      # Skip empty groups
      if repoFiles.len == 0:
        continue
      
      var group = CommitGroup(
        name: $changeType & " changes across repositories",
        description: "Changes related to " & $changeType & " across multiple repositories",
        commits: @[],
        groupType: cgtFeature, # Will be updated below
        changeType: changeType,
        confidence: 0.85,
        keywords: @[]
      )
      
      # Set appropriate group type based on change type
      case changeType
      of ChangeType.ctFeature:
        group.groupType = cgtFeature
      of ChangeType.ctBugfix:
        group.groupType = cgtBugfix
      of ChangeType.ctRefactor:
        group.groupType = cgtRefactor
      else:
        group.groupType = cgtMixed
      
      # Create commits for each repository with files of this change type
      var allKeywords = initHashSet[string]()
      
      for repoName, files in repoFiles:
        # Skip repositories with no files
        if files.len == 0:
          continue
        
        let messagePrefix = $changeType & " changes"
        let commit = createCommitInfo(repoName, files, changeType, messagePrefix)
        
        group.commits.add(commit)
        
        # Collect keywords
        for keyword in commit.keywords:
          allKeywords.incl(keyword)
      
      # Save keywords to group
      group.keywords = toSeq(allKeywords)
      
      # Add group if it has any commits
      if group.commits.len > 0:
        proposal.commitGroups.add(group)
        totalConfidence += group.confidence
        groupCount += 1
  
  # 2. Create groups based on dependencies if enabled
  if config.groupByDependency:
    let dependencyGroups = analyzeDependencyBasedChanges(diff, dependencies)
    
    for groupName, repoFiles in dependencyGroups:
      # Skip groups with no files
      if repoFiles.len == 0:
        continue
      
      var group = CommitGroup(
        name: "Cross-dependency: " & groupName,
        description: "Changes involving dependencies between repositories",
        commits: @[],
        groupType: cgtDependency,
        changeType: ChangeType.ctFeature, # Default, may be updated
        confidence: 0.9,
        keywords: @[]
      )
      
      # Create commits for each repository
      var allKeywords = initHashSet[string]()
      
      for repoName, files in repoFiles:
        # Skip repositories with no files
        if files.len == 0:
          continue
        
        # Determine dominant change type for this repo's files
        var typeScores = initTable[ChangeType, int]()
        for changeType in ChangeType:
          typeScores[changeType] = 0
        
        for file in files:
          let changeType = single_semantic.detectChangeType(file.diff)
          typeScores[changeType] += 1
        
        # Find the most common change type
        var maxScore = 0
        var dominantType = ChangeType.ctFeature
        
        for changeType, score in typeScores:
          if score > maxScore:
            maxScore = score
            dominantType = changeType
        
        let messagePrefix = "cross-repository compatibility changes"
        let commit = createCommitInfo(repoName, files, dominantType, messagePrefix)
        
        group.commits.add(commit)
        
        # Collect keywords
        for keyword in commit.keywords:
          allKeywords.incl(keyword)
      
      # Save keywords to group
      group.keywords = toSeq(allKeywords)
      
      # Add group if it has any commits
      if group.commits.len > 0:
        proposal.commitGroups.add(group)
        totalConfidence += group.confidence
        groupCount += 1
  
  # 3. Create groups based on file types if enabled
  if config.groupByFileType:
    let fileTypeGroups = analyzeFilesAcrossRepos(diff)
    
    for fileType, repoFiles in fileTypeGroups:
      # Skip groups with no files or single files
      if repoFiles.len == 0:
        continue
      
      # Check if this is a single file across all repos
      var totalFiles = 0
      for repoName, files in repoFiles:
        totalFiles += files.len
      
      if totalFiles <= 1:
        continue
      
      var group = CommitGroup(
        name: fileType & " file updates",
        description: "Changes to " & fileType & " files across repositories",
        commits: @[],
        groupType: cgtFileType,
        changeType: ChangeType.ctChore, # Default, may be updated
        confidence: 0.75,
        keywords: @[]
      )
      
      # Create commits for each repository
      var allKeywords = initHashSet[string]()
      
      for repoName, files in repoFiles:
        # Skip repositories with no files
        if files.len == 0:
          continue
        
        # Determine dominant change type
        var typeScores = initTable[ChangeType, int]()
        for changeType in ChangeType:
          typeScores[changeType] = 0
        
        for file in files:
          let changeType = single_semantic.detectChangeType(file.diff)
          typeScores[changeType] += 1
        
        # Find the most common change type
        var maxScore = 0
        var dominantType = ChangeType.ctChore
        
        for changeType, score in typeScores:
          if score > maxScore:
            maxScore = score
            dominantType = changeType
        
        let messagePrefix = "update " & fileType & " files"
        let commit = createCommitInfo(repoName, files, dominantType, messagePrefix)
        
        group.commits.add(commit)
        
        # Collect keywords
        for keyword in commit.keywords:
          allKeywords.incl(keyword)
      
      # Save keywords to group
      group.keywords = toSeq(allKeywords)
      
      # Add group if it has any commits
      if group.commits.len > 0:
        proposal.commitGroups.add(group)
        totalConfidence += group.confidence
        groupCount += 1
  
  # 4. Create groups based on directory structure if enabled
  if config.groupByDirectory:
    let dirGroups = analyzeDirectoriesAcrossRepos(diff)
    
    for dirName, repoFiles in dirGroups:
      # Skip groups with no files or single files
      if repoFiles.len == 0:
        continue
      
      # Check if this is a single file across all repos
      var totalFiles = 0
      for repoName, files in repoFiles:
        totalFiles += files.len
      
      if totalFiles <= 1:
        continue
      
      var group = CommitGroup(
        name: dirName & " directory changes",
        description: "Changes in " & dirName & " directory across repositories",
        commits: @[],
        groupType: cgtDirectory,
        changeType: ChangeType.ctChore, # Default, may be updated
        confidence: 0.8,
        keywords: @[]
      )
      
      # Create commits for each repository
      var allKeywords = initHashSet[string]()
      
      for repoName, files in repoFiles:
        # Skip repositories with no files
        if files.len == 0:
          continue
        
        # Determine dominant change type
        var typeScores = initTable[ChangeType, int]()
        for changeType in ChangeType:
          typeScores[changeType] = 0
        
        for file in files:
          let changeType = single_semantic.detectChangeType(file.diff)
          typeScores[changeType] += 1
        
        # Find the most common change type
        var maxScore = 0
        var dominantType = ChangeType.ctChore
        
        for changeType, score in typeScores:
          if score > maxScore:
            maxScore = score
            dominantType = changeType
        
        let messagePrefix = "update " & dirName & " module"
        let commit = createCommitInfo(repoName, files, dominantType, messagePrefix)
        
        group.commits.add(commit)
        
        # Collect keywords
        for keyword in commit.keywords:
          allKeywords.incl(keyword)
      
      # Save keywords to group
      group.keywords = toSeq(allKeywords)
      
      # Add group if it has any commits
      if group.commits.len > 0:
        proposal.commitGroups.add(group)
        totalConfidence += group.confidence
        groupCount += 1
  
  # 5. Finally, create a catch-all group for any remaining files
  var remainingFiles = initTable[string, seq[jujutsu.FileDiff]]()
  var filesInProposal = initTable[string, HashSet[string]]()
  
  # Track which files are already included in the proposal
  for group in proposal.commitGroups:
    for commit in group.commits:
      if not filesInProposal.hasKey(commit.repository):
        filesInProposal[commit.repository] = initHashSet[string]()
      
      for change in commit.changes:
        filesInProposal[commit.repository].incl(change.path)
  
  # Find files that aren't in any group yet
  for repoName, files in diff.changes:
    remainingFiles[repoName] = @[]
    
    for file in files:
      if not filesInProposal.hasKey(repoName) or not filesInProposal[repoName].contains(file.path):
        remainingFiles[repoName].add(file)
  
  # Create a catch-all group if needed
  var hasMissingFiles = false
  for repoName, files in remainingFiles:
    if files.len > 0:
      hasMissingFiles = true
      break
  
  if hasMissingFiles:
    var group = CommitGroup(
      name: "Miscellaneous changes",
      description: "Other changes not covered in other groups",
      commits: @[],
      groupType: cgtMixed,
      changeType: ChangeType.ctChore,
      confidence: 0.6,
      keywords: @[]
    )
    
    # Create commits for each repository
    var allKeywords = initHashSet[string]()
    
    for repoName, files in remainingFiles:
      if files.len == 0:
        continue
      
      # Determine dominant change type
      var typeScores = initTable[ChangeType, int]()
      for changeType in ChangeType:
        typeScores[changeType] = 0
      
      for file in files:
        let changeType = single_semantic.detectChangeType(file.diff)
        typeScores[changeType] += 1
      
      # Find the most common change type
      var maxScore = 0
      var dominantType = ChangeType.ctChore
      
      for changeType, score in typeScores:
        if score > maxScore:
          maxScore = score
          dominantType = changeType
      
      let commit = createCommitInfo(repoName, files, dominantType)
      
      group.commits.add(commit)
      
      # Collect keywords
      for keyword in commit.keywords:
        allKeywords.incl(keyword)
    
    # Save keywords to group
    group.keywords = toSeq(allKeywords)
    
    # Add group if it has any commits
    if group.commits.len > 0:
      proposal.commitGroups.add(group)
      totalConfidence += group.confidence
      groupCount += 1
  
  # Calculate overall confidence score
  if groupCount > 0:
    proposal.confidenceScore = totalConfidence / groupCount.float
  
  # Sort commit groups by type (most important first)
  proposal.commitGroups.sort(proc(a, b: CommitGroup): int = 
    # Sort by group type first
    result = if ord(a.groupType) < ord(b.groupType): -1
             elif ord(a.groupType) > ord(b.groupType): 1
             # Then by confidence
             elif a.confidence > b.confidence: -1
             elif a.confidence < b.confidence: 1
             else: 0
  )
  
  return proposal

proc getDependencyOrder*(manager: RepositoryManager): seq[string] =
  ## Gets a dependency order for repositories (topological sort)
  ## This is a convenience method that calls the manager's implementation
  # Just use the manager's implementation
  return manager.getDependencyOrder()