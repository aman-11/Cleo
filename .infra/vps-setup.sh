#!/usr/bin/env bash
#
# Cleo VPS Security Hardening Script
# Idempotent setup script for Hetzner CX33 VPS
# Implements security baseline: SSH keys only, fail2ban, ufw, Docker
#
# Usage: Run as root on fresh Ubuntu 24.04 VPS
# Prerequisites: authorized_keys at /tmp/authorized_keys for aman user

set -euo pipefail

# Configuration
LOG_FILE="/var/log/vps-setup.log"
ADMIN_USER="aman"
ROLLBACK_STEPS=()

# Logging function
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# Rollback function
rollback() {
    local line_number=$1
    log "ERROR: Script failed at line $line_number"
    log "ROLLBACK: Reverting completed steps (${#ROLLBACK_STEPS[@]} steps)"

    # Execute rollback steps in reverse order
    for ((i=${#ROLLBACK_STEPS[@]}-1; i>=0; i--)); do
        log "ROLLBACK: ${ROLLBACK_STEPS[$i]}"
        eval "${ROLLBACK_STEPS[$i]}" || log "ROLLBACK WARNING: Step failed: ${ROLLBACK_STEPS[$i]}"
    done

    log "ROLLBACK: Complete. Check log at $LOG_FILE for details."
    exit 1
}

# Set trap for error handling
trap 'rollback ${LINENO}' ERR

# Verification function
verify() {
    log "============================================"
    log "VERIFICATION REPORT"
    log "============================================"

    # SSH configuration
    log "SSH Config (PermitRootLogin, PasswordAuthentication):"
    grep -E "^(PermitRootLogin|PasswordAuthentication|ChallengeResponseAuthentication)" /etc/ssh/sshd_config | tee -a "$LOG_FILE"

    # Firewall status
    log ""
    log "UFW Status:"
    ufw status verbose | tee -a "$LOG_FILE"

    # fail2ban status
    log ""
    log "fail2ban Status:"
    systemctl status fail2ban --no-pager | tee -a "$LOG_FILE"

    # Docker version
    log ""
    log "Docker Version:"
    docker --version | tee -a "$LOG_FILE"

    # User verification
    log ""
    log "Admin User ($ADMIN_USER) Info:"
    id "$ADMIN_USER" | tee -a "$LOG_FILE"
    log "Groups: $(groups $ADMIN_USER)"

    log "============================================"
    log "SETUP COMPLETE - All steps verified"
    log "============================================"
}

# Main execution
log "============================================"
log "Cleo VPS Security Hardening - Starting"
log "============================================"

# Step 1: System updates
log "STEP 1: System updates"
if apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
    log "STEP 1: Complete (updates cannot be rolled back)"
else
    log "STEP 1: FAILED"
    exit 1
fi

# Step 2: Create non-root user
log "STEP 2: Create non-root user ($ADMIN_USER)"
if id "$ADMIN_USER" &>/dev/null; then
    log "STEP 2: User $ADMIN_USER already exists, skipping"
else
    adduser --disabled-password --gecos "" "$ADMIN_USER"
    usermod -aG sudo "$ADMIN_USER"

    # Configure passwordless sudo
    echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ADMIN_USER"
    chmod 0440 "/etc/sudoers.d/$ADMIN_USER"

    ROLLBACK_STEPS+=("userdel -r $ADMIN_USER 2>/dev/null || true")
    ROLLBACK_STEPS+=("rm -f /etc/sudoers.d/$ADMIN_USER")
    log "STEP 2: Complete - User $ADMIN_USER created with sudo access"
fi

# Step 3: SSH key setup
log "STEP 3: SSH key setup for $ADMIN_USER"
SSH_DIR="/home/$ADMIN_USER/.ssh"
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Copy authorized_keys from /tmp if available
    if [ -f /tmp/authorized_keys ]; then
        cp /tmp/authorized_keys "$SSH_DIR/authorized_keys"
        chmod 600 "$SSH_DIR/authorized_keys"
        chown -R "$ADMIN_USER:$ADMIN_USER" "$SSH_DIR"
        log "STEP 3: Complete - SSH keys copied from /tmp/authorized_keys"
    else
        log "STEP 3: WARNING - /tmp/authorized_keys not found. You must manually add SSH keys to $SSH_DIR/authorized_keys before disabling password auth."
    fi

    ROLLBACK_STEPS+=("rm -rf $SSH_DIR")
else
    log "STEP 3: $SSH_DIR already exists, skipping"
fi

# Step 4: Harden SSH configuration
log "STEP 4: Harden SSH configuration"
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original config
if [ ! -f "${SSHD_CONFIG}.backup" ]; then
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup"
    ROLLBACK_STEPS+=("mv ${SSHD_CONFIG}.backup $SSHD_CONFIG")
fi

# Apply SSH hardening
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"

# Restart SSH (Ubuntu uses 'ssh' service name, not 'sshd')
systemctl restart ssh
log "STEP 4: Complete - SSH hardened (root login disabled, password auth disabled)"

# Step 5: Configure UFW firewall
log "STEP 5: Configure UFW firewall"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
log "STEP 5: Complete - UFW enabled (SSH only)"

# Step 6: Install and configure fail2ban
log "STEP 6: Install fail2ban"
if ! command -v fail2ban-client &>/dev/null; then
    apt install -y fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    log "STEP 6: Complete - fail2ban installed and running"
else
    log "STEP 6: fail2ban already installed, ensuring it's running"
    systemctl enable fail2ban
    systemctl start fail2ban
fi

# Step 7: Install Docker
log "STEP 7: Install Docker"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$ADMIN_USER"
    log "STEP 7: Complete - Docker installed, $ADMIN_USER added to docker group"
else
    log "STEP 7: Docker already installed, ensuring $ADMIN_USER in docker group"
    usermod -aG docker "$ADMIN_USER"
fi

# Step 8: Configure Docker logging
log "STEP 8: Configure Docker logging"
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
if [ ! -f "$DOCKER_DAEMON_JSON" ]; then
    cat > "$DOCKER_DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  }
}
EOF
    systemctl restart docker
    log "STEP 8: Complete - Docker logging configured (json-file, 10m max, 3 files, compressed)"
else
    log "STEP 8: $DOCKER_DAEMON_JSON already exists, skipping"
fi

# Step 9: Install unattended-upgrades
log "STEP 9: Install and configure unattended-upgrades"
if ! dpkg -l | grep -q unattended-upgrades; then
    apt install -y unattended-upgrades

    # Configure to exclude Docker packages from auto-updates
    cat > /etc/apt/apt.conf.d/51unattended-upgrades-docker-blacklist <<'EOF'
// Exclude Docker packages from unattended-upgrades
Unattended-Upgrade::Package-Blacklist {
    "docker-ce";
    "docker-ce-cli";
    "containerd.io";
};
EOF

    # Enable automatic security updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    log "STEP 9: Complete - unattended-upgrades configured (security only, Docker excluded)"
else
    log "STEP 9: unattended-upgrades already installed"
fi

# Step 10: Verification
log "STEP 10: Running verification checks"
verify

log ""
log "============================================"
log "SUCCESS: VPS security hardening complete"
log "============================================"
log "Next steps:"
log "  1. Exit and reconnect as: ssh $ADMIN_USER@<VPS_IP>"
log "  2. Verify root login fails: ssh root@<VPS_IP> (should fail)"
log "  3. Proceed to Docker Compose deployment"
log "============================================"
log ""

exit 0
