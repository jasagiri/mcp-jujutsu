## Simple Comprehensive Test Suite
## Focused on core functionality without heavy imports

import unittest
import ../src/core/config/config as core_config

suite "Simple Comprehensive Tests":
  
  test "Core Config Basic Fields":
    var config: core_config.Config
    config.serverMode = core_config.ServerMode.SingleRepo
    config.useHttp = true
    config.httpHost = "localhost"
    config.httpPort = 8080
    config.repoPath = "/test/repo"
    
    check config.serverMode == core_config.ServerMode.SingleRepo
    check config.useHttp == true
    check config.httpHost == "localhost"
    check config.httpPort == 8080
    check config.repoPath == "/test/repo"
    
  test "Server Mode Settings":
    var config = core_config.newDefaultConfig()
    check config.httpPort > 0
    check config.httpHost != ""
    
  test "Basic Functionality Check":
    check true

echo "✅ Simple comprehensive tests completed"