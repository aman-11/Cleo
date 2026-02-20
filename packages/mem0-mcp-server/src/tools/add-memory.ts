import { MCPTool, ToolInput, ToolOutput } from 'mcp-framework';
import { z } from 'zod';
import { ToolConfig, mem0Request } from './base.js';

const inputSchema = z.object({
  content: z.string().describe('The content to store as a memory'),
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
  metadata: z.record(z.any()).optional().describe('Optional metadata to attach'),
});

export class AddMemoryTool extends MCPTool<typeof inputSchema> {
  name = 'add_memory';
  description = 'Store a new memory in mem0. Use for remembering facts, preferences, decisions, or context.';
  schema = inputSchema;

  private config: ToolConfig;

  constructor(config: ToolConfig) {
    super();
    this.config = config;
  }

  async execute(input: z.infer<typeof inputSchema>): Promise<ToolOutput> {
    try {
      const result = await mem0Request(this.config, '/memories', {
        method: 'POST',
        body: JSON.stringify({
          content: input.content,
          user_id: input.user_id,
          metadata: input.metadata || {},
        }),
      });

      return {
        content: [{
          type: 'text',
          text: `Memory added successfully: ${JSON.stringify(result)}`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to add memory: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }],
        isError: true,
      };
    }
  }
}
