import { MCPTool, ToolOutput } from 'mcp-framework';
import { z } from 'zod';
import { ToolConfig, mem0Request } from './base.js';

const inputSchema = z.object({
  memory_id: z.string().describe('ID of the memory to update'),
  content: z.string().describe('New content for the memory'),
});

export class UpdateMemoryTool extends MCPTool<typeof inputSchema> {
  name = 'update_memory';
  description = 'Update an existing memory by ID. Use to correct or modify stored information.';
  schema = inputSchema;

  private config: ToolConfig;

  constructor(config: ToolConfig) {
    super();
    this.config = config;
  }

  async execute(input: z.infer<typeof inputSchema>): Promise<ToolOutput> {
    try {
      const result = await mem0Request(this.config, `/memories/${input.memory_id}`, {
        method: 'PUT',
        body: JSON.stringify({ content: input.content }),
      });

      return {
        content: [{
          type: 'text',
          text: `Memory updated successfully: ${JSON.stringify(result)}`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to update memory: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }],
        isError: true,
      };
    }
  }
}
