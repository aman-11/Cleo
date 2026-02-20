"""
mem0 Configuration - 100% FREE models + Qdrant as PRIMARY vector store.

Per Phase 1.5 decisions:
- Qdrant is now the primary vector store (not pgvector)
- 100% FREE models via LiteLLM + OpenRouter + Hugging Face
- $0/month guaranteed API cost

PostgreSQL will be repurposed for structured data in future phases.
"""
import os
from typing import Dict, Any


def validate_free_model(model: str) -> None:
    """Ensure model is free to prevent accidental charges."""
    if not model.endswith(":free") and model != "openrouter/free":
        raise ValueError(
            f"Model '{model}' is not free! "
            "Use ':free' suffix (e.g., 'openrouter/google/gemini-2.0-flash-exp:free') "
            "or 'openrouter/free' router."
        )


# Embedding dimensions - MUST match model
EMBEDDING_DIMS = {
    "sentence-transformers/all-MiniLM-L6-v2": 384,
    "sentence-transformers/all-mpnet-base-v2": 768,
    "BAAI/bge-small-en-v1.5": 384,
}


def get_mem0_config() -> Dict[str, Any]:
    """
    Build mem0 configuration with 100% FREE models.

    Cost: $0/month guaranteed
    - LLM: OpenRouter free tier via LiteLLM (gemini-2.0-flash-exp:free)
    - Embeddings: Hugging Face sentence-transformers (all-MiniLM-L6-v2)
    - Vector Store: Qdrant (self-hosted)
    """
    # LLM: OpenRouter free tier via LiteLLM
    llm_model = os.getenv(
        "MEM0_LLM_MODEL",
        "openrouter/google/gemini-2.0-flash-exp:free"  # 1M context, FREE
    )
    validate_free_model(llm_model)

    # Embeddings: Hugging Face sentence-transformers (FREE)
    embedding_model = os.getenv(
        "MEM0_EMBEDDING_MODEL",
        "sentence-transformers/all-MiniLM-L6-v2"  # 384 dims, FREE via HF Inference API
    )
    embedding_dims = EMBEDDING_DIMS.get(embedding_model, 384)

    return {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "url": os.getenv("QDRANT_URL", "http://qdrant:6333"),
                "api_key": os.getenv("QDRANT_API_KEY"),
                "collection_name": os.getenv("QDRANT_COLLECTION", "cleo_memories"),
                "embedding_model_dims": embedding_dims,  # 384 for all-MiniLM-L6-v2
            }
        },
        "llm": {
            "provider": "litellm",
            "config": {
                "model": llm_model,
                "temperature": 0.1,
                "max_tokens": 2000,
                "api_base": "https://openrouter.ai/api/v1",
                "api_key": os.getenv("OPENROUTER_API_KEY"),
            }
        },
        "embedder": {
            "provider": "huggingface",
            "config": {
                "model": embedding_model,
                # Uses HF Inference API by default (FREE tier)
                # Optionally set huggingface_base_url for local TEI deployment
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
