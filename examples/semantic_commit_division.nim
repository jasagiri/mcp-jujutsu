## Semantic Commit Division Example
## Demonstrates using the MCP client for intelligent semantic commit splitting
## Shows both manual analysis and automated division using the server

import std/[asyncdispatch, os, strformat, json, tables, sequtils, strutils]
import mcp_jujutsu/client/client

type
  FileChange = object
    path: string
    additions: int
    deletions: int
    hunks: seq[string]  # Changed code sections
  
  SemanticGroup = object
    category: string  # feat, fix, refactor, docs, test, etc.
    scope: string     # module or component affected
    files: seq[FileChange]
    reason: string    # Why these changes belong together

proc analyzeFileChange(change: FileChange): tuple[category: string, scope: string] =
  ## Analyze a file change to determine its semantic category and scope
  let path = change.path.toLowerAscii()
  let ext = path.splitFile().ext
  
  # Determine category based on file patterns
  var category = "chore"
  var scope = "general"
  
  if path.contains("test") or path.endsWith("_test.nim"):
    category = "test"
  elif path.contains("docs/") or ext in [".md", ".rst", ".txt"]:
    category = "docs"
  elif path.contains("examples/"):
    category = "docs"
    scope = "examples"
  elif ext in [".nim", ".c", ".cpp", ".js", ".py"]:
    # Analyze code changes
    if change.additions > change.deletions * 2:
      category = "feat"  # Likely adding new functionality
    elif change.deletions > change.additions * 2:
      category = "refactor"  # Likely removing/simplifying code
    else:
      category = "fix"  # Likely fixing existing code
  
  # Determine scope from path
  let parts = path.split('/')
  if parts.len > 1:
    scope = parts[0]  # Use top-level directory as scope
  
  return (category, scope)

proc groupChangesSemantically(changes: seq[FileChange]): seq[SemanticGroup] =
  ## Group file changes based on semantic analysis
  var groups = initTable[string, SemanticGroup]()
  
  for change in changes:
    let (category, scope) = analyzeFileChange(change)
    let key = fmt"{category}({scope})"
    
    if key notin groups:
      groups[key] = SemanticGroup(
        category: category,
        scope: scope,
        files: @[],
        reason: ""
      )
    
    groups[key].files.add(change)
  
  # Add reasoning for each group
  for key, group in groups.mpairs:
    case group.category
    of "feat":
      group.reason = fmt"New feature additions in {group.scope}"
    of "fix":
      group.reason = fmt"Bug fixes in {group.scope}"
    of "refactor":
      group.reason = fmt"Code improvements in {group.scope} without changing behavior"
    of "docs":
      group.reason = fmt"Documentation updates for {group.scope}"
    of "test":
      group.reason = fmt"Test additions/modifications for {group.scope}"
    else:
      group.reason = fmt"Maintenance changes in {group.scope}"
  
  return groups.values.toSeq()

proc generateCommitMessage(group: SemanticGroup): string =
  ## Generate a semantic commit message for a group
  let fileCount = group.files.len
  let totalAdditions = group.files.mapIt(it.additions).foldl(a + b)
  let totalDeletions = group.files.mapIt(it.deletions).foldl(a + b)
  
  # Build commit message
  var message = fmt"{group.category}({group.scope}): "
  
  case group.category
  of "feat":
    message &= "add new functionality"
  of "fix":
    message &= "resolve issues"
  of "refactor":
    message &= "improve code structure"
  of "docs":
    message &= "update documentation"
  of "test":
    message &= "enhance test coverage"
  else:
    message &= "update configuration"
  
  message &= fmt"\n\n{group.reason}\n\n"
  message &= fmt"- Modified {fileCount} file(s)\n"
  message &= fmt"- Added {totalAdditions} lines\n"
  message &= fmt"- Removed {totalDeletions} lines\n\n"
  message &= "Files changed:\n"
  
  for file in group.files:
    message &= fmt"- {file.path} (+{file.additions}, -{file.deletions})\n"
  
  return message

proc runSemanticDivisionExample() =
  echo "=== Semantic Commit Division Example ==="
  echo "Analyzing a mixed commit for intelligent splitting..."
  
  # Ensure output directory exists
  createDir("build/analysis/reports")
  
  # Simulate a large mixed commit
  let mixedChanges = @[
    # Feature additions
    FileChange(path: "src/parser/json_parser.nim", additions: 150, deletions: 10, 
               hunks: @["proc parseObject*", "proc parseArray*"]),
    FileChange(path: "src/parser/yaml_parser.nim", additions: 200, deletions: 5,
               hunks: @["proc parseYaml*", "proc validateYaml*"]),
    
    # Bug fixes
    FileChange(path: "src/utils/string_utils.nim", additions: 20, deletions: 15,
               hunks: @["proc escapeString* # Fixed escape sequence bug"]),
    FileChange(path: "src/core/validator.nim", additions: 10, deletions: 8,
               hunks: @["proc validate* # Fixed nil check"]),
    
    # Tests
    FileChange(path: "tests/test_json_parser.nim", additions: 100, deletions: 0,
               hunks: @["test parseObject", "test parseArray"]),
    FileChange(path: "tests/test_string_utils.nim", additions: 30, deletions: 5,
               hunks: @["test escapeString with special chars"]),
    
    # Documentation
    FileChange(path: "docs/parser_guide.md", additions: 50, deletions: 10,
               hunks: @["## JSON Parser", "## YAML Parser"]),
    FileChange(path: "README.md", additions: 20, deletions: 5,
               hunks: @["### New Features", "### Bug Fixes"]),
    
    # Refactoring
    FileChange(path: "src/config/settings.nim", additions: 40, deletions: 60,
               hunks: @["Simplified configuration loading"])
  ]
  
  echo fmt"\nOriginal commit has {mixedChanges.len} files with mixed changes"
  echo "Analyzing semantic groups..."
  
  # Group changes semantically
  let semanticGroups = groupChangesSemantically(mixedChanges)
  
  echo fmt"\nIdentified {semanticGroups.len} semantic groups:"
  
  var divisionPlan: seq[JsonNode] = @[]
  
  for i, group in semanticGroups:
    echo fmt"\n--- Commit {i+1}: {group.category}({group.scope}) ---"
    echo fmt"Files: {group.files.len}"
    echo fmt"Reason: {group.reason}"
    
    let commitMessage = generateCommitMessage(group)
    echo "\nGenerated commit message:"
    echo commitMessage.indent(2)
    
    # Add to division plan
    divisionPlan.add(%*{
      "commitNumber": i + 1,
      "category": group.category,
      "scope": group.scope,
      "reason": group.reason,
      "message": commitMessage,
      "files": group.files.mapIt(%*{
        "path": it.path,
        "additions": it.additions,
        "deletions": it.deletions
      })
    })
  
  # Save division plan
  let planJson = %*{
    "timestamp": $now(),
    "originalCommit": {
      "fileCount": mixedChanges.len,
      "totalAdditions": mixedChanges.mapIt(it.additions).foldl(a + b),
      "totalDeletions": mixedChanges.mapIt(it.deletions).foldl(a + b)
    },
    "semanticDivision": {
      "commitCount": semanticGroups.len,
      "commits": divisionPlan
    }
  }
  
  writeFile("build/analysis/reports/commit_division_plan.json", planJson.pretty())
  echo "\n📄 Division plan saved to: build/analysis/reports/commit_division_plan.json"
  
  # Generate Jujutsu commands
  echo "\n--- Jujutsu Commands to Execute Division ---"
  echo "# Create a new working copy for each semantic commit"
  
  var jjCommands: seq[string] = @[]
  
  for i, group in semanticGroups:
    let branchName = fmt"{group.category}-{group.scope}-{i+1}"
    jjCommands.add(fmt"jj new -m 'WIP: {group.category}({group.scope})' @")
    
    for file in group.files:
      jjCommands.add(fmt"jj squash --into @ -- {file.path}")
    
    let message = generateCommitMessage(group)
    jjCommands.add(fmt"jj describe -m '{message.replace('\n', '\\n')}'")
    jjCommands.add("")  # Empty line for readability
  
  # Save commands script
  let scriptContent = jjCommands.join("\n")
  writeFile("build/analysis/reports/division_commands.sh", scriptContent)
  echo "\n📄 Jujutsu commands saved to: build/analysis/reports/division_commands.sh"
  
  # Analyze commit relationships
  echo "\n--- Commit Dependency Analysis ---"
  
  # Simple dependency detection based on shared modules
  var dependencies: seq[tuple[from: int, to: int, reason: string]] = @[]
  
  for i, group1 in semanticGroups:
    for j, group2 in semanticGroups:
      if i < j and group1.scope == group2.scope:
        dependencies.add((from: i, to: j, 
                         reason: fmt"Both modify {group1.scope} module"))
  
  if dependencies.len > 0:
    echo "\nDetected dependencies between commits:"
    for dep in dependencies:
      echo fmt"  - Commit {dep.from + 1} → Commit {dep.to + 1}: {dep.reason}"
  else:
    echo "\nNo dependencies detected - commits can be applied independently"
  
  # Save analysis summary
  let summaryJson = %*{
    "analysis": {
      "totalFiles": mixedChanges.len,
      "semanticGroups": semanticGroups.len,
      "dependencies": dependencies.mapIt(%*{
        "from": it.from + 1,
        "to": it.to + 1,
        "reason": it.reason
      })
    },
    "benefits": {
      "clarity": "Each commit has a single, clear purpose",
      "reviewability": "Smaller, focused commits are easier to review",
      "revertability": "Can revert specific changes without affecting others",
      "history": "Clean, semantic commit history"
    }
  }
  
  writeFile("build/analysis/reports/division_summary.json", summaryJson.pretty())
  echo "\n📄 Analysis summary saved to: build/analysis/reports/division_summary.json"

proc runClientSemanticDivision() {.async.} =
  echo "\n=== MCP Client Semantic Division Example ==="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Analyze a commit range
    echo "\n1. Analyzing commit range for semantic patterns..."
    let analysis = await client.analyzeCommitRange(repoPath, "HEAD~1..HEAD")
    
    let fileCount = analysis["analysis"]["fileCount"].getInt
    echo fmt"   Found {fileCount} files to analyze"
    
    # Try different strategies and compare
    echo "\n2. Comparing division strategies:"
    let strategies = @["semantic", "filetype", "directory", "balanced"]
    
    var bestStrategy = ""
    var bestConfidence = 0.0
    var bestProposal: JsonNode
    
    for strategy in strategies:
      let proposal = await client.proposeCommitDivision(
        repoPath,
        "HEAD~1..HEAD",
        strategy,
        "medium",
        10
      )
      
      let confidence = proposal["proposal"]["confidence"].getFloat
      let commitCount = proposal["proposal"]["proposedCommits"].len
      
      echo fmt"   {strategy}: {confidence:.1%} confidence, {commitCount} commits"
      
      if confidence > bestConfidence:
        bestConfidence = confidence
        bestStrategy = strategy
        bestProposal = proposal
    
    echo fmt"\n3. Best strategy: {bestStrategy} ({bestConfidence:.1%} confidence)"
    
    # Show the semantic division details
    echo "\n4. Proposed semantic commits:"
    let commits = bestProposal["proposal"]["proposedCommits"]
    
    for i, commit in commits:
      let msg = commit["message"].getStr
      let files = commit["changes"].len
      echo fmt"\n   Commit {i+1}: {msg}"
      echo fmt"   Files: {files}"
      
      # Show first 3 files as examples
      for j, change in commit["changes"]:
        if j >= 3:
          echo fmt"   ... and {files - 3} more files"
          break
        echo fmt"   - {change["path"].getStr}"
    
    # Save the analysis
    createDir("build/semantic_analysis")
    
    let analysisReport = %*{
      "timestamp": $now(),
      "repository": repoPath,
      "strategies": strategies.mapIt(%*{
        "name": it,
        "tested": true
      }),
      "bestStrategy": bestStrategy,
      "confidence": bestConfidence,
      "proposal": bestProposal["proposal"]
    }
    
    writeFile("build/semantic_analysis/division_analysis.json", analysisReport.pretty())
    echo "\n📄 Analysis saved to: build/semantic_analysis/division_analysis.json"
    
    # Optionally execute
    if bestConfidence >= 0.8:
      echo fmt"\n5. High confidence ({bestConfidence:.1%})! Execute division? (y/n): "
      let answer = stdin.readLine().toLowerAscii()
      
      if answer == "y":
        echo "   Executing semantic division..."
        let result = await client.executeCommitDivision(repoPath, bestProposal["proposal"])
        
        let commitIds = result["result"]["commitIds"]
        echo fmt"   ✅ Created {commitIds.len} semantic commits!"
        
        # Save execution result
        let execReport = %*{
          "timestamp": $now(),
          "strategy": bestStrategy,
          "commits": commitIds,
          "success": true
        }
        writeFile("build/semantic_analysis/execution_result.json", execReport.pretty())
    else:
      echo fmt"\n5. Confidence ({bestConfidence:.1%}) below threshold. Manual review recommended."
  
  except MpcError as e:
    echo fmt"\nError: {e.msg}"
    echo "Make sure the MCP server is running and you're in a Jujutsu repository."

when isMainModule:
  echo "Semantic Commit Division Examples"
  echo "================================"
  
  # Run the local analysis example
  runSemanticDivisionExample()
  
  # Run the client example
  echo "\n" & "=".repeat(50)
  waitFor runClientSemanticDivision()
  
  echo "\n✅ All semantic division examples completed!"