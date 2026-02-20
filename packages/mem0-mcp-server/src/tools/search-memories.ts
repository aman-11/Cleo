import { MCPTool, ToolOutput } from 'mcp-framework';
import { z } from 'zod';
import { ToolConfig, mem0Request } from './base.js';

const inputSchema = z.object({
  query: z.string().describe('Search query for semantic similarity search'),
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
  limit: z.number().int().positive().default(10).describe('Maximum results to return (default: 10)'),
});

export class SearchMemoriesTool extends MCPTool<typeof inputSchema> {
  name = 'search_memories';
  description = 'Search memories by semantic similarity. Use to recall past context, decisions, or preferences.';
  schema = inputSchema;

  private config: ToolConfig;

  constructor(config: ToolConfig) {
    super();
    this.config = config;
  }

  async execute(input: z.infer<typeof inputSchema>): Promise<ToolOutput> {
    try {
      const params = new URLSearchParams({
        query: input.query,
        user_id: input.user_id,
        limit: input.limit.toString(),
      });

      const result = await mem0Request(this.config, `/memories?${params}`);

      const memories = result.results || [];
      const formattedResults = memories.map((m: any, i: number) =>
        `${i + 1}. ${m.memory || m.content || JSON.stringify(m)}`
      ).join('\n');

      return {
        content: [{
          type: 'text',
          text: memories.length > 0
            ? `Found ${memories.length} memories:\n${formattedResults}`
            : `No memories found for query: "${input.query}"`,
        }],
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Failed to search memories: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }],
        isError: true,
      };
    }
  }
}
