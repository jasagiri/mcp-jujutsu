import unittest
import std/[asyncdispatch, options]
import ../../src/core/repository/jujutsu_version

suite "Jujutsu Version Detection Tests":
  
  test "Parse version strings":
    let v1 = parseVersion("jj 0.28.2")
    check v1.major == 0
    check v1.minor == 28
    check v1.patch == 2
    check v1.prerelease == ""
    
    let v2 = parseVersion("0.27.1-dev")
    check v2.major == 0
    check v2.minor == 27
    check v2.patch == 1
    check v2.prerelease == "dev"
    
    let v3 = parseVersion("1.0.0")
    check v3.major == 1
    check v3.minor == 0
    check v3.patch == 0
  
  test "Version comparison":
    let v1 = parseVersion("0.28.0")
    let v2 = parseVersion("0.27.5")
    let v3 = parseVersion("0.28.0")
    let v4 = parseVersion("0.28.1-dev")
    let v5 = parseVersion("0.28.1")
    
    check compareVersions(v1, v2) > 0  # 0.28.0 > 0.27.5
    check compareVersions(v1, v3) == 0 # 0.28.0 == 0.28.0
    check compareVersions(v4, v5) < 0  # 0.28.1-dev < 0.28.1
    check compareVersions(v1, v4) < 0  # 0.28.0 < 0.28.1-dev
  
  test "Command generation for different versions":
    let v28 = parseVersion("0.28.2")
    let v27 = parseVersion("0.27.1")
    let v26 = parseVersion("0.26.0")
    
    let cmd28 = getCommandsForVersion(v28)
    let cmd27 = getCommandsForVersion(v27)
    let cmd26 = getCommandsForVersion(v26)
    
    # Version 0.28+ should use auto-tracking
    check cmd28.addCommand == ""
    check cmd28.parentRevset == "@-"
    
    # Version 0.27 should use jj add
    check cmd27.addCommand == "jj add"
    check cmd27.parentRevset == "@~"
    
    # Version 0.26 should use different init command
    check cmd26.initCommand == "jj init --git"
  
  test "Capability detection":
    let v28 = parseVersion("0.28.0")
    let v27 = parseVersion("0.27.0")
    let v25 = parseVersion("0.25.0")
    let v24 = parseVersion("0.24.0")
    
    let cap28 = getJujutsuCapabilities(v28)
    let cap27 = getJujutsuCapabilities(v27)
    let cap25 = getJujutsuCapabilities(v25)
    let cap24 = getJujutsuCapabilities(v24)
    
    check cap28.hasAutoTracking == true
    check cap27.hasAutoTracking == false
    
    check cap28.hasNewRevsetSyntax == true
    check cap27.hasNewRevsetSyntax == false
    
    check cap25.hasWorkspaceCommand == true
    check cap24.hasWorkspaceCommand == false
  
  test "Revset building":
    let cmd28 = getCommandsForVersion(parseVersion("0.28.0"))
    let cmd27 = getCommandsForVersion(parseVersion("0.27.0"))
    
    # Parent revsets
    check buildParentRevset(cmd28) == "@-"
    check buildParentRevset(cmd27) == "@~"
    check buildParentRevset(cmd28, 2) == "@--"
    check buildParentRevset(cmd27, 3) == "@~3"
    
    # Range revsets
    check buildRangeRevset(cmd28) == "@-..@"
    check buildRangeRevset(cmd27) == "@~..@"
    check buildRangeRevset(cmd28, "abc123") == "abc123..@"
  
  test "Log command building":
    let cmd28 = getCommandsForVersion(parseVersion("0.28.0"))
    let cmd27 = getCommandsForVersion(parseVersion("0.27.0"))
    
    let log28 = buildLogCommand(cmd28, "@", "commit_id.short()")
    let log27 = buildLogCommand(cmd27, "@", "commit_id.short()")
    
    check "-T" in log28
    check "--template" in log27
    check "'commit_id.short()'" in log28
    check "'commit_id.short()'" in log27
    
    # Test that the template is properly quoted
    check log28 == "jj log -r @ --no-graph -T 'commit_id.short()'"
    check log27 == "jj log -r @ --no-graph --template 'commit_id.short()'"
  
  test "Version caching":
    # Clear cache first
    clearVersionCache()
    
    # Test that cache clearing works
    check cachedVersion.isNone
    check cachedCommands.isNone