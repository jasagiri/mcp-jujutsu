#!/bin/bash
# Test script for stdio MCP transport

echo "Testing MCP-Jujutsu stdio transport..."

# Test initialize request
echo '{"jsonrpc":"2.0","method":"initialize","params":{"client":{"name":"test-client"}},"id":1}' | /Users/jasagiri/_temp/_fix_progress/_environment-dev/mcp-jujutsu/mcp_jujutsu --stdio --repo-path=/tmp/test-repo

echo ""
echo "Test complete."