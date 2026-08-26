#!/usr/bin/env node
/**
 * mem0 MCP Server - Model Context Protocol server for mem0 memory operations
 *
 * Built with mcp-framework (QuantGeekDev/mcp-framework)
 * Wraps mem0 REST API for standardized MCP tool access
 *
 * Tools (auto-discovered from ./tools/):
 * - add_memory: Store a new memory
 * - search_memories: Semantic search across memories
 * - get_all_memories: List all memories for a user
 * - update_memory: Update an existing memory
 * - delete_memory: Delete a memory by ID
 *
 * Environment variables:
 * - MEM0_API_URL: mem0 REST API URL (default: http://localhost:8080)
 * - MEM0_API_KEY: mem0 API key for authentication
 */

import { MCPServer } from 'mcp-framework';

// Configuration from environment
const MEM0_API_URL = process.env.MEM0_API_URL || 'http://localhost:8080';
const MEM0_API_KEY = process.env.MEM0_API_KEY || '';
const MCP_TRANSPORT = process.env.MCP_TRANSPORT || 'http-stream'; // 'stdio' or 'http-stream'
const MCP_PORT = parseInt(process.env.MCP_PORT || '3001');
const MCP_ENDPOINT = process.env.MCP_ENDPOINT || '/mcp';

// Log to stderr (stdout reserved for MCP JSON-RPC in stdio mode)
const log = MCP_TRANSPORT === 'stdio' ? console.error : console.log;
log(`[mem0-mcp] Starting server...`);
log(`[mem0-mcp] mem0 API URL: ${MEM0_API_URL}`);
log(`[mem0-mcp] Transport: ${MCP_TRANSPORT}`);
if (MCP_TRANSPORT === 'http-stream') {
  log(`[mem0-mcp] MCP Port: ${MCP_PORT}`);
  log(`[mem0-mcp] MCP Endpoint: ${MCP_ENDPOINT}`);
}
log(`[mem0-mcp] Auto-discovering tools from dist/tools/`);

// Create MCP server with configurable transport
// DO NOT provide basePath - let framework auto-discover dist/tools/ directory
const serverConfig: any = {
  name: 'mem0-mcp',
  version: '1.0.0',
};

// Add transport config only for HTTP (stdio is default)
if (MCP_TRANSPORT === 'http-stream') {
  serverConfig.transport = {
    type: 'http-stream',
    options: {
      port: MCP_PORT,
      endpoint: MCP_ENDPOINT,
      responseMode: 'stream', // Use Server-Sent Events for real-time responses
      cors: {
        allowOrigin: '*', // Allow OpenClaw to connect from any origin
        allowMethods: 'GET, POST, OPTIONS',
        allowHeaders: 'Content-Type, Authorization, x-api-key',
      },
    },
  };
}

const server = new MCPServer(serverConfig);

// Start server
await server.start();

if (MCP_TRANSPORT === 'http-stream') {
  log(`[mem0-mcp] Server started successfully on http://0.0.0.0:${MCP_PORT}${MCP_ENDPOINT}`);
} else {
  log(`[mem0-mcp] Server started successfully on stdio transport`);
}
