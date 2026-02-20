#!/bin/bash
# scripts/setup-tailscale.sh - Install and configure Tailscale on VPS
#
# This script sets up Tailscale on the Cleo VPS for secure multi-device access.
#
# Prerequisites:
# - Root or sudo access on VPS
# - Tailscale account (https://login.tailscale.com)
#
# What this does:
# - Installs Tailscale (curl | sh installer)
# - Authenticates to your tailnet (opens browser or uses auth key)
# - Configures MagicDNS hostname (cleo-vps)
# - Configures UFW to allow Tailscale interface
# - Verifies connectivity

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo)"
        echo "  Usage: sudo ./scripts/setup-tailscale.sh"
        exit 1
    fi
}

# Check if Tailscale is already installed
check_existing() {
    if command -v tailscale &> /dev/null; then
        info "Tailscale is already installed"
        tailscale version

        # Check if already connected
        if tailscale status &> /dev/null; then
            success "Tailscale is already connected"
            tailscale status

            read -p "Do you want to reconfigure? (y/N): " reconfigure
            if [[ "${reconfigure,,}" != "y" ]]; then
                info "Skipping reconfiguration. Run 'tailscale up' to reconnect if needed."
                exit 0
            fi
        fi
    fi
}

# Install Tailscale
install_tailscale() {
    info "Installing Tailscale..."

    # Official one-liner installer
    curl -fsSL https://tailscale.com/install.sh | sh

    # Verify installation
    if command -v tailscale &> /dev/null; then
        success "Tailscale installed successfully"
        tailscale version
    else
        error "Tailscale installation failed"
        exit 1
    fi
}

# Configure UFW for Tailscale
configure_ufw() {
    info "Configuring UFW for Tailscale..."

    if command -v ufw &> /dev/null; then
        # Allow Tailscale interface (tailscale0)
        # Tailscale handles its own encryption, so we allow all traffic on tailscale0
        ufw allow in on tailscale0
        ufw allow out on tailscale0

        success "UFW configured to allow Tailscale interface"

        # Note: We keep existing SSH rules for fallback access
        info "Existing SSH rules preserved for fallback access"
    else
        warn "UFW not installed - skipping firewall configuration"
    fi
}

# Authenticate and connect to Tailnet
authenticate_tailscale() {
    info "Authenticating Tailscale..."

    # Check for auth key environment variable
    if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
        info "Using TAILSCALE_AUTH_KEY for authentication"
        tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname="cleo-vps"
    else
        info "No TAILSCALE_AUTH_KEY found. Using interactive authentication."
        echo ""
        echo "  A browser window will open (or URL will be displayed)."
        echo "  Log in with your Tailscale account to authorize this device."
        echo ""

        tailscale up --hostname="cleo-vps"
    fi

    # Verify connection
    sleep 3
    if tailscale status &> /dev/null; then
        success "Tailscale connected successfully"
        tailscale status
    else
        error "Tailscale connection failed"
        echo "  Check: tailscale status"
        exit 1
    fi
}

# Configure MagicDNS hostname
configure_hostname() {
    info "Configuring MagicDNS hostname..."

    # Hostname is set during 'tailscale up' with --hostname flag
    # Verify it's set correctly
    local current_hostname
    current_hostname=$(tailscale status --json | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

    if [[ "$current_hostname" == "cleo-vps" ]]; then
        success "MagicDNS hostname: cleo-vps"
    else
        warn "Hostname is '$current_hostname', expected 'cleo-vps'"
        echo "  To change: tailscale set --hostname=cleo-vps"
    fi

    # Display MagicDNS info
    info "Your VPS is now accessible via:"
    echo "  - cleo-vps (within your tailnet)"
    echo "  - cleo-vps.[tailnet-name].ts.net (fully qualified)"
}

# Display next steps
show_next_steps() {
    echo ""
    echo "=================================="
    echo "Tailscale Setup Complete"
    echo "=================================="
    echo ""
    echo "VPS Information:"
    echo "  - Hostname: cleo-vps"
    tailscale ip -4 | xargs -I{} echo "  - Tailscale IP: {}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Install Tailscale on your laptop:"
    echo "     - macOS: brew install tailscale"
    echo "     - Linux: curl -fsSL https://tailscale.com/install.sh | sh"
    echo "     - Windows: https://tailscale.com/download/windows"
    echo ""
    echo "  2. Install Tailscale on your phone:"
    echo "     - iOS: App Store 'Tailscale'"
    echo "     - Android: Play Store 'Tailscale'"
    echo ""
    echo "  3. Connect both devices to same tailnet (same login)"
    echo ""
    echo "  4. Verify connectivity:"
    echo "     ssh aman@cleo-vps  # From laptop"
    echo "     # Access VPS web services from phone browser"
    echo ""
    echo "  5. Update Claude Code MCP config to use Tailscale:"
    echo "     # In ~/.claude.json, change 'cleo-vps' SSH alias to Tailscale hostname"
    echo ""
    echo "Useful commands:"
    echo "  - Status:     tailscale status"
    echo "  - IP:         tailscale ip -4"
    echo "  - Reconnect:  tailscale up"
    echo "  - Disconnect: tailscale down"
    echo ""
}

# Main execution
main() {
    echo "=================================="
    echo "Cleo VPS - Tailscale Setup"
    echo "=================================="
    echo ""

    check_root
    check_existing
    install_tailscale
    configure_ufw
    authenticate_tailscale
    configure_hostname
    show_next_steps

    success "Tailscale setup complete!"
}

main "$@"
