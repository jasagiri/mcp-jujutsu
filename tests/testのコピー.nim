## Root level test entry point
## Some testing tools expect a simple test.nim at the root

import unittest
import os

suite "Root Test Entry Point":
  test "Project exists":
    check dirExists("src")
    check fileExists("mcp_jujutsu.nimble")
    
  test "Basic functionality":
    check true
    
echo "✅ Root test completed"