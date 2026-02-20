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
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Get current directory for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration from environment
const MEM0_API_URL = process.env.MEM0_API_URL || 'http://localhost:8080';
const MEM0_API_KEY = process.env.MEM0_API_KEY || '';

// Log to stderr (stdout reserved for MCP JSON-RPC)
console.error(`[mem0-mcp] Starting server...`);
console.error(`[mem0-mcp] mem0 API URL: ${MEM0_API_URL}`);
console.error(`[mem0-mcp] Base path: ${join(__dirname, '..')}`);

// Create MCP server with auto-discovery
const server = new MCPServer({
  name: 'mem0-mcp',
  version: '1.0.0',
  basePath: join(__dirname, '..'),
});

// Start server (stdio transport by default, auto-discovers tools from dist/tools/)
await server.start();

console.error(`[mem0-mcp] Server started successfully`);
