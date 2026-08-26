# Stage 1: Build
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@8.15.0

# Copy dependency manifests first (cache layer)
COPY package.json pnpm-lock.yaml tsconfig.json ./

# Install all dependencies (including devDependencies for build)
RUN pnpm install --frozen-lockfile

# Copy source code
COPY src/ ./src/

# Build TypeScript
RUN pnpm build

# Copy public directory (HTML, CSS, JS that don't need transpiling)
RUN mkdir -p dist/public && cp -r src/public/* dist/public/ 2>/dev/null || true

# Stage 2: Production
FROM node:22-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Run as non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

WORKDIR /app

# Copy built artifacts and production dependencies only
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Expose health check port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start with Node directly (not npm) for proper signal handling
CMD ["node", "dist/index.js"]
