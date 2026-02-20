# Tailscale Setup for Cleo VPS

This document covers Tailscale configuration for multi-device access to the Cleo VPS.

## Why Tailscale?

Added in Phase 1.5 for:
- **Multi-device access** - Laptop + phone can both access VPS
- **Travel reliability** - Works across network changes (Wi-Fi, mobile, hotel)
- **Easy web access** - Access OpenClaw dashboard from phone browser
- **No SSH tunnel maintenance** - Automatic reconnection, MagicDNS hostnames
- **Zero public ports** - SSH and services only accessible via Tailscale

## Quick Start

### 1. VPS Setup (Already Done)

```bash
# On VPS (run as root)
sudo ./scripts/setup-tailscale.sh
```

VPS is accessible as `cleo-vps` on the tailnet.

### 2. Laptop Setup

**macOS:**
```bash
# Install
brew install tailscale

# Or download from https://tailscale.com/download/mac

# Connect (same account as VPS)
tailscale up

# Verify VPS access
ping cleo-vps
ssh aman@cleo-vps
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

### 3. Phone Setup

**iOS:**
1. Install "Tailscale" from App Store
2. Open app, tap "Log in"
3. Sign in with same account as VPS
4. VPS services now accessible via Safari

**Android:**
1. Install "Tailscale" from Play Store
2. Open app, sign in with same account
3. VPS services accessible via Chrome

### 4. Verify Connectivity

From any connected device:
```bash
./scripts/verify-tailscale.sh
```

## Architecture

```
                    Tailscale Network (encrypted mesh)
                    ================================

    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │   Laptop     │     │    Phone     │     │   Cleo VPS   │
    │              │     │              │     │  (cleo-vps)  │
    │ tailscale0   │◄───►│ tailscale0   │◄───►│ tailscale0   │
    │ 100.x.x.x    │     │ 100.x.x.x    │     │ 100.x.x.x    │
    └──────────────┘     └──────────────┘     └──────────────┘
           │                    │                    │
           │                    │                    ├── OpenClaw :18789
           │                    │                    ├── mem0 :8080
           │                    │                    ├── Qdrant :6333
           │                    │                    └── SSH :22
           │                    │
           └──── Claude Code ───┴── Browser access to VPS services
```

## MagicDNS

Tailscale provides automatic DNS for all devices on your tailnet:

| Hostname | Service | URL |
|----------|---------|-----|
| `cleo-vps` | SSH | `ssh aman@cleo-vps` |
| `cleo-vps` | OpenClaw | `http://cleo-vps:18789/` |
| `cleo-vps` | mem0 API | `http://cleo-vps:8080/` |
| `cleo-vps` | Qdrant | `http://cleo-vps:6333/` |

Fully qualified domain: `cleo-vps.[tailnet-name].ts.net`

## Service Binding Configuration

By default, Cleo services bind to `127.0.0.1` (localhost only). To access via Tailscale, services need to bind to the Tailscale interface.

### Option A: Bind to 0.0.0.0 (All Interfaces)

Edit `docker-compose.infra.yml`:
```yaml
services:
  openclaw:
    ports:
      - "0.0.0.0:18789:18789"  # Change from 127.0.0.1
```

**Security note:** Only safe because UFW blocks external access. Tailscale traffic goes through `tailscale0` interface.

### Option B: Bind to Tailscale IP Only

```bash
# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)

# Use in docker-compose
ports:
  - "${TAILSCALE_IP}:18789:18789"
```

### Option C: Use Tailscale Serve (Recommended for OpenClaw)

OpenClaw has native Tailscale Serve support:

```json
// openclaw.json
{
  "gateway": {
    "binding": "127.0.0.1",  // Keep localhost
    "auth": {
      "allowTailscale": true  // Allow Tailscale identity auth
    }
  },
  "tailscale": {
    "mode": "serve"  // Tailscale Serve handles external access
  }
}
```

Then configure Tailscale Serve:
```bash
tailscale serve --bg https://localhost:18789
```

## Claude Code MCP Configuration

Update `~/.claude.json` to use Tailscale instead of SSH tunnel:

### Before (SSH Tunnel)
```json
{
  "mcpServers": {
    "mem0": {
      "type": "stdio",
      "command": "ssh",
      "args": ["cleo-vps", "docker", "exec", "-i", "cleo-mem0-mcp", "node", "dist/index.js"]
    }
  }
}
```

### After (Tailscale - Same Config!)
```json
{
  "mcpServers": {
    "mem0": {
      "type": "stdio",
      "command": "ssh",
      "args": ["cleo-vps", "docker", "exec", "-i", "cleo-mem0-mcp", "node", "dist/index.js"]
    }
  }
}
```

**Key insight:** The config looks the same! `cleo-vps` now resolves via MagicDNS instead of SSH config alias. The difference is:
- SSH tunnel: Requires manual SSH config, public SSH port exposure
- Tailscale: Automatic MagicDNS, no public ports, auto-reconnect

## SSH Configuration

You can remove the `cleo-vps` entry from `~/.ssh/config` since MagicDNS handles resolution:

**Before (Required):**
```
Host cleo-vps
  HostName 123.45.67.89
  User aman
  IdentityFile ~/.ssh/cleo_vps_key
```

**After (Optional - only for non-default settings):**
```
Host cleo-vps
  User aman
  IdentityFile ~/.ssh/cleo_vps_key
  # HostName not needed - MagicDNS resolves it
```

## ACLs (Access Control Lists)

For production, configure Tailscale ACLs to control which devices can access which services.

See `.infra/tailscale-acl.json` for template configuration.

### Basic ACL Policy

```json
{
  "acls": [
    // aman's devices can access VPS
    {"action": "accept", "src": ["tag:aman-devices"], "dst": ["tag:cleo-vps:*"]},

    // VPS can only respond (no outbound to other devices)
    {"action": "accept", "src": ["tag:cleo-vps"], "dst": ["*:*"]}
  ],
  "tagOwners": {
    "tag:aman-devices": ["autogroup:admin"],
    "tag:cleo-vps": ["autogroup:admin"]
  }
}
```

## Troubleshooting

### "cleo-vps: Name or service not known"

1. Check Tailscale is running: `tailscale status`
2. Check VPS is in tailnet: `tailscale status | grep cleo-vps`
3. Check MagicDNS enabled: Tailscale Admin Console > DNS

### "Connection refused" to services

Services may be bound to localhost only:
1. Check binding: `netstat -tlnp | grep 18789`
2. Update to bind to Tailscale IP or 0.0.0.0
3. Or use Tailscale Serve for HTTPS access

### High latency

Tailscale uses direct peer-to-peer when possible:
1. Check connection type: `tailscale status`
2. If showing "relay", may be NAT issues
3. Try `tailscale netcheck` for diagnostics

### VPS disconnected

```bash
# On VPS
tailscale status  # Check if connected
tailscale up      # Reconnect
journalctl -u tailscaled  # Check logs
```

## Security Considerations

| Aspect | Configuration |
|--------|---------------|
| **Public SSH port** | Can now disable if only using Tailscale access |
| **Service exposure** | Bind to Tailscale IP or use Tailscale Serve |
| **Authentication** | Tailscale identity + existing service auth |
| **Encryption** | WireGuard (all traffic encrypted) |
| **Access control** | Tailscale ACLs for device/service restrictions |

### Recommended Security Posture

1. **Keep SSH fallback** initially (in case Tailscale issues)
2. After confirming stability (1 week), consider:
   - Removing public SSH port from UFW
   - Using Tailscale SSH instead of standard SSH
3. Configure ACLs for granular access control

## Useful Commands

| Command | Purpose |
|---------|---------|
| `tailscale status` | Show connection status and devices |
| `tailscale ip -4` | Show Tailscale IPv4 address |
| `tailscale up` | Connect to tailnet |
| `tailscale down` | Disconnect from tailnet |
| `tailscale ping cleo-vps` | Test connectivity to VPS |
| `tailscale netcheck` | Network diagnostics |
| `tailscale bugreport` | Generate debug info |
