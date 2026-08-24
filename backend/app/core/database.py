import logging
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.core.config import settings

logger = logging.getLogger(__name__)

Base = declarative_base()

try:
    db_url = settings.DATABASE_URL.strip() if settings.DATABASE_URL else ""
    engine = create_async_engine(
        db_url,
        echo=settings.DEBUG,
        future=True,
        pool_pre_ping=True,
        connect_args={"statement_cache_size": 0},
    )
    async_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
except Exception as e:
    logger.warning(f"Database engine initialization error: {e}")
    engine = None
    async_session_factory = None


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    if async_session_factory is None:
        yield None
        return

    async with async_session_factory() as session:
        try:
            yield session
        except Exception as e:
            await session.rollback()
            raise e
        finally:
            await session.close()


async def init_db():
    """Create database tables if engine is connected.

    Previously this called Base.metadata.create_all() without ever having
    imported app.models anywhere in the startup path, so no table classes
    were registered against Base and create_all() was a silent no-op —
    the README/architecture docs claimed Postgres persistence but nothing
    was ever actually written there (see COMPLETION_PLAN.md item #5). The
    import below is intentionally local (not at module top) to avoid a
    circular import, since app.models.* modules import Base from this
    file.
    """
    if engine is None:
        logger.warning("Database engine is not configured.")
        return

    try:
        import app.models  # noqa: F401 — registers User/ChatSession/ChatMessage/CachedWeather on Base
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables initialized successfully.")
    except Exception as e:
        logger.warning(f"Could not connect to PostgreSQL / PostGIS: {e}. Running in memory-only mode.")
