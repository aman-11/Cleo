import { MCPTool, ToolOutput } from 'mcp-framework';
import { z } from 'zod';
import { ToolConfig, mem0Request } from './base.js';

const inputSchema = z.object({
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
});

export class GetAllMemoriesTool extends MCPTool<typeof inputSchema> {
  name = 'get_all_memories';
  description = 'Retrieve all memories for a user. Use to list everything remembered.';
  schema = inputSchema;

  private config: ToolConfig;

  constructor(config: ToolConfig) {
    super();
    this.config = config;
  }

  async execute(input: z.infer<typeof inputSchema>): Promise<ToolOutput> {
    try {
      const params = new URLSearchParams({ user_id: input.user_id });
      const result = await mem0Request(this.config, `/memories/all?${params}`);

      const memories = result.memories || [];
      const formattedResults = memories.map((m: any, i: number) =>
        `${i + 1}. [${m.id || 'no-id'}] ${m.memory || m.content || JSON.stringify(m)}`
      ).join('\n');

      return {
        content: [{
          type: 'text',
          text: memories.length > 0
            ? `Total memories: ${memories.length}\n${formattedResults}`
            : 'No memories found.',
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to get memories: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }],
        isError: true,
      };
    }
  }
}
