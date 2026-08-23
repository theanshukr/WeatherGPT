import logging
from typing import Optional
import redis.asyncio as redis
from app.core.config import settings

logger = logging.getLogger(__name__)


class RedisManager:
    def __init__(self):
        self.client: Optional[redis.Redis] = None

    async def connect(self):
        try:
            self.client = redis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
            )
            await self.client.ping()
            logger.info("Connected to Redis successfully.")
        except Exception as e:
            logger.warning(f"Could not connect to Redis: {e}. Caching disabled.")
            self.client = None

    async def close(self):
        if self.client:
            await self.client.close()

    async def get(self, key: str) -> Optional[str]:
        if self.client:
            try:
                return await self.client.get(key)
            except Exception as e:
                logger.error(f"Redis get error: {e}")
        return None

    async def set(self, key: str, value: str, expire: int = 300) -> bool:
        if self.client:
            try:
                await self.client.set(key, value, ex=expire)
                return True
            except Exception as e:
                logger.error(f"Redis set error: {e}")
        return False

    async def delete(self, key: str) -> bool:
        if self.client:
            try:
                await self.client.delete(key)
                return True
            except Exception as e:
                logger.error(f"Redis delete error: {e}")
        return False

    async def exists(self, key: str) -> bool:
        if self.client:
            try:
                return bool(await self.client.exists(key))
            except Exception as e:
                logger.error(f"Redis exists error: {e}")
        return False


redis_manager = RedisManager()

