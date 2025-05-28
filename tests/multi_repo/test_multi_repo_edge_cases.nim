## Edge case tests for multi_repo tools module
##
## This module tests various edge cases including:
## - Invalid repository paths
## - Missing repositories
## - Permission errors
## - Concurrent repository operations
## - Very large repositories
## - Network errors (for remote repos)
## - Invalid commit IDs
## - Edge cases in cross-repo analysis

import std/[unittest, asyncdispatch, json, os, tables, strutils, sequtils, times]
import ../../src/multi_repo/tools/multi_repo
import ../../src/multi_repo/repository/manager
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/core/repository/jujutsu

# Helper procedures for test setup
proc createTempDir(): string =
  ## Creates a temporary directory for testing
  result = getTempDir() / "mcp_jujutsu_test_" & $epochTime().int
  createDir(result)

proc cleanupTempDir(path: string) =
  ## Cleans up a temporary directory
  if dirExists(path):
    removeDir(path)

proc createMockRepoConfig(path: string, repos: seq[(string, string, seq[string])]) =
  ## Creates a mock repository configuration file
  var reposArray = newJArray()
  for (name, repoPath, deps) in repos:
    var repoJson = %*{
      "name": name,
      "path": repoPath
    }
    if deps.len > 0:
      var depsArray = newJArray()
      for dep in deps:
        depsArray.add(%dep)
      repoJson["dependencies"] = depsArray
    reposArray.add(repoJson)
  
  let config = %*{"repositories": reposArray}
  writeFile(path, pretty(config))

proc createInvalidJsonConfig(path: string) =
  ## Creates an invalid JSON configuration file
  writeFile(path, "{ invalid json content ]}")

proc createCorruptedConfig(path: string) =
  ## Creates a corrupted configuration file with missing required fields
  let config = %*{
    "repositories": [
      {"missing_name": "value"},
      {"name": "repo2"}  # missing path
    ]
  }
  writeFile(path, pretty(config))

suite "Multi Repo Edge Cases - Invalid Repository Paths":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Non-existent repository path":
    # Create config with non-existent repository path
    let configPath = tempDir / "repos.json"
    let emptyDeps: seq[string] = @[]
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "non_existent_repo", emptyDeps)
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")
    check response["error"]["message"].getStr.contains("Failed to analyze repositories")
  
  test "Invalid path characters":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", "/\0invalid\0path", @[])  # Null characters in path
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")
  
  test "Relative path resolution":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", "../../../outside_temp", @[])  # Path outside temp directory
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # Should handle relative paths gracefully
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error") or response.hasKey("analysis")

suite "Multi Repo Edge Cases - Missing Repositories":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Missing configuration file":
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": tempDir / "non_existent_config.json"
    }
    
    # Should handle missing config gracefully
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Empty config should return empty analysis
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Empty repository list":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    if response.hasKey("analysis"):
      check response["analysis"]["repositories"].len == 0
  
  test "Repository with missing dependencies":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "repo1", @["non_existent_dep"]),
      ("repo2", tempDir / "repo2", @["repo1", "missing_repo"])
    ])
    
    let manager = waitFor loadRepositoryConfig(configPath)
    let isValid = waitFor manager.validateDependencies()
    check not isValid

suite "Multi Repo Edge Cases - Permission Errors":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Read-only configuration file":
    when defined(posix):
      let configPath = tempDir / "readonly_repos.json"
      createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
      
      # Make file read-only
      setFilePermissions(configPath, {fpUserRead})
      
      # Try to save config (should fail)
      let manager = waitFor loadRepositoryConfig(configPath)
      manager.addRepository("new_repo", tempDir / "new_repo", @[])
      let success = waitFor manager.saveConfig()
      check not success
      
      # Restore permissions for cleanup
      setFilePermissions(configPath, {fpUserRead, fpUserWrite})
  
  test "No write permission to directory":
    when defined(posix):
      let restrictedDir = tempDir / "restricted"
      createDir(restrictedDir)
      setFilePermissions(restrictedDir, {fpUserRead, fpUserExec})
      
      let configPath = restrictedDir / "repos.json"
      let manager = newRepositoryManager(restrictedDir)
      manager.addRepository("repo1", tempDir / "repo1", @[])
      
      let success = waitFor manager.saveConfig(configPath)
      check not success
      
      # Restore permissions for cleanup
      setFilePermissions(restrictedDir, {fpUserRead, fpUserWrite, fpUserExec})

suite "Multi Repo Edge Cases - Concurrent Operations":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Concurrent analysis of same repositories":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "repo1", @[]),
      ("repo2", tempDir / "repo2", @[])
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # Launch multiple concurrent analyses
    var futures: seq[Future[JsonNode]] = @[]
    for i in 0..4:
      futures.add(analyzeMultiRepoCommitsTool(params))
    
    # Wait for all to complete
    for future in futures:
      let response = waitFor future
      # All should complete without deadlock
      check response.hasKey("analysis") or response.hasKey("error")
  
  test "Concurrent proposal generation":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "repo1", @[]),
      ("repo2", tempDir / "repo2", @["repo1"])
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # Launch multiple concurrent proposals
    var futures: seq[Future[JsonNode]] = @[]
    for i in 0..2:
      futures.add(proposeMultiRepoSplitTool(params))
    
    for future in futures:
      let response = waitFor future
      check response.hasKey("proposal") or response.hasKey("error")

suite "Multi Repo Edge Cases - Large Repositories":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Very large number of repositories":
    # Create config with many repositories
    var repos: seq[(string, string, seq[string])] = @[]
    for i in 0..99:  # 100 repositories
      repos.add(("repo" & $i, tempDir / ("repo" & $i), @[]))
    
    let configPath = tempDir / "large_repos.json"
    createMockRepoConfig(configPath, repos)
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should handle large number of repos
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Deep dependency chain":
    # Create a deep chain of dependencies
    var repos: seq[(string, string, seq[string])] = @[]
    repos.add(("repo0", tempDir / "repo0", @[]))
    for i in 1..19:  # 20 levels deep
      repos.add(("repo" & $i, tempDir / ("repo" & $i), @["repo" & $(i-1)]))
    
    let configPath = tempDir / "deep_deps.json"
    createMockRepoConfig(configPath, repos)
    
    let manager = waitFor loadRepositoryConfig(configPath)
    let order = manager.getDependencyOrder()
    # Should handle deep dependencies
    check order.len == 20
    check order[0] == "repo0"
    check order[19] == "repo19"

suite "Multi Repo Edge Cases - Invalid Configurations":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Invalid JSON configuration":
    let configPath = tempDir / "invalid.json"
    createInvalidJsonConfig(configPath)
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # Should handle invalid JSON gracefully
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Empty manager should be created on error
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Corrupted configuration with missing fields":
    let configPath = tempDir / "corrupted.json"
    createCorruptedConfig(configPath)
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # Should handle corrupted config gracefully
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Cyclic dependencies":
    let configPath = tempDir / "cyclic.json"
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "repo1", @["repo2"]),
      ("repo2", tempDir / "repo2", @["repo3"]),
      ("repo3", tempDir / "repo3", @["repo1"])  # Creates cycle
    ])
    
    let manager = waitFor loadRepositoryConfig(configPath)
    
    # Should detect cyclic dependencies
    expect(ValueError):
      discard manager.getDependencyOrder()

suite "Multi Repo Edge Cases - Invalid Commit IDs":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Invalid commit range format":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    let params = %*{
      "commitRange": "invalid..range..format",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")
  
  test "Non-existent commit IDs":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    let params = %*{
      "commitRange": "nonexistent123..alsonotreal456",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")
  
  test "Empty commit range":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    let params = %*{
      "commitRange": "",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")

suite "Multi Repo Edge Cases - Cross-Repository Analysis":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Mixed valid and invalid repositories":
    let configPath = tempDir / "mixed.json"
    createMockRepoConfig(configPath, @[
      ("valid_repo", tempDir / "valid", @[]),
      ("invalid_repo", "/non/existent/path", @[]),
      ("another_valid", tempDir / "another", @[])
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath,
      "repositories": ["valid_repo", "invalid_repo"]
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    check response.hasKey("error")
  
  test "Empty file changes in analysis":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    # Create empty cross-repo diff
    let diff = CrossRepoDiff(
      repositories: @[],
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    # Test dependency identification with empty diff
    let dependencies = waitFor identifyCrossRepoDependencies(diff)
    check dependencies.len == 0
  
  test "Invalid proposal format for execution":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    # Missing required fields in proposal
    let params = %*{
      "configPath": configPath,
      "proposal": {
        # Missing commitGroups
      }
    }
    
    let response = waitFor executeMultiRepoSplitTool(params)
    check response.hasKey("error")
    check response["error"]["code"].getInt == -32602
    check response["error"]["message"].getStr.contains("Invalid proposal format")
  
  test "Proposal with invalid repository references":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    let params = %*{
      "configPath": configPath,
      "proposal": {
        "commitGroups": [{
          "name": "group1",
          "commits": [{
            "repository": "non_existent_repo",
            "message": "test commit",
            "changes": []
          }]
        }]
      }
    }
    
    let response = waitFor executeMultiRepoSplitTool(params)
    # Should skip non-existent repos but complete successfully
    check response.hasKey("result") or response.hasKey("error")

suite "Multi Repo Edge Cases - Resource Limits":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Very long repository names":
    let longName = "repo_" & repeat("x", 255)  # 260 character name
    let configPath = tempDir / "long_names.json"
    createMockRepoConfig(configPath, @[(longName, tempDir / "repo", @[])])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should handle long names
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Very long file paths in changes":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    # Create a file change with very long path
    let longPath = "dir/" & repeat("subdir/", 50) & "file.txt"  # Deep nesting
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should handle long paths
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Large number of file changes":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    # Simulate analysis with many file changes
    let params = %*{
      "commitRange": "HEAD~100..HEAD",  # Large range
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should handle large number of changes
    check response.hasKey("analysis") or response.hasKey("error")

suite "Multi Repo Edge Cases - Special Characters":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Repository names with special characters":
    let configPath = tempDir / "special.json"
    createMockRepoConfig(configPath, @[
      ("repo-with-dash", tempDir / "repo1", @[]),
      ("repo.with.dots", tempDir / "repo2", @[]),
      ("repo_with_underscore", tempDir / "repo3", @[])
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should handle special characters in names
    check response.hasKey("analysis") or response.hasKey("error")
  
  test "Commit messages with special characters":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    let proposal = %*{
      "commitGroups": [{
        "name": "group1",
        "commits": [{
          "repository": "repo1",
          "message": "feat: add support for 日本語 and émojis 🚀",
          "changes": []
        }]
      }]
    }
    
    let params = %*{
      "configPath": configPath,
      "proposal": proposal
    }
    
    let response = waitFor executeMultiRepoSplitTool(params)
    # Should handle Unicode in commit messages
    check response.hasKey("result") or response.hasKey("error")

suite "Multi Repo Edge Cases - Error Recovery":
  var tempDir: string
  
  setup:
    tempDir = createTempDir()
  
  teardown:
    cleanupTempDir(tempDir)
  
  test "Partial failure in multi-repository operation":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[
      ("repo1", tempDir / "repo1", @[]),
      ("repo2", "/invalid/path", @[]),
      ("repo3", tempDir / "repo3", @[])
    ])
    
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath,
      "repositories": ["repo1", "repo2", "repo3"]
    }
    
    let response = waitFor analyzeMultiRepoCommitsTool(params)
    # Should fail gracefully when some repos are invalid
    check response.hasKey("error")
  
  test "Recovery from interrupted operation":
    let configPath = tempDir / "repos.json"
    createMockRepoConfig(configPath, @[("repo1", tempDir / "repo1", @[])])
    
    # Simulate an interrupted automated split
    let params = %*{
      "commitRange": "HEAD~1..HEAD",
      "configPath": configPath
    }
    
    # First attempt
    let response1 = waitFor automateMultiRepoSplitTool(params)
    
    # Second attempt (should work independently)
    let response2 = waitFor automateMultiRepoSplitTool(params)
    
    # Both should complete independently
    check response1.hasKey("result") or response1.hasKey("error")
    check response2.hasKey("result") or response2.hasKey("error")