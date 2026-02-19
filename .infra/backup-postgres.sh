#!/bin/bash
# .infra/backup-postgres.sh - Daily PostgreSQL backup with pgvector support
#
# This script creates a daily backup of the mem0 PostgreSQL database.
# Backups are stored in /var/backups/cleo/ with 7-day retention.
#
# IMPORTANT: When restoring a pgvector database, you must:
# 1. Create the target database
# 2. Run: CREATE EXTENSION IF NOT EXISTS vector;
# 3. Then restore the backup
#
# Usage:
#   ./backup-postgres.sh           # Run backup
#   ./backup-postgres.sh restore   # Show restore instructions

set -euo pipefail

# Configuration
BACKUP_DIR="/var/backups/cleo"
RETENTION_DAYS=7
CONTAINER_NAME="cleo-postgres"
DB_NAME="mem0"
DB_USER="postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/mem0_${TIMESTAMP}.sql.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Show restore instructions if requested
if [[ "${1:-}" == "restore" ]]; then
    echo -e "${YELLOW}PostgreSQL pgvector Restore Instructions${NC}"
    echo ""
    echo "1. Stop containers:"
    echo "   docker compose -f docker-compose.infra.yml stop mem0"
    echo ""
    echo "2. Create fresh database with pgvector extension:"
    echo "   docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} <<EOF"
    echo "   DROP DATABASE IF EXISTS ${DB_NAME};"
    echo "   CREATE DATABASE ${DB_NAME};"
    echo "   \\c ${DB_NAME}"
    echo "   CREATE EXTENSION IF NOT EXISTS vector;"
    echo "   EOF"
    echo ""
    echo "3. Restore from backup:"
    echo "   gunzip -c ${BACKUP_DIR}/mem0_YYYYMMDD_HHMMSS.sql.gz | \\"
    echo "     docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${DB_NAME}"
    echo ""
    echo "4. Restart services:"
    echo "   docker compose -f docker-compose.infra.yml up -d"
    echo ""
    echo -e "${GREEN}Available backups:${NC}"
    ls -lh ${BACKUP_DIR}/*.sql.gz 2>/dev/null || echo "  (none found)"
    exit 0
fi

log "${GREEN}Starting PostgreSQL backup${NC}"

# Create backup directory if it doesn't exist
if [[ ! -d "${BACKUP_DIR}" ]]; then
    log "Creating backup directory: ${BACKUP_DIR}"
    sudo mkdir -p "${BACKUP_DIR}"
    sudo chown aman:aman "${BACKUP_DIR}"
fi

# Check if postgres container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "${RED}Error: PostgreSQL container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Create backup
log "Creating backup: ${BACKUP_FILE}"
docker exec ${CONTAINER_NAME} pg_dump -U ${DB_USER} -d ${DB_NAME} | gzip > "${BACKUP_FILE}"

# Verify backup was created
if [[ -f "${BACKUP_FILE}" ]]; then
    SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    log "${GREEN}Backup created successfully: ${BACKUP_FILE} (${SIZE})${NC}"
else
    log "${RED}Error: Backup file was not created${NC}"
    exit 1
fi

# Clean up old backups
log "Cleaning up backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name "mem0_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

# List current backups
log "Current backups:"
ls -lh "${BACKUP_DIR}"/mem0_*.sql.gz 2>/dev/null || echo "  (none)"

log "${GREEN}Backup complete${NC}"
