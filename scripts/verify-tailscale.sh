#!/bin/bash
# scripts/verify-tailscale.sh - Verify Tailscale connectivity and services
#
# Run this script from any device on the tailnet to verify connectivity
# to the Cleo VPS and its services.

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

# Check Tailscale status
check_tailscale_local() {
    info "Checking local Tailscale status..."

    if ! command -v tailscale &> /dev/null; then
        fail "Tailscale not installed locally"
        echo "  Install: curl -fsSL https://tailscale.com/install.sh | sh"
        FAILURES=$((FAILURES + 1))
        return
    fi

    if tailscale status &> /dev/null; then
        pass "Tailscale is running"

        # Show local device info
        local local_ip
        local_ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
        info "  Local Tailscale IP: $local_ip"
    else
        fail "Tailscale is not connected"
        echo "  Connect: tailscale up"
        FAILURES=$((FAILURES + 1))
    fi
}

# Check VPS reachability via Tailscale
check_vps_reachable() {
    info "Checking VPS reachability via Tailscale..."

    # Try to resolve cleo-vps via MagicDNS
    if ping -c 1 -W 5 cleo-vps &> /dev/null; then
        pass "VPS reachable via MagicDNS (cleo-vps)"
    else
        # Fallback: check if VPS is in tailnet
        local vps_ip
        vps_ip=$(tailscale status --json 2>/dev/null | grep -o '"cleo-vps"[^}]*' | grep -o '"TailscaleIPs":\["[^"]*"' | cut -d'"' -f4 || echo "")

        if [[ -n "$vps_ip" ]]; then
            warn "MagicDNS may not be working, but VPS found at: $vps_ip"
            if ping -c 1 -W 5 "$vps_ip" &> /dev/null; then
                pass "VPS reachable via Tailscale IP ($vps_ip)"
            else
                fail "VPS not reachable even via Tailscale IP"
                FAILURES=$((FAILURES + 1))
            fi
        else
            fail "VPS (cleo-vps) not found in tailnet"
            echo "  Check: tailscale status"
            FAILURES=$((FAILURES + 1))
        fi
    fi
}

# Check SSH access
check_ssh_access() {
    info "Checking SSH access via Tailscale..."

    if ssh -o ConnectTimeout=10 -o BatchMode=yes cleo-vps echo "SSH_OK" 2>/dev/null | grep -q "SSH_OK"; then
        pass "SSH access working via Tailscale"
    else
        warn "SSH access via 'cleo-vps' failed"
        echo "  May need to update ~/.ssh/config to use Tailscale IP"
        echo "  Or ensure SSH key is configured"
    fi
}

# Check VPS services via Tailscale
check_vps_services() {
    info "Checking VPS services via Tailscale..."

    # OpenClaw Gateway
    if curl -sf --connect-timeout 10 "http://cleo-vps:18789/health" &> /dev/null; then
        pass "OpenClaw Gateway accessible (http://cleo-vps:18789)"
    else
        warn "OpenClaw Gateway not accessible via Tailscale"
        echo "  May need to bind to 0.0.0.0 or Tailscale IP"
    fi

    # mem0 API
    if curl -sf --connect-timeout 10 "http://cleo-vps:8080/health" &> /dev/null; then
        pass "mem0 API accessible (http://cleo-vps:8080)"
    else
        warn "mem0 API not accessible via Tailscale"
        echo "  Services may be bound to localhost only"
    fi

    # Qdrant
    if curl -sf --connect-timeout 10 "http://cleo-vps:6333/health" &> /dev/null; then
        pass "Qdrant accessible (http://cleo-vps:6333)"
    else
        warn "Qdrant not accessible via Tailscale"
        echo "  Service may be bound to localhost only"
    fi
}

# Measure latency
measure_latency() {
    info "Measuring Tailscale latency to VPS..."

    local latency
    latency=$(ping -c 5 cleo-vps 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "N/A")

    if [[ "$latency" != "N/A" ]]; then
        info "  Average latency: ${latency}ms"

        if (( $(echo "$latency < 50" | bc -l 2>/dev/null || echo 0) )); then
            pass "Excellent latency (<50ms)"
        elif (( $(echo "$latency < 100" | bc -l 2>/dev/null || echo 0) )); then
            pass "Good latency (<100ms)"
        else
            warn "High latency (${latency}ms) - may affect MCP tool responsiveness"
        fi
    else
        warn "Could not measure latency"
    fi
}

# Show tailnet devices
show_devices() {
    info "Devices in your tailnet:"
    tailscale status 2>/dev/null | head -20 || echo "  (Could not retrieve device list)"
}

# Print summary
print_summary() {
    echo ""
    echo "=================================="
    echo "Tailscale Verification Summary"
    echo "=================================="

    if [ $FAILURES -eq 0 ]; then
        pass "All critical checks passed"
        echo ""
        echo "Your devices can now access Cleo VPS services via Tailscale:"
        echo "  - SSH: ssh aman@cleo-vps"
        echo "  - OpenClaw: http://cleo-vps:18789/"
        echo "  - mem0: http://cleo-vps:8080/"
    else
        fail "$FAILURES critical check(s) failed"
        echo ""
        echo "Troubleshooting:"
        echo "  - Ensure Tailscale is running: tailscale up"
        echo "  - Check VPS Tailscale: ssh -o 'HostName=<VPS-PUBLIC-IP>' aman@vps tailscale status"
        echo "  - View logs: tailscale bugreport"
    fi
}

# Main
main() {
    echo "=================================="
    echo "Tailscale Connectivity Verification"
    echo "=================================="
    echo ""

    check_tailscale_local
    check_vps_reachable
    check_ssh_access
    check_vps_services
    measure_latency
    show_devices
    print_summary

    exit $FAILURES
}

main "$@"
