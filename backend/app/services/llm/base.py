from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
from app.schemas.chat import ChatMessageRequest, ChatMessageResponse


class BaseLLMService(ABC):
    @abstractmethod
    async def process_chat(self, request: ChatMessageRequest) -> ChatMessageResponse:
        """Process user message, execute tools if required, and return formatted response."""
        pass
