# packages/mem0-mcp-server/Dockerfile
# Simplified single-stage build for mem0 MCP server
#
# Build context: monorepo root (not package directory)
# Usage: docker build -f packages/mem0-mcp-server/Dockerfile -t cleo/mem0-mcp .

FROM node:20-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@8.15.0

# Copy only the MCP server package
COPY packages/mem0-mcp-server/package.json ./package.json
COPY packages/mem0-mcp-server/tsconfig.json ./tsconfig.json

# Install dependencies
RUN pnpm install --frozen-lockfile=false

# Copy source and build
COPY packages/mem0-mcp-server/src ./src
RUN pnpm build

# Create non-root user for security
RUN addgroup -g 1001 -S mcp && \
    adduser -S mcp -u 1001 -G mcp && \
    chown -R mcp:mcp /app

# Switch to non-root user
USER mcp

# Environment variables (can be overridden at runtime)
ENV MEM0_API_URL=http://mem0:8080
ENV MEM0_API_KEY=
ENV NODE_ENV=production

# MCP servers use stdio, not HTTP - no EXPOSE needed

# Start MCP server
CMD ["node", "dist/index.js"]
