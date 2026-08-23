from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.core.database import get_db
from app.core.redis import redis_manager
from app.core.config import settings
from app.schemas.health import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse, tags=["System"])
async def health_check(db: AsyncSession = Depends(get_db)):
    # Database status check
    db_status = "disconnected"
    if db is not None:
        try:
            await db.execute(text("SELECT 1"))
            db_status = "connected"
        except Exception:
            db_status = "error"

    # Redis status check
    redis_status = "disconnected"
    if redis_manager.client:
        try:
            pong = await redis_manager.client.ping()
            if pong:
                redis_status = "connected"
        except Exception:
            redis_status = "error"

    return HealthResponse(
        status="healthy",
        project=settings.PROJECT_NAME,
        database=db_status,
        redis=redis_status,
        llm_provider=settings.DEFAULT_LLM_PROVIDER,
        version="1.0.0",
    )
