#!/bin/bash
# .infra/setup-backup-cron.sh - Install daily backup cron job on VPS
#
# Run this script on the VPS to set up daily PostgreSQL backups at 3 AM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup-postgres.sh"

# Verify backup script exists
if [[ ! -f "${BACKUP_SCRIPT}" ]]; then
    echo "Error: backup-postgres.sh not found at ${BACKUP_SCRIPT}"
    exit 1
fi

# Make backup script executable
chmod +x "${BACKUP_SCRIPT}"

# Create cron entry for 3 AM daily
CRON_ENTRY="0 3 * * * ${BACKUP_SCRIPT} >> /var/log/cleo-backup.log 2>&1"

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "backup-postgres.sh"; then
    echo "Backup cron job already exists"
    crontab -l | grep "backup-postgres"
else
    # Add cron entry
    (crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -
    echo "Backup cron job installed:"
    echo "  ${CRON_ENTRY}"
fi

# Create log file
sudo touch /var/log/cleo-backup.log
sudo chown aman:aman /var/log/cleo-backup.log

echo ""
echo "Setup complete. Daily backups will run at 3 AM."
echo "Check logs at: /var/log/cleo-backup.log"
echo "Backups stored at: /var/backups/cleo/"
