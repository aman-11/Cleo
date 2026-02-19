"""
Authentication middleware.

Single Responsibility: Handle API key verification.
"""
import logging
from fastapi import HTTPException, Header
from ..config.mem0_config import get_api_key

logger = logging.getLogger(__name__)


def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")) -> bool:
    """
    Verify the API key matches the configured key.

    Args:
        x_api_key: API key from request header

    Returns:
        bool: True if verified

    Raises:
        HTTPException: If API key is invalid
    """
    expected_key = get_api_key()

    if not expected_key:
        logger.warning("MEM0_API_KEY not configured, allowing all requests")
        return True

    if x_api_key != expected_key:
        raise HTTPException(status_code=401, detail="Invalid API key")

    return True
