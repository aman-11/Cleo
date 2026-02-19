#!/usr/bin/env bash
#
# OpenClaw Deployment Script
# Follows official docs: https://docs.openclaw.ai/install/docker
#
# CONTEXT.md LOCKED DECISION:
# - Clone official repo
# - Checkout v2026.1.29 (CVE-2026-25253 patched)
# - Run ./docker-setup.sh
# - Image is openclaw:local (NOT Docker Hub)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/openclaw-setup.log"
OPENCLAW_DIR="/home/aman/openclaw"
OPENCLAW_VERSION="v2026.1.29"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    log "ERROR: $1"
    exit 1
}

# Ensure running as aman user (not root)
if [[ "$EUID" -eq 0 ]]; then
    error "This script should be run as 'aman' user, not root. Use: su - aman -c '$0'"
fi

log "=== OpenClaw Deployment Script ==="
log "Version: $OPENCLAW_VERSION (CVE-2026-25253 patched)"

# Step 1: Clone OpenClaw repo (or update if exists)
log "Step 1: Cloning OpenClaw repository..."
if [[ -d "$OPENCLAW_DIR" ]]; then
    log "OpenClaw directory exists, updating..."
    cd "$OPENCLAW_DIR"
    git fetch --all --tags
else
    log "Cloning fresh OpenClaw repo..."
    git clone https://github.com/openclaw/openclaw.git "$OPENCLAW_DIR"
    cd "$OPENCLAW_DIR"
fi

# Step 2: Checkout patched version
log "Step 2: Checking out $OPENCLAW_VERSION..."
git checkout "$OPENCLAW_VERSION" || error "Failed to checkout $OPENCLAW_VERSION"
log "Checked out $(git describe --tags 2>/dev/null || git rev-parse --short HEAD)"

# Step 3: Run official docker-setup.sh
log "Step 3: Running official docker-setup.sh..."
log "This will build openclaw:local image and run onboarding wizard"
if [[ ! -x "./docker-setup.sh" ]]; then
    chmod +x ./docker-setup.sh
fi
./docker-setup.sh || error "docker-setup.sh failed"

# Step 4: Verify image was built
log "Step 4: Verifying openclaw:local image..."
if docker image inspect openclaw:local &>/dev/null; then
    log "SUCCESS: openclaw:local image exists"
    docker image inspect openclaw:local --format '{{.Id}}' | head -c 20
else
    error "openclaw:local image NOT found after build"
fi

# Step 5: Configure network to use cleo-network
log "Step 5: Configuring OpenClaw to use cleo-network..."
COMPOSE_FILE="$OPENCLAW_DIR/docker-compose.yml"
if [[ -f "$COMPOSE_FILE" ]]; then
    # Add external network reference if not present
    if ! grep -q "cleo-network" "$COMPOSE_FILE"; then
        log "Adding cleo-network to OpenClaw compose file..."
        # Append network configuration
        cat >> "$COMPOSE_FILE" << 'EOF'

networks:
  cleo-network:
    external: true
    name: cleo-network
EOF
        log "cleo-network added to OpenClaw compose"
    else
        log "cleo-network already configured"
    fi
else
    log "WARNING: OpenClaw docker-compose.yml not found at expected location"
fi

# Step 6: Print dashboard access instructions
log ""
log "=== OpenClaw Deployment Complete ==="
log ""
log "DASHBOARD ACCESS (SSH Tunnel Required):"
log "From local machine:"
log "  ssh -L 18789:localhost:18789 cleo-vps"
log ""
log "Then browse to:"
log "  http://localhost:18789"
log ""
log "START OPENCLAW:"
log "  cd $OPENCLAW_DIR && docker compose up -d"
log ""
log "CONFIGURE DISCORD CHANNEL:"
log "  docker compose run --rm openclaw-cli channels add --channel discord --token 'YOUR_DISCORD_BOT_TOKEN'"
log ""
log "Security: Port 18789 is bound to 127.0.0.1 only (VPS localhost)"
log "         Requires SSH tunnel to access from outside VPS"
