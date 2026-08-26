# Local Claude Code MCP Setup

Connect your local Claude Code to the VPS mem0 server for shared memory.

## Prerequisites

1. ✅ Tailscale connected on both laptop and VPS
2. ✅ SSH key configured for `aman@cleo-vps`  
3. ✅ VPS mem0-mcp container running
4. ✅ MEM0_API_KEY in your local environment

## Setup Steps

### 1. Add mem0 MCP Server to Claude Code

Edit `~/.claude.json` and add:

```json
{
  "mcpServers": {
    "mem0": {
      "command": "ssh",
      "args": [
        "-o", "StrictHostKeyChecking=no",
        "aman@cleo-vps",
        "docker", "exec", "-i", "cleo-mem0-mcp",
        "node", "dist/index.js"
      ],
      "env": {
        "MEM0_API_URL": "http://mem0:8080",
        "MEM0_API_KEY": "YOUR_MEM0_API_KEY_HERE"
      }
    }
  }
}
```

**Replace `YOUR_MEM0_API_KEY_HERE` with your actual key from `.env`**

### 2. Verify Connection

In Claude Code, type `/mcp` and you should see:

```
Available MCP servers:
  mem0 (5 tools)
    - add_memory
    - search_memories  
    - get_all_memories
    - update_memory
    - delete_memory
```

### 3. Test Memory Operations

Try adding a memory:
```
Can you remember that I prefer TypeScript over Python for backend services?
```

Claude Code will use the `add_memory` tool to store this in the VPS mem0.

Try searching:
```
What do you remember about my language preferences?
```

Claude Code will use `search_memories` to retrieve from VPS mem0.

## How It Works

```
Your Laptop                    VPS (cleo-vps)
┌─────────────┐               ┌──────────────────────┐
│ Claude Code │               │  cleo-mem0-mcp       │
│             │──SSH stdio──▶ │  (stdio transport)   │
│ ~/.claude   │               │       ↓              │
│   .json     │               │  mem0 API :8080      │
│             │               │       ↓              │
│             │               │  PostgreSQL+Qdrant   │
└─────────────┘               └──────────────────────┘
```

- **Transport**: SSH + stdio (standard for Claude Code MCP)
- **Authentication**: SSH key + MEM0_API_KEY
- **Network**: Tailscale VPN (no public exposure)

## Troubleshooting

### "Server not responding"
```bash
# Test SSH connection
ssh aman@cleo-vps "echo 'SSH works'"

# Test container
ssh aman@cleo-vps "docker exec cleo-mem0-mcp node dist/index.js --version"
```

### "Tools not discovered"
```bash
# Check tools exist
ssh aman@cleo-vps "docker exec cleo-mem0-mcp ls -la dist/tools/"
```

### "API key error"
- Check MEM0_API_KEY in ~/.claude.json matches .env on VPS
- Restart Claude Code after changing config

## Shared Brain Architecture

Both **VPS Cleo** and **your local Claude Code** write to the **same mem0 instance**:

- Memories you create locally → stored on VPS
- Memories Cleo creates → accessible to you  
- Single source of truth for aman's context

This is the "shared brain" - MEM-02 requirement fulfilled! ✅
