/**
 * Base utilities for mem0 MCP tools
 */

export interface ToolConfig {
  apiUrl: string;
  apiKey: string;
}

/**
 * Get tool configuration from environment variables
 */
export function getToolConfig(): ToolConfig {
  return {
    apiUrl: process.env.MEM0_API_URL || 'http://localhost:8080',
    apiKey: process.env.MEM0_API_KEY || '',
  };
}

/**
 * Make authenticated request to mem0 REST API
 */
export async function mem0Request(
  config: ToolConfig,
  endpoint: string,
  options: RequestInit = {}
): Promise<any> {
  const url = `${config.apiUrl}${endpoint}`;

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> || {}),
  };

  if (config.apiKey) {
    headers['X-API-Key'] = config.apiKey;
  }

  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`mem0 API error (${response.status}): ${error}`);
  }

  return response.json();
}
