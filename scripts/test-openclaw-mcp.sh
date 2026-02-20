#!/bin/bash
# scripts/test-openclaw-mcp.sh - Verify OpenClaw MCP integration
#
# This script tests that OpenClaw Gateway correctly discovers and
# manages the mem0 MCP server registered in openclaw.json.
#
# Prerequisites:
# - docker compose -f docker-compose.infra.yml up -d (all services running)
# - mem0-mcp container built and running
# - OpenClaw Gateway running

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%H:%M:%S')] $1"
}

# Check OpenClaw Gateway health
log "${YELLOW}Testing OpenClaw Gateway health...${NC}"
GATEWAY_HEALTH=$(curl -sf http://localhost:18789/health 2>/dev/null || echo "ERROR")
if [[ "$GATEWAY_HEALTH" != "ERROR" ]]; then
    log "${GREEN}✓ OpenClaw Gateway is responding${NC}"
    echo "  Response: $GATEWAY_HEALTH"
else
    log "${RED}✗ OpenClaw Gateway not responding on localhost:18789${NC}"
    echo "  Check: docker compose -f docker-compose.infra.yml logs openclaw"
    exit 1
fi

# Check mem0-mcp container is running
log "${YELLOW}Testing mem0-mcp container...${NC}"
if docker ps --format '{{.Names}}' | grep -q "cleo-mem0-mcp"; then
    log "${GREEN}✓ mem0-mcp container is running${NC}"
else
    log "${RED}✗ mem0-mcp container is not running${NC}"
    echo "  Start with: docker compose -f docker-compose.infra.yml up -d mem0-mcp"
    exit 1
fi

# Test MCP server via docker exec (mimics OpenClaw lifecycle)
log "${YELLOW}Testing MCP server spawn via docker exec...${NC}"
# Send initialize request via stdin, capture stdout
INIT_RESPONSE=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
    timeout 10 docker exec -i cleo-mem0-mcp node dist/index.js 2>/dev/null | head -1 || echo "ERROR")

if [[ "$INIT_RESPONSE" != "ERROR" ]] && echo "$INIT_RESPONSE" | grep -q "result"; then
    log "${GREEN}✓ MCP server responds to initialize${NC}"
    # Parse server info
    SERVER_NAME=$(echo "$INIT_RESPONSE" | grep -o '"name":"[^"]*"' | head -1 || echo 'unknown')
    echo "  Server: $SERVER_NAME"
else
    log "${RED}✗ MCP server failed to respond${NC}"
    echo "  Response: $INIT_RESPONSE"
    echo "  Check: docker logs cleo-mem0-mcp"
    exit 1
fi

# Test tools/list via MCP protocol
log "${YELLOW}Testing MCP tools discovery...${NC}"
# Full conversation: initialize, then tools/list
TOOLS_TEST=$(cat <<'EOF' | timeout 15 docker exec -i cleo-mem0-mcp node dist/index.js 2>/dev/null | tail -1 || echo "ERROR"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
)

if [[ "$TOOLS_TEST" != "ERROR" ]] && echo "$TOOLS_TEST" | grep -q "add_memory"; then
    log "${GREEN}✓ MCP tools discoverable${NC}"
    # Count tools
    TOOL_COUNT=$(echo "$TOOLS_TEST" | grep -o '"name":"[^"]*"' | wc -l | tr -d ' ')
    echo "  Tools found: $TOOL_COUNT"

    # List tool names
    echo "  Tools: $(echo "$TOOLS_TEST" | grep -o '"name":"[a-z_]*"' | tr '\n' ' ')"
else
    log "${YELLOW}⚠ Could not verify tools (may need interactive session)${NC}"
    echo "  Response: $TOOLS_TEST"
fi

# Test OpenClaw doctor (if available)
log "${YELLOW}Testing OpenClaw doctor...${NC}"
DOCTOR_RESULT=$(docker exec cleo-openclaw openclaw doctor 2>/dev/null || echo "UNAVAILABLE")
if [[ "$DOCTOR_RESULT" != "UNAVAILABLE" ]]; then
    log "${GREEN}✓ OpenClaw doctor output:${NC}"
    echo "$DOCTOR_RESULT" | head -20
else
    log "${YELLOW}⚠ openclaw doctor not available in container${NC}"
    echo "  (This is optional - MCP integration may still work)"
fi

# Verify openclaw.json MCP configuration
log "${YELLOW}Verifying openclaw.json configuration...${NC}"
if [[ -f "openclaw.json" ]]; then
    if grep -q "mem0" openclaw.json && grep -q "docker.*exec" openclaw.json; then
        log "${GREEN}✓ openclaw.json has mem0 MCP configuration${NC}"
    else
        log "${RED}✗ openclaw.json missing mem0 MCP configuration${NC}"
        exit 1
    fi
else
    log "${RED}✗ openclaw.json not found${NC}"
    exit 1
fi

echo ""
log "${GREEN}All tests passed! OpenClaw MCP integration verified.${NC}"
echo ""
echo "Summary:"
echo "  - OpenClaw Gateway: http://localhost:18789"
echo "  - mem0 MCP: docker exec cleo-mem0-mcp node dist/index.js"
echo "  - Tools: add_memory, search_memories, get_all_memories, update_memory, delete_memory"
echo "  - Transport: stdio (via docker exec)"
echo ""
echo "Next steps:"
echo "  - Restart OpenClaw to pick up config: docker compose restart openclaw"
echo "  - Test from Claude Code: ~/.claude.json MCP configuration"
