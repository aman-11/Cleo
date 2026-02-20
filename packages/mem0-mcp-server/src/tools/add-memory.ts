import { MCPTool, ToolResponse } from 'mcp-framework';
import { z } from 'zod';
import { mem0Request, getToolConfig } from './base.js';

const inputSchema = z.object({
  content: z.string().describe('The content to store as a memory'),
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
  metadata: z.record(z.any()).optional().describe('Optional metadata to attach'),
});

class AddMemoryTool extends MCPTool {
  name = 'add_memory';
  description = 'Store a new memory in mem0. Use for remembering facts, preferences, decisions, or context.';
  schema = inputSchema;

  async execute(input: z.infer<typeof inputSchema>): Promise<string | ToolResponse> {
    try {
      const config = getToolConfig();
      const result = await mem0Request(config, '/memories', {
        method: 'POST',
        body: JSON.stringify({
          content: input.content,
          user_id: input.user_id,
          metadata: input.metadata || {},
        }),
      });

      return `Memory added successfully: ${JSON.stringify(result)}`;
    } catch (error) {
      return this.createErrorResponse(error as Error);
    }
  }
}

export default AddMemoryTool;
