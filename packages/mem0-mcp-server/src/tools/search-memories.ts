import { MCPTool, ToolResponse } from 'mcp-framework';
import { z } from 'zod';
import { mem0Request, getToolConfig } from './base.js';

const inputSchema = z.object({
  query: z.string().describe('Search query for semantic similarity search'),
  user_id: z.string().default('aman').describe('User ID for namespace (default: aman)'),
  limit: z.number().int().positive().default(10).describe('Maximum results to return (default: 10)'),
});

class SearchMemoriesTool extends MCPTool {
  name = 'search_memories';
  description = 'Search memories by semantic similarity. Use to recall past context, decisions, or preferences.';
  schema = inputSchema;

  async execute(input: z.infer<typeof inputSchema>): Promise<string | ToolResponse> {
    try {
      const config = getToolConfig();
      const params = new URLSearchParams({
        query: input.query,
        user_id: input.user_id,
        limit: input.limit.toString(),
      });

      const result = await mem0Request(config, `/memories?${params}`);

      const memories = result.results || [];
      const formattedResults = memories.map((m: any, i: number) =>
        `${i + 1}. ${m.memory || m.content || JSON.stringify(m)}`
      ).join('\n');

      return memories.length > 0
        ? `Found ${memories.length} memories:\n${formattedResults}`
        : `No memories found for query: "${input.query}"`;
    } catch (error) {
      return this.createErrorResponse(error as Error);
    }
  }
}

export default SearchMemoriesTool;
