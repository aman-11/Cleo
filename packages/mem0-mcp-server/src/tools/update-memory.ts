import { MCPTool, ToolResponse } from 'mcp-framework';
import { z } from 'zod';
import { mem0Request, getToolConfig } from './base.js';

const inputSchema = z.object({
  memory_id: z.string().describe('ID of the memory to update'),
  content: z.string().describe('New content for the memory'),
});

class UpdateMemoryTool extends MCPTool {
  name = 'update_memory';
  description = 'Update an existing memory by ID. Use to correct or modify stored information.';
  schema = inputSchema;

  async execute(input: z.infer<typeof inputSchema>): Promise<string | ToolResponse> {
    try {
      const config = getToolConfig();
      const result = await mem0Request(config, `/memories/${input.memory_id}`, {
        method: 'PUT',
        body: JSON.stringify({ content: input.content }),
      });

      return `Memory updated successfully: ${JSON.stringify(result)}`;
    } catch (error) {
      return this.createErrorResponse(error as Error);
    }
  }
}

export default UpdateMemoryTool;
