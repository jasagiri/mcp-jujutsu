## Test cases for semantic analyzer module (simplified)
##
## This module provides tests for semantic analysis of code changes.

import unittest, asyncdispatch, json, options, sets, tables, strutils
import ../../src/single_repo/analyzer/semantic
import ../../src/core/repository/jujutsu

# Helper function to check if a string contains a substring
proc hasSubstring(s, sub: string): bool =
  return strutils.find(s, sub) >= 0

suite "Semantic Analyzer Tests":
  
  setup:
    # Create sample diff data for testing
    let diffResult = DiffResult(
      commitRange: "HEAD~1..HEAD",
      files: @[
        FileDiff(
          path: "src/file1.nim",
          changeType: "modify",
          diff: """diff --git a/src/file1.nim b/src/file1.nim
--- a/src/file1.nim
+++ b/src/file1.nim
@@ -10,7 +10,7 @@ proc someFunction() =
   echo "Hello, world!"
   
-proc buggyFunction() =
-  echo "This has a bug"
+proc fixedFunction() =
+  echo "The bug is fixed now"
   
 proc otherFunction() =
   echo "Other function"
"""
        ),
        FileDiff(
          path: "src/file2.nim",
          changeType: "add",
          diff: """diff --git a/src/file2.nim b/src/file2.nim
new file mode 100644
--- /dev/null
+++ b/src/file2.nim
@@ -0,0 +1,5 @@
+proc newFeature() =
+  echo "This is a new feature"
+  
+proc helperFunction() =
+  echo "This is a helper function"
"""
        ),
        FileDiff(
          path: "docs/readme.md",
          changeType: "modify",
          diff: """diff --git a/docs/readme.md b/docs/readme.md
--- a/docs/readme.md
+++ b/docs/readme.md
@@ -1,3 +1,5 @@
 # Sample Project
 
 This is a sample project.
+
+Added documentation for the new feature.
"""
        )
      ]
    )
  
  test "Analyze Changes":
    let analysisResult = waitFor analyzeChanges(diffResult)
    
    # Verify files are counted correctly
    check(analysisResult.files.len == 3)
    
    # Verify change types are counted correctly
    check(analysisResult.changeTypes["modify"] == 2)
    check(analysisResult.changeTypes["add"] == 1)
    
    # Verify file types are identified correctly
    check(analysisResult.fileTypes["nim"] == 2)
    check(analysisResult.fileTypes["md"] == 1)
  
  test "Identify Semantic Boundaries":
    let patterns = waitFor identifySemanticBoundaries(diffResult)
    
    # Verify patterns are extracted
    check(patterns.len > 0)
    
    # Find patterns - look for documentation and code patterns
    var foundDocPattern = false
    var foundCodePattern = false
    
    for pattern in patterns:
      # Check if this pattern includes documentation files
      if "docs/readme.md" in pattern.files:
        foundDocPattern = true
        # The analysis may classify differently based on content
        # Just verify that we found the doc pattern
        check(pattern.changeType in [ctDocs, ctFeature, ctChore])
      
      # Check if this pattern includes source files
      if "src/file1.nim" in pattern.files or "src/file2.nim" in pattern.files:
        foundCodePattern = true
    
    # Should find both patterns
    check(foundDocPattern)
    check(foundCodePattern)
  
  test "Generate Commit Message":
    let files = ["src/file1.nim", "src/file2.nim"].toHashSet()
    
    # Test bug fix pattern
    let bugFixMsg = generateCommitMessage("Fix bug in function", files)
    check(hasSubstring(bugFixMsg, "fix"))
    
    # Test feature pattern
    let featureMsg = generateCommitMessage("Add new feature", files)
    check(hasSubstring(featureMsg, "feat"))
    
    # Test docs pattern
    let docsMsg = generateCommitMessage("Update documentation", files)
    check(hasSubstring(docsMsg, "docs"))
  
  test "Generate Semantic Division Proposal":
    let proposal = waitFor generateSemanticDivisionProposal(diffResult)
    
    # Verify proposal contains original commit info
    check(proposal.originalCommitId == "HEAD~1")
    check(proposal.targetCommitId == "HEAD")
    
    # Verify proposal has commits
    check(proposal.proposedCommits.len > 0)
    
    # Verify total changes
    check(proposal.totalChanges == 3)
    
    # Verify all files are included in proposed commits
    var allFiles: HashSet[string]
    for commit in proposal.proposedCommits:
      for change in commit.changes:
        allFiles.incl(change.path)
    
    check("src/file1.nim" in allFiles)
    check("src/file2.nim" in allFiles)
    check("docs/readme.md" in allFiles)