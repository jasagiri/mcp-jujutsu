#!/bin/bash
# Script to start the MCP server for Jujutsu semantic commit division

# Default port
PORT=${1:-8080}

# Default mode (single or multi)
MODE=${2:-single}

echo "Starting MCP-Jujutsu in $MODE mode on port $PORT..."

# Check if binary exists
if [ ! -f "./bin/mcp_jujutsu" ]; then
  echo "Binary not found. Building..."
  nimble build
fi

if [ "$MODE" == "multi" ] || [ "$MODE" == "hub" ]; then
  echo "Starting in multi-repository mode"
  ./bin/mcp_jujutsu --mode=multi --port=$PORT
else
  echo "Starting in single-repository mode"
  ./bin/mcp_jujutsu --port=$PORT
fi