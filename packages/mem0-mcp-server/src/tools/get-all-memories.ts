import { MCPTool, ToolResponse } from 'mcp-framework';
import { z } from 'zod';
import { mem0Request, getToolConfig } from './base.js';

const inputSchema = z.object({
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
});

class GetAllMemoriesTool extends MCPTool {
  name = 'get_all_memories';
  description = 'Retrieve all memories for a user. Use to list everything remembered.';
  schema = inputSchema;

  async execute(input: z.infer<typeof inputSchema>): Promise<string | ToolResponse> {
    try {
      const config = getToolConfig();
      const params = new URLSearchParams({ user_id: input.user_id });
      const result = await mem0Request(config, `/memories/all?${params}`);

      const memories = result.memories || [];
      const formattedResults = memories.map((m: any, i: number) =>
        `${i + 1}. [${m.id || 'no-id'}] ${m.memory || m.content || JSON.stringify(m)}`
      ).join('\n');

      return memories.length > 0
        ? `Total memories: ${memories.length}\n${formattedResults}`
        : 'No memories found.';
    } catch (error) {
      return this.createErrorResponse(error as Error);
    }
  }
}

export default GetAllMemoriesTool;
