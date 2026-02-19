#!/bin/bash
# Verification script for PostgreSQL + pgvector + mem0 setup

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verifying PostgreSQL Setup for Cleo mem0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check container is running
echo "1. Checking postgres container health..."
if docker ps | grep -q cleo-postgres; then
    echo "   ✅ Container running"
else
    echo "   ❌ Container not running"
    exit 1
fi

# Check pgvector extension
echo "2. Checking pgvector extension..."
PGVECTOR_VERSION=$(docker exec cleo-postgres psql -U postgres -d mem0 -tAc "SELECT extversion FROM pg_extension WHERE extname = 'vector';")
if [ -n "$PGVECTOR_VERSION" ]; then
    echo "   ✅ pgvector $PGVECTOR_VERSION enabled"
else
    echo "   ❌ pgvector not enabled"
    exit 1
fi

# Check mem0user exists
echo "3. Checking mem0user..."
USER_EXISTS=$(docker exec cleo-postgres psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'mem0user';")
if [ "$USER_EXISTS" = "1" ]; then
    echo "   ✅ mem0user created"
else
    echo "   ❌ mem0user not found"
    exit 1
fi

# Check mem0user can connect
echo "4. Checking mem0user can connect to mem0 database..."
if docker exec cleo-postgres psql -U mem0user -d mem0 -c "SELECT 1;" > /dev/null 2>&1; then
    echo "   ✅ mem0user can connect"
else
    echo "   ❌ mem0user cannot connect"
    exit 1
fi

# Check mem0 tables (if mem0 SDK has initialized)
echo "5. Checking mem0 tables..."
TABLES=$(docker exec cleo-postgres psql -U mem0user -d mem0 -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('memories', 'collections');")
if [ "$TABLES" -gt 0 ]; then
    echo "   ✅ mem0 tables exist ($TABLES/2)"
    MEMORY_COUNT=$(docker exec cleo-postgres psql -U mem0user -d mem0 -tAc "SELECT COUNT(*) FROM memories;" 2>/dev/null || echo "0")
    echo "   ℹ️  Memories stored: $MEMORY_COUNT"
else
    echo "   ⚠️  mem0 tables not yet created (will be created on first mem0 service start)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PostgreSQL setup verification complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
