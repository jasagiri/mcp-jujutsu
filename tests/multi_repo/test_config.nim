## Tests for multi repository configuration

import std/[unittest, os, strutils]
import ../../src/multi_repo/config/config
import ../../src/core/config/config as core_config

suite "Multi Repository Configuration Tests":
  test "Multi Repo Default Configuration":
    # Test that multi-repo config uses core config properly
    var config = core_config.newDefaultConfig()
    config.serverMode = MultiRepo
    
    check config.serverMode == MultiRepo
    # Default config sets these to current directory values
    check config.reposDir == getCurrentDir()
    check config.repoConfigPath == getCurrentDir() / "repos.json"

  test "Multi Repo Specific Fields":
    var config = core_config.newDefaultConfig()
    config.serverMode = MultiRepo
    config.reposDir = "/home/repos"
    config.repoConfigPath = "/home/repos/config.json"
    
    check config.serverMode == MultiRepo
    check config.reposDir == "/home/repos"
    check config.repoConfigPath == "/home/repos/config.json"

  test "Parse Multi Repo Mode":
    # Test configuration for multi-repo mode
    var config = core_config.newDefaultConfig()
    
    # Simulate multi-repo mode
    config.serverMode = MultiRepo
    config.reposDir = getCurrentDir() / "repos"
    config.repoConfigPath = getCurrentDir() / "repos.json"
    
    check config.serverMode == MultiRepo
    check config.reposDir.endsWith("repos")
    check config.repoConfigPath.endsWith("repos.json")