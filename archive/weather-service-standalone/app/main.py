"""
M3 Weather Service - FastAPI Main Application & M2 APIRouter
Exposes standardized weather integration endpoints for M2 (Backend) and M4 (AI/LLM).
"""

from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI, APIRouter, Query, HTTPException, status, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .models import (
    M2WeatherResponse,
    M4WeatherContext,
    GeocodingResult,
    WeatherServiceError,
)
from .validator import ValidationError, WeatherDataValidator
from .weather_api import OpenMeteoClient, WeatherApiError

# Global reusable async client for connection pooling
http_client: Optional[httpx.AsyncClient] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(timeout=httpx.Timeout(settings.REQUEST_TIMEOUT_SECONDS))
    yield
    if http_client and not http_client.is_closed:
        await http_client.aclose()


# Dependency injection for OpenMeteoClient
def get_weather_client() -> OpenMeteoClient:
    return OpenMeteoClient(client=http_client)


# =====================================================================
# M3 APIRouter (Can be imported & mounted directly by M2 FastAPI backend)
# =====================================================================
router = APIRouter(prefix="/api/v1/weather", tags=["M3 Weather Data Service"])


@router.get(
    "/current",
    response_model=M2WeatherResponse,
    summary="Get current standardized weather observations",
    description="Retrieves and normalizes real-time weather observations from Open-Meteo for given coordinates.",
    responses={
        400: {"model": WeatherServiceError, "description": "Invalid coordinates or parameters"},
        502: {"model": WeatherServiceError, "description": "Upstream meteorological service error"},
        504: {"model": WeatherServiceError, "description": "Upstream timeout"},
    },
)
async def get_current_weather(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude in decimal degrees WGS84"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude in decimal degrees WGS84"),
    location_name: Optional[str] = Query(None, description="Optional human-readable location name"),
    client: OpenMeteoClient = Depends(get_weather_client),
):
    try:
        return await client.get_current_weather(latitude=latitude, longitude=longitude, location_name=location_name)
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )
    except WeatherApiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )


@router.get(
    "/forecast",
    response_model=M2WeatherResponse,
    summary="Get hourly and daily weather forecast",
    description="Retrieves multi-day forecast with hourly intervals and daily summaries from Open-Meteo.",
    responses={
        400: {"model": WeatherServiceError},
        502: {"model": WeatherServiceError},
    },
)
async def get_forecast(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude WGS84"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude WGS84"),
    forecast_days: int = Query(7, ge=1, le=16, description="Number of forecast days (1-16)"),
    location_name: Optional[str] = Query(None, description="Optional location name"),
    client: OpenMeteoClient = Depends(get_weather_client),
):
    try:
        return await client.get_forecast(
            latitude=latitude,
            longitude=longitude,
            forecast_days=forecast_days,
            location_name=location_name,
        )
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )
    except WeatherApiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )


@router.get(
    "/historical",
    response_model=M2WeatherResponse,
    summary="Get historical weather data archive",
    description="Retrieves verified historical weather observations from the Open-Meteo Historical Archive (1940-present).",
    responses={
        400: {"model": WeatherServiceError},
        502: {"model": WeatherServiceError},
    },
)
async def get_historical_weather(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude WGS84"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude WGS84"),
    start_date: str = Query(..., description="Start date in YYYY-MM-DD format"),
    end_date: str = Query(..., description="End date in YYYY-MM-DD format"),
    location_name: Optional[str] = Query(None, description="Optional location name"),
    client: OpenMeteoClient = Depends(get_weather_client),
):
    try:
        return await client.get_historical_weather(
            latitude=latitude,
            longitude=longitude,
            start_date=start_date,
            end_date=end_date,
            location_name=location_name,
        )
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )
    except WeatherApiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )


@router.get(
    "/m4-context",
    response_model=M4WeatherContext,
    summary="Get compact factual weather payload for M4 LLM prompt injection",
    description="Provides ultra-compact, verified meteorological facts specifically formatted to minimize tokens and prevent AI hallucination.",
    responses={
        400: {"model": WeatherServiceError},
        502: {"model": WeatherServiceError},
    },
)
async def get_m4_context(
    latitude: float = Query(..., ge=-90.0, le=90.0, description="Latitude WGS84"),
    longitude: float = Query(..., ge=-180.0, le=180.0, description="Longitude WGS84"),
    location_name: Optional[str] = Query(None, description="Optional location name"),
    client: OpenMeteoClient = Depends(get_weather_client),
):
    try:
        return await client.get_m4_context(latitude=latitude, longitude=longitude, location_name=location_name)
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )
    except WeatherApiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )


@router.get(
    "/geocode",
    response_model=List[GeocodingResult],
    summary="Search location coordinates via Open-Meteo Geocoding",
    description="Resolves geographic name queries into latitude, longitude, country, and administrative units.",
    responses={
        400: {"model": WeatherServiceError},
        502: {"model": WeatherServiceError},
    },
)
async def geocode_location(
    query: str = Query(..., min_length=1, description="Location name query (e.g. 'Delhi', 'Tokyo')"),
    count: int = Query(5, ge=1, le=20, description="Max candidate results to return"),
    client: OpenMeteoClient = Depends(get_weather_client),
):
    try:
        return await client.geocode_location(query=query, count=count)
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )
    except WeatherApiError as e:
        raise HTTPException(
            status_code=e.status_code,
            detail={"error_code": e.error_code, "message": e.message, "details": e.details},
        )


# =====================================================================
# Standalone FastAPI App Instance
# =====================================================================
app = FastAPI(
    title="M3 Meteorological Weather Data Integration Service",
    description=(
        "Standardized meteorological telemetry and forecast integration service for conversational weather AI. "
        "Strictly powered by Open-Meteo, WMO WIS2.0, and OGC standards."
    ),
    version=settings.SERVICE_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS Middleware for local M1 / M2 development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Weather Router
app.include_router(router)


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check probe endpoint."""
    return {
        "status": "healthy",
        "service": settings.SERVICE_NAME,
        "version": settings.SERVICE_VERSION,
        "environment": settings.ENVIRONMENT,
        "upstream_sources": {
            "forecast_api": settings.OPEN_METEO_FORECAST_URL,
            "archive_api": settings.OPEN_METEO_ARCHIVE_URL,
            "geocoding_api": settings.OPEN_METEO_GEOCODING_URL,
        }
    }
