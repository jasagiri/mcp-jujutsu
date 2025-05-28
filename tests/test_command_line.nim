## Tests for command line parsing and main entry point

import std/[unittest, asyncdispatch, os, strutils, parseopt]
import ../src/core/config/config as core_config
import ../src/single_repo/config/config as single_config
import ../src/multi_repo/config/config as multi_config

suite "Command Line Parsing":
  test "Parse Single Repo Mode Options":
    # Test parsing command line for single repo mode
    let args = @["--port=8090", "--host=localhost", "--repo-path=/tmp/repo"]
    
    # Simulate command line parsing
    var p = initOptParser(args)
    var config = single_config.newConfig()
    
    for kind, key, val in p.getopt():
      case kind
      of cmdLongOption:
        case key
        of "port":
          config.httpPort = parseInt(val)
        of "host":
          config.httpHost = val
        of "repo-path":
          config.repoPath = val
        else:
          discard
      else:
        discard
    
    check config.httpPort == 8090
    check config.httpHost == "localhost"
    check config.repoPath == "/tmp/repo"
    
  test "Parse Multi Repo Mode Options":
    # Test parsing command line for multi repo mode
    let args = @["--mode=multi", "--repos-dir=/tmp/repos", "--port=9090"]
    
    var p = initOptParser(args)
    var isMulti = false
    var reposDir = ""
    var port = 8080
    
    for kind, key, val in p.getopt():
      case kind
      of cmdLongOption:
        case key
        of "mode":
          isMulti = val.toLowerAscii() == "multi"
        of "repos-dir":
          reposDir = val
        of "port":
          port = parseInt(val)
        else:
          discard
      else:
        discard
    
    check isMulti
    check reposDir == "/tmp/repos"
    check port == 9090
    
  test "Parse Transport Options":
    # Test parsing transport configuration
    let args = @["--http", "--stdio", "--no-http"]
    
    var p = initOptParser(args)
    var useHttp = true
    var useStdio = false
    
    for kind, key, val in p.getopt():
      case kind
      of cmdLongOption:
        case key
        of "http":
          useHttp = true
        of "stdio":
          useStdio = true
        of "no-http":
          useHttp = false
        else:
          discard
      else:
        discard
    
    check not useHttp  # --no-http should override --http
    check useStdio
    
  test "Parse Short Options":
    # Test short option parsing
    let args = @["-h", "-v"]
    
    var p = initOptParser(args)
    var showHelp = false
    var showVersion = false
    
    for kind, key, val in p.getopt():
      case kind
      of cmdShortOption:
        case key
        of "h":
          showHelp = true
        of "v":
          showVersion = true
        else:
          discard
      else:
        discard
    
    check showHelp
    check showVersion
    
  test "Parse Invalid Options":
    # Test handling of invalid options
    let args = @["--invalid-option=value", "--another-bad-option"]
    
    var p = initOptParser(args)
    var unknownOptions: seq[string] = @[]
    
    for kind, key, val in p.getopt():
      case kind
      of cmdLongOption:
        if key notin ["port", "host", "mode", "help", "version"]:
          unknownOptions.add(key)
      else:
        discard
    
    check unknownOptions.len == 2
    check "invalid-option" in unknownOptions
    check "another-bad-option" in unknownOptions
    
  test "Parse Mixed Options":
    # Test parsing mixed short and long options
    let args = @["-h", "--port=8080", "-v", "--mode=single"]
    
    var p = initOptParser(args)
    var showHelp = false
    var showVersion = false
    var port = 0
    var mode = ""
    
    for kind, key, val in p.getopt():
      case kind
      of cmdShortOption:
        case key
        of "h":
          showHelp = true
        of "v":
          showVersion = true
        else:
          discard
      of cmdLongOption:
        case key
        of "port":
          port = parseInt(val)
        of "mode":
          mode = val
        else:
          discard
      else:
        discard
    
    check showHelp
    check showVersion
    check port == 8080
    check mode == "single"
    
  test "Default Values":
    # Test that default values are used when options not specified
    let config = single_config.newConfig()
    
    check config.httpPort == 8080  # Default port
    check config.httpHost == "127.0.0.1"  # Default host
    check config.useHttp == true  # HTTP enabled by default
    check config.useStdio == false  # Stdio disabled by default
    
  test "Port Number Validation":
    # Test port number parsing edge cases
    proc parsePort(s: string): int =
      try:
        result = parseInt(s)
        if result < 1 or result > 65535:
          result = -1
      except ValueError:
        result = -1
    
    check parsePort("8080") == 8080
    check parsePort("0") == -1  # Too low
    check parsePort("65536") == -1  # Too high
    check parsePort("abc") == -1  # Not a number
    check parsePort("") == -1  # Empty string
    
  test "Mode Detection":
    # Test server mode detection from various inputs
    proc parseMode(s: string): string =
      case s.toLowerAscii()
      of "multi", "multirepo", "multi-repo":
        result = "multi"
      else:
        result = "single"
    
    check parseMode("multi") == "multi"
    check parseMode("MultiRepo") == "multi"
    check parseMode("multi-repo") == "multi"
    check parseMode("single") == "single"
    check parseMode("unknown") == "single"  # Default to single
    
  test "Boolean Flag Parsing":
    # Test parsing boolean flags
    proc parseBoolFlag(args: seq[string], flag: string): bool =
      for arg in args:
        if arg == "--" & flag or arg == "--no-" & flag:
          return not arg.startsWith("--no-")
      return false
    
    check parseBoolFlag(@["--restart"], "restart") == true
    check parseBoolFlag(@["--no-restart"], "restart") == false
    check parseBoolFlag(@[], "restart") == false  # Not specified