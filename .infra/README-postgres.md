# PostgreSQL Setup for Cleo mem0

## Architecture

```
PostgreSQL (pgvector/pgvector:pg16)
  ↓
  pgvector extension enabled
  ↓
  Database: mem0
  ↓
  User: mem0user (dedicated, least privilege)
  ↓
  mem0 SDK auto-creates tables:
    - memories (content, embeddings, metadata)
    - collections (memory organization)
```

## Initialization Flow

1. **Container starts** → PostgreSQL runs `.infra/postgres-init.sql`
2. **Init script**:
   - Enables `pgvector` extension
   - Creates `mem0user` with password from `POSTGRES_PASSWORD`
   - Grants privileges on `mem0` database
3. **mem0 service starts** → connects as `mem0user`
4. **mem0 SDK initializes** → auto-creates tables on first connection

## Schema

mem0 SDK automatically creates:

### `memories` table
- `id` - UUID primary key
- `content` - Memory text content
- `embedding` - Vector embedding (384 dimensions for HuggingFace all-MiniLM-L6-v2)
- `user_id` - User namespace (always "aman" for single-tenant)
- `metadata` - JSONB metadata
- `created_at` - Timestamp
- `updated_at` - Timestamp

### `collections` table
- `id` - UUID primary key
- `name` - Collection name (e.g., "cleo_memories")
- `config` - JSONB configuration
- `created_at` - Timestamp

### Indexes
mem0 SDK creates:
- Vector similarity index on `memories.embedding` (pgvector IVFFlat or HNSW)
- B-tree index on `memories.user_id`
- B-tree index on `memories.created_at`

## Security

- ✅ Dedicated `mem0user` (not postgres superuser)
- ✅ Least privilege (only `mem0` database access)
- ✅ Password from environment variable
- ✅ No hardcoded credentials

## Backup Strategy

See `.infra/backup-postgres.sh`:
- Daily pg_dump with gzip compression
- 7-day retention
- Includes pgvector extension in dump
- Restore command provided in backup script

## Verification

After deployment:

```bash
# Connect to container
docker exec -it cleo-postgres psql -U mem0user -d mem0

# Check pgvector extension
\dx

# Check mem0 tables (after mem0 SDK initializes)
\dt

# Check memory count
SELECT COUNT(*) FROM memories;

# Sample vector search (if memories exist)
SELECT content, metadata
FROM memories
ORDER BY embedding <-> (SELECT embedding FROM memories LIMIT 1)
LIMIT 5;
```

## Troubleshooting

**Issue**: mem0 can't connect
```bash
# Check postgres is healthy
docker exec cleo-postgres pg_isready -U mem0user -d mem0

# Check logs
docker logs cleo-postgres
docker logs cleo-mem0
```

**Issue**: pgvector not enabled
```bash
# Verify extension exists
docker exec cleo-postgres psql -U postgres -d mem0 -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

**Issue**: Permission denied for mem0user
```bash
# Re-grant permissions
docker exec cleo-postgres psql -U postgres -d mem0 -c "GRANT ALL PRIVILEGES ON DATABASE mem0 TO mem0user;"
```
