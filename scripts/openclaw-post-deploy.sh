#!/bin/bash
# scripts/openclaw-post-deploy.sh - OpenClaw Post-Deployment Configuration
#
# Run this script after `docker compose up -d openclaw` to configure:
# - Gateway authentication
# - Discord channel
# - MCP server verification
# - Health checks
#
# Prerequisites:
# - docker-compose.infra.yml services running
# - .env file with required environment variables

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date '+%H:%M:%S')] $1"; }
info() { log "${BLUE}INFO:${NC} $1"; }
success() { log "${GREEN}✓${NC} $1"; }
warn() { log "${YELLOW}⚠${NC} $1"; }
error() { log "${RED}✗${NC} $1"; }

# Check required environment variables
check_env_vars() {
    info "Checking required environment variables..."
    local missing=0

    for var in OPENCLAW_GATEWAY_TOKEN DISCORD_BOT_TOKEN MEM0_API_KEY OPENROUTER_API_KEY; do
        if [ -z "${!var:-}" ]; then
            error "Missing required environment variable: $var"
            missing=1
        else
            success "$var is set"
        fi
    done

    if [ $missing -eq 1 ]; then
        error "Please set missing environment variables in .env and re-run"
        exit 1
    fi
}

# Wait for OpenClaw container to be ready
wait_for_openclaw() {
    info "Waiting for OpenClaw Gateway to be ready..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose exec -T openclaw curl -sf http://localhost:18789/health > /dev/null 2>&1; then
            success "OpenClaw Gateway is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    echo ""
    error "OpenClaw Gateway did not become ready within 60 seconds"
    echo "Check logs: docker compose logs openclaw"
    exit 1
}

# Check gateway status
check_gateway_status() {
    info "Checking OpenClaw Gateway status..."

    local status_output
    status_output=$(docker compose exec -T openclaw openclaw gateway status 2>&1 || true)

    if echo "$status_output" | grep -q "Runtime: running"; then
        success "Gateway runtime: running"
    else
        warn "Gateway status check returned: $status_output"
    fi

    if echo "$status_output" | grep -q "RPC probe: ok"; then
        success "Gateway RPC probe: ok"
    fi
}

# Configure Discord channel
configure_discord() {
    info "Configuring Discord channel..."

    # Check if Discord is already configured
    local discord_status
    discord_status=$(docker compose exec -T openclaw openclaw channels status --probe 2>&1 || true)

    if echo "$discord_status" | grep -qi "discord.*connected\|discord.*ready"; then
        success "Discord channel already configured and connected"
        return 0
    fi

    # Add Discord channel via CLI
    info "Adding Discord channel..."
    docker compose exec -T openclaw openclaw channels add \
        --channel discord \
        --token "$DISCORD_BOT_TOKEN" 2>&1 || {
        warn "Discord channel add command returned non-zero (may already exist)"
    }

    # Verify Discord connection
    sleep 5
    discord_status=$(docker compose exec -T openclaw openclaw channels status --probe 2>&1 || true)

    if echo "$discord_status" | grep -qi "discord"; then
        success "Discord channel configured"
    else
        warn "Discord channel status unclear - check manually with: docker compose exec openclaw openclaw channels status --probe"
    fi
}

# Verify MCP server registration
verify_mcp_servers() {
    info "Verifying MCP server registration..."

    # Check for MCP server logs
    local mcp_logs
    mcp_logs=$(docker compose logs openclaw 2>&1 | grep -i "mcp" | tail -5 || true)

    if echo "$mcp_logs" | grep -qi "mem0"; then
        success "mem0 MCP server appears in logs"
    else
        warn "mem0 MCP server not found in recent logs - may need gateway restart"
    fi

    # Test MCP server via docker exec
    info "Testing mem0 MCP server response..."
    local init_response
    init_response=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
        timeout 15 docker compose exec -T cleo-mem0-mcp node dist/index.js 2>/dev/null | head -1 || echo "ERROR")

    if [[ "$init_response" != "ERROR" ]] && echo "$init_response" | grep -q "result"; then
        success "mem0 MCP server responds to initialize request"
    else
        warn "mem0 MCP server not responding - check container: docker logs cleo-mem0-mcp"
    fi
}

# Run OpenClaw doctor
run_doctor() {
    info "Running OpenClaw doctor diagnostics..."

    local doctor_output
    doctor_output=$(docker compose exec -T openclaw openclaw doctor 2>&1 || true)

    echo "--- Doctor Output ---"
    echo "$doctor_output"
    echo "--------------------"

    if echo "$doctor_output" | grep -qi "error\|critical\|blocking"; then
        warn "Doctor found issues - review output above"
        echo ""
        echo "To auto-fix issues, run: docker compose exec openclaw openclaw doctor --fix"
    else
        success "Doctor reports no blocking issues"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=================================="
    echo "OpenClaw Post-Deployment Summary"
    echo "=================================="
    echo ""
    echo "Services:"
    echo "  - OpenClaw Gateway: http://127.0.0.1:18789"
    echo "  - Control UI: http://127.0.0.1:18789/"
    echo ""
    echo "Configuration:"
    echo "  - Config file: ~/.openclaw/openclaw.json"
    echo "  - Workspace: ~/.openclaw/workspace"
    echo ""
    echo "Useful commands:"
    echo "  - Gateway status:   docker compose exec openclaw openclaw gateway status"
    echo "  - Channel status:   docker compose exec openclaw openclaw channels status --probe"
    echo "  - View logs:        docker compose logs openclaw -f"
    echo "  - Run diagnostics:  docker compose exec openclaw openclaw doctor"
    echo "  - Restart gateway:  docker compose restart openclaw"
    echo ""
    echo "Next steps:"
    echo "  1. Access Control UI: http://127.0.0.1:18789/"
    echo "  2. Paste gateway token from .env into Settings"
    echo "  3. Test Discord: Send DM to bot"
    echo "  4. Test mem0 MCP: Ask bot to 'Remember my test value is 42'"
    echo ""
}

# Main execution
main() {
    echo "=================================="
    echo "OpenClaw Post-Deployment Setup"
    echo "=================================="
    echo ""

    # Load .env if exists
    if [ -f .env ]; then
        info "Loading .env file..."
        set -a
        source .env
        set +a
    fi

    check_env_vars
    wait_for_openclaw
    check_gateway_status
    configure_discord
    verify_mcp_servers
    run_doctor
    print_summary

    success "Post-deployment configuration complete!"
}

main "$@"
