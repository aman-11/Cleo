# OpenClaw Gateway Operations Guide

This document covers post-deployment operations for OpenClaw Gateway on the Cleo VPS.

## Quick Start (Post-Deployment)

After `docker compose -f docker-compose.infra.yml up -d`:

```bash
# Run automated post-deployment setup
./scripts/openclaw-post-deploy.sh

# Or manually:
# 1. Wait for gateway
docker compose logs openclaw -f

# 2. Check status
docker compose exec openclaw openclaw gateway status

# 3. Run diagnostics
docker compose exec openclaw openclaw doctor
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      VPS (Cleo Network)                      │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────┐    ┌───────────────┐    ┌─────────────┐  │
│  │   OpenClaw    │───▶│   mem0-mcp    │───▶│    mem0     │  │
│  │   Gateway     │    │   (stdio)     │    │   (REST)    │  │
│  │ :18789        │    │               │    │   :8080     │  │
│  └───────────────┘    └───────────────┘    └─────────────┘  │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌───────────────┐                        ┌─────────────┐   │
│  │    Discord    │                        │   Qdrant    │   │
│  │   (Channel)   │                        │   :6333     │   │
│  └───────────────┘                        └─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## CLI Commands Reference

All OpenClaw CLI commands must be wrapped with Docker:

```bash
# Pattern: docker compose exec openclaw openclaw [command]

# Gateway Management
docker compose exec openclaw openclaw gateway status          # Check status
docker compose exec openclaw openclaw gateway status --deep   # Deep diagnostics
docker compose exec openclaw openclaw gateway stop            # Stop gateway

# Health & Diagnostics
docker compose exec openclaw openclaw health                  # Full health check
docker compose exec openclaw openclaw doctor                  # Configuration audit
docker compose exec openclaw openclaw doctor --fix            # Auto-fix issues

# Channel Management
docker compose exec openclaw openclaw channels list           # List channels
docker compose exec openclaw openclaw channels status --probe # Check connectivity

# Configuration
docker compose exec openclaw openclaw config get gateway.port # Get config value
docker compose exec openclaw openclaw config set KEY VALUE    # Set config value

# Logs
docker compose logs openclaw -f                               # Follow live logs
docker compose logs openclaw --tail 100                       # Last 100 lines
```

## Configuration File

**Location:** `~/.openclaw/openclaw.json` (inside container: `/home/node/.openclaw/openclaw.json`)

**Format:** JSON5 (supports comments and trailing commas)

### Key Sections

```json5
{
  // Gateway configuration
  "gateway": {
    "port": 18789,
    "bind": "loopback",  // localhost only
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    },
    "reload": {
      "mode": "hybrid"  // Hot reload for most changes
    }
  },

  // MCP Server Registration
  "mcp": {
    "servers": {
      "mem0": {
        "command": "docker",
        "args": ["exec", "-i", "cleo-mem0-mcp", "node", "dist/index.js"],
        "env": {
          "MEM0_API_URL": "http://mem0:8080",
          "MEM0_API_KEY": "${MEM0_API_KEY}"
        }
      }
    }
  },

  // Channel Configuration
  "channels": {
    "discord": {
      "enabled": true,
      "token": "${DISCORD_BOT_TOKEN}",
      "dmPolicy": "pairing"  // Require pairing approval for DMs
    }
  },

  // Agent Configuration
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/google/gemini-2.0-flash-exp:free"
      }
    }
  }
}
```

### Configuration Hot Reload

Most configuration changes auto-reload (`reload.mode: "hybrid"`).

**Changes requiring restart:**
- MCP server registration (adding/removing servers)
- Gateway port changes
- Authentication mode changes

```bash
# Restart to apply changes
docker compose restart openclaw
```

## Discord Integration

### Initial Setup

1. **Enable Required Intents** in Discord Developer Portal:
   - Message Content Intent (required)
   - Server Members Intent (recommended)
   - Presence Intent (optional)

2. **Invite Bot** to server with required permissions:
   - Send Messages
   - Read Message History
   - Add Reactions

3. **Configure in openclaw.json:**
```json5
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "${DISCORD_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    }
  }
}
```

### Pairing Workflow (DMs)

1. User sends DM to bot
2. Bot responds with pairing code (expires in 1 hour)
3. Admin approves via CLI:
```bash
docker compose exec openclaw openclaw pairing list discord
docker compose exec openclaw openclaw pairing approve discord <CODE>
```

### Troubleshooting Discord

```bash
# Check channel status
docker compose exec openclaw openclaw channels status --probe

# Common issues:
# - "unauthorized" → Invalid bot token
# - Bot not responding → Check Message Content Intent is enabled
# - No response to DMs → Check dmPolicy and pairing status
```

## MCP Server Management

### How MCP Servers Work

1. OpenClaw spawns MCP server as child process
2. Communication via stdio (JSON-RPC 2.0 over stdin/stdout)
3. OpenClaw manages lifecycle (start, stop, restart on failure)
4. Tools auto-discovered via `tools/list` protocol

### Testing MCP Server Manually

```bash
# Send initialize request to MCP server
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
  docker compose exec -T cleo-mem0-mcp node dist/index.js

# List tools
cat <<EOF | docker compose exec -T cleo-mem0-mcp node dist/index.js
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
EOF
```

### MCP Server Logs

MCP servers write debug logs to stderr (stdout reserved for JSON-RPC):

```bash
# View mem0-mcp logs
docker compose logs cleo-mem0-mcp -f
```

## Health Checks

### Manual Health Check

```bash
# Run comprehensive verification
./scripts/verify-openclaw.sh

# Or individual checks:
curl http://127.0.0.1:18789/health              # Gateway
curl http://127.0.0.1:8080/health               # mem0 API
curl http://127.0.0.1:6333/health               # Qdrant
```

### Automated Health Checks

Docker health checks are configured in docker-compose.infra.yml:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:18789/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### Common Health Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Gateway not responding | Container crashed | `docker compose restart openclaw` |
| Discord bot offline | Invalid token | Check DISCORD_BOT_TOKEN in .env |
| MCP tools missing | Server not started | Check openclaw.json mcp.servers |
| mem0 API errors | Qdrant connection | Check qdrant container health |

## Troubleshooting

### Gateway Won't Start

```bash
# Check logs
docker compose logs openclaw --tail 100

# Common causes:
# - Port conflict (EADDRINUSE)
# - Invalid config (schema validation)
# - Missing required env vars
```

### Discord Bot Not Responding

```bash
# Check channel status
docker compose exec openclaw openclaw channels status --probe

# Common causes:
# - Message Content Intent not enabled
# - requireMention: true in guild config
# - Pairing not approved (dmPolicy: pairing)
```

### MCP Server Not Loading

```bash
# Check MCP-related logs
docker compose logs openclaw | grep -i mcp

# Test server manually
docker compose exec -T cleo-mem0-mcp node dist/index.js

# Common causes:
# - Incorrect path in openclaw.json
# - Missing node_modules
# - Container not running
```

### Configuration Changes Not Applying

```bash
# Check reload mode
docker compose exec openclaw openclaw config get gateway.reload.mode

# Force restart
docker compose restart openclaw
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| OPENCLAW_GATEWAY_TOKEN | Yes | Gateway authentication token |
| DISCORD_BOT_TOKEN | Yes | Discord bot token |
| MEM0_API_KEY | Yes | mem0 API authentication |
| OPENROUTER_API_KEY | Yes | OpenRouter API for LLM (FREE tier) |
| HUGGINGFACE_API_KEY | No | HuggingFace API for embeddings |

## Security Notes

- Gateway bound to loopback only (127.0.0.1)
- All secrets via environment variables (not hardcoded)
- Token authentication required for gateway access
- Discord DMs require pairing approval by default
- SSH tunnel or Tailscale for remote access

## Cost Verification

**$0/month API cost guaranteed:**
- LLM: `openrouter/google/gemini-2.0-flash-exp:free` (OpenRouter free tier)
- Embeddings: `sentence-transformers/all-MiniLM-L6-v2` (HuggingFace free tier)
- No OpenAI API required

**Rate Limits:**
- OpenRouter: 50-1000 req/day (free tier)
- HuggingFace: ~few hundred req/hour

## Useful Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/openclaw-post-deploy.sh` | Automated post-deployment setup |
| `./scripts/verify-openclaw.sh` | Health verification and diagnostics |
| `./scripts/test-openclaw-mcp.sh` | MCP integration testing |
| `./scripts/test-local-mcp.sh` | Local Claude Code connectivity test |
