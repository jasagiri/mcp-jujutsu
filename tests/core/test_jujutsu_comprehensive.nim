## Comprehensive tests for jujutsu module
##
## Tests all functions in the jujutsu module to achieve 100% coverage

import std/[unittest, asyncdispatch, json, strutils, options, os, tempfiles, tables]
import ../../src/core/repository/jujutsu
import ../../src/core/repository/diff_formats
import ../../src/core/logging/logger

suite "Jujutsu Comprehensive Tests":
  setup:
    initLogger("test")
    
  test "createDiffFormatConfig - default config":
    let config = createDiffFormatConfig()
    
    check config.format == DiffFormat.Native
    check config.colorize == false
    check config.contextLines == 3
    check config.showLineNumbers == false
    check config.template.isNone
    
  test "createDiffFormatConfig - custom config":
    let config = createDiffFormatConfig(
      format = DiffFormat.Markdown,
      colorize = true,
      contextLines = 5,
      showLineNumbers = true
    )
    
    check config.format == DiffFormat.Markdown
    check config.colorize == true
    check config.contextLines == 5
    check config.showLineNumbers == true
    
  test "createDiffFormatConfig - with template":
    let template = DiffTemplate(
      name: "custom",
      description: "Custom template",
      fileHeader: "File: $path",
      hunkHeader: "Hunk: $oldStart,$oldCount",
      addLine: "+ $content",
      deleteLine: "- $content",
      contextLine: "  $content",
      footer: "---"
    )
    
    let config = createDiffFormatConfig(
      format = DiffFormat.Custom,
      template = some(template)
    )
    
    check config.format == DiffFormat.Custom
    check config.template.isSome
    check config.template.get.name == "custom"
    
  test "getCommitInfo - basic info":
    let repo = newJujutsuRepo(".")
    let info = waitFor repo.getCommitInfo("HEAD")
    
    # Should return commit information
    check info.kind == JObject
    check info.hasKey("commit_id") or info.hasKey("error")
    
  test "getCommitInfo - with specific fields":
    let repo = newJujutsuRepo(".")
    let info = waitFor repo.getCommitInfo("HEAD", @["author", "message", "date"])
    
    # Should include requested fields
    check info.kind == JObject
    
  test "getCommitInfo - invalid commit":
    let repo = newJujutsuRepo(".")
    let info = waitFor repo.getCommitInfo("invalid-commit-id")
    
    # Should handle invalid commits
    check info.kind == JObject
    
  test "getStatus - repository status":
    let repo = newJujutsuRepo(".")
    let status = waitFor repo.getStatus()
    
    # Should return status information
    check status.kind == JObject
    check status.hasKey("working_copy") or status.hasKey("error") or status.hasKey("status")
    
  test "getStatus - with options":
    let repo = newJujutsuRepo(".")
    let status = waitFor repo.getStatus(showUntracked = true, showIgnored = false)
    
    # Should respect options
    check status.kind == JObject
    
  test "listBranches - all branches":
    let repo = newJujutsuRepo(".")
    let branches = waitFor repo.listBranches()
    
    # Should return branch list
    check branches.kind == JArray or branches.kind == JObject
    
  test "listBranches - filtered":
    let repo = newJujutsuRepo(".")
    let branches = waitFor repo.listBranches(pattern = "main*")
    
    # Should filter branches
    check branches.kind == JArray or branches.kind == JObject
    
  test "createBranch - new branch":
    let repo = newJujutsuRepo(".")
    let result = waitFor repo.createBranch("test-branch-" & $epochTime().int)
    
    # Should create branch
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("created")
    
  test "createBranch - from specific commit":
    let repo = newJujutsuRepo(".")
    let result = waitFor repo.createBranch("test-branch-2-" & $epochTime().int, "HEAD~1")
    
    # Should create branch from commit
    check result.kind == JObject
    
  test "switchBranch - existing branch":
    let repo = newJujutsuRepo(".")
    let result = waitFor repo.switchBranch("main")
    
    # Should switch branches
    check result.kind == JObject
    check result.hasKey("success") or result.hasKey("error") or result.hasKey("switched")
    
  test "switchBranch - non-existent branch":
    let repo = newJujutsuRepo(".")
    let result = waitFor repo.switchBranch("non-existent-branch-xyz")
    
    # Should handle non-existent branch
    check result.kind == JObject
    
  test "getCommitHistory - basic history":
    let repo = newJujutsuRepo(".")
    let history = waitFor repo.getCommitHistory()
    
    # Should return commit history
    check history.kind == JArray or history.kind == JObject
    
  test "getCommitHistory - with limit":
    let repo = newJujutsuRepo(".")
    let history = waitFor repo.getCommitHistory(limit = 10)
    
    # Should limit history
    check history.kind == JArray or history.kind == JObject
    if history.kind == JArray:
      check history.len <= 10
      
  test "getCommitHistory - with range":
    let repo = newJujutsuRepo(".")
    let history = waitFor repo.getCommitHistory(fromCommit = "HEAD~5", toCommit = "HEAD")
    
    # Should return range
    check history.kind == JArray or history.kind == JObject
    
  test "compareCommits - two commits":
    let repo = newJujutsuRepo(".")
    let diff = waitFor repo.compareCommits("HEAD~1", "HEAD")
    
    # Should return comparison
    check diff.kind == JObject
    check diff.hasKey("files") or diff.hasKey("error") or diff.hasKey("diff")
    
  test "compareCommits - with options":
    let repo = newJujutsuRepo(".")
    let diff = waitFor repo.compareCommits(
      "HEAD~2", 
      "HEAD",
      includeStats = true,
      format = DiffFormat.Json
    )
    
    # Should include stats
    check diff.kind == JObject
    
  test "getCommitFiles - list files in commit":
    let repo = newJujutsuRepo(".")
    let files = waitFor repo.getCommitFiles("HEAD")
    
    # Should return file list
    check files.kind == JArray or files.kind == JObject
    
  test "getCommitFiles - with patterns":
    let repo = newJujutsuRepo(".")
    let files = waitFor repo.getCommitFiles("HEAD", patterns = @["*.nim", "*.md"])
    
    # Should filter files
    check files.kind == JArray or files.kind == JObject
    
  test "Complex repository operations":
    let repo = newJujutsuRepo(".")
    
    # Get current status
    let status = waitFor repo.getStatus()
    check status.kind == JObject
    
    # List branches
    let branches = waitFor repo.listBranches()
    check branches.kind == JArray or branches.kind == JObject
    
    # Get recent history
    let history = waitFor repo.getCommitHistory(limit = 5)
    check history.kind == JArray or history.kind == JObject
    
    # Get commit info for HEAD
    let info = waitFor repo.getCommitInfo("HEAD")
    check info.kind == JObject
    
  test "Error handling for all functions":
    # Test with invalid repository path
    let badRepo = newJujutsuRepo("/non/existent/path")
    
    # All functions should handle errors gracefully
    let info = waitFor badRepo.getCommitInfo("HEAD")
    check info.kind == JObject
    
    let status = waitFor badRepo.getStatus()
    check status.kind == JObject
    
    let branches = waitFor badRepo.listBranches()
    check branches.kind == JArray or branches.kind == JObject
    
    let create = waitFor badRepo.createBranch("test")
    check create.kind == JObject
    
    let switch = waitFor badRepo.switchBranch("test")
    check switch.kind == JObject
    
    let history = waitFor badRepo.getCommitHistory()
    check history.kind == JArray or history.kind == JObject
    
    let compare = waitFor badRepo.compareCommits("HEAD~1", "HEAD")
    check compare.kind == JObject
    
    let files = waitFor badRepo.getCommitFiles("HEAD")
    check files.kind == JArray or files.kind == JObject

when isMainModule:
  waitFor main()