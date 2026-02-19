"""
Repository layer for mem0 client operations.

Single Responsibility: Interface with mem0 SDK, abstract data access.
Dependency Injection: Receives mem0 client, doesn't create it.
"""
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class MemoryRepository:
    """
    Repository for memory CRUD operations.

    This class follows Repository pattern - it abstracts the data source
    (mem0 client) from the business logic (services layer).
    """

    def __init__(self, mem0_client):
        """
        Initialize repository with mem0 client.

        Args:
            mem0_client: Initialized mem0.Memory instance
        """
        self.client = mem0_client

    def add(
        self,
        content: str,
        user_id: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Add a memory to mem0.

        Args:
            content: Memory content text
            user_id: User namespace
            metadata: Optional metadata dict

        Returns:
            dict: Result from mem0.add()

        Raises:
            Exception: If mem0 add operation fails
        """
        try:
            result = self.client.add(
                content,
                user_id=user_id,
                metadata=metadata or {}
            )
            logger.info(f"Added memory for user {user_id}")
            return result
        except Exception as e:
            logger.error(f"Failed to add memory: {e}")
            raise

    def search(
        self,
        query: str,
        user_id: str,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Search memories by semantic similarity.

        Args:
            query: Search query text
            user_id: User namespace
            limit: Maximum results to return

        Returns:
            list: List of matching memory dicts

        Raises:
            Exception: If mem0 search operation fails
        """
        try:
            results = self.client.search(
                query=query,
                user_id=user_id,
                limit=limit
            )
            logger.info(f"Search for '{query}' returned {len(results)} results")
            return results
        except Exception as e:
            logger.error(f"Failed to search memories: {e}")
            raise

    def get_all(self, user_id: str) -> List[Dict[str, Any]]:
        """
        Get all memories for a user.

        Args:
            user_id: User namespace

        Returns:
            list: List of all memory dicts

        Raises:
            Exception: If mem0 get_all operation fails
        """
        try:
            results = self.client.get_all(user_id=user_id)
            return results
        except Exception as e:
            logger.error(f"Failed to get all memories: {e}")
            raise

    def update(self, memory_id: str, content: str) -> Dict[str, Any]:
        """
        Update an existing memory.

        Args:
            memory_id: Memory ID to update
            content: New content

        Returns:
            dict: Update result

        Raises:
            Exception: If mem0 update operation fails
        """
        try:
            result = self.client.update(memory_id, content)
            logger.info(f"Updated memory {memory_id}")
            return result
        except Exception as e:
            logger.error(f"Failed to update memory: {e}")
            raise

    def delete(self, memory_id: str) -> None:
        """
        Delete a memory by ID.

        Args:
            memory_id: Memory ID to delete

        Raises:
            Exception: If mem0 delete operation fails
        """
        try:
            self.client.delete(memory_id)
            logger.info(f"Deleted memory {memory_id}")
        except Exception as e:
            logger.error(f"Failed to delete memory: {e}")
            raise
