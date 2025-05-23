## Multi repository configuration module
##
## This module extends the core configuration for multi repository mode.

import std/[os, parseopt, strutils]
import ../../core/config/config as core_config

proc parseCommandLine*(): core_config.Config =
  ## Parses command-line arguments with multi repository specific options
  var config = core_config.parseCommandLine()
  
  # Set mode to multi repository
  config.serverMode = core_config.MultiRepo
  
  # Parse command-line arguments again for multi repo specific options
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "multi", "multi-repo":
        config.serverMode = core_config.MultiRepo
      of "repos-dir":
        config.reposDir = p.val
      of "repo-config":
        config.repoConfigPath = p.val
    of cmdArgument:
      # In multi mode, first argument might be repos directory
      if config.reposDir == getCurrentDir():
        let arg = p.key
        if dirExists(arg):
          config.reposDir = absolutePath(arg)
          # Default config file in repos directory
          if config.repoConfigPath == getCurrentDir() / "repos.json":
            config.repoConfigPath = config.reposDir / "repos.json"
  
  return config