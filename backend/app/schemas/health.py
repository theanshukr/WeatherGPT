from typing import Optional
from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    project: str
    database: str
    redis: str
    llm_provider: str
    version: str = "1.0.0"
