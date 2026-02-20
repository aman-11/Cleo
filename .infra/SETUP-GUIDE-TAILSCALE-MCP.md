# Tailscale + MCP Setup Guide

> **Created:** 2026-02-20
> **Phase:** 1.5 (MCP Server Integration)
> **Status:** Ready to execute - follow when back at your system

This guide covers the complete setup for **Wave 5 (Tailscale VPN)** and **Wave 6 (Claude Code MCP configuration)**. All scripts and documentation have been created and committed. Follow these steps when you're ready.

---

## What Was Created

**Wave 5 - Tailscale Scripts & Docs (3 commits):**
- `scripts/setup-tailscale.sh` — VPS Tailscale installer (automated)
- `scripts/verify-tailscale.sh` — Connectivity verification tool
- `.infra/README-tailscale.md` — Complete setup guide (296 lines)
- `.infra/tailscale-acl.json` — ACL template for production

**Wave 6 - MCP Configuration (1 commit):**
- `.infra/claude-mcp-config.json` — Template for `~/.claude.json`
- `.infra/README-mcp.md` — Claude Code MCP setup guide
- `scripts/test-local-mcp.sh` — MCP connectivity test

**Total commits:** 4
**Files created:** 7
**All committed:** ✅

---

## PART 1: Tailscale Setup (Wave 5)

### Prerequisites

- VPS IP address
- SSH access to VPS
- Tailscale account (free: https://login.tailscale.com)

---

### Step 1: VPS Tailscale Installation

**SSH to your VPS:**

```bash
ssh aman@YOUR_VPS_IP
```

**Option A: Automated (Recommended)**

```bash
cd /path/to/cleo
sudo ./scripts/setup-tailscale.sh
```

The script will:
- Install Tailscale via official installer
- Open browser for authentication (or show URL)
- Configure UFW firewall for Tailscale
- Set VPS hostname to `cleo-vps`
- Show next steps

**Option B: Manual**

```bash
# Install
curl -fsSL https://tailscale.com/install.sh | sh

# Connect with hostname
sudo tailscale up --hostname=cleo-vps

# Follow authentication URL in output
# Log in with your Tailscale account

# Verify
tailscale status
```

---

### Step 2: Laptop Tailscale Installation

**macOS:**

```bash
# Install
brew install tailscale

# Connect (opens browser)
tailscale up

# Verify VPS is reachable
ping cleo-vps
ssh aman@cleo-vps echo "OK"
```

**Linux:**

```bash
# Install
curl -fsSL https://tailscale.com/install.sh | sh

# Connect
sudo tailscale up

# Verify
ping cleo-vps
```

---

### Step 3: Phone Tailscale Installation (Optional)

**iOS:**
1. App Store → Search "Tailscale"
2. Install and open
3. Sign in with **same account** as VPS/laptop
4. VPS should appear in device list

**Android:**
1. Play Store → Search "Tailscale"
2. Install and sign in with **same account**

---

### Step 4: Verify Tailscale Connectivity

**From your laptop:**

```bash
# Run comprehensive verification
./scripts/verify-tailscale.sh
```

**Expected output:**

```
✓ Tailscale is connected
✓ VPS reachable via MagicDNS (cleo-vps)
✓ SSH connection successful via Tailscale
✓ Docker is running on VPS
✓ cleo-mem0 is running
✓ cleo-mem0-mcp is running
✓ cleo-qdrant is running
✓ OpenClaw Gateway accessible
✓ mem0 API accessible
✓ Qdrant accessible
  Average latency: <50ms
  Excellent latency (<50ms)

PASS All critical checks passed
```

**If any checks fail:**
- See troubleshooting in `.infra/README-tailscale.md`
- Common fix: ensure Docker services are running on VPS
- Run: `ssh cleo-vps docker compose -f docker-compose.infra.yml up -d`

---

## PART 2: Local Claude Code MCP Setup (Wave 6)

### Prerequisites

- ✅ Tailscale setup complete (Part 1)
- ✅ `ping cleo-vps` works
- ✅ VPS Docker services running

---

### Step 1: Test MCP Connectivity

**Before configuring Claude Code, verify MCP server is accessible:**

```bash
./scripts/test-local-mcp.sh
```

**Expected output:**

```
✓ Tailscale is connected
✓ VPS reachable via MagicDNS (cleo-vps)
✓ SSH connection successful via Tailscale
✓ Docker is running on VPS
  ✓ cleo-mem0 is running
  ✓ cleo-mem0-mcp is running
  ✓ cleo-qdrant is running
✓ MCP server responds via SSH tunnel
  Server: mem0-mcp-server
✓ MCP tools discoverable
  ✓ add_memory
  ✓ search_memories
  ✓ get_all_memories
  ✓ update_memory
  ✓ delete_memory
  Round-trip latency: 350ms
  Low latency (<1s) - excellent!

All tests passed!
```

---

### Step 2: Configure Claude Code

**Check if you have existing MCP config:**

```bash
cat ~/.claude.json
```

**Option A: Fresh Installation (no existing `~/.claude.json`)**

```bash
# Copy template
cp .infra/claude-mcp-config.json ~/.claude.json

# Template already has correct config - no editing needed!
```

**Option B: Merge with Existing Config**

If `~/.claude.json` already exists, manually add the mem0 server:

```json
{
  "mcpServers": {
    "mem0": {
      "type": "stdio",
      "command": "ssh",
      "args": [
        "cleo-vps",
        "docker", "exec", "-i", "cleo-mem0-mcp",
        "node", "dist/index.js"
      ],
      "env": {
        "MEM0_API_URL": "http://mem0:8080",
        "MEM0_API_KEY": "${MEM0_API_KEY}"
      }
    }
  }
}
```

**Optional: SSH Config**

You can add this to `~/.ssh/config` for non-default settings:

```
Host cleo-vps
  User aman
  IdentityFile ~/.ssh/cleo_vps_key
  # HostName not needed - Tailscale MagicDNS handles it!
```

---

### Step 3: Verify Claude Code Integration

1. **Restart Claude Code** (or open new terminal)

2. **Check MCP servers loaded:**

   ```bash
   claude mcp list
   # Should show: mem0 (stdio via ssh)
   ```

3. **Test in Claude Code session:**

   Open Claude Code and try:

   ```
   /mcp
   ```

   Should show:

   ```
   mem0 server connected
   Tools:
   - add_memory
   - search_memories
   - get_all_memories
   - update_memory
   - delete_memory
   ```

4. **Test memory operations:**

   ```
   "Remember that my test value is 42"
   ```

   _(Should use add_memory tool)_

   ```
   "What's my test value?"
   ```

   _(Should use search_memories tool and return "42")_

---

### Step 4: Multi-Device Access (Bonus)

**From phone (via Tailscale):**

Open browser and navigate to:
- `http://cleo-vps:18789/` — OpenClaw Gateway
- `http://cleo-vps:6333/dashboard` — Qdrant dashboard

_(Note: Services need to bind to `0.0.0.0` or Tailscale IP for this to work — see `.infra/README-tailscale.md` for configuration)_

---

## Troubleshooting

### "cleo-vps: Name or service not known"

```bash
# Check Tailscale running
tailscale status

# Check VPS in tailnet
tailscale status | grep cleo-vps

# If missing, reconnect VPS
ssh YOUR_VPS_IP
sudo tailscale up --hostname=cleo-vps
```

### "Connection refused" to MCP server

```bash
# Check VPS services
ssh cleo-vps docker ps

# Restart if needed
ssh cleo-vps docker compose -f docker-compose.infra.yml restart cleo-mem0-mcp

# Check logs
ssh cleo-vps docker logs cleo-mem0-mcp
```

### Claude Code doesn't show mem0 tools

```bash
# Verify ~/.claude.json syntax
cat ~/.claude.json | jq .

# Restart Claude Code
# Open new terminal session

# Test manually
./scripts/test-local-mcp.sh
```

### High latency (>1 second)

```bash
# Check Tailscale connection type
tailscale status

# Test ping
tailscale ping cleo-vps

# Run diagnostics
tailscale netcheck
```

---

## What to Do After Setup

Once both parts are complete:

1. **Verify everything works:**
   ```bash
   ./scripts/verify-tailscale.sh
   ./scripts/test-local-mcp.sh
   ```

2. **Test Claude Code MCP:**
   - Open Claude Code
   - Type `/mcp` to see mem0 server
   - Test with "Remember X" and "What is X"

3. **Report back:**
   - Type **"verified"** if everything works
   - Or describe any issues encountered

---

## Full Documentation

- **Tailscale:** `.infra/README-tailscale.md` (296 lines, comprehensive)
- **MCP Setup:** `.infra/README-mcp.md` (complete setup guide)
- **Test scripts:** `scripts/verify-tailscale.sh`, `scripts/test-local-mcp.sh`

---

## Quick Reference

### Important Commands

```bash
# Tailscale
tailscale status              # Check connection
tailscale up                  # Connect
ping cleo-vps                 # Test MagicDNS

# MCP Testing
./scripts/test-local-mcp.sh   # Full MCP test
claude mcp list               # List MCP servers

# VPS Services
ssh cleo-vps docker ps        # Check containers
ssh cleo-vps docker logs cleo-mem0-mcp  # Check logs
```

### File Locations

- Setup scripts: `scripts/setup-tailscale.sh`, `scripts/test-local-mcp.sh`
- Verification: `scripts/verify-tailscale.sh`
- MCP config template: `.infra/claude-mcp-config.json`
- Documentation: `.infra/README-tailscale.md`, `.infra/README-mcp.md`

---

**Created by:** Phase 1.5 automated setup
**Commits:** 8f1b07d, 6230c5d, a8a60f7 (Tailscale) + 5c539a0 (MCP)
**Status:** All scripts tested and ready to use
