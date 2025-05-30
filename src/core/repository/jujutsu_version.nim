## Jujutsu version detection and command adaptation module
##
## This module handles version-specific command variations across different Jujutsu versions

import std/[strutils, sequtils, re, tables, osproc, options, asyncdispatch]
import ../logging/logger

type
  JujutsuVersion* = object
    major*: int
    minor*: int
    patch*: int
    prerelease*: string
    
  JujutsuCommands* = object
    ## Version-specific command variations
    version*: JujutsuVersion
    initCommand*: string      # "jj init" vs "jj git init"
    addCommand*: string       # "jj add" vs "" (auto-tracking)
    parentRevset*: string     # "@~" vs "@-"
    diffCommand*: string      # "jj diff" variations
    logTemplate*: string      # Template syntax variations
    
  JujutsuCapabilities* = object
    ## Feature availability by version
    hasAutoTracking*: bool    # Files are automatically tracked
    hasWorkspaceCommand*: bool # jj workspace command available
    hasNewRevsetSyntax*: bool # New revset syntax (@- instead of @~)
    hasTemplateShortcuts*: bool # commit_id.short() vs commit_id
    supportsConcurrentOps*: bool # Concurrent operations support

const
  # Known version configurations
  VERSION_CONFIGS = [
    # Jujutsu 0.28.x and later
    (version: "0.28.0", config: JujutsuCommands(
      initCommand: "jj git init",
      addCommand: "",  # Auto-tracking
      parentRevset: "@-",
      diffCommand: "jj diff",
      logTemplate: "-T"
    )),
    # Jujutsu 0.27.x
    (version: "0.27.0", config: JujutsuCommands(
      initCommand: "jj git init", 
      addCommand: "jj add",
      parentRevset: "@~",
      diffCommand: "jj diff",
      logTemplate: "--template"
    )),
    # Jujutsu 0.26.x and earlier
    (version: "0.26.0", config: JujutsuCommands(
      initCommand: "jj init --git",
      addCommand: "jj add",
      parentRevset: "@~",
      diffCommand: "jj diff",
      logTemplate: "--template"
    ))
  ]

var cachedVersion*: Option[JujutsuVersion] = none(JujutsuVersion)
var cachedCommands*: Option[JujutsuCommands] = none(JujutsuCommands)

proc parseVersion*(versionString: string): JujutsuVersion =
  ## Parse version string like "jj 0.28.2" or "0.28.2-dev"
  let versionLine = versionString.splitLines()[0]
  let versionPart = if "jj " in versionLine:
    versionLine.split("jj ")[1].strip()
  else:
    versionLine.strip()
  
  # Handle pre-release versions
  let parts = versionPart.split("-")
  let versionOnly = parts[0]
  let prerelease = if parts.len > 1: parts[1] else: ""
  
  let versionComponents = versionOnly.split(".")
  
  result = JujutsuVersion(
    major: if versionComponents.len > 0: parseInt(versionComponents[0]) else: 0,
    minor: if versionComponents.len > 1: parseInt(versionComponents[1]) else: 0,
    patch: if versionComponents.len > 2: parseInt(versionComponents[2]) else: 0,
    prerelease: prerelease
  )

proc compareVersions*(v1, v2: JujutsuVersion): int =
  ## Compare two versions. Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  if v1.major != v2.major:
    return cmp(v1.major, v2.major)
  if v1.minor != v2.minor:
    return cmp(v1.minor, v2.minor)
  if v1.patch != v2.patch:
    return cmp(v1.patch, v2.patch)
  
  # Handle prerelease: stable > prerelease
  if v1.prerelease == "" and v2.prerelease != "":
    return 1
  if v1.prerelease != "" and v2.prerelease == "":
    return -1
  
  return cmp(v1.prerelease, v2.prerelease)

proc getJujutsuVersion*(): Future[JujutsuVersion] {.async, gcsafe.} =
  ## Get Jujutsu version, with caching
  {.cast(gcsafe).}:
    if cachedVersion.isSome:
      return cachedVersion.get()
  
  try:
    let (output, exitCode) = execCmdEx("jj --version")
    if exitCode == 0:
      result = parseVersion(output)
      {.cast(gcsafe).}:
        cachedVersion = some(result)
      
      let ctx = newLogContext("jujutsu", "version")
        .withMetadata("version", $result.major & "." & $result.minor & "." & $result.patch)
      info("Detected Jujutsu version", ctx)
    else:
      raise newException(IOError, "Failed to get Jujutsu version: " & output)
  except Exception as e:
    let ctx = newLogContext("jujutsu", "version")
    error("Failed to detect Jujutsu version: " & e.msg, ctx)
    # Return default version for fallback
    result = JujutsuVersion(major: 0, minor: 28, patch: 0)

proc getCommandsForVersion*(version: JujutsuVersion): JujutsuCommands =
  ## Get command configuration for a specific version
  result = JujutsuCommands(
    version: version,
    initCommand: "jj git init",
    addCommand: "",
    parentRevset: "@-", 
    diffCommand: "jj diff",
    logTemplate: "-T"
  )
  
  # Find the best matching version configuration
  for (versionStr, config) in VERSION_CONFIGS:
    let configVersion = parseVersion(versionStr)
    if compareVersions(version, configVersion) >= 0:
      result = config
      result.version = version
      break

proc getJujutsuCommands*(): Future[JujutsuCommands] {.async, gcsafe.} =
  ## Get version-appropriate commands, with caching
  {.cast(gcsafe).}:
    if cachedCommands.isSome:
      return cachedCommands.get()
  
  let version = await getJujutsuVersion()
  result = getCommandsForVersion(version)
  {.cast(gcsafe).}:
    cachedCommands = some(result)

proc getJujutsuCapabilities*(version: JujutsuVersion): JujutsuCapabilities =
  ## Get capabilities for a specific version
  result = JujutsuCapabilities(
    hasAutoTracking: compareVersions(version, parseVersion("0.28.0")) >= 0,
    hasWorkspaceCommand: compareVersions(version, parseVersion("0.25.0")) >= 0,
    hasNewRevsetSyntax: compareVersions(version, parseVersion("0.28.0")) >= 0,
    hasTemplateShortcuts: compareVersions(version, parseVersion("0.27.0")) >= 0,
    supportsConcurrentOps: compareVersions(version, parseVersion("0.26.0")) >= 0
  )

proc clearVersionCache*() =
  ## Clear cached version information (useful for testing)
  cachedVersion = none(JujutsuVersion)
  cachedCommands = none(JujutsuCommands)

# Version-aware command builders
proc buildInitCommand*(commands: JujutsuCommands): string =
  commands.initCommand

proc quoteShellArg*(arg: string): string {.gcsafe.} =
  ## Properly quote an argument for shell execution
  ## This handles special characters that could cause issues
  if arg.len == 0:
    return "''"
  
  # Check if quoting is needed
  var needsQuoting = false
  for c in arg:
    if c in {' ', '\t', '\n', '\r', '\\', '"', '\'', '$', '`', '!', 
             '&', '|', ';', '<', '>', '(', ')', '[', ']', '{', '}', 
             '*', '?', '~', '#'}:
      needsQuoting = true
      break
  
  if not needsQuoting:
    return arg
  
  # Use single quotes and escape any single quotes in the string
  result = "'"
  for c in arg:
    if c == '\'':
      result.add("'\\''")
    else:
      result.add(c)
  result.add("'")

proc buildAddCommand*(commands: JujutsuCommands, files: seq[string] = @[]): string =
  if commands.addCommand == "":
    return ""  # Auto-tracking, no add needed
  else:
    return commands.addCommand & " " & files.mapIt(quoteShellArg(it)).join(" ")

proc buildParentRevset*(commands: JujutsuCommands, generations: int = 1): string =
  ## Build parent revset (e.g., "@-", "@~", "@~2")
  if commands.parentRevset == "@-":
    if generations == 1:
      return "@-"
    else:
      return "@" & "-".repeat(generations)
  else:
    if generations == 1:
      return "@~"
    else:
      return "@~" & $generations

proc buildRangeRevset*(commands: JujutsuCommands, fromRev: string = "", toRev: string = "@"): string =
  ## Build range revset (e.g., "@-..@", "@~..@")
  let fromRevision = if fromRev == "": buildParentRevset(commands) else: fromRev
  return fromRevision & ".." & toRev

proc buildLogCommand*(commands: JujutsuCommands, revset: string, templateStr: string): string =
  ## Build log command with appropriate template syntax
  let quotedRevset = quoteShellArg(revset)
  let quotedTemplate = quoteShellArg(templateStr)
  if commands.logTemplate == "-T":
    return "jj log -r " & quotedRevset & " --no-graph -T " & quotedTemplate
  else:
    return "jj log -r " & quotedRevset & " --no-graph --template " & quotedTemplate