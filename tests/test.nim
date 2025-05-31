## Tests directory test entry point
## Alternative location for test discovery

import unittest
import os

suite "Tests Directory Entry Point":
  test "Test directory structure":
    check dirExists("../src")
    check fileExists("../mcp_jujutsu.nimble")
    
  test "Tests are accessible":
    check fileExists("test_mcp_jujutsu_basic.nim")
    
echo "✅ Tests directory entry point completed"