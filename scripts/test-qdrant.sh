#!/bin/bash
# scripts/test-qdrant.sh - Verify Qdrant deployment and mem0 integration
#
# Run this script after docker compose up to verify:
# 1. Qdrant container is healthy
# 2. mem0 API can connect to Qdrant
# 3. Vector operations (add, search) work correctly

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%H:%M:%S')] $1"
}

# Check Qdrant health
log "${YELLOW}Testing Qdrant health...${NC}"
if curl -sf http://localhost:6333/healthz > /dev/null 2>&1; then
    log "${GREEN}✓ Qdrant is healthy${NC}"
else
    log "${RED}✗ Qdrant is not responding on localhost:6333${NC}"
    echo "  Check: docker compose -f docker-compose.infra.yml logs qdrant"
    exit 1
fi

# Check Qdrant collections endpoint
log "${YELLOW}Testing Qdrant API...${NC}"
COLLECTIONS=$(curl -sf http://localhost:6333/collections 2>/dev/null || echo "ERROR")
if [[ "$COLLECTIONS" != "ERROR" ]]; then
    log "${GREEN}✓ Qdrant API accessible${NC}"
    echo "  Collections: $COLLECTIONS"
else
    log "${RED}✗ Cannot access Qdrant API${NC}"
    exit 1
fi

# Test mem0 health
log "${YELLOW}Testing mem0 API health...${NC}"
MEM0_HEALTH=$(curl -sf http://localhost:8080/health 2>/dev/null || echo "ERROR")
if [[ "$MEM0_HEALTH" != "ERROR" ]]; then
    log "${GREEN}✓ mem0 API is responding${NC}"
    echo "  Response: $MEM0_HEALTH"
else
    log "${RED}✗ mem0 API not responding on localhost:8080${NC}"
    echo "  Check: docker compose -f docker-compose.infra.yml logs mem0"
    exit 1
fi

# Test add memory via mem0 API
log "${YELLOW}Testing add memory operation...${NC}"
ADD_RESULT=$(curl -sf -X POST http://localhost:8080/memories \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${MEM0_API_KEY:-}" \
    -d '{"content": "Phase 1.5 test: Qdrant integration verified", "user_id": "aman", "metadata": {"test": true}}' \
    2>/dev/null || echo "ERROR")

if [[ "$ADD_RESULT" != "ERROR" ]] && echo "$ADD_RESULT" | grep -q "success"; then
    log "${GREEN}✓ Memory added successfully${NC}"
    echo "  Result: $ADD_RESULT"
else
    log "${RED}✗ Failed to add memory${NC}"
    echo "  Result: $ADD_RESULT"
    exit 1
fi

# Test search memories
log "${YELLOW}Testing search operation...${NC}"
SEARCH_RESULT=$(curl -sf "http://localhost:8080/memories?query=Qdrant&user_id=aman&limit=5" \
    -H "X-API-Key: ${MEM0_API_KEY:-}" \
    2>/dev/null || echo "ERROR")

if [[ "$SEARCH_RESULT" != "ERROR" ]]; then
    log "${GREEN}✓ Search operation successful${NC}"
    echo "  Results found: $(echo "$SEARCH_RESULT" | grep -o '"count":[0-9]*' || echo 'unable to parse')"
else
    log "${RED}✗ Search operation failed${NC}"
    exit 1
fi

# Verify Qdrant collection was created
log "${YELLOW}Verifying Qdrant collection...${NC}"
CLEO_COLLECTION=$(curl -sf http://localhost:6333/collections/cleo_memories 2>/dev/null || echo "NOT_FOUND")
if [[ "$CLEO_COLLECTION" != "NOT_FOUND" ]] && echo "$CLEO_COLLECTION" | grep -q "cleo_memories"; then
    log "${GREEN}✓ cleo_memories collection exists in Qdrant${NC}"
else
    log "${YELLOW}⚠ Collection may not exist yet (will be created on first write)${NC}"
fi

echo ""
log "${GREEN}All tests passed! Qdrant + mem0 integration verified.${NC}"
echo ""
echo "Summary:"
echo "  - Qdrant: http://localhost:6333"
echo "  - mem0 API: http://localhost:8080"
echo "  - Collection: cleo_memories"
echo "  - Vector store: Qdrant (PRIMARY)"
