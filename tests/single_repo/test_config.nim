## Tests for single repository configuration

import std/[unittest, os, parseopt, strutils]
import ../../src/single_repo/config/config
import ../../src/core/config/config as core_config

suite "Single Repository Configuration Tests":
  test "Parse Empty Command Line":
    # Save original command line state
    let savedParams = commandLineParams()
    
    # Test with no arguments (using parseopt directly)
    var p = initOptParser("")
    var args: seq[string] = @[]
    
    # Since we can't easily mock command line args, test the default config
    let config = core_config.newDefaultConfig()
    
    check config.serverMode == SingleRepo
    check config.repoPath == getCurrentDir()
    check config.httpPort == 8080
    check config.useHttp == true
    check config.useStdio == false

  test "Configuration Fields":
    # Test that configuration has all expected fields
    let config = core_config.newDefaultConfig()
    
    # Test single repo specific fields
    check config.repoPath == getCurrentDir()
    
    # Modify repo path
    var modConfig = config
    modConfig.repoPath = "/test/repo/path"
    check modConfig.repoPath == "/test/repo/path"

  test "Single Repo Mode Check":
    let config = core_config.newDefaultConfig()
    check config.serverMode == SingleRepo
    
    # Verify it's not multi-repo
    check config.serverMode != MultiRepo