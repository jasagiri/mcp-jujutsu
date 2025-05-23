## Single repository configuration module
##
## This module extends the core configuration for single repository mode.

import std/[os, parseopt, strutils]
import ../../core/config/config as core_config

proc parseCommandLine*(): core_config.Config =
  ## Parses command-line arguments with single repository specific options
  var config = core_config.parseCommandLine()
  
  # Set mode to single repository
  config.serverMode = core_config.SingleRepo
  
  # Parse command-line arguments again for single repo specific options
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key.toLowerAscii()
      of "single", "single-repo":
        config.serverMode = core_config.SingleRepo
      of "repo-path":
        config.repoPath = p.val
      of "jj-path":
        # Future option for specifying Jujutsu executable path
        # Currently recognized but not used
        discard  # Intentional no-op, not an error case
    of cmdArgument:
      # In single mode, first argument might be repo path
      if config.repoPath == getCurrentDir():
        let arg = p.key
        if dirExists(arg) and dirExists(arg / ".jj"):
          config.repoPath = absolutePath(arg)
  
  return config