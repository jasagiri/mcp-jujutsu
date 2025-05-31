## Debug test to identify field issues

import ../src/core/config/config as core_config

proc main() =
  echo "Testing core_config fields..."
  
  var config: core_config.Config
  config.serverMode = core_config.ServerMode.SingleRepo
  config.useHttp = true
  config.useStdio = false
  config.repoPath = "/test/repo"
  config.reposDir = "/test/repos"
  config.httpHost = "localhost"
  config.httpPort = 8080
  
  echo "All fields set successfully!"
  echo "serverMode: ", config.serverMode
  echo "useHttp: ", config.useHttp
  echo "repoPath: ", config.repoPath

main()