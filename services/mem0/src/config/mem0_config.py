"""
Configuration management for mem0 integration.

Single Responsibility: Build and provide mem0 configuration from environment.
"""
import os
from typing import Dict, Any


def get_mem0_config() -> Dict[str, Any]:
    """
    Build mem0 configuration from environment variables.

    Returns:
        dict: Complete mem0 configuration with vector store, LLM, and embedder settings
    """
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


def get_api_key() -> str | None:
    """
    Get the configured API key from environment.

    Returns:
        str | None: API key if configured, None otherwise
    """
    return os.getenv("MEM0_API_KEY")


def get_port() -> int:
    """
    Get the server port from environment.

    Returns:
        int: Port number (default: 8080)
    """
    return int(os.getenv("PORT", "8080"))
