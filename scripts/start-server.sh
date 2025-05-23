#!/bin/bash
# Script to start the MCP server for Semantic Divide

# Default port
PORT=${1:-8080}

# Default mode (server or hub)
MODE=${2:-server}

echo "Starting MCP-Jujutsu in $MODE mode on port $PORT..."

if [ "$MODE" == "hub" ]; then
  echo "Starting in hub mode (multi-repository support)"
  nimble run --hub --port=$PORT
else
  echo "Starting in server mode (single repository)"
  nimble run --port=$PORT
fi