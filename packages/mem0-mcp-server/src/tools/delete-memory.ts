import { MCPTool, ToolResponse } from 'mcp-framework';
import { z } from 'zod';
import { mem0Request, getToolConfig } from './base.js';

const inputSchema = z.object({
  memory_id: z.string().describe('ID of the memory to delete'),
});

class DeleteMemoryTool extends MCPTool {
  name = 'delete_memory';
  description = 'Delete a memory by ID. Use to remove outdated or incorrect information.';
  schema = inputSchema;

  async execute(input: z.infer<typeof inputSchema>): Promise<string | ToolResponse> {
    try {
      const config = getToolConfig();
      await mem0Request(config, `/memories/${input.memory_id}`, {
        method: 'DELETE',
      });

      return `Memory deleted successfully: ${input.memory_id}`;
    } catch (error) {
      return this.createErrorResponse(error as Error);
    }
  }
}

export default DeleteMemoryTool;
