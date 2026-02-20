#!/bin/bash
# scripts/verify-openclaw.sh - OpenClaw Health Verification and Diagnostics
#
# Run this script to check OpenClaw Gateway health and diagnose issues.
# Can be run at any time for health checks.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
pass() { log "${GREEN}PASS${NC} $1"; }
fail() { log "${RED}FAIL${NC} $1"; }
warn() { log "${YELLOW}WARN${NC} $1"; }
info() { log "${BLUE}INFO${NC} $1"; }

FAILURES=0

# Check Docker container status
check_containers() {
    info "Checking Docker containers..."

    for container in cleo-openclaw cleo-mem0-mcp cleo-mem0 cleo-qdrant; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            pass "$container is running"
        else
            fail "$container is NOT running"
            FAILURES=$((FAILURES + 1))
        fi
    done
}

# Check OpenClaw Gateway health
check_gateway_health() {
    info "Checking OpenClaw Gateway health..."

    # HTTP health endpoint
    local health_response
    health_response=$(curl -sf http://127.0.0.1:18789/health 2>&1 || echo "ERROR")

    if [[ "$health_response" != "ERROR" ]]; then
        pass "Gateway HTTP health endpoint responding"
    else
        fail "Gateway HTTP health endpoint not responding"
        FAILURES=$((FAILURES + 1))
    fi

    # Gateway status via CLI
    local status
    status=$(docker compose exec -T openclaw openclaw gateway status 2>&1 || echo "ERROR")

    if echo "$status" | grep -q "Runtime: running"; then
        pass "Gateway runtime: running"
    else
        fail "Gateway runtime not running"
        echo "  Status output: $status"
        FAILURES=$((FAILURES + 1))
    fi

    if echo "$status" | grep -q "RPC probe: ok"; then
        pass "Gateway RPC probe: ok"
    else
        warn "Gateway RPC probe unclear"
    fi
}

# Check channel status
check_channels() {
    info "Checking channel status..."

    local channels
    channels=$(docker compose exec -T openclaw openclaw channels status --probe 2>&1 || echo "ERROR")

    if echo "$channels" | grep -qi "discord.*connected\|discord.*ready"; then
        pass "Discord channel connected"
    else
        warn "Discord channel status unclear"
        echo "  Channel output: $channels"
    fi
}

# Check MCP servers
check_mcp_servers() {
    info "Checking MCP servers..."

    # Test mem0 MCP server
    local mcp_response
    mcp_response=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}' | \
        timeout 10 docker compose exec -T cleo-mem0-mcp node dist/index.js 2>/dev/null | head -1 || echo "ERROR")

    if [[ "$mcp_response" != "ERROR" ]] && echo "$mcp_response" | grep -q "result"; then
        pass "mem0 MCP server responds correctly"

        # Extract server info
        local server_name
        server_name=$(echo "$mcp_response" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
        info "  Server name: $server_name"
    else
        fail "mem0 MCP server not responding"
        FAILURES=$((FAILURES + 1))
    fi

    # Test tools/list
    local tools_response
    tools_response=$(cat <<'EOF' | timeout 15 docker compose exec -T cleo-mem0-mcp node dist/index.js 2>/dev/null | tail -1 || echo "ERROR"
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
)

    if [[ "$tools_response" != "ERROR" ]] && echo "$tools_response" | grep -q "add_memory"; then
        pass "MCP tools discoverable (add_memory found)"

        # Count tools
        local tool_count
        tool_count=$(echo "$tools_response" | grep -o '"name":"[a-z_]*"' | wc -l | tr -d ' ')
        info "  Tools found: $tool_count"
    else
        warn "MCP tools discovery returned unexpected result"
    fi
}

# Check backend services
check_backend_services() {
    info "Checking backend services..."

    # mem0 API
    local mem0_health
    mem0_health=$(curl -sf http://127.0.0.1:8080/health 2>&1 || echo "ERROR")

    if [[ "$mem0_health" != "ERROR" ]]; then
        pass "mem0 API health check passed"
    else
        fail "mem0 API not responding on localhost:8080"
        FAILURES=$((FAILURES + 1))
    fi

    # Qdrant
    local qdrant_health
    qdrant_health=$(curl -sf http://127.0.0.1:6333/health 2>&1 || echo "ERROR")

    if [[ "$qdrant_health" != "ERROR" ]]; then
        pass "Qdrant health check passed"
    else
        fail "Qdrant not responding on localhost:6333"
        FAILURES=$((FAILURES + 1))
    fi
}

# Check resource usage
check_resources() {
    info "Checking resource usage..."

    # Get container stats
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
        cleo-openclaw cleo-mem0-mcp cleo-mem0 cleo-qdrant 2>/dev/null || true
}

# Run OpenClaw doctor
run_doctor() {
    info "Running OpenClaw doctor..."

    docker compose exec -T openclaw openclaw doctor 2>&1 || true
}

# Print summary
print_summary() {
    echo ""
    echo "=================================="
    echo "Verification Summary"
    echo "=================================="

    if [ $FAILURES -eq 0 ]; then
        pass "All critical checks passed"
    else
        fail "$FAILURES critical check(s) failed"
        echo ""
        echo "Troubleshooting commands:"
        echo "  - View logs:       docker compose logs openclaw -f"
        echo "  - Restart:         docker compose restart openclaw"
        echo "  - Full diagnostics: docker compose exec openclaw openclaw doctor"
    fi
}

# Main
main() {
    echo "=================================="
    echo "OpenClaw Health Verification"
    echo "=================================="
    echo ""

    check_containers
    check_gateway_health
    check_channels
    check_mcp_servers
    check_backend_services
    check_resources
    run_doctor
    print_summary

    exit $FAILURES
}

main "$@"
