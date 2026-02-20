import { MCPTool, ToolOutput } from 'mcp-framework';
import { z } from 'zod';
import { ToolConfig, mem0Request } from './base.js';

const inputSchema = z.object({
  memory_id: z.string().describe('ID of the memory to delete'),
});

export class DeleteMemoryTool extends MCPTool<typeof inputSchema> {
  name = 'delete_memory';
  description = 'Delete a memory by ID. Use to remove outdated or incorrect information.';
  schema = inputSchema;

  private config: ToolConfig;

  constructor(config: ToolConfig) {
    super();
    this.config = config;
  }

  async execute(input: z.infer<typeof inputSchema>): Promise<ToolOutput> {
    try {
      const result = await mem0Request(this.config, `/memories/${input.memory_id}`, {
        method: 'DELETE',
      });

      return {
        content: [{
          type: 'text',
          text: `Memory deleted successfully: ${input.memory_id}`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to delete memory: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }],
        isError: true,
      };
    }
  }
}
