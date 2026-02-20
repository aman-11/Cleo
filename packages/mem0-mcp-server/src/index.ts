#!/usr/bin/env node
/**
 * mem0 MCP Server - Model Context Protocol server for mem0 memory operations
 *
 * Built with mcp-framework (QuantGeekDev/mcp-framework)
 * Wraps mem0 REST API for standardized MCP tool access
 *
 * Tools:
 * - add_memory: Store a new memory
 * - search_memories: Semantic search across memories
 * - get_all_memories: List all memories for a user
 * - update_memory: Update an existing memory
 * - delete_memory: Delete a memory by ID
 */

import { MCPServer } from 'mcp-framework';
import { AddMemoryTool } from './tools/add-memory.js';
import { SearchMemoriesTool } from './tools/search-memories.js';
import { GetAllMemoriesTool } from './tools/get-all-memories.js';
import { UpdateMemoryTool } from './tools/update-memory.js';
import { DeleteMemoryTool } from './tools/delete-memory.js';

// Configuration from environment
const MEM0_API_URL = process.env.MEM0_API_URL || 'http://localhost:8080';
const MEM0_API_KEY = process.env.MEM0_API_KEY || '';

// Log to stderr (stdout reserved for MCP JSON-RPC)
console.error(`[mem0-mcp] Starting server...`);
console.error(`[mem0-mcp] mem0 API URL: ${MEM0_API_URL}`);

// Create MCP server
const server = new MCPServer({
  name: 'mem0-mcp',
  version: '1.0.0',
  description: 'MCP server for mem0 memory storage and retrieval',
});

// Register tools with shared configuration
const toolConfig = { apiUrl: MEM0_API_URL, apiKey: MEM0_API_KEY };

server.addTool(new AddMemoryTool(toolConfig));
server.addTool(new SearchMemoriesTool(toolConfig));
server.addTool(new GetAllMemoriesTool(toolConfig));
server.addTool(new UpdateMemoryTool(toolConfig));
server.addTool(new DeleteMemoryTool(toolConfig));

// Start server (stdio transport by default)
server.start();

console.error(`[mem0-mcp] Server started with ${5} tools`);
