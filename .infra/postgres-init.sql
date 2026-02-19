-- PostgreSQL initialization for Cleo mem0 storage
-- This script runs automatically when the postgres container first starts

-- Enable pgvector extension (required for vector similarity search)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create dedicated mem0 user (not superuser - principle of least privilege)
-- Password will be set via environment variable POSTGRES_PASSWORD
-- Note: We reuse POSTGRES_PASSWORD for both postgres and mem0user for simplicity
-- In production, you'd want separate passwords
DO
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'mem0user') THEN
        CREATE USER mem0user WITH PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
$$;

-- Grant mem0user all privileges on mem0 database
GRANT ALL PRIVILEGES ON DATABASE mem0 TO mem0user;

-- Connect to mem0 database for schema setup
\c mem0

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO mem0user;

-- Ensure mem0user can create tables and use sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO mem0user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO mem0user;

-- Create mem0 schema (mem0 SDK will create tables here automatically)
-- mem0 SDK creates these tables:
--   - memories: stores memory content, embeddings, metadata
--   - collections: organizes memories into collections
--
-- We don't create them manually - mem0 SDK handles this.
-- This script just ensures:
--   1. pgvector extension is enabled
--   2. mem0user has proper permissions
--   3. Database is ready for mem0 SDK initialization

-- Verify setup
SELECT
    'PostgreSQL initialized for mem0' as status,
    version() as pg_version,
    (SELECT extversion FROM pg_extension WHERE extname = 'vector') as pgvector_version;
