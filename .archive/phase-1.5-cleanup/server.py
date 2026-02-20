"""
mem0 API Server - Full integration with PostgreSQL/pgvector backend.

This server exposes mem0 SDK via REST API for both VPS Cleo and aman's
local Claude Code sessions (via SSH tunnel).
"""
import os
import logging
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Header
from pydantic import BaseModel
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# mem0 configuration - will be initialized on startup
mem0_client = None

class MemoryInput(BaseModel):
    """Input model for adding a memory."""
    content: str
    user_id: str = "aman"
    metadata: Optional[Dict[str, Any]] = None

class MemoryUpdate(BaseModel):
    """Input model for updating a memory."""
    content: str
    metadata: Optional[Dict[str, Any]] = None

class MemorySearchResponse(BaseModel):
    """Response model for memory search."""
    results: List[Dict[str, Any]]
    query: str
    count: int

def get_mem0_config() -> dict:
    """Build mem0 configuration from environment variables."""
    return {
        "vector_store": {
            "provider": "pgvector",
            "config": {
                "user": os.getenv("POSTGRES_USER", "postgres"),
                "password": os.getenv("POSTGRES_PASSWORD"),
                "host": os.getenv("POSTGRES_HOST", "postgres"),
                "port": int(os.getenv("POSTGRES_PORT", "5432")),
                "dbname": os.getenv("POSTGRES_DB", "mem0"),
                "collection_name": "cleo_memories",
                "embedding_model_dims": 1536,  # OpenAI ada-002 dimensions
            }
        },
        "llm": {
            "provider": "openai",
            "config": {
                "model": "gpt-4o-mini",  # Cheap model for memory operations
                "temperature": 0.1,
            }
        },
        "embedder": {
            "provider": "openai",
            "config": {
                "model": "text-embedding-3-small",
            }
        }
    }

def verify_api_key(api_key: str = Header(..., alias="X-API-Key")) -> bool:
    """Verify the API key matches the configured key."""
    expected_key = os.getenv("MEM0_API_KEY")
    if not expected_key:
        logger.warning("MEM0_API_KEY not configured, allowing all requests")
        return True
    if api_key != expected_key:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return True

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize mem0 on startup."""
    global mem0_client
    try:
        from mem0 import Memory
        config = get_mem0_config()
        logger.info("Initializing mem0 with pgvector backend...")
        mem0_client = Memory.from_config(config)
        logger.info("mem0 initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize mem0: {e}")
        # Continue running - health check will report degraded state
    yield
    logger.info("Shutting down mem0 server")

app = FastAPI(
    title="Cleo mem0 API",
    version="1.0.0",
    description="Shared brain for Cleo and aman's local Claude Code sessions",
    lifespan=lifespan
)

@app.get("/health")
async def health():
    """Health check endpoint for Docker and monitoring."""
    if mem0_client is None:
        return {
            "status": "degraded",
            "service": "mem0",
            "error": "mem0 client not initialized"
        }
    return {"status": "healthy", "service": "mem0"}

@app.post("/memories")
async def add_memory(
    memory: MemoryInput,
    x_api_key: str = Header(None, alias="X-API-Key")
):
    """
    Add a memory to mem0.

    Memories are stored with user_id for namespace separation (single tenant: aman only).
    """
    if x_api_key:
        verify_api_key(x_api_key)

    if mem0_client is None:
        raise HTTPException(status_code=503, detail="mem0 not initialized")

    try:
        result = mem0_client.add(
            memory.content,
            user_id=memory.user_id,
            metadata=memory.metadata or {}
        )
        logger.info(f"Added memory for user {memory.user_id}")
        return {"status": "success", "result": result}
    except Exception as e:
        logger.error(f"Failed to add memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/memories")
async def search_memories(
    query: str = Query(..., description="Search query"),
    user_id: str = Query("aman", description="User ID for namespace"),
    limit: int = Query(10, ge=1, le=100, description="Max results to return"),
    x_api_key: str = Header(None, alias="X-API-Key")
) -> MemorySearchResponse:
    """
    Search memories by semantic similarity.

    Uses pgvector for efficient vector search.
    """
    if x_api_key:
        verify_api_key(x_api_key)

    if mem0_client is None:
        raise HTTPException(status_code=503, detail="mem0 not initialized")

    try:
        results = mem0_client.search(
            query=query,
            user_id=user_id,
            limit=limit
        )
        logger.info(f"Search for '{query}' returned {len(results)} results")
        return MemorySearchResponse(
            results=results,
            query=query,
            count=len(results)
        )
    except Exception as e:
        logger.error(f"Failed to search memories: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/memories/all")
async def get_all_memories(
    user_id: str = Query("aman", description="User ID for namespace"),
    x_api_key: str = Header(None, alias="X-API-Key")
):
    """Get all memories for a user."""
    if x_api_key:
        verify_api_key(x_api_key)

    if mem0_client is None:
        raise HTTPException(status_code=503, detail="mem0 not initialized")

    try:
        results = mem0_client.get_all(user_id=user_id)
        return {"memories": results, "count": len(results)}
    except Exception as e:
        logger.error(f"Failed to get all memories: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/memories/{memory_id}")
async def update_memory(
    memory_id: str,
    memory: MemoryUpdate,
    x_api_key: str = Header(None, alias="X-API-Key")
):
    """Update an existing memory."""
    if x_api_key:
        verify_api_key(x_api_key)

    if mem0_client is None:
        raise HTTPException(status_code=503, detail="mem0 not initialized")

    try:
        result = mem0_client.update(memory_id, memory.content)
        logger.info(f"Updated memory {memory_id}")
        return {"status": "success", "result": result}
    except Exception as e:
        logger.error(f"Failed to update memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/memories/{memory_id}")
async def delete_memory(
    memory_id: str,
    x_api_key: str = Header(None, alias="X-API-Key")
):
    """Delete a memory by ID."""
    if x_api_key:
        verify_api_key(x_api_key)

    if mem0_client is None:
        raise HTTPException(status_code=503, detail="mem0 not initialized")

    try:
        mem0_client.delete(memory_id)
        logger.info(f"Deleted memory {memory_id}")
        return {"status": "success", "deleted": memory_id}
    except Exception as e:
        logger.error(f"Failed to delete memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    """Root endpoint with API documentation link."""
    return {
        "service": "Cleo mem0 API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "status": "healthy" if mem0_client else "degraded"
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    uvicorn.run(app, host="0.0.0.0", port=port)
