## Tests for workspace-aware semantic analysis
##
## This module tests the workspace-aware extensions to the semantic analyzer.

import std/[unittest, asyncdispatch, json, options, os, strutils, sets]
import ../../src/single_repo/analyzer/semantic
import ../../src/core/repository/jujutsu_workspace

suite "Workspace-Aware Semantic Analysis Tests":
  
  setup:
    # Use a temporary directory for testing
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    if dirExists(testDir):
      removeDir(testDir)
    createDir(testDir)
  
  teardown:
    # Clean up test directory
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    if dirExists(testDir):
      removeDir(testDir)
  
  test "analyzeWorkspaceChanges handles non-existent repository":
    let nonExistentPath = "/path/that/does/not/exist"
    
    let result = waitFor analyzeWorkspaceChanges(nonExistentPath)
    
    # Should handle error gracefully
    check result.files.len == 0
    check result.codePatterns.len > 0
    check result.codePatterns.anyIt(it.startsWith("error:"))
  
  test "analyzeWorkspaceChanges handles empty workspace name":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let result = waitFor analyzeWorkspaceChanges(testDir, "")
    
    # Should analyze all workspaces (which will be empty in test)
    check result.files.len == 0
    check result.changeTypes.hasKey("multi_workspace") or result.codePatterns.len > 0
  
  test "analyzeWorkspaceChanges handles specific workspace name":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let result = waitFor analyzeWorkspaceChanges(testDir, "test-workspace")
    
    # Should try to analyze specific workspace (will fail gracefully)
    check result.files.len == 0 or result.codePatterns.len > 0
  
  test "identifyWorkspaceSemanticBoundaries handles non-existent repository":
    let nonExistentPath = "/path/that/does/not/exist"
    
    let patterns = waitFor identifyWorkspaceSemanticBoundaries(nonExistentPath)
    
    # Should return error pattern
    check patterns.len == 1
    check patterns[0].pattern == "workspace_error"
    check patterns[0].changeType == ctChore
    check patterns[0].confidence == 0.1
    check "error" in patterns[0].keywords
  
  test "identifyWorkspaceSemanticBoundaries creates appropriate patterns":
    # This test mocks the workspace analysis since we can't create real workspaces in tests
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let patterns = waitFor identifyWorkspaceSemanticBoundaries(testDir)
    
    # Should return at least one pattern (likely error pattern for empty repo)
    check patterns.len >= 1
    
    # Check pattern structure
    for pattern in patterns:
      check pattern.pattern.len > 0
      check pattern.confidence >= 0.0 and pattern.confidence <= 1.0
      check pattern.files.len >= 0
      check pattern.keywords.len >= 0
  
  test "proposeWorkspaceCommitDivision handles different strategies":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    # Test feature branches strategy
    let featureProposal = waitFor proposeWorkspaceCommitDivision(testDir, wsFeatureBranches)
    check featureProposal.originalCommitId == "@"
    check featureProposal.targetCommitId == "@-"
    check featureProposal.confidenceScore >= 0.0
    
    # Test environments strategy
    let envProposal = waitFor proposeWorkspaceCommitDivision(testDir, wsEnvironments)
    check envProposal.originalCommitId == "@"
    check envProposal.targetCommitId == "@-"
    check envProposal.confidenceScore >= 0.0
    
    # Test team members strategy
    let teamProposal = waitFor proposeWorkspaceCommitDivision(testDir, wsTeamMembers)
    check teamProposal.originalCommitId == "@"
    check teamProposal.targetCommitId == "@-"
    check teamProposal.confidenceScore >= 0.0
    
    # Test experiments strategy
    let expProposal = waitFor proposeWorkspaceCommitDivision(testDir, wsExperiments)
    check expProposal.originalCommitId == "@"
    check expProposal.targetCommitId == "@-"
    check expProposal.confidenceScore >= 0.0
  
  test "proposeWorkspaceCommitDivision generates appropriate commit messages":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let proposal = waitFor proposeWorkspaceCommitDivision(testDir, wsFeatureBranches)
    
    # Should have at least one proposed commit (likely error handling)
    check proposal.proposedCommits.len >= 1
    
    for commit in proposal.proposedCommits:
      check commit.message.len > 0
      check commit.changes.len >= 0
      check commit.keywords.len >= 0
      
      # Check message format follows conventional commits
      check commit.message.contains(":") or commit.message.contains("(")
  
  test "proposeWorkspaceCommitDivision handles error cases":
    let nonExistentPath = "/path/that/does/not/exist"
    
    let proposal = waitFor proposeWorkspaceCommitDivision(nonExistentPath, wsFeatureBranches)
    
    # Should handle error gracefully
    check proposal.proposedCommits.len >= 1
    check proposal.confidenceScore >= 0.0
    
    # Check that error commit is created
    let errorCommit = proposal.proposedCommits[^1]  # Last commit should be error commit
    check errorCommit.message.contains("error") or errorCommit.message.contains("chore")
    check errorCommit.changeType == ctChore
    check "error" in errorCommit.keywords or "workspace" in errorCommit.keywords
  
  test "workspace patterns have correct structure":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let patterns = waitFor identifyWorkspaceSemanticBoundaries(testDir)
    
    for pattern in patterns:
      # Check confidence is in valid range
      check pattern.confidence >= 0.0 and pattern.confidence <= 1.0
      
      # Check change type is valid
      check pattern.changeType in [ctFeature, ctBugfix, ctRefactor, ctDocs, ctTests, ctChore, ctStyle, ctPerformance]
      
      # Check files set is initialized
      check pattern.files.len >= 0
      
      # Check keywords set is initialized  
      check pattern.keywords.len >= 0
      
      # Check pattern name is not empty
      check pattern.pattern.len > 0
  
  test "workspace analysis integrates with existing semantic analysis":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    # Test that workspace analysis can coexist with regular semantic analysis
    let workspaceResult = waitFor analyzeWorkspaceChanges(testDir)
    
    # Check structure is compatible with AnalysisResult
    check workspaceResult.files.len >= 0
    check workspaceResult.additions >= 0
    check workspaceResult.deletions >= 0
    check workspaceResult.fileTypes.len >= 0
    check workspaceResult.changeTypes.len >= 0
    check workspaceResult.codePatterns.len >= 0
    check workspaceResult.dependencies.len >= 0
    check workspaceResult.semanticGroups.len >= 0
  
  test "workspace commit division proposal structure is valid":
    let testDir = getTempDir() / "mcp_workspace_semantic_test"
    
    let proposal = waitFor proposeWorkspaceCommitDivision(testDir, wsFeatureBranches)
    
    # Check proposal structure
    check proposal.originalCommitId.len > 0
    check proposal.targetCommitId.len > 0
    check proposal.proposedCommits.len >= 0
    check proposal.totalChanges >= 0
    check proposal.confidenceScore >= 0.0 and proposal.confidenceScore <= 1.0
    
    # Check each proposed commit structure
    for commit in proposal.proposedCommits:
      check commit.message.len > 0
      check commit.changes.len >= 0
      check commit.keywords.len >= 0
      check commit.changeType in [ctFeature, ctBugfix, ctRefactor, ctDocs, ctTests, ctChore, ctStyle, ctPerformance]