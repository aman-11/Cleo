# Claude Code MCP Configuration

This document explains how to configure local Claude Code to access the VPS mem0 MCP server via Tailscale.

## Prerequisites

1. **Tailscale connected** - Both laptop and VPS on same tailnet (Plan 06 complete)
2. **VPS accessible** - `ping cleo-vps` works (MagicDNS)
3. **SSH key configured** - SSH key for VPS access
4. **VPS services running** - `docker compose -f docker-compose.infra.yml up -d`
5. **Environment variables** - `MEM0_API_KEY` set locally

## Tailscale Verification

Tailscale provides MagicDNS - no SSH config entry needed for hostname resolution:

```bash
tailscale status              # Check connected
ping cleo-vps                 # Test MagicDNS
ssh aman@cleo-vps echo "OK"   # Test SSH via Tailscale
```

## SSH Config (Optional)

Only needed for non-default settings (user, key path):

```
Host cleo-vps
  User aman
  IdentityFile ~/.ssh/cleo_vps_key
  # HostName NOT needed - Tailscale MagicDNS resolves it
```

## Install MCP Configuration

### Option A: Merge with existing ~/.claude.json

If you already have a ~/.claude.json file, add the mcpServers section:

```bash
# View current config
cat ~/.claude.json

# Manually merge the mem0 server from .infra/claude-mcp-config.json
```

### Option B: Fresh installation

If ~/.claude.json doesn't exist:

```bash
# Copy template
cp .infra/claude-mcp-config.json ~/.claude.json

# Replace placeholder with actual API key
sed -i '' "s/\${MEM0_API_KEY}/$MEM0_API_KEY/" ~/.claude.json
```

## Verify Configuration

1. **Restart Claude Code** (or open new terminal)

2. **Check MCP servers loaded:**
   ```
   claude mcp list
   # Should show: mem0 (stdio via ssh)
   ```

3. **Test connectivity:**
   ```
   # In Claude Code, type:
   /mcp
   # Should show mem0 server with 5 tools
   ```

4. **Test tool execution:**
   ```
   # In Claude Code session:
   "Remember that my favorite color is blue"
   # Should use add_memory tool

   "What's my favorite color?"
   # Should use search_memories tool
   ```

## Troubleshooting

### "Connection refused"
- Check VPS is reachable: `ssh cleo-vps echo "OK"`
- Check Docker services: `ssh cleo-vps docker ps`
- Check mem0-mcp container: `ssh cleo-vps docker logs cleo-mem0-mcp`

### "No MCP servers found"
- Verify ~/.claude.json exists and has correct syntax
- Check file location is ~/.claude.json (NOT ~/.claude/mcp-settings.json)
- Restart Claude Code after config changes

### "Tool execution failed"
- Check MEM0_API_KEY is correct
- Test mem0 API directly: `curl http://localhost:8080/health` (via SSH tunnel)
- Check mem0 service logs: `ssh cleo-vps docker logs cleo-mem0`

### Slow tool responses
- Expected latency with Tailscale: <1 second (peer-to-peer)
- If >3 seconds, check Tailscale: `tailscale ping cleo-vps`
- Run diagnostics: `tailscale netcheck`

## Environment Variables

The MCP server expects these environment variables (passed through SSH):

| Variable | Description | Required |
|----------|-------------|----------|
| MEM0_API_KEY | API key for mem0 authentication | Yes |
| MEM0_API_URL | mem0 REST API URL | No (default: http://mem0:8080) |

Set in your local shell profile (~/.zshrc or ~/.bashrc):

```bash
export MEM0_API_KEY="your_api_key_here"
```

## Security Notes

- SSH key authentication required (no password)
- API key passed via environment (not in config file)
- stdio transport - no ports exposed
- All traffic encrypted via Tailscale (WireGuard)
- No public SSH port exposure needed

## Multi-Device Access

Thanks to Tailscale:
- **Laptop**: Full Claude Code MCP access
- **Phone**: Can access VPS web services via browser
- **Travel**: Works from any network
