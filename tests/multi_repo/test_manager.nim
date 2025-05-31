## Tests for repository manager (additional tests)

import std/[unittest, tables, options]
import ../../src/multi_repo/repository/manager

suite "Repository Manager Extended Tests":
  test "Manager Creation":
    let manager = newRepositoryManager("/test/root")
    check manager.rootDir == "/test/root"
    check manager.repos.len == 0
    check manager.configPath == ""

  test "Add Repository by Object":
    let manager = newRepositoryManager("/test/root")
    let repo = Repository(
      name: "test-repo",
      path: "/test/root/test-repo",
      dependencies: @["dep1", "dep2"]
    )
    
    manager.addRepository(repo)
    
    check manager.repos.len == 1
    check manager.repos.hasKey("test-repo")
    check manager.repos["test-repo"].dependencies.len == 2

  test "Get Repository":
    let manager = newRepositoryManager("/test/root")
    manager.addRepository("repo1", "/path/to/repo1", @["repo2"])
    
    let repoOpt = manager.getRepository("repo1")
    check repoOpt.isSome()
    
    let repo = repoOpt.get()
    check repo.name == "repo1"
    check repo.path == "/path/to/repo1"
    check repo.dependencies == @["repo2"]
    
    # Test non-existent repository
    let missingOpt = manager.getRepository("missing")
    check missingOpt.isNone

  test "Get All Repositories":
    let manager = newRepositoryManager("/test/root")
    manager.addRepository("repo1", "/path/1", @[])
    manager.addRepository("repo2", "/path/2", @["repo1"])
    manager.addRepository("repo3", "/path/3", @["repo1", "repo2"])
    
    let allRepos = manager.getAllRepositories()
    check allRepos.len == 3
    
    # Check that all repos are included
    var repoNames: seq[string] = @[]
    for repo in allRepos:
      repoNames.add(repo.name)
    
    check "repo1" in repoNames
    check "repo2" in repoNames
    check "repo3" in repoNames

  test "Complex Dependency Graph":
    let manager = newRepositoryManager("/test/root")
    
    # Create a more complex dependency structure
    manager.addRepository("core", "/path/core", @[])
    manager.addRepository("utils", "/path/utils", @["core"])
    manager.addRepository("api", "/path/api", @["core", "utils"])
    manager.addRepository("frontend", "/path/frontend", @["api", "utils"])
    manager.addRepository("backend", "/path/backend", @["api", "utils", "core"])
    
    check manager.repos.len == 5
    
    # Verify each repository's dependencies
    check manager.repos["core"].dependencies.len == 0
    check manager.repos["utils"].dependencies.len == 1
    check manager.repos["api"].dependencies.len == 2
    check manager.repos["frontend"].dependencies.len == 2
    check manager.repos["backend"].dependencies.len == 3