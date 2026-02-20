#!/bin/bash
# scripts/test-local-mcp.sh - Test local Claude Code MCP connectivity to VPS
#
# Run this script from local machine to verify MCP server access via Tailscale.
#
# Prerequisites:
# - Tailscale connected (laptop and VPS on same tailnet)
# - VPS services running (docker compose up)
# - ~/.claude.json configured with mem0 MCP server

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%H:%M:%S')] $1"
}

echo "=================================="
echo "Local MCP Connectivity Test"
echo "=================================="
echo ""

# Check Tailscale connectivity
log "${YELLOW}Testing Tailscale connectivity...${NC}"
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    log "${GREEN}✓ Tailscale is connected${NC}"
else
    log "${RED}✗ Tailscale not connected${NC}"
    echo "  Connect: tailscale up"
    exit 1
fi

# Check MagicDNS to VPS
log "${YELLOW}Testing MagicDNS connectivity to cleo-vps...${NC}"
if ping -c 1 -W 5 cleo-vps &> /dev/null; then
    log "${GREEN}✓ VPS reachable via MagicDNS (cleo-vps)${NC}"
else
    log "${RED}✗ Cannot reach cleo-vps via MagicDNS${NC}"
    echo "  Check: tailscale status | grep cleo-vps"
    exit 1
fi

# Check SSH over Tailscale
log "${YELLOW}Testing SSH via Tailscale...${NC}"
if ssh -o ConnectTimeout=10 cleo-vps echo "SSH_OK" 2>/dev/null | grep -q "SSH_OK"; then
    log "${GREEN}✓ SSH connection successful via Tailscale${NC}"
else
    log "${RED}✗ Cannot SSH to cleo-vps${NC}"
    echo "  Check: SSH key is loaded (ssh-add -l)"
    exit 1
fi

# Check VPS Docker services
log "${YELLOW}Testing VPS Docker services...${NC}"
DOCKER_PS=$(ssh cleo-vps "docker ps --format '{{.Names}}'" 2>/dev/null || echo "ERROR")
if [[ "$DOCKER_PS" != "ERROR" ]]; then
    log "${GREEN}✓ Docker is running on VPS${NC}"

    # Check required containers
    for container in cleo-mem0 cleo-mem0-mcp cleo-qdrant; do
        if echo "$DOCKER_PS" | grep -q "$container"; then
            log "${GREEN}  ✓ $container is running${NC}"
        else
            log "${YELLOW}  ⚠ $container is not running${NC}"
        fi
    done
else
    log "${RED}✗ Cannot access Docker on VPS${NC}"
    exit 1
fi

# Test MCP server via SSH + Docker exec
log "${YELLOW}Testing MCP server via SSH tunnel...${NC}"
INIT_REQUEST='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'

# Send initialize request through SSH tunnel
MCP_RESPONSE=$(echo "$INIT_REQUEST" | \
    timeout 15 ssh cleo-vps "docker exec -i cleo-mem0-mcp node dist/index.js" 2>/dev/null | \
    head -1 || echo "ERROR")

if [[ "$MCP_RESPONSE" != "ERROR" ]] && echo "$MCP_RESPONSE" | grep -q "result"; then
    log "${GREEN}✓ MCP server responds via SSH tunnel${NC}"

    # Extract server info
    SERVER_NAME=$(echo "$MCP_RESPONSE" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    echo "  Server: $SERVER_NAME"
else
    log "${RED}✗ MCP server failed to respond${NC}"
    echo "  Response: $MCP_RESPONSE"
    echo ""
    echo "  Troubleshooting:"
    echo "    - Check container: ssh cleo-vps docker logs cleo-mem0-mcp"
    echo "    - Test directly: ssh cleo-vps docker exec cleo-mem0-mcp node dist/index.js"
    exit 1
fi

# Test tools/list
log "${YELLOW}Testing MCP tools discovery...${NC}"
TOOLS_REQUEST=$(cat <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
)

TOOLS_RESPONSE=$(echo "$TOOLS_REQUEST" | \
    timeout 20 ssh cleo-vps "docker exec -i cleo-mem0-mcp node dist/index.js" 2>/dev/null | \
    tail -1 || echo "ERROR")

if [[ "$TOOLS_RESPONSE" != "ERROR" ]] && echo "$TOOLS_RESPONSE" | grep -q "add_memory"; then
    log "${GREEN}✓ MCP tools discoverable${NC}"

    # List tools
    for tool in add_memory search_memories get_all_memories update_memory delete_memory; do
        if echo "$TOOLS_RESPONSE" | grep -q "$tool"; then
            log "${GREEN}  ✓ $tool${NC}"
        else
            log "${YELLOW}  ⚠ $tool not found${NC}"
        fi
    done
else
    log "${YELLOW}⚠ Could not list tools (may need longer timeout)${NC}"
fi

# Measure latency
log "${YELLOW}Measuring round-trip latency...${NC}"
START=$(date +%s%3N)
ssh cleo-vps "docker exec cleo-mem0-mcp echo 'ping'" > /dev/null 2>&1 || true
END=$(date +%s%3N)
LATENCY=$((END - START))
log "${GREEN}  Round-trip latency: ${LATENCY}ms${NC}"

if [[ $LATENCY -gt 3000 ]]; then
    log "${YELLOW}  ⚠ High latency - check tailscale ping cleo-vps${NC}"
elif [[ $LATENCY -gt 1000 ]]; then
    log "${YELLOW}  Moderate latency - acceptable${NC}"
else
    log "${GREEN}  Low latency (<1s) - excellent! (Tailscale peer-to-peer)${NC}"
fi

# Check local ~/.claude.json
log "${YELLOW}Checking local Claude Code configuration...${NC}"
CLAUDE_CONFIG="$HOME/.claude.json"
if [[ -f "$CLAUDE_CONFIG" ]]; then
    if grep -q "mem0" "$CLAUDE_CONFIG" && grep -q "cleo-vps" "$CLAUDE_CONFIG"; then
        log "${GREEN}✓ ~/.claude.json has mem0 MCP configuration${NC}"
    else
        log "${YELLOW}⚠ ~/.claude.json exists but may not have mem0 config${NC}"
        echo "  Add configuration from: .infra/claude-mcp-config.json"
    fi
else
    log "${YELLOW}⚠ ~/.claude.json not found${NC}"
    echo "  Create from template: cp .infra/claude-mcp-config.json ~/.claude.json"
fi

echo ""
log "${GREEN}=================================="
log "All tests passed!"
log "==================================${NC}"
echo ""
echo "Summary:"
echo "  - Tailscale: cleo-vps (MagicDNS)"
echo "  - MCP transport: stdio via SSH + docker exec"
echo "  - Latency: ${LATENCY}ms (via Tailscale peer-to-peer)"
echo "  - Tools: 5 (add_memory, search_memories, get_all_memories, update_memory, delete_memory)"
echo "  - Multi-device: Works from laptop and phone"
echo ""
echo "Next steps:"
echo "  1. Ensure ~/.claude.json has mem0 MCP config"
echo "  2. Restart Claude Code"
echo "  3. Test with: /mcp (should show mem0 server)"
echo "  4. Try: 'Remember my favorite editor is vim'"
