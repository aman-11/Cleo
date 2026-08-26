# Cleo Agent Development Guidelines

**CRITICAL**: This file defines the development workflow and architecture for the Cleo project. All AI agents working on this codebase MUST follow these rules.

---

## 🚨 Golden Rule: Local First, Then Deploy

**NEVER make changes directly on the VPS.** All code changes MUST follow this workflow:

1. **Develop Locally** - Make ALL changes in `/Users/aayushaman/personal/Cleo`
2. **Test Locally** - Build and verify changes work
3. **Deploy to VPS** - Use deployment scripts to push changes
4. **Verify on VPS** - Test deployed changes

### ❌ FORBIDDEN
- Running `ssh aman@cleo-vps "echo 'code' > /opt/cleo/file.ts"`
- Creating files directly on VPS
- Editing configuration directly on VPS (except `.env` for secrets)
- Installing packages on VPS manually
- Running `docker exec` to modify files inside containers

### ✅ ALLOWED
- Reading logs: `ssh aman@cleo-vps "docker logs cleo-app"`
- Checking status: `ssh aman@cleo-vps "docker ps"`
- Testing connectivity: `ssh aman@cleo-vps "curl localhost:3000"`
- Reading configuration: `ssh aman@cleo-vps "cat /opt/cleo/.env"`
- ONE-TIME manual .env updates (after local .env is updated)

---

## 📐 Cleo Architecture

### System Overview
```
┌─────────────────────────────────────────────────────────────┐
│                        VPS (Hetzner CX33)                   │
│                     cleo-vps.tail499b42.ts.net              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐      ┌──────────────┐                     │
│  │  Tailscale  │─────▶│ Cleo App     │ :3000               │
│  │   (HTTPS)   │      │ - Dashboard  │ (Health Server)     │
│  └─────────────┘      │ - Health API │                     │
│                       │ - Heartbeat  │                     │
│                       └──────┬───────┘                     │
│                              │                             │
│         ┌────────────────────┼────────────────────┐        │
│         │                    │                    │        │
│         ▼                    ▼                    ▼        │
│  ┌─────────────┐      ┌──────────┐        ┌──────────┐    │
│  │  OpenClaw   │      │  mem0    │        │PostgreSQL│    │
│  │  Gateway    │      │  API     │◀───────│ +pgvector│    │
│  │  :18789     │      │  :8080   │        │  :5432   │    │
│  └─────────────┘      └──────────┘        └──────────┘    │
│         │                    │                             │
│         ├─ Discord (DMs)     └─ Qdrant Cloud (vectors)    │
│         └─ GitHub (API)                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

**Cleo App** (`/opt/cleo` → Docker: `cleo-app`)
- **Health Server**: Serves dashboard and health API on port 3000
- **Heartbeat**: Periodic status checks and Discord DMs
- **Orchestration**: Coordinates mem0, OpenClaw, GitHub

**OpenClaw Gateway** (`/home/aman/openclaw` → Docker: `openclaw-openclaw-gateway-1`)
- **Discord Bridge**: Handles Discord bot and message routing
- **GitHub Integration**: PR comments, issue tracking
- **WebSocket Server**: Port 18789 (bound to loopback)
- **Tailscale Serve**: Exposes Control UI via Tailscale

**mem0** (`cleo-mem0`)
- **Memory API**: Vector-based memory storage
- **Embeddings**: sentence-transformers/all-MiniLM-L6-v2
- **Backend**: PostgreSQL + pgvector + Qdrant Cloud

**PostgreSQL** (`cleo-postgres`)
- **Database**: Primary data store
- **pgvector Extension**: Vector similarity search
- **Port**: 5432 (internal only)

**Tailscale VPN**
- **Access Method**: Private network for all services
- **Dashboard URL**: `https://cleo-vps.tail499b42.ts.net/dashboard`
- **Security**: Network-level auth, no public exposure

### Network Architecture

**Docker Networks:**
- `cleo-network`: Cleo app, mem0, PostgreSQL
- `openclaw_default`: OpenClaw Gateway (separate)

**Network Connections:**
- Cleo → OpenClaw: via Docker gateway (172.18.0.1:18789)
- Cleo → mem0: via Docker network (mem0:8080)
- Cleo → PostgreSQL: via Docker network (postgres:5432)
- mem0 → PostgreSQL: via Docker network (postgres:5432)
- Tailscale → Cleo: via localhost (127.0.0.1:3000)

**Why OpenClaw uses gateway IP:**
OpenClaw binds to loopback (127.0.0.1) inside its container for Tailscale Serve security. The published port (18789) is accessible from host, so Cleo accesses it via Docker gateway IP.

---

## 🔄 Development Workflow

### 1. Making Changes

```bash
# Navigate to project
cd /Users/aayushaman/personal/Cleo

# Make changes to source files
vim src/health-checks.ts

# Update dependencies if needed
pnpm install

# Build TypeScript
pnpm build

# Verify build output
ls -la dist/
```

### 2. Testing Locally (Optional)

```bash
# Run dev server
pnpm dev

# Or build and run with Docker
docker build -t cleo/app:local .
docker run --rm -p 3000:3000 --env-file .env cleo/app:local
```

### 3. Deployment to VPS

```bash
# Deploy infrastructure + Cleo app
./scripts/deploy-to-vps.sh

# This script:
# 1. Syncs files to /opt/cleo
# 2. Builds Docker images on VPS
# 3. Restarts containers
# 4. Shows logs and status
```

### 4. Manual .env Updates (Only for Secrets)

```bash
# After updating local .env, sync to VPS
scp .env aman@cleo-vps:/opt/cleo/.env

# Or edit directly (ONE-TIME exceptions only)
ssh aman@cleo-vps "vim /opt/cleo/.env"

# Then recreate containers to pick up changes
ssh aman@cleo-vps "cd /opt/cleo && docker compose up -d --force-recreate"
```

### 5. Verification

```bash
# Check logs
ssh aman@cleo-vps "docker logs cleo-app --tail 50"

# Test endpoints
curl https://cleo-vps.tail499b42.ts.net/
curl https://cleo-vps.tail499b42.ts.net/api/health

# Open dashboard
open https://cleo-vps.tail499b42.ts.net/dashboard
```

---

## 📂 Project Structure

```
/Users/aayushaman/personal/Cleo/          # Local development
├── src/
│   ├── index.ts                          # Main entry point
│   ├── health.ts                         # Health server + dashboard
│   ├── health-checks.ts                  # Service health checks
│   ├── public/
│   │   └── dashboard.html                # Dashboard UI
│   └── heartbeat/
│       ├── openclaw-client.ts            # OpenClaw API client
│       ├── system-status.ts              # System health checks
│       └── scheduler.ts                  # Heartbeat scheduler
├── docker-compose.yml                    # Cleo app compose
├── docker-compose.infra.yml              # Infrastructure compose
├── Dockerfile                            # Cleo app image
├── package.json                          # Dependencies
├── .env                                  # Environment variables
├── scripts/
│   └── deploy-to-vps.sh                 # Deployment script
└── .planning/                            # Planning documents
    ├── dashboard-plan.md
    ├── health-check-fix-plan.md
    └── deployment-checklist.md

/opt/cleo/                                # VPS deployment (mirrored from local)
/home/aman/openclaw/                      # OpenClaw installation (separate)
```

---

## 🔧 Common Development Tasks

### Adding a New Feature

1. **Create feature branch** (optional)
2. **Modify source files** in `src/`
3. **Update types/interfaces** if needed
4. **Build**: `pnpm build`
5. **Deploy**: `./scripts/deploy-to-vps.sh`
6. **Verify**: Check logs and test endpoints

### Fixing Health Checks

1. **Edit**: `src/health-checks.ts`
2. **Use HTTP/TCP only** - NO Docker CLI commands
3. **Test database connections** with `pg` client
4. **Build and deploy**

### Updating Dashboard

1. **Edit**: `src/public/dashboard.html`
2. **Build**: `pnpm build` (copies to dist/public/)
3. **Deploy**: Deployment script syncs public directory
4. **Verify**: Open dashboard URL

### Debugging on VPS

```bash
# View logs
ssh aman@cleo-vps "docker logs -f cleo-app"

# Check container status
ssh aman@cleo-vps "docker ps -a"

# Exec into container (READ-ONLY debugging)
ssh aman@cleo-vps "docker exec -it cleo-app sh"

# Check health endpoint
ssh aman@cleo-vps "curl -s http://localhost:3000/health | jq ."
```

---

## ⚙️ Environment Variables

### Required in .env

```bash
# Discord
DISCORD_USER_ID=<user-id>
DISCORD_BOT_TOKEN=<in-openclaw-config>

# mem0
MEM0_API_KEY=<api-key>

# PostgreSQL
POSTGRES_PASSWORD=<password>
POSTGRES_DB=cleo
POSTGRES_USER=postgres

# OpenClaw
OPENCLAW_API_URL=http://172.18.0.1:18789

# Tailscale
TAILSCALE_HOSTNAME=cleo-vps
TAILSCALE_IP=100.98.92.78
```

---

## 🚀 Deployment Script Details

`./scripts/deploy-to-vps.sh`:
- Checks Tailscale connection
- Syncs files via rsync (excludes: .git, node_modules, .planning)
- Builds Docker images on VPS
- Starts services with docker compose
- Shows status and logs

**What it DOESN'T do:**
- Doesn't sync .env (contains secrets, manual sync)
- Doesn't modify OpenClaw (separate installation)
- Doesn't change Tailscale config (one-time setup)

---

## 📊 Health Check Implementation

### Current Approach (Fixed)
- **OpenClaw**: HTTP GET to health endpoint
- **mem0**: HTTP GET to /health endpoint
- **PostgreSQL**: Direct connection using `pg` client
- **Tailscale**: Environment variables (static)

### What We DON'T Do
- ❌ Docker CLI commands (`docker ps`, `docker exec`)
- ❌ Tailscale CLI commands (`tailscale status`)
- ❌ Container inspections
- ❌ Log parsing for health status

### Why?
Running CLI commands from inside containers requires:
- Docker socket mount (security risk)
- Special permissions
- Host access

HTTP/TCP checks work from inside containers without special permissions.

---

## 🔐 Security Principles

1. **No public exposure** - Everything behind Tailscale
2. **Non-root containers** - Cleo runs as `nodejs` user (UID 1001)
3. **Minimal permissions** - No Docker socket, no privileged mode
4. **Secrets in .env** - Never committed to git
5. **Read-only health checks** - No mutations in health endpoints

---

## 📝 Key Learnings

1. **OpenClaw binding**: Binds to loopback for Tailscale Serve security
2. **Network gateway**: Use 172.18.0.1 to access host ports from containers
3. **Health checks**: Use HTTP/TCP, not CLI commands
4. **Deployment**: Always local first, then VPS
5. **Docker compose**: env vars override works with `${VAR:-default}` syntax

---

**Last Updated**: 2026-03-03
**Architecture Version**: v1.0
**Deployment Target**: Hetzner CX33 VPS via Tailscale
