## Robust end-to-end tests that work without Jujutsu
##
## This module provides tests that validate the multi-repository
## functionality even when Jujutsu is not available.

import unittest, asyncdispatch, json, options, tables, os, strutils, sequtils, times, sets
import ../../src/multi_repo/tools/multi_repo
import ../../src/multi_repo/repository/manager
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/core/repository/jujutsu
import ../../src/single_repo/analyzer/semantic as single_semantic

# Create mock diff data for testing
proc createMockDiff(path: string, changeType: string, content: string): jujutsu.FileDiff =
  ## Creates a mock FileDiff with realistic content
  var diff = "diff --git a/" & path & " b/" & path & "\n"
  
  case changeType
  of "add":
    diff &= "new file mode 100644\n"
    diff &= "--- /dev/null\n"
    diff &= "+++ b/" & path & "\n"
    diff &= "@@ -0,0 +1,10 @@\n"
    for line in content.splitLines()[0..min(9, content.splitLines().len-1)]:
      diff &= "+" & line & "\n"
  of "modify":
    diff &= "--- a/" & path & "\n"
    diff &= "+++ b/" & path & "\n"
    diff &= "@@ -1,5 +1,5 @@\n"
    diff &= "-old content\n"
    diff &= "+new content\n"
    for line in content.splitLines()[0..min(3, content.splitLines().len-1)]:
      diff &= "+" & line & "\n"
  else:
    discard
  
  return jujutsu.FileDiff(
    path: path,
    changeType: changeType,
    diff: diff
  )

suite "Robust End-to-End Tests":
  var manager: RepositoryManager
  var baseDir: string
  
  setup:
    baseDir = getTempDir() / "mcp_jujutsu_robust_test_" & $epochTime().int
    createDir(baseDir)
    manager = newRepositoryManager(baseDir)
    
    # Add test repositories
    manager.addRepository(Repository(
      name: "core-lib",
      path: baseDir / "core-lib"
    ))
    
    manager.addRepository(Repository(
      name: "api-service",
      path: baseDir / "api-service",
      dependencies: @["core-lib"]
    ))
    
    manager.addRepository(Repository(
      name: "frontend-app",
      path: baseDir / "frontend-app",
      dependencies: @["api-service"]
    ))
  
  teardown:
    if dirExists(baseDir):
      removeDir(baseDir)
  
  test "Mock Analysis Without Jujutsu":
    # Create a mock diff directly
    var mockDiff = CrossRepoDiff(
      repositories: toSeq(manager.repos.values),
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    # Add mock changes
    mockDiff.changes["core-lib"] = @[
      createMockDiff("src/models.nim", "modify", """type User* = object
  id*: string
  email*: string"""),
      createMockDiff("src/auth.nim", "modify", """import models
proc authenticate*(user: User): bool""")
    ]
    
    mockDiff.changes["api-service"] = @[
      createMockDiff("src/routes.nim", "modify", """import core-lib/models
import core-lib/auth

proc handleLogin*() = discard""")
    ]
    
    mockDiff.changes["frontend-app"] = @[
      createMockDiff("src/login.ts", "modify", """export function login(email: string) {
  return fetch('/api/login', { body: JSON.stringify({ email }) });
}""")
    ]
    
    # Test dependency detection
    let dependencies = waitFor identifyCrossRepoDependencies(mockDiff)
    check(dependencies.len > 0)
    
    # Find core-lib import dependency
    var foundImport = false
    for dep in dependencies:
      if dep.source == "api-service" and dep.target == "core-lib" and dep.dependencyType == "import":
        foundImport = true
        break
    
    check(foundImport)
  
  test "Mock Proposal Generation":
    # Create mock diff
    var mockDiff = CrossRepoDiff(
      repositories: toSeq(manager.repos.values),
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    mockDiff.changes["core-lib"] = @[
      createMockDiff("src/models.nim", "modify", "type User* = object")
    ]
    mockDiff.changes["api-service"] = @[
      createMockDiff("src/api.nim", "modify", "import core-lib/models")
    ]
    mockDiff.changes["frontend-app"] = @[
      createMockDiff("src/app.ts", "modify", "fetch('/api')")
    ]
    
    # Generate proposal
    let proposal = waitFor generateCrossRepoProposal(mockDiff, manager)
    
    # Basic checks
    check(proposal.commitGroups.len > 0)
    check(proposal.confidenceScore >= 0.0)
    
    # Check all repos are included
    var repos = initHashSet[string]()
    for group in proposal.commitGroups:
      for commit in group.commits:
        repos.incl(commit.repository)
    
    check(repos.len == 3)
    check("core-lib" in repos)
    check("api-service" in repos)
    check("frontend-app" in repos)
  
  test "Empty Diff Handling":
    # Test with empty diff
    var emptyDiff = CrossRepoDiff(
      repositories: toSeq(manager.repos.values),
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    # Initialize empty changes
    for repo in emptyDiff.repositories:
      emptyDiff.changes[repo.name] = @[]
    
    # Should not crash
    let dependencies = waitFor identifyCrossRepoDependencies(emptyDiff)
    check(dependencies.len == 0)
    
    let proposal = waitFor generateCrossRepoProposal(emptyDiff, manager)
    check(proposal.commitGroups.len == 0)
    check(proposal.confidenceScore == 0.0)
  
  test "Semantic Analysis":
    # Create diff with different types of changes
    var mockDiff = CrossRepoDiff(
      repositories: toSeq(manager.repos.values),
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    mockDiff.changes["core-lib"] = @[
      createMockDiff("src/feature.nim", "add", """proc newFeature*(): string =
  ## This is a new feature
  return "feature""""),
      createMockDiff("tests/test_feature.nim", "add", """import unittest
test "new feature": check(newFeature() == "feature")""")
    ]
    
    mockDiff.changes["api-service"] = @[
      createMockDiff("src/fix.nim", "modify", """# Fixed bug in authentication
proc authenticate() = discard # fixed""")
    ]
    
    # Analyze semantics
    let semanticGroups = analyzeSemanticsAcrossRepos(mockDiff)
    
    # Should have feature and test changes
    check(semanticGroups.hasKey(single_semantic.ChangeType.ctFeature))
    check(semanticGroups.hasKey(single_semantic.ChangeType.ctTests))
    
    # Generate proposal with semantic grouping
    let proposal = waitFor generateCrossRepoProposal(mockDiff, manager)
    check(proposal.commitGroups.len > 0)
    
    # Check for different change types
    var hasFeature = false
    var hasTest = false
    
    for group in proposal.commitGroups:
      if group.changeType == single_semantic.ChangeType.ctFeature:
        hasFeature = true
      elif group.changeType == single_semantic.ChangeType.ctTests:
        hasTest = true
    
    check(hasFeature or hasTest)