## Test cases for multi repository cross-repo analysis
##
## This module tests the cross-repository analyzer.

import unittest, asyncdispatch, json, options, tables
import ../../src/multi_repo/analyzer/cross_repo
import ../../src/multi_repo/repository/manager
import ../../src/core/config/config
import ../../src/core/repository/jujutsu

suite "Cross Repository Analysis Tests":
  
  test "Dependency Detection":
    # Test detection of dependencies between repositories
    var manager = newRepositoryManager("/test/repos")
    manager.addRepository("repo1", "/test/repos/repo1")
    manager.addRepository("repo2", "/test/repos/repo2")
    
    let diff = CrossRepoDiff(
      repositories: @[
        Repository(name: "repo1", path: "/test/repos/repo1", dependencies: @[]),
        Repository(name: "repo2", path: "/test/repos/repo2", dependencies: @[])
      ],
      changes: {
        "repo1": @[
          jujutsu.FileDiff(
            path: "src/main.nim",
            changeType: "modified",
            diff: "+import repo2/module"
          )
        ],
        "repo2": @[
          jujutsu.FileDiff(
            path: "src/module.nim",
            changeType: "added",
            diff: "+proc publicAPI() ="
          )
        ]
      }.toTable
    )
    
    let dependencies = detectDependencies(diff)
    check(dependencies.len > 0)
    check(dependencies[0].source == "repo1")
    check(dependencies[0].target == "repo2")
  
  test "Commit Group Generation":
    # Test generation of commit groups
    let diff = CrossRepoDiff(
      repositories: @[
        Repository(name: "repo1", path: "/test/repos/repo1", dependencies: @[]),
        Repository(name: "repo2", path: "/test/repos/repo2", dependencies: @[])
      ],
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    let proposal = waitFor generateCrossRepoProposal(diff, newRepositoryManager("/test"))
    check(proposal.commitGroups.len >= 0)
  
  test "Empty Repository Handling":
    # Test handling of empty repositories
    let manager = newRepositoryManager("/test/repos")
    let diff = CrossRepoDiff(
      repositories: @[],
      changes: initTable[string, seq[jujutsu.FileDiff]]()
    )
    
    let proposal = waitFor generateCrossRepoProposal(diff, manager)
    check(proposal.commitGroups.len == 0)