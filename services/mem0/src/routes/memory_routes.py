"""
API route definitions for memory operations.

Single Responsibility: Define HTTP endpoints and request/response handling.
Dependency Injection: Receives service instance.
"""
from fastapi import APIRouter, HTTPException, Query, Header
from typing import Optional
from ..services.memory_service import MemoryService
from ..models.memory import (
    MemoryInput,
    MemoryUpdate,
    MemorySearchResponse,
    HealthResponse
)
from ..middleware.auth import verify_api_key


def create_memory_router(get_service, get_client) -> APIRouter:
    """
    Create memory API router with dependency injection.

    Args:
        get_service: Callable that returns MemoryService instance
        get_client: Callable that returns mem0 client instance

    Returns:
        APIRouter: Configured router
    """
    router = APIRouter()

    @router.get("/", tags=["info"])
    async def root():
        """Root endpoint with API documentation link."""
        client = get_client()
        return {
            "service": "Cleo mem0 API",
            "version": "1.0.0",
            "docs": "/docs",
            "health": "/health",
            "status": "healthy" if client else "degraded"
        }

    @router.get("/health", response_model=HealthResponse, tags=["info"])
    async def health():
        """Health check endpoint for Docker and monitoring."""
        client = get_client()
        if client is None:
            return HealthResponse(
                status="degraded",
                service="mem0",
                error="mem0 client not initialized"
            )
        return HealthResponse(status="healthy", service="mem0")

    @router.post("/memories", tags=["memories"])
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

        if get_client() is None:
            raise HTTPException(status_code=503, detail="mem0 not initialized")

        try:
            return get_service().add_memory(memory)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.get("/memories", response_model=MemorySearchResponse, tags=["memories"])
    async def search_memories(
        query: str = Query(..., description="Search query"),
        user_id: str = Query("aman", description="User ID for namespace"),
        limit: int = Query(10, ge=1, le=100, description="Max results to return"),
        x_api_key: str = Header(None, alias="X-API-Key")
    ):
        """
        Search memories by semantic similarity.

        Uses pgvector for efficient vector search.
        """
        if x_api_key:
            verify_api_key(x_api_key)

        if get_client() is None:
            raise HTTPException(status_code=503, detail="mem0 not initialized")

        try:
            return get_service().search_memories(query, user_id, limit)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.get("/memories/all", tags=["memories"])
    async def get_all_memories(
        user_id: str = Query("aman", description="User ID for namespace"),
        x_api_key: str = Header(None, alias="X-API-Key")
    ):
        """Get all memories for a user."""
        if x_api_key:
            verify_api_key(x_api_key)

        if get_client() is None:
            raise HTTPException(status_code=503, detail="mem0 not initialized")

        try:
            return get_service().get_all_memories(user_id)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.put("/memories/{memory_id}", tags=["memories"])
    async def update_memory(
        memory_id: str,
        memory: MemoryUpdate,
        x_api_key: str = Header(None, alias="X-API-Key")
    ):
        """Update an existing memory."""
        if x_api_key:
            verify_api_key(x_api_key)

        if get_client() is None:
            raise HTTPException(status_code=503, detail="mem0 not initialized")

        try:
            return get_service().update_memory(memory_id, memory)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @router.delete("/memories/{memory_id}", tags=["memories"])
    async def delete_memory(
        memory_id: str,
        x_api_key: str = Header(None, alias="X-API-Key")
    ):
        """Delete a memory by ID."""
        if x_api_key:
            verify_api_key(x_api_key)

        if get_client() is None:
            raise HTTPException(status_code=503, detail="mem0 not initialized")

        try:
            return get_service().delete_memory(memory_id)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    return router
