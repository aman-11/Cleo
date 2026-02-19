"""
Business logic layer for memory operations.

Single Responsibility: Handle memory business logic and validation.
Dependency Injection: Receives repository, doesn't create it.
Open/Closed: Can extend with new business logic without modifying repository.
"""
from typing import List, Dict, Any, Optional
from ..repositories.memory_repository import MemoryRepository
from ..models.memory import MemoryInput, MemoryUpdate, MemorySearchResponse


class MemoryService:
    """
    Service layer for memory operations.

    This class implements business logic and validation, delegating
    data access to the repository layer.
    """

    def __init__(self, repository: MemoryRepository):
        """
        Initialize service with repository.

        Args:
            repository: MemoryRepository instance
        """
        self.repository = repository

    def add_memory(self, memory: MemoryInput) -> Dict[str, Any]:
        """
        Add a memory with validation.

        Args:
            memory: MemoryInput model

        Returns:
            dict: Operation result
        """
        # Business logic: ensure content is not empty
        if not memory.content.strip():
            raise ValueError("Memory content cannot be empty")

        result = self.repository.add(
            content=memory.content,
            user_id=memory.user_id,
            metadata=memory.metadata
        )
        return {"status": "success", "result": result}

    def search_memories(
        self,
        query: str,
        user_id: str = "aman",
        limit: int = 10
    ) -> MemorySearchResponse:
        """
        Search memories with validation.

        Args:
            query: Search query
            user_id: User namespace
            limit: Result limit

        Returns:
            MemorySearchResponse: Search results with metadata
        """
        # Business logic: validate query and limit
        if not query.strip():
            raise ValueError("Search query cannot be empty")
        if limit < 1 or limit > 100:
            raise ValueError("Limit must be between 1 and 100")

        results = self.repository.search(
            query=query,
            user_id=user_id,
            limit=limit
        )

        return MemorySearchResponse(
            results=results,
            query=query,
            count=len(results)
        )

    def get_all_memories(self, user_id: str = "aman") -> Dict[str, Any]:
        """
        Get all memories for a user.

        Args:
            user_id: User namespace

        Returns:
            dict: All memories with count
        """
        results = self.repository.get_all(user_id=user_id)
        return {"memories": results, "count": len(results)}

    def update_memory(
        self,
        memory_id: str,
        memory: MemoryUpdate
    ) -> Dict[str, Any]:
        """
        Update a memory with validation.

        Args:
            memory_id: Memory ID to update
            memory: MemoryUpdate model

        Returns:
            dict: Update result
        """
        # Business logic: ensure content is not empty
        if not memory.content.strip():
            raise ValueError("Memory content cannot be empty")

        result = self.repository.update(memory_id, memory.content)
        return {"status": "success", "result": result}

    def delete_memory(self, memory_id: str) -> Dict[str, Any]:
        """
        Delete a memory.

        Args:
            memory_id: Memory ID to delete

        Returns:
            dict: Deletion confirmation
        """
        self.repository.delete(memory_id)
        return {"status": "success", "deleted": memory_id}
