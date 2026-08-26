# mem0 MCP Server

Model Context Protocol (MCP) server for mem0 memory operations.

## Overview

This MCP server provides tools for interacting with mem0's memory API, allowing AI assistants to:
- Add new memories
- Search memories semantically
- Get all memories for a user
- Update existing memories
- Delete memories

## Architecture

- **Framework**: mcp-framework v0.2.18
- **Transport**: HTTP Stream (Server-Sent Events)
- **Port**: 3001 (default)
- **Endpoint**: `/mcp`
- **Tools**: 5 (auto-discovered from `dist/tools/`)

## Configuration

### Environment Variables

```bash
# mem0 API connection
MEM0_API_URL=http://mem0:8080
MEM0_API_KEY=<your-api-key>

# MCP server configuration
MCP_PORT=3001              # HTTP server port
MCP_ENDPOINT=/mcp          # MCP endpoint path
```

### Docker Compose

```yaml
mem0-mcp:
  image: cleo/mem0-mcp:latest
  environment:
    - MEM0_API_URL=http://mem0:8080
    - MEM0_API_KEY=${MEM0_API_KEY}
    - MCP_PORT=3001
    - MCP_ENDPOINT=/mcp
  ports:
    - "127.0.0.1:3001:3001"
  networks:
    - cleo-network
```

## Usage

### HTTP Transport

The server runs on HTTP with Server-Sent Events (SSE) for streaming responses.

**Base URL**: `http://localhost:3001/mcp` (or `http://mem0-mcp:3001/mcp` from Docker network)

**Session Management**: The server requires a session ID for all requests. To start a session:

1. Make an initial request (any method)
2. The server will assign a session ID in the `Mcp-Session-Id` header
3. Include this session ID in subsequent requests

**Example Request**:
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -H "Mcp-Session-Id: <session-id>" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'
```

### OpenClaw Integration

To use this MCP server with OpenClaw:

1. **Configure OpenClaw** to connect to the MCP server:
   - URL: `http://mem0-mcp:3001/mcp` (internal Docker network)
   - Or: `http://localhost:3001/mcp` (from host)
   - Or: `https://cleo-vps.tail499b42.ts.net:3001/mcp` (via Tailscale)

2. **MCP Client Configuration**:
   ```json
   {
     "mcpServers": {
       "mem0": {
         "url": "http://mem0-mcp:3001/mcp",
         "transport": "http"
       }
     }
   }
   ```

3. **Use the tools** in OpenClaw workflows:
   - `add_memory`: Store new memories
   - `search_memories`: Semantic search
   - `get_all_memories`: List all memories
   - `update_memory`: Update existing memory
   - `delete_memory`: Remove a memory

### Available Tools

1. **add_memory**
   - Add a new memory to mem0
   - Parameters: `user_id`, `messages` (array of message objects)

2. **search_memories**
   - Search memories using semantic similarity
   - Parameters: `user_id`, `query`, `limit` (optional)

3. **get_all_memories**
   - Retrieve all memories for a user
   - Parameters: `user_id`, `limit` (optional)

4. **update_memory**
   - Update an existing memory
   - Parameters: `memory_id`, `data` (new memory content)

5. **delete_memory**
   - Delete a memory by ID
   - Parameters: `memory_id`

## Development

### Build

```bash
pnpm install
pnpm build
```

### Run Locally

```bash
# Set environment variables
export MEM0_API_URL=http://localhost:8080
export MEM0_API_KEY=your-api-key

# Run the server
node dist/index.js
```

### Docker Build

```bash
docker build -t cleo/mem0-mcp:latest -f packages/mem0-mcp-server/Dockerfile .
```

## Transport: stdio vs HTTP

### stdio (Previous)
- ❌ Exits when no client connected
- ❌ Restart loop in Docker
- ✅ Standard MCP desktop app integration
- Use case: Claude Desktop, local MCP clients

### HTTP (Current)
- ✅ Runs as a daemon
- ✅ Stable in Docker
- ✅ OpenClaw integration
- ✅ Web-based MCP clients
- Use case: VPS deployment, multi-client access

## Troubleshooting

### Server restart loop
**Fixed** in v1.0.0 by switching to HTTP transport. If using stdio mode, this is expected behavior - stdio servers exit when no client is connected.

### "No valid session ID provided"
This is normal. The HTTP transport uses session management. Include the `Mcp-Session-Id` header from the server's response in subsequent requests.

### Health Check Failing
The health check tries to access `http://localhost:3001/mcp` with wget. If failing:
```bash
# Check if server is listening
docker exec cleo-mem0-mcp netstat -tlnp | grep 3001

# Check logs
docker logs cleo-mem0-mcp
```

## References

- [MCP Framework Documentation](https://mcp-framework.com)
- [Model Context Protocol Spec](https://modelcontextprotocol.io)
- [mem0 API Documentation](https://docs.mem0.ai)
- [OpenClaw MCP Integration Guide](https://safeclaw.io/blog/openclaw-mcp)

## Sources
- [OpenClaw MCP GitHub](https://github.com/freema/openclaw-mcp)
- [OpenClaw MCP SafeClaw Blog](https://safeclaw.io/blog/openclaw-mcp)
- [MCP Protocol AAIF Governance](https://modelcontextprotocol.io/blog/mcp-joins-agentic-ai-foundation)
