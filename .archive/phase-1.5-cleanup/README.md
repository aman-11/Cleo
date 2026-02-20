# Phase 1.5 Cleanup Archive

Archived on: 2026-02-20
Phase: 01.5-mcp-server-integration
Plan: 00 (cleanup before execution)

## Files Archived NOW

### server.py (from services/mem0/)

**Reason:** Superseded by SOLID architecture refactoring.

**Context:**
- Original: Monolithic 250-line FastAPI server
- Replacement: `services/mem0/src/main.py` with layered architecture
- Dockerfile CMD uses: `python -m src.main`

**References:**
- FIXES.md documents the refactoring
- New architecture in `services/mem0/src/` follows SOLID principles

## Files to Archive AFTER Phase 1.5-06 (Tailscale)

The following files will become obsolete after Tailscale deployment (Plan 01.5-06):

### .infra/ssh-tunnel.sh

**Status:** DEPRECATED - archive after Tailscale setup verified
**Reason:** Tailscale MagicDNS replaces SSH tunnels
**Superseded by:** `scripts/setup-tailscale.sh`, `scripts/verify-tailscale.sh`

### .infra/cleo-mem0-tunnel.service

**Status:** DEPRECATED - archive after Tailscale setup verified
**Reason:** Tailscale runs as system service with auto-reconnect
**Superseded by:** Tailscale daemon (tailscaled)

## Files Updated (Not Archived)

These files were updated to reflect Phase 1.5 decisions:

### .infra/README-postgres.md
- Changed: OpenAI ada-002 (1536 dims) → HuggingFace all-MiniLM-L6-v2 (384 dims)
- Changed: pgvector as PRIMARY → Qdrant as PRIMARY (PostgreSQL for structured data)

### .infra/POSTGRES-FAQ.md
- Changed: OpenAI embeddings → HuggingFace embeddings
- Changed: VECTOR(1536) → VECTOR(384)
- Added note: Qdrant is now PRIMARY vector store

## Why Archive Instead of Delete?

1. Reference for historical context
2. May contain edge case handling not yet ported to new architecture
3. Easy rollback if issues discovered
4. Git history preserved but clutter removed from active codebase
