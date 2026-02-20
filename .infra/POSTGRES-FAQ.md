# PostgreSQL + mem0 Storage FAQ

> **Note (Phase 1.5):** Qdrant is now the PRIMARY vector store. PostgreSQL with pgvector
> is retained for structured data and as a backup vector store option. See Plan 01.5-01.

## Q: Where are we creating the PostgreSQL database and user?

**A:** Automatically on first container start via `.infra/postgres-init.sql`

### Initialization Flow:

```
1. docker compose -f docker-compose.infra.yml up -d postgres
   ↓
2. PostgreSQL container starts for the FIRST time
   ↓
3. PostgreSQL runs ALL scripts in /docker-entrypoint-initdb.d/
   ↓
4. Our postgres-init.sql is mounted there:
      - ./.infra/postgres-init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
   ↓
5. Script runs and:
   ✅ Enables pgvector extension
   ✅ Creates mem0user with password from POSTGRES_PASSWORD env
   ✅ Grants all privileges on mem0 database to mem0user
   ✅ Sets up schema permissions
```

**Location:** `.infra/postgres-init.sql`
**When:** First container start only (idempotent - uses `IF NOT EXISTS`)
**Trigger:** Automatic (Docker entrypoint init.d pattern)

---

## Q: Where is the database schema defined?

**A:** The mem0 SDK auto-creates tables on first connection

### Schema Creation Flow:

```
1. mem0 service starts (depends_on postgres healthy)
   ↓
2. src/main.py runs lifespan() startup
   ↓
3. Initializes mem0 SDK:
      mem0_client = Memory.from_config(config)
   ↓
4. mem0 SDK connects to PostgreSQL as mem0user
   ↓
5. mem0 SDK checks if tables exist
   ↓
6. If NOT exist, auto-creates:
   ✅ memories table (content, embedding vector, metadata, timestamps)
   ✅ collections table (memory organization)
   ✅ Vector indexes (pgvector HNSW/IVFFlat for similarity search)
```

**Schema Definition:** mem0 SDK internal (not in our codebase)
**Tables Created:** `memories`, `collections`
**Indexes:** Vector similarity indexes on `memories.embedding`
**When:** First mem0 service start

---

## Q: How will mem0 store data?

**A:** PostgreSQL with pgvector for vector embeddings + semantic search

### Storage Architecture:

```
PostgreSQL Container (pgvector/pgvector:pg16)
├── Database: mem0
├── User: mem0user (least privilege)
├── Extension: pgvector (vector similarity search)
│
└── Tables (auto-created by mem0 SDK):
    │
    ├── memories
    │   ├── id: UUID (primary key)
    │   ├── content: TEXT (memory text content)
    │   ├── embedding: VECTOR(1536) ⚡ pgvector type
    │   ├── user_id: TEXT (namespace - always "aman")
    │   ├── metadata: JSONB (arbitrary key-value data)
    │   ├── created_at: TIMESTAMP
    │   └── updated_at: TIMESTAMP
    │
    └── collections
        ├── id: UUID (primary key)
        ├── name: TEXT (e.g., "cleo_memories")
        ├── config: JSONB (collection settings)
        └── created_at: TIMESTAMP
```

### Vector Embeddings:

- **Model:** HuggingFace `all-MiniLM-L6-v2` (384 dimensions, FREE)
- **Type:** `VECTOR(384)` (pgvector extension)
- **Index:** HNSW or IVFFlat (for fast similarity search)
- **Search:** Cosine similarity via `<->` operator

### Example Queries:

```sql
-- Search memories by semantic similarity
SELECT content, metadata
FROM memories
WHERE user_id = 'aman'
ORDER BY embedding <-> $query_embedding
LIMIT 10;

-- Count total memories
SELECT COUNT(*) FROM memories WHERE user_id = 'aman';

-- View recent memories
SELECT content, created_at
FROM memories
WHERE user_id = 'aman'
ORDER BY created_at DESC
LIMIT 10;
```

---

## Q: When does schema initialization happen - Phase 1 or later?

**A:** Phase 1 - happening NOW (already committed)

### Phase 1 Includes:

✅ **PostgreSQL setup** (docker-compose.infra.yml)
✅ **Database initialization** (.infra/postgres-init.sql)
✅ **mem0user creation** (first container start)
✅ **pgvector extension** (enabled in init script)
✅ **mem0 SDK integration** (services/mem0/src/)
✅ **Auto-schema creation** (mem0 SDK on first connection)

### What Happens on VPS Deployment:

```bash
# Phase 1 deployment (happening soon):
cd /home/aman/Cleo

# 1. Create .env from .env.example
cp .env.example .env
vim .env  # Set POSTGRES_PASSWORD, OPENAI_API_KEY, etc.

# 2. Start infrastructure
docker compose -f docker-compose.infra.yml up -d

# What happens:
# - postgres container starts
# - Runs postgres-init.sql (creates mem0user, enables pgvector)
# - mem0 container starts
# - mem0 SDK connects and auto-creates tables
# - SSH tunnel provides local access to mem0 API

# 3. Verify setup
./.infra/verify-postgres.sh

# Output:
# ✅ Container running
# ✅ pgvector 0.7.0 enabled
# ✅ mem0user created
# ✅ mem0user can connect
# ✅ mem0 tables exist (2/2)
# ℹ️  Memories stored: 0
```

---

## Q: How do I access the database?

**A:** Multiple ways depending on use case

### 1. Via mem0 API (Recommended):

```bash
# From local machine (SSH tunnel)
ssh -L 9090:localhost:8080 cleo-vps

# Add a memory
curl -X POST http://localhost:9090/memories \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{"content": "Remember this", "user_id": "aman"}'

# Search memories
curl "http://localhost:9090/memories?query=remember&user_id=aman"
```

### 2. Direct PostgreSQL Access:

```bash
# From VPS
docker exec -it cleo-postgres psql -U mem0user -d mem0

# From local (SSH tunnel)
ssh -L 5432:localhost:5432 cleo-vps
psql -h localhost -U mem0user -d mem0
```

### 3. Via mem0 Python SDK (Future):

```python
from mem0 import Memory
import os

# Connect to VPS mem0 via SSH tunnel
config = {
    "vector_store": {
        "provider": "pgvector",
        "config": {
            "host": "localhost",  # Via SSH tunnel
            "port": 5432,
            "user": "mem0user",
            "password": os.getenv("POSTGRES_PASSWORD"),
            "dbname": "mem0",
        }
    }
}

client = Memory.from_config(config)
client.add("This is a memory", user_id="aman")
results = client.search("memory", user_id="aman")
```

---

## Q: What about backups?

**A:** Automated daily backups with 7-day retention

See `.infra/backup-postgres.sh`:
- Daily pg_dump with gzip compression
- Stored in `/var/backups/cleo/`
- 7-day retention (old backups auto-deleted)
- Includes pgvector extension metadata
- Restore instructions in script

---

## Summary

✅ **PostgreSQL setup:** Phase 1 (NOW)
✅ **Database user:** mem0user (created automatically on first start)
✅ **Schema:** Auto-created by mem0 SDK
✅ **Storage:** PostgreSQL with pgvector for vector similarity search
✅ **Access:** mem0 API (port 8080) via SSH tunnel
✅ **Backups:** Daily automated backups with 7-day retention
✅ **Verification:** `.infra/verify-postgres.sh` script

**Next:** Deploy to VPS and verify everything works!
