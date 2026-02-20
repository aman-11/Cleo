# packages/mem0-mcp-server/Dockerfile
# Multi-stage build for mem0 MCP server
#
# Build context: monorepo root (not package directory)
# Usage: docker build -f packages/mem0-mcp-server/Dockerfile -t cleo/mem0-mcp .

# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@8.15.0

# Copy workspace root files
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./

# Copy package directory
COPY packages/mem0-mcp-server/package.json packages/mem0-mcp-server/

# Install dependencies (production only for runtime)
RUN pnpm install --frozen-lockfile

# Copy source
COPY packages/mem0-mcp-server/src packages/mem0-mcp-server/src
COPY packages/mem0-mcp-server/tsconfig.json packages/mem0-mcp-server/

# Build TypeScript
RUN pnpm --filter @cleo/mem0-mcp-server build

# Runtime stage
FROM node:20-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S mcp && \
    adduser -S mcp -u 1001 -G mcp

# Install pnpm for workspace resolution
RUN npm install -g pnpm@8.15.0

# Copy built artifacts from builder
COPY --from=builder /app/packages/mem0-mcp-server/dist ./dist
COPY --from=builder /app/packages/mem0-mcp-server/package.json ./
COPY --from=builder /app/node_modules ./node_modules

# Switch to non-root user
USER mcp

# Environment variables (can be overridden at runtime)
ENV MEM0_API_URL=http://mem0:8080
ENV MEM0_API_KEY=

# MCP servers use stdio, not HTTP - no EXPOSE needed
# Health check not applicable for stdio servers

# Start MCP server
CMD ["node", "dist/index.js"]
