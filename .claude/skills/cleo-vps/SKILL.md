# Cleo VPS Management Skill

## Purpose
SSH into Cleo VPS for deployment, verification, and operations with strict safety guardrails.

## Activation
USE WHEN:
- User asks to "ssh into cleo-vps"
- User asks to "deploy to cleo"
- User asks to "check cleo server"
- User asks to "manage cleo infrastructure"

## Core Principles

### 🔒 SAFETY FIRST - ALWAYS ASK PERMISSION FOR:
1. **File deletion** (`rm`, `rm -rf`, etc.)
2. **Service restarts** (`systemctl restart`, `docker restart`)
3. **Container removal** (`docker rm`, `docker compose down`)
4. **Firewall changes** (`ufw`, `iptables`)
5. **User management** (`useradd`, `userdel`, `passwd`)
6. **Any destructive operation**

### ✅ SAFE OPERATIONS (no permission needed):
- File reading (`cat`, `ls`, `tail`, `head`)
- Service status checks (`systemctl status`, `docker ps`)
- Log viewing (`journalctl`, `docker logs`)
- Network checks (`netstat`, `ss`, `ip a`)
- Disk usage (`df`, `du`)

## VPS Configuration

- **Hostname**: `cleo-vps` (via Tailscale MagicDNS)
- **Project Path**: `/opt/cleo/`
- **User**: `root` (initial setup) → `cleo` (production)
- **Access**: SSH via Tailscale only (no public SSH)

## Common Tasks

### 1. Check Server Status
```bash
ssh cleo-vps "docker ps && df -h && free -h"
```

### 2. View Logs
```bash
ssh cleo-vps "cd /opt/cleo && docker compose logs --tail=50"
```

### 3. Check Security Hardening
```bash
ssh cleo-vps "sudo ufw status && sudo fail2ban-client status"
```

### 4. Deploy Infrastructure (idempotent)
```bash
# Sync files
rsync -avz --exclude=node_modules --exclude=.git \
  /Users/aayushaman/personal/Cleo/ cleo-vps:/opt/cleo/

# Deploy services
ssh cleo-vps "cd /opt/cleo && docker compose -f docker-compose.infra.yml up -d"
```

## Deployment Script Requirements

The deployment script MUST be:
1. **Idempotent** - Can run multiple times safely
2. **Atomic** - Services update without downtime
3. **Reversible** - Can rollback on failure
4. **Observable** - Logs all actions

## Workflow

When skill is invoked:
1. **Verify Tailscale connection** to cleo-vps
2. **SSH into server** and gather current state
3. **Report findings** to user
4. **Ask permission** before any destructive operation
5. **Execute approved actions** with confirmation
6. **Verify results** after changes

## Example Session

```
User: "ssh into cleo-vps and check security"

Skill:
1. SSH to cleo-vps
2. Check: ufw status, fail2ban status, SSH config
3. Report: "✅ UFW active, ✅ fail2ban running, ⚠️ SSH allows password (should be key-only)"
4. Ask: "Should I disable password auth?"
5. If YES → execute and verify
6. If NO → document finding
```
