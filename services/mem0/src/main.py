"""
Application entry point with dependency injection.

Composition Root: Wire up all dependencies here.
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
import uvicorn

from .config.mem0_config import get_mem0_config, get_port
from .repositories.memory_repository import MemoryRepository
from .services.memory_service import MemoryService
from .routes.memory_routes import create_memory_router
from .utils.logging_config import setup_logging

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

# Global state (initialized on startup)
mem0_client = None
memory_repository = None
memory_service = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Initialize dependencies on startup, cleanup on shutdown.

    This is the Composition Root - where all dependencies are wired together.
    """
    global mem0_client, memory_repository, memory_service

    try:
        # Initialize mem0 client
        from mem0 import Memory
        config = get_mem0_config()
        logger.info("Initializing mem0 with Qdrant backend (100% FREE models)...")
        mem0_client = Memory.from_config(config)
        logger.info("mem0 initialized successfully")

        # Wire up dependencies (Dependency Injection)
        memory_repository = MemoryRepository(mem0_client)
        memory_service = MemoryService(memory_repository)

    except Exception as e:
        logger.error(f"Failed to initialize mem0: {e}")
        # Continue running - health check will report degraded state

    yield

    logger.info("Shutting down mem0 server")


def get_mem0_client():
    """Get current mem0 client instance (avoids closure capture)."""
    return mem0_client


def get_memory_service():
    """Get current memory service instance (avoids closure capture)."""
    return memory_service


def create_app() -> FastAPI:
    """
    Application factory.

    Returns:
        FastAPI: Configured application instance
    """
    app = FastAPI(
        title="Cleo mem0 API",
        version="1.0.0",
        description="Shared brain for Cleo and aman's local Claude Code sessions",
        lifespan=lifespan
    )

    # Register routes (pass getter functions to avoid closure capture)
    memory_router = create_memory_router(get_memory_service, get_mem0_client)
    app.include_router(memory_router)

    return app


# Create app instance
app = create_app()


if __name__ == "__main__":
    port = get_port()
    uvicorn.run(app, host="0.0.0.0", port=port)
