#!/bin/bash
# .infra/ssh-tunnel.sh - Persistent SSH tunnel to VPS mem0 API
#
# This script creates an auto-reconnecting SSH tunnel from local machine
# to the VPS mem0 API. Used by local Claude Code sessions to write to
# the shared mem0 brain.
#
# Usage:
#   ./ssh-tunnel.sh               # Uses cleo-vps from SSH config
#   ./ssh-tunnel.sh 123.45.67.89  # Uses explicit IP
#
# Prerequisites:
#   - autossh installed: brew install autossh (macOS) or apt install autossh (Linux)
#   - SSH key configured for VPS access
#   - SSH config entry 'cleo-vps' (see .infra/README.md)

set -euo pipefail

# Configuration
REMOTE_USER="aman"
REMOTE_HOST="${1:-cleo-vps}"  # Default to SSH config alias
REMOTE_PORT=8080              # mem0 API port on VPS
LOCAL_PORT=9090               # Local port to forward to

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting SSH tunnel to Cleo VPS mem0 API${NC}"
echo "  Local:  localhost:${LOCAL_PORT}"
echo "  Remote: ${REMOTE_HOST}:${REMOTE_PORT}"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Check if autossh is installed
if ! command -v autossh &> /dev/null; then
    echo -e "${RED}Error: autossh is not installed${NC}"
    echo "Install with:"
    echo "  macOS:  brew install autossh"
    echo "  Ubuntu: sudo apt install autossh"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :${LOCAL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}Error: Port ${LOCAL_PORT} is already in use${NC}"
    echo "Another tunnel may be running. Check with: lsof -i :${LOCAL_PORT}"
    exit 1
fi

# Start autossh tunnel
# -M 0: Disable autossh monitoring port, use SSH keepalive instead
# -N: No remote command, just forward ports
# -L: Local port forwarding
# ServerAliveInterval/CountMax: Detect dead connections
# ExitOnForwardFailure: Exit if port forward fails
autossh -M 0 \
    -N \
    -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "ExitOnForwardFailure=yes" \
    -o "StrictHostKeyChecking=accept-new" \
    ${REMOTE_USER}@${REMOTE_HOST}
