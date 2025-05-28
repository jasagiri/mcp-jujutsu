## Basic tests for semantic analyzer
##
## Tests core functionality without complex edge cases

import std/[unittest, asyncdispatch, json, sets, strutils, tables]
import ../../src/single_repo/analyzer/semantic
import ../../src/core/repository/jujutsu

suite "Semantic Analyzer Basic Tests":
  
  test "ChangeType enum values":
    # Test that all change types are defined
    check ord(ctFeature) >= 0
    check ord(ctBugfix) >= 0
    check ord(ctRefactor) >= 0
    check ord(ctDocs) >= 0
    check ord(ctTests) >= 0
    check ord(ctChore) >= 0
    check ord(ctStyle) >= 0
    check ord(ctPerformance) >= 0
  
  test "FileDiff structure":
    # Test basic FileDiff creation
    let diff = FileDiff(
      path: "test.nim",
      changeType: "modify",
      diff: "+added line\n-removed line"
    )
    
    check diff.path == "test.nim"
    check diff.changeType == "modify"
    check diff.diff.len > 0
  
  test "DiffResult structure":
    # Test DiffResult creation
    let result = DiffResult(
      commitRange: "abc123..def456",
      files: @[
        FileDiff(path: "file1.nim", changeType: "add", diff: "+new file"),
        FileDiff(path: "file2.nim", changeType: "modify", diff: "+change")
      ],
      stats: %*{"added": 10, "removed": 5}
    )
    
    check result.commitRange == "abc123..def456"
    check result.files.len == 2
    check result.stats["added"].getInt() == 10
  
  test "Basic pattern detection":
    # Test that patterns can be created
    let pattern = CodePattern(
      pattern: "function definition",
      regex: "proc.*\\(",
      changeType: ctFeature,
      weight: 1.0
    )
    
    check pattern.pattern == "function definition"
    check pattern.changeType == ctFeature
    check pattern.weight == 1.0
  
  test "CommitDivisionProposal structure":
    # Test proposal creation
    let proposal = CommitDivisionProposal(
      originalCommitId: "original123",
      targetCommitId: "target456",
      proposedCommits: @[],
      totalChanges: 15,
      confidenceScore: 0.85
    )
    
    check proposal.originalCommitId == "original123"
    check proposal.targetCommitId == "target456"
    check proposal.totalChanges == 15
    check proposal.confidenceScore == 0.85
  
  test "ProposedCommit structure":
    # Test proposed commit creation
    let proposed = ProposedCommit(
      message: "feat: add new feature",
      changes: @[],
      changeType: ctFeature,
      keywords: @["add", "feature", "new"]
    )
    
    check proposed.message == "feat: add new feature"
    check proposed.changeType == ctFeature
    check proposed.keywords.len == 3
  
  test "AnalysisResult initialization":
    # Test analysis result creation
    var result = AnalysisResult()
    result.files = @["file1.nim", "file2.nim"]
    result.additions = 100
    result.deletions = 50
    result.fileTypes["nim"] = 2
    result.changeTypes["feature"] = 1
    result.codePatterns = @["pattern1", "pattern2"]
    
    check result.files.len == 2
    check result.additions == 100
    check result.deletions == 50
    check result.fileTypes["nim"] == 2
    check result.changeTypes["feature"] == 1
    check result.codePatterns.len == 2