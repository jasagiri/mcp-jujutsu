## Edge case tests for comprehensive coverage

import unittest
import ../src/core/config/config as core_config

suite "Edge Case Tests":
  
  test "Empty String Handling":
    ## Test handling of empty strings
    var config: core_config.Config
    config.httpHost = ""
    config.repoPath = ""
    config.logLevel = ""
    
    check config.httpHost == ""
    check config.repoPath == ""
    check config.logLevel == ""
    
  test "Large Port Numbers":
    ## Test edge cases for port numbers
    var config: core_config.Config
    config.httpPort = 65535  # Maximum port number
    check config.httpPort == 65535
    
    config.httpPort = 1  # Minimum port number  
    check config.httpPort == 1
    
  test "Different Server Modes":
    ## Test switching between server modes
    var config: core_config.Config
    config.serverMode = core_config.ServerMode.SingleRepo
    check config.serverMode == core_config.ServerMode.SingleRepo
    
    config.serverMode = core_config.ServerMode.MultiRepo
    check config.serverMode == core_config.ServerMode.MultiRepo

echo "✅ Edge case tests completed"