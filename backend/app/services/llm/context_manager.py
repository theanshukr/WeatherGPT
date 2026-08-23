import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
from app.core.redis import redis_manager

logger = logging.getLogger(__name__)


class LocationContext(BaseModel):
    name: str
    latitude: float
    longitude: float


class SessionContext(BaseModel):
    session_id: str
    active_location: Optional[LocationContext] = None
    persona: str = "general"
    language: str = "en"
    recent_intent: Optional[str] = None
    secondary_intents: List[str] = []
    recent_time_reference: str = "current"
    conversation_summary: Optional[str] = None
    history: List[Dict[str, str]] = []  # [{"role": "user"|"ai", "text": "...", "timestamp": "..."}]
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())


class ContextManager:
    """
    Hybrid Session & Conversation Context Manager.
    Uses Redis for fast distributed session state with local memory fallback.
    Optimized for single-roundtrip batched turn persistence.
    """

    def __init__(self, ttl_seconds: int = 86400):
        self.ttl_seconds = ttl_seconds
        self._local_cache: Dict[str, SessionContext] = {}

    def _redis_key(self, session_id: str) -> str:
        return f"weathergpt:session:{session_id}"

    async def get_context(self, session_id: str) -> SessionContext:
        """Fetch active session context from local cache, Redis, or create new."""
        # 1. Fast local cache check
        if session_id in self._local_cache:
            return self._local_cache[session_id]

        # 2. Try Redis
        try:
            cached_data = await redis_manager.get(self._redis_key(session_id))
            if cached_data:
                parsed = json.loads(cached_data)
                ctx = SessionContext(**parsed)
                self._local_cache[session_id] = ctx
                return ctx
        except Exception as e:
            logger.debug(f"Redis get_context fallback for session {session_id}: {e}")

        # 3. Initialize fresh context
        new_ctx = SessionContext(session_id=session_id)
        self._local_cache[session_id] = new_ctx
        return new_ctx

    async def record_turn(
        self,
        session_id: str,
        user_message: str,
        ai_response: str,
        active_location: Optional[Dict[str, Any]] = None,
        persona: Optional[str] = None,
        language: Optional[str] = None,
        recent_intent: Optional[str] = None,
        secondary_intents: Optional[List[str]] = None,
        recent_time_reference: Optional[str] = None,
        conversation_summary: Optional[str] = None,
        max_history: int = 10,
    ) -> SessionContext:
        """
        Batched single-roundtrip update: updates context fields and appends
        both user and AI messages in memory, persisting to Redis with exactly
        one atomic SET call instead of 3 separate round-trips per chat turn.
        """
        ctx = await self.get_context(session_id)

        if active_location:
            ctx.active_location = LocationContext(**active_location)
        if persona:
            ctx.persona = persona.lower()
        if language:
            ctx.language = language
        if recent_intent:
            ctx.recent_intent = recent_intent
        if secondary_intents is not None:
            ctx.secondary_intents = secondary_intents
        if recent_time_reference:
            ctx.recent_time_reference = recent_time_reference
        if conversation_summary:
            ctx.conversation_summary = conversation_summary

        now_iso = datetime.utcnow().isoformat()
        ctx.updated_at = now_iso
        ctx.history.append({"role": "user", "text": user_message, "timestamp": now_iso})
        ctx.history.append({"role": "ai", "text": ai_response, "timestamp": now_iso})

        if len(ctx.history) > max_history:
            ctx.history = ctx.history[-max_history:]

        self._local_cache[session_id] = ctx

        # Exactly 1 Redis write for the whole turn
        try:
            payload = ctx.model_dump_json()
            await redis_manager.set(self._redis_key(session_id), payload, expire=self.ttl_seconds)
        except Exception as e:
            logger.debug(f"Redis record_turn fallback for session {session_id}: {e}")

        return ctx

    async def update_context(
        self,
        session_id: str,
        active_location: Optional[Dict[str, Any]] = None,
        persona: Optional[str] = None,
        language: Optional[str] = None,
        recent_intent: Optional[str] = None,
        secondary_intents: Optional[List[str]] = None,
        recent_time_reference: Optional[str] = None,
        conversation_summary: Optional[str] = None,
    ) -> SessionContext:
        """Update context fields and persist to Redis and local cache."""
        ctx = await self.get_context(session_id)

        if active_location:
            ctx.active_location = LocationContext(**active_location)
        if persona:
            ctx.persona = persona.lower()
        if language:
            ctx.language = language
        if recent_intent:
            ctx.recent_intent = recent_intent
        if secondary_intents is not None:
            ctx.secondary_intents = secondary_intents
        if recent_time_reference:
            ctx.recent_time_reference = recent_time_reference
        if conversation_summary:
            ctx.conversation_summary = conversation_summary

        ctx.updated_at = datetime.utcnow().isoformat()
        self._local_cache[session_id] = ctx

        # Save to Redis
        try:
            payload = ctx.model_dump_json()
            await redis_manager.set(self._redis_key(session_id), payload, expire=self.ttl_seconds)
        except Exception as e:
            logger.debug(f"Redis save_context fallback for session {session_id}: {e}")

        return ctx

    async def append_message(self, session_id: str, role: str, text: str, max_history: int = 10):
        """Append turn to recent conversation history (retains last N turns)."""
        ctx = await self.get_context(session_id)
        ctx.history.append({
            "role": role,
            "text": text,
            "timestamp": datetime.utcnow().isoformat(),
        })
        if len(ctx.history) > max_history:
            ctx.history = ctx.history[-max_history:]

        self._local_cache[session_id] = ctx
        try:
            payload = ctx.model_dump_json()
            await redis_manager.set(self._redis_key(session_id), payload, expire=self.ttl_seconds)
        except Exception as e:
            logger.debug(f"Redis append_message error: {e}")

    async def clear_context(self, session_id: str) -> bool:
        """Clear active session context."""
        self._local_cache.pop(session_id, None)
        try:
            await redis_manager.delete(self._redis_key(session_id))
            return True
        except Exception as e:
            logger.debug(f"Redis clear_context error: {e}")
            return True


context_manager = ContextManager()
