"""
Data models for memory operations.

Single Responsibility: Define data transfer objects for API requests/responses.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel


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


class HealthResponse(BaseModel):
    """Response model for health check."""
    status: str
    service: str
    error: Optional[str] = None
