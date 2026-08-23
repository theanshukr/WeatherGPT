"""
FastAPI endpoint tests for M3 Weather Data Service using starlette TestClient and respx.
Verifies the M2 interface contract and M4 context generation.
"""

import pytest
import respx
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


class TestHealthEndpoint:
    def test_health_check(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "m3-weather-data-service"


class TestWeatherEndpoints:
    @respx.mock
    def test_get_current_weather_endpoint_success(self, client, sample_open_meteo_forecast_raw):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            json=sample_open_meteo_forecast_raw,
        )

        response = client.get("/api/v1/weather/current?latitude=28.6139&longitude=77.2090&location_name=Delhi")
        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "success"
        assert data["source"] == "Open-Meteo"
        assert data["location"]["name"] == "Delhi"
        assert data["current"]["temperature_c"] == 31.2
        assert data["current"]["humidity_percent"] == 78
        assert data["current"]["weather_description"] == "Mainly clear"

    def test_get_current_weather_invalid_lat(self, client):
        response = client.get("/api/v1/weather/current?latitude=999.0&longitude=77.2090")
        assert response.status_code == 422 or response.status_code == 400

    @respx.mock
    def test_get_forecast_endpoint_success(self, client, sample_open_meteo_forecast_raw):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            json=sample_open_meteo_forecast_raw,
        )

        response = client.get("/api/v1/weather/forecast?latitude=28.6139&longitude=77.2090&forecast_days=7")
        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "success"
        assert len(data["forecast_daily"]) == 2
        assert data["forecast_daily"][0]["temp_max_c"] == 36.2

    @respx.mock
    def test_get_historical_endpoint_success(self, client, sample_open_meteo_archive_raw):
        respx.get(settings.OPEN_METEO_ARCHIVE_URL).respond(
            status_code=200,
            json=sample_open_meteo_archive_raw,
        )

        response = client.get(
            "/api/v1/weather/historical?latitude=28.6139&longitude=77.2090&start_date=2023-01-01&end_date=2023-01-02"
        )
        assert response.status_code == 200
        data = response.json()

        assert data["status"] == "success"
        assert len(data["historical_daily"]) == 2
        assert data["historical_daily"][0]["temp_max_c"] == 18.5

    @respx.mock
    def test_get_m4_context_endpoint_success(self, client, sample_open_meteo_forecast_raw):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            json=sample_open_meteo_forecast_raw,
        )

        response = client.get("/api/v1/weather/m4-context?latitude=28.6139&longitude=77.2090&location_name=Delhi, India")
        assert response.status_code == 200
        data = response.json()

        assert data["location"] == "Delhi, India"
        assert data["temperature_c"] == 31.2
        assert data["condition"] == "Mainly clear"
        assert data["humidity_pct"] == 78
        assert data["wind_direction"] == "S"
        assert data["source"] == "Open-Meteo / WMO"
        assert "forecast_24h" in data

    @respx.mock
    def test_geocode_endpoint_success(self, client, sample_open_meteo_geocoding_raw):
        respx.get(settings.OPEN_METEO_GEOCODING_URL).respond(
            status_code=200,
            json=sample_open_meteo_geocoding_raw,
        )

        response = client.get("/api/v1/weather/geocode?query=Delhi&count=2")
        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)
        assert len(data) == 2
        assert data[0]["name"] == "Delhi"
        assert data[0]["latitude"] == 28.65195
