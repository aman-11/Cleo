#!/usr/bin/env bash
#
# Idempotent deployment script for Cleo VPS infrastructure
# Can be run multiple times safely - only updates what's changed
#
# Usage: ./scripts/deploy-to-vps.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VPS_HOST="cleo-vps"
VPS_USER="aman"
PROJECT_PATH="/opt/cleo"
LOCAL_PATH="/Users/aayushaman/personal/Cleo"

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_tailscale() {
    log_info "Checking connection to ${VPS_HOST}..."

    # Try Tailscale first if available
    if command -v tailscale &> /dev/null; then
        if tailscale status | grep -q "${VPS_HOST}"; then
            log_info "✅ Tailscale connection verified"
            return 0
        fi
    fi

    # Fall back to SSH config check
    if ssh -o ConnectTimeout=5 "${VPS_USER}@${VPS_HOST}" "echo 'SSH OK'" &>/dev/null; then
        log_info "✅ SSH connection verified (via SSH config or Tailscale)"
        return 0
    fi

    log_error "Cannot connect to ${VPS_HOST}"
    log_info "Ensure Tailscale is running or SSH config is set up"
    exit 1
}

# check_ssh is now handled by check_tailscale()

sync_files() {
    log_info "Syncing files to VPS..."

    # Create project directory if it doesn't exist
    ssh "${VPS_USER}@${VPS_HOST}" "mkdir -p ${PROJECT_PATH}"

    # Sync files (excluding dev artifacts)
    rsync -avz \
        --exclude='.git' \
        --exclude='.claude' \
        --exclude='.planning' \
        --exclude='.archive' \
        --exclude='.zed' \
        --exclude='node_modules' \
        --exclude='dist' \
        --exclude='.env.local' \
        --exclude='*.log' \
        --exclude='README.md' \
        --delete \
        "${LOCAL_PATH}/" \
        "${VPS_USER}@${VPS_HOST}:${PROJECT_PATH}/"

    log_info "✅ Files synced"
}

check_env_file() {
    log_info "Checking .env file on VPS..."

    if ! ssh "${VPS_USER}@${VPS_HOST}" "test -f ${PROJECT_PATH}/.env"; then
        log_warn ".env file not found on VPS"
        log_info "Copy your .env file manually:"
        echo "  scp .env ${VPS_USER}@${VPS_HOST}:${PROJECT_PATH}/.env"
        return 1
    fi

    log_info "✅ .env file exists"
    return 0
}

deploy_infrastructure() {
    log_info "Deploying infrastructure services..."

    # Build custom images (mem0, mem0-mcp) on VPS
    log_info "Building custom Docker images..."
    ssh "${VPS_USER}@${VPS_HOST}" "cd ${PROJECT_PATH} && docker compose -f docker-compose.infra.yml build"

    # Pull pre-built images (postgres only - using Qdrant Cloud)
    log_info "Pulling pre-built images..."
    ssh "${VPS_USER}@${VPS_HOST}" "cd ${PROJECT_PATH} && docker compose -f docker-compose.infra.yml pull postgres"

    # Deploy with docker compose (idempotent - only recreates changed containers)
    log_info "Starting services..."
    ssh "${VPS_USER}@${VPS_HOST}" "cd ${PROJECT_PATH} && docker compose -f docker-compose.infra.yml up -d --remove-orphans"

    log_info "✅ Infrastructure deployed"
}

check_services() {
    log_info "Checking service health..."

    # Wait a few seconds for services to start
    sleep 5

    # Check running containers
    log_info "Running containers:"
    ssh "${VPS_USER}@${VPS_HOST}" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

    # Check service health
    log_info "\nService health checks:"
    ssh "${VPS_USER}@${VPS_HOST}" "docker compose -f ${PROJECT_PATH}/docker-compose.infra.yml ps"
}

show_logs() {
    log_info "\nRecent logs (last 20 lines):"
    ssh "${VPS_USER}@${VPS_HOST}" "cd ${PROJECT_PATH} && docker compose -f docker-compose.infra.yml logs --tail=20"
}

main() {
    log_info "=== Cleo VPS Deployment ==="
    log_info "Target: ${VPS_USER}@${VPS_HOST}:${PROJECT_PATH}"
    log_info ""

    # Pre-flight checks
    check_tailscale

    # Sync files
    sync_files

    # Check environment
    if ! check_env_file; then
        log_error "Deployment paused - .env file required"
        exit 1
    fi

    # Deploy services
    deploy_infrastructure

    # Verify deployment
    check_services

    # Show logs
    show_logs

    log_info ""
    log_info "=== Deployment Complete ==="
    log_info "Access services via Tailscale:"
    log_info "  mem0 API: http://cleo-vps:8080"
    log_info "  Qdrant: http://cleo-vps:6333"
    log_info "  PostgreSQL: cleo-vps:5432"
}

# Run main function
main "$@"
