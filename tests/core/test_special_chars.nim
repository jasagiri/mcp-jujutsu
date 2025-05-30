## Test special characters in filenames and arguments

import std/[unittest, asyncdispatch, os, strutils, tempfiles]
import ../../src/core/repository/[jujutsu, jujutsu_version]

template asyncTest(name: string, body: untyped) =
  test name:
    waitFor((proc {.async.} = body)())

suite "Special Characters Handling":
  test "quoteShellArg handles various special characters":
    check quoteShellArg("") == "''"
    check quoteShellArg("simple") == "simple"
    check quoteShellArg("with space") == "'with space'"
    check quoteShellArg("with'quote") == "'with'\\''quote'"
    check quoteShellArg("$(echo test)") == "'$(echo test)'"
    check quoteShellArg("`echo test`") == "'`echo test`'"
    check quoteShellArg("test;ls") == "'test;ls'"
    check quoteShellArg("test&ls") == "'test&ls'"
    check quoteShellArg("test|ls") == "'test|ls'"
    check quoteShellArg("test>file") == "'test>file'"
    check quoteShellArg("test<file") == "'test<file'"
    check quoteShellArg("test*") == "'test*'"
    check quoteShellArg("test?") == "'test?'"
    check quoteShellArg("test[123]") == "'test[123]'"
    check quoteShellArg("test{a,b}") == "'test{a,b}'"
    check quoteShellArg("test~") == "'test~'"
    check quoteShellArg("test#comment") == "'test#comment'"
    check quoteShellArg("test!") == "'test!'"
    check quoteShellArg("test$var") == "'test$var'"
    check quoteShellArg("test\\escape") == "'test\\escape'"
    check quoteShellArg("test\"quote") == "'test\"quote'"
    
  test "buildAddCommand escapes filenames":
    let commands = JujutsuCommands(
      addCommand: "jj add",
      version: JujutsuVersion(major: 0, minor: 27, patch: 0)
    )
    
    let files = @[
      "normal.txt",
      "with space.txt", 
      "$(dangerous).txt",
      "file'with'quotes.txt",
      "test;command.txt"
    ]
    
    let result = buildAddCommand(commands, files)
    check "normal.txt" in result
    check "'with space.txt'" in result
    check "'$(dangerous).txt'" in result
    check "'file'\\''with'\\''quotes.txt'" in result
    check "'test;command.txt'" in result
    
  test "buildLogCommand escapes arguments":
    let commands = JujutsuCommands(
      logTemplate: "-T",
      version: JujutsuVersion(major: 0, minor: 28, patch: 0)
    )
    
    let result = buildLogCommand(commands, "@-", "commit_id.short()")
    check "@-" in result  # @- doesn't need quoting
    check "'commit_id.short()'" in result
    
    let result2 = buildLogCommand(commands, "$(bad)", "test;ls")
    check "'$(bad)'" in result2
    check "'test;ls'" in result2

  asyncTest "repository operations with special characters":
    let tmpDir = createTempDir("jj_test_", "")
    defer: removeDir(tmpDir)
    
    try:
      # Initialize repository
      let repo = await initJujutsuRepo(tmpDir, initIfNotExists = true)
      
      # Test creating files with special characters
      let specialFiles = @[
        (path: "file with spaces.txt", content: "test"),
        (path: "file'with'quotes.txt", content: "test"),
        (path: "file$var.txt", content: "test")
      ]
      
      # Create commit with special filenames
      let commitId = await createCommit(repo, "Test special chars", specialFiles)
      check commitId != ""
      
      # Verify files were created
      for file in specialFiles:
        check fileExists(tmpDir / file.path)
        
      # Test getting diff with special commit ID (though unlikely in practice)
      # This mainly tests that our escaping doesn't break normal operations
      let diff = await getDiffForCommitRange(repo, "@")
      check diff.commitRange == "@"
      
    except CatchableError as e:
      echo "Error in test: ", e.msg
      fail()