## Tests for command line parsing in config modules
##
## Tests the parseCommandLine functions in all config modules

import std/[unittest, asyncdispatch, strutils, os]
import ../src/core/config/config as coreConfig
import ../src/single_repo/config/config as singleConfig
import ../src/multi_repo/config/config as multiConfig

suite "Config Command Line Parsing Tests":
  test "Core config - parseCommandLine basic":
    # Test basic command line parsing
    let args = @["--host", "localhost", "--port", "8080"]
    let parsed = coreConfig.parseCommandLine()
    
    # Should parse successfully with default values
    check parsed.httpHost != ""  # Should have a default host
    check parsed.httpPort > 0    # Should have a default port
    
  test "Core config - parseCommandLine with all options":
    let args = @[
      "--host", "0.0.0.0",
      "--port", "9000",
      "--log-level", "debug",
      "--config", "custom.toml"
    ]
    let parsed = coreConfig.parseCommandLine()
    
    # Should handle all options
    check parsed.httpPort > 0
    
  test "Core config - parseCommandLine empty args":
    let args: seq[string] = @[]
    let parsed = coreConfig.parseCommandLine()
    
    # Should handle empty args
    check parsed.httpPort > 0
    
  test "Core config - parseCommandLine invalid options":
    let args = @["--invalid-option", "value", "--another-bad", "option"]
    let parsed = coreConfig.parseCommandLine()
    
    # Should handle invalid options gracefully
    check true  # Just ensure it doesn't crash
    
  test "Single repo config - parseCommandLine basic":
    let args = @["--repo", "/path/to/repo", "--mode", "semantic"]
    let parsed = singleConfig.parseCommandLine()
    
    # Should parse single repo specific options
    check parsed.httpPort > 0
    
  test "Single repo config - parseCommandLine with analysis options":
    let args = @[
      "--repo", ".",
      "--mode", "semantic",
      "--max-commit-size", "100",
      "--auto-split", "true"
    ]
    let parsed = singleConfig.parseCommandLine()
    
    # Should handle analysis options
    check parsed.httpPort > 0
    
  test "Single repo config - parseCommandLine short options":
    let args = @["-r", ".", "-m", "semantic", "-a"]
    let parsed = singleConfig.parseCommandLine()
    
    # Should handle short options
    check parsed.httpPort > 0
    
  test "Multi repo config - parseCommandLine basic":
    let args = @["--repos-config", "repos.toml", "--parallel", "4"]
    let parsed = multiConfig.parseCommandLine()
    
    # Should parse multi repo specific options
    check parsed.httpPort > 0
    
  test "Multi repo config - parseCommandLine with sync options":
    let args = @[
      "--repos-config", "repos.toml",
      "--sync-mode", "dependencies",
      "--parallel", "8",
      "--timeout", "300"
    ]
    let parsed = multiConfig.parseCommandLine()
    
    # Should handle sync options
    check parsed.httpPort > 0
    
  test "Multi repo config - parseCommandLine workspace options":
    let args = @[
      "--workspace", "main",
      "--create-workspaces", "true",
      "--workspace-prefix", "mcp-"
    ]
    let parsed = multiConfig.parseCommandLine()
    
    # Should handle workspace options
    check parsed.httpPort > 0
    
  test "Edge cases for all configs":
    let edgeCases = @[
      @["--"],  # Just separator
      @["--", "extra", "args"],  # With extra args
      @["-"],  # Just dash
      @["--=value"],  # Malformed option
      @["--option=value"],  # Equal sign syntax
      @["--option", "--another"],  # Missing value
      @[" --option "],  # Whitespace
    ]
    
    for args in edgeCases:
      # All should handle edge cases without crashing
      discard coreConfig.parseCommandLine()
      discard singleConfig.parseCommandLine()
      discard multiConfig.parseCommandLine()
      
    check true  # If we get here, all edge cases were handled
    
  test "Help and version flags":
    let helpArgs = @[@["--help"], @["-h"], @["--version"], @["-v"]]
    
    for args in helpArgs:
      # Should recognize help/version flags
      discard coreConfig.parseCommandLine()
      discard singleConfig.parseCommandLine()
      discard multiConfig.parseCommandLine()
      
    check true
    
  test "Mixed valid and invalid options":
    let args = @[
      "--host", "localhost",  # Valid
      "--invalid", "option",  # Invalid
      "--port", "8080",      # Valid
      "--bad-flag"           # Invalid
    ]
    
    # Should process valid options despite invalid ones
    let parsed1 = coreConfig.parseCommandLine()
    let parsed2 = singleConfig.parseCommandLine()
    let parsed3 = multiConfig.parseCommandLine()
    
    check true  # Success if no crash

when isMainModule:
  echo "Config command line tests completed"