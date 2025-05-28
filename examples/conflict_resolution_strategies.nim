## Conflict Resolution Strategies Example
## Demonstrates analyzing and resolving conflicts using MCP-Jujutsu
## Shows how to use the client to understand complex merge scenarios

import std/[asyncdispatch, os, strutils, sequtils, tables, json, times, algorithm]
import mcp_jujutsu/client/client

# Conflict types and resolution strategies
type
  ConflictType = enum
    ctTextual = "textual"          # Simple text conflicts
    ctSemantic = "semantic"        # Code logic conflicts
    ctStructural = "structural"    # File structure conflicts
    ctBinary = "binary"           # Binary file conflicts
    ctDependency = "dependency"    # Package dependency conflicts

  ResolutionStrategy = enum
    rsManual = "manual"           # User resolves manually
    rsOurs = "ours"              # Keep our version
    rsTheirs = "theirs"          # Keep their version
    rsMerge = "merge"            # Attempt automatic merge
    rsSemantic = "semantic"       # Use semantic understanding
    rsRename = "rename"          # Rename conflicting items

  Conflict = object
    id: string
    conflictType: ConflictType
    file: string
    description: string
    ourChanges: seq[string]
    theirChanges: seq[string]
    baseContent: string
    suggestedResolution: ResolutionStrategy
    semanticAnalysis: JsonNode

  ConflictResolution = object
    conflictId: string
    strategy: ResolutionStrategy
    resolvedContent: string
    explanation: string
    confidence: float  # 0.0 to 1.0

# Example conflicts from a feature branch merge
let exampleConflicts = @[
  Conflict(
    id: "conf-001",
    conflictType: ctTextual,
    file: "src/api/userController.js",
    description: "Both branches modified the same function",
    ourChanges: @[
      "  async getUserProfile(req, res) {",
      "    const userId = req.params.id;",
      "    const includePreferences = req.query.preferences === 'true';",
      "    const user = await User.findById(userId);",
      "    if (includePreferences) {",
      "      user.preferences = await getUserPreferences(userId);",
      "    }",
      "    res.json(user);",
      "  }"
    ],
    theirChanges: @[
      "  async getUserProfile(req, res) {",
      "    const userId = req.params.id;",
      "    const user = await User.findById(userId).cache(300);",
      "    if (!user) {",
      "      return res.status(404).json({ error: 'User not found' });",
      "    }",
      "    res.json(user);",
      "  }"
    ],
    baseContent: """
  async getUserProfile(req, res) {
    const userId = req.params.id;
    const user = await User.findById(userId);
    res.json(user);
  }
""",
    suggestedResolution: rsSemantic
  ),
  Conflict(
    id: "conf-002",
    conflictType: ctSemantic,
    file: "src/models/User.js",
    description: "Conflicting schema modifications",
    ourChanges: @[
      "const UserSchema = new Schema({",
      "  name: String,",
      "  email: { type: String, unique: true },",
      "  preferences: {",
      "    theme: { type: String, default: 'light' },",
      "    notifications: { type: Boolean, default: true }",
      "  }",
      "});"
    ],
    theirChanges: @[
      "const UserSchema = new Schema({",
      "  name: String,",
      "  email: { type: String, unique: true },",
      "  settings: {",
      "    language: { type: String, default: 'en' },",
      "    timezone: { type: String, default: 'UTC' }",
      "  }",
      "});"
    ],
    baseContent: """
const UserSchema = new Schema({
  name: String,
  email: { type: String, unique: true }
});
""",
    suggestedResolution: rsMerge
  ),
  Conflict(
    id: "conf-003",
    conflictType: ctDependency,
    file: "package.json",
    description: "Different versions of the same dependency",
    ourChanges: @[
      '"dependencies": {',
      '  "express": "^4.18.0",',
      '  "mongoose": "^6.5.0",',
      '  "redis": "^4.2.0"',
      '}'
    ],
    theirChanges: @[
      '"dependencies": {',
      '  "express": "^4.17.0",',
      '  "mongoose": "^6.6.0",',
      '  "ioredis": "^5.0.0"',
      '}'
    ],
    baseContent: """
"dependencies": {
  "express": "^4.17.0",
  "mongoose": "^6.4.0"
}
""",
    suggestedResolution: rsSemantic
  )
]

# Semantic analysis functions
proc analyzeCodeSemantics(conflict: Conflict): JsonNode =
  ## Performs semantic analysis on code conflicts
  result = %* {
    "conflict_type": $conflict.conflictType,
    "semantic_changes": {
      "ours": [],
      "theirs": []
    },
    "compatibility": "unknown",
    "merge_possibility": 0.0,
    "risks": []
  }
  
  case conflict.id:
    of "conf-001":
      # Analyze getUserProfile conflict
      result["semantic_changes"]["ours"] = %* [
        {"type": "feature", "description": "Added preferences loading"},
        {"type": "parameter", "description": "Added query parameter handling"}
      ]
      result["semantic_changes"]["theirs"] = %* [
        {"type": "optimization", "description": "Added caching"},
        {"type": "error_handling", "description": "Added 404 response"}
      ]
      result["compatibility"] = %"compatible"
      result["merge_possibility"] = %0.9
      result["risks"] = %* ["Cache invalidation needed when preferences change"]
    
    of "conf-002":
      # Analyze schema conflict
      result["semantic_changes"]["ours"] = %* [
        {"type": "schema", "description": "Added preferences object"}
      ]
      result["semantic_changes"]["theirs"] = %* [
        {"type": "schema", "description": "Added settings object"}
      ]
      result["compatibility"] = %"mergeable"
      result["merge_possibility"] = %0.95
      result["risks"] = %* ["Both changes add different nested objects"]
    
    of "conf-003":
      # Analyze dependency conflict
      result["semantic_changes"]["ours"] = %* [
        {"type": "dependency", "description": "Added redis client"},
        {"type": "version", "description": "Updated mongoose to 6.5.0"}
      ]
      result["semantic_changes"]["theirs"] = %* [
        {"type": "dependency", "description": "Added ioredis client"},
        {"type": "version", "description": "Updated mongoose to 6.6.0"}
      ]
      result["compatibility"] = %"conflicting"
      result["merge_possibility"] = %0.3
      result["risks"] = %* [
        "Different Redis clients (redis vs ioredis)",
        "Potential mongoose API differences"
      ]

# Resolution strategies
proc resolveTextualConflict(conflict: Conflict): ConflictResolution =
  ## Resolves textual conflicts with semantic understanding
  let analysis = analyzeCodeSemantics(conflict)
  
  result.conflictId = conflict.id
  result.confidence = analysis["merge_possibility"].getFloat
  
  if result.confidence > 0.8:
    result.strategy = rsMerge
    # Merge both changes intelligently
    result.resolvedContent = """
  async getUserProfile(req, res) {
    const userId = req.params.id;
    const includePreferences = req.query.preferences === 'true';
    
    // Their optimization: caching
    const user = await User.findById(userId).cache(300);
    
    // Their error handling
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Our feature: preferences
    if (includePreferences) {
      user.preferences = await getUserPreferences(userId);
    }
    
    res.json(user);
  }
"""
    result.explanation = "Successfully merged both changes: caching, error handling, and preferences feature"
  else:
    result.strategy = rsManual
    result.resolvedContent = ""
    result.explanation = "Conflicts too complex for automatic resolution"

proc resolveSchemaConflict(conflict: Conflict): ConflictResolution =
  ## Resolves schema conflicts by merging compatible changes
  result.conflictId = conflict.id
  result.strategy = rsMerge
  result.confidence = 0.95
  
  result.resolvedContent = """
const UserSchema = new Schema({
  name: String,
  email: { type: String, unique: true },
  // Merged from both branches
  preferences: {
    theme: { type: String, default: 'light' },
    notifications: { type: Boolean, default: true }
  },
  settings: {
    language: { type: String, default: 'en' },
    timezone: { type: String, default: 'UTC' }
  }
});
"""
  result.explanation = "Merged both 'preferences' and 'settings' objects as they don't conflict"

proc resolveDependencyConflict(conflict: Conflict): ConflictResolution =
  ## Resolves dependency conflicts with compatibility checks
  result.conflictId = conflict.id
  
  # Analyze dependency compatibility
  let analysis = analyzeCodeSemantics(conflict)
  
  if analysis["compatibility"].getStr == "conflicting":
    result.strategy = rsManual
    result.confidence = 0.3
    result.resolvedContent = ""
    result.explanation = "Manual resolution needed: conflicting Redis libraries (redis vs ioredis)"
  else:
    result.strategy = rsSemantic
    result.confidence = 0.7
    result.resolvedContent = """
"dependencies": {
  "express": "^4.18.0",
  "mongoose": "^6.6.0",
  "redis": "^4.2.0"
}
"""
    result.explanation = "Selected newer compatible versions"

# Advanced conflict resolution workflow
proc executeConflictResolution*(conflicts: seq[Conflict]): seq[ConflictResolution] =
  ## Executes intelligent conflict resolution
  echo "Conflict Resolution Workflow"
  echo "==========================="
  
  for conflict in conflicts:
    echo &"\nProcessing conflict: {conflict.id}"
    echo &"Type: {conflict.conflictType}"
    echo &"File: {conflict.file}"
    echo &"Description: {conflict.description}"
    
    # Perform semantic analysis
    conflict.semanticAnalysis = analyzeCodeSemantics(conflict)
    echo "\nSemantic Analysis:"
    echo conflict.semanticAnalysis.pretty
    
    # Apply appropriate resolution strategy
    let resolution = case conflict.conflictType:
      of ctTextual: resolveTextualConflict(conflict)
      of ctSemantic: resolveSchemaConflict(conflict)
      of ctDependency: resolveDependencyConflict(conflict)
      else: ConflictResolution(
        conflictId: conflict.id,
        strategy: rsManual,
        confidence: 0.0,
        explanation: "No automatic resolution available"
      )
    
    result.add(resolution)
    
    echo &"\nResolution:"
    echo &"  Strategy: {resolution.strategy}"
    echo &"  Confidence: {resolution.confidence * 100:.1f}%"
    echo &"  Explanation: {resolution.explanation}"
    
    if resolution.resolvedContent.len > 0:
      echo "\nResolved content:"
      echo resolution.resolvedContent.indent(2)

# Conflict visualization and reporting
proc generateConflictReport*(conflicts: seq[Conflict], 
                           resolutions: seq[ConflictResolution]): JsonNode =
  ## Generates comprehensive conflict resolution report
  result = %* {
    "report_generated": now().format("yyyy-MM-dd HH:mm:ss"),
    "total_conflicts": conflicts.len,
    "resolution_summary": {
      "automatic": 0,
      "manual": 0,
      "high_confidence": 0,
      "low_confidence": 0
    },
    "conflicts_by_type": {},
    "detailed_resolutions": [],
    "recommendations": []
  }
  
  # Count resolutions by type
  for resolution in resolutions:
    if resolution.strategy != rsManual:
      result["resolution_summary"]["automatic"] = 
        result["resolution_summary"]["automatic"].getInt + 1
    else:
      result["resolution_summary"]["manual"] = 
        result["resolution_summary"]["manual"].getInt + 1
    
    if resolution.confidence > 0.8:
      result["resolution_summary"]["high_confidence"] = 
        result["resolution_summary"]["high_confidence"].getInt + 1
    else:
      result["resolution_summary"]["low_confidence"] = 
        result["resolution_summary"]["low_confidence"].getInt + 1
  
  # Group conflicts by type
  for conflict in conflicts:
    let typeStr = $conflict.conflictType
    if typeStr notin result["conflicts_by_type"]:
      result["conflicts_by_type"][typeStr] = %0
    result["conflicts_by_type"][typeStr] = 
      result["conflicts_by_type"][typeStr].getInt + 1
  
  # Add detailed resolution information
  for i, conflict in conflicts:
    let resolution = resolutions[i]
    result["detailed_resolutions"].add(%* {
      "conflict_id": conflict.id,
      "file": conflict.file,
      "type": $conflict.conflictType,
      "resolution_strategy": $resolution.strategy,
      "confidence": resolution.confidence,
      "automated": resolution.strategy != rsManual,
      "risks": conflict.semanticAnalysis["risks"]
    })
  
  # Generate recommendations
  let autoRate = result["resolution_summary"]["automatic"].getInt / 
                 conflicts.len * 100
  
  if autoRate < 50:
    result["recommendations"].add(
      %"Many conflicts require manual resolution. Consider clearer separation of concerns."
    )
  
  if result["conflicts_by_type"].hasKey("dependency"):
    result["recommendations"].add(
      %"Dependency conflicts detected. Consider using a dependency management strategy."
    )

# Interactive conflict resolution helper
proc interactiveResolution*(conflict: Conflict): ConflictResolution =
  ## Provides interactive conflict resolution interface
  echo "\n" & "=" * 60
  echo "Interactive Conflict Resolution"
  echo "=" * 60
  echo &"\nFile: {conflict.file}"
  echo &"Type: {conflict.conflictType}"
  echo "\nBase version:"
  echo conflict.baseContent.indent(2)
  echo "\nOur changes:"
  for line in conflict.ourChanges:
    echo "  + " & line
  echo "\nTheir changes:"
  for line in conflict.theirChanges:
    echo "  + " & line
  
  let analysis = analyzeCodeSemantics(conflict)
  echo "\nSemantic analysis:"
  echo &"  Compatibility: {analysis[\"compatibility\"].getStr}"
  echo &"  Auto-merge possibility: {analysis[\"merge_possibility\"].getFloat * 100:.1f}%"
  
  if analysis["risks"].len > 0:
    echo "  Risks:"
    for risk in analysis["risks"]:
      echo &"    - {risk.getStr}"
  
  # In a real implementation, this would prompt for user input
  result = ConflictResolution(
    conflictId: conflict.id,
    strategy: rsManual,
    confidence: 1.0,
    explanation: "User manually resolved conflict"
  )

# Main demonstration
proc demonstrateConflictResolution*() =
  echo "Advanced Conflict Resolution Demonstration"
  echo "========================================="
  
  # Execute automatic resolution
  let resolutions = executeConflictResolution(exampleConflicts)
  
  # Generate comprehensive report
  let outputDir = "build/conflict-resolution"
  createDir(outputDir)
  
  let report = generateConflictReport(exampleConflicts, resolutions)
  writeFile(outputDir / "conflict-report.json", report.pretty)
  
  echo &"\n\nConflict resolution report saved to: {outputDir}/conflict-report.json"
  
  # Summary
  echo "\nResolution Summary:"
  echo &"  Total conflicts: {exampleConflicts.len}"
  echo &"  Automatically resolved: {report[\"resolution_summary\"][\"automatic\"].getInt}"
  echo &"  Requiring manual resolution: {report[\"resolution_summary\"][\"manual\"].getInt}"
  echo &"  High confidence resolutions: {report[\"resolution_summary\"][\"high_confidence\"].getInt}"
  
  echo "\nRecommendations:"
  for rec in report["recommendations"]:
    echo &"  • {rec.getStr}"

proc demonstrateMcpConflictAnalysis() {.async.} =
  echo "\n\nMCP-Based Conflict Analysis"
  echo "==========================="
  
  let repoPath = if paramCount() > 0: paramStr(1) else: getCurrentDir()
  let client = newMcpClient("http://localhost:8080/mcp")
  
  try:
    # Analyze a merge conflict scenario
    echo "\n1. Analyzing merge conflict between branches..."
    
    # In a real scenario, you would have actual conflicting branches
    # For this example, we'll analyze commits that might conflict
    let baseAnalysis = await client.analyzeCommitRange(repoPath, "HEAD~2..HEAD~1")
    let featureAnalysis = await client.analyzeCommitRange(repoPath, "HEAD~1..HEAD")
    
    echo "\nBase branch changes:"
    echo fmt"  Files: {baseAnalysis[\"analysis\"][\"fileCount\"].getInt}"
    echo fmt"  Changes: +{baseAnalysis[\"analysis\"][\"totalAdditions\"].getInt} -{baseAnalysis[\"analysis\"][\"totalDeletions\"].getInt}"
    
    echo "\nFeature branch changes:"
    echo fmt"  Files: {featureAnalysis[\"analysis\"][\"fileCount\"].getInt}"
    echo fmt"  Changes: +{featureAnalysis[\"analysis\"][\"totalAdditions\"].getInt} -{featureAnalysis[\"analysis\"][\"totalDeletions\"].getInt}"
    
    # Use semantic analysis to predict conflicts
    echo "\n2. Using semantic analysis to predict merge conflicts..."
    
    let semanticProposal = await client.proposeCommitDivision(
      repoPath,
      "HEAD~2..HEAD",
      "semantic",
      "medium",
      10
    )
    
    # Analyze commit structure for potential conflicts
    echo "\n3. Analyzing commit structure for conflict patterns..."
    
    let commits = semanticProposal["proposal"]["proposedCommits"]
    var potentialConflicts: seq[string] = @[]
    
    # Check for files modified in multiple semantic groups
    var fileModifications = initTable[string, seq[string]]()
    
    for i, commit in commits:
      for change in commit["changes"]:
        let path = change["path"].getStr
        if path notin fileModifications:
          fileModifications[path] = @[]
        fileModifications[path].add(fmt"Commit {i+1}: {commit[\"message\"].getStr}")
    
    for path, modifications in fileModifications:
      if modifications.len > 1:
        potentialConflicts.add(path)
        echo fmt"\n   ⚠️  Potential conflict in: {path}"
        for mod in modifications:
          echo fmt"      - {mod}"
    
    if potentialConflicts.len == 0:
      echo "\n   ✅ No potential conflicts detected in commit structure"
    
    # Generate conflict resolution strategy
    echo "\n4. Recommended conflict resolution strategy:"
    
    if potentialConflicts.len > 0:
      echo "   Based on semantic analysis:"
      echo "   1. Split commits by semantic purpose first"
      echo "   2. Resolve conflicts file by file"
      echo "   3. Use semantic understanding to merge logic"
      echo "   4. Test each resolution independently"
    else:
      echo "   Clean merge possible - commits affect different areas"
    
    # Save analysis report
    createDir("build/conflict-analysis")
    
    let conflictReport = %*{
      "timestamp": $now(),
      "repository": repoPath,
      "analysis": {
        "baseChanges": baseAnalysis["analysis"],
        "featureChanges": featureAnalysis["analysis"],
        "semanticGroups": commits.len,
        "potentialConflicts": potentialConflicts
      },
      "recommendations": {
        "splitStrategy": "semantic",
        "conflictFiles": potentialConflicts,
        "resolutionOrder": if potentialConflicts.len > 0: 
          "Resolve core logic first, then dependencies" 
        else: 
          "Direct merge possible"
      }
    }
    
    writeFile("build/conflict-analysis/mcp_conflict_report.json", conflictReport.pretty())
    echo "\n\n📄 MCP conflict analysis saved to: build/conflict-analysis/mcp_conflict_report.json"
    
  except MpcError as e:
    echo fmt"\nError: {e.msg}"
    echo "Ensure the MCP server is running and you're in a Jujutsu repository."

when isMainModule:
  # Run the local conflict resolution demo
  demonstrateConflictResolution()
  
  # Run the MCP-based analysis
  waitFor demonstrateMcpConflictAnalysis()