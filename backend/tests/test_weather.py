"""
Unit and integration tests for OpenMeteoClient using respx for HTTP mocking.
Tests API fetching, retry policies, error handling, rate limiting, and timeouts.
"""

import pytest
import respx
import httpx
from app.weather_api import OpenMeteoClient, WeatherApiError
from app.validator import ValidationError
from app.config import settings


@pytest.mark.asyncio
class TestOpenMeteoClient:
    @respx.mock
    async def test_get_current_weather_success(self, sample_open_meteo_forecast_raw):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            json=sample_open_meteo_forecast_raw,
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            result = await client.get_current_weather(28.6139, 77.2090, location_name="Delhi")

            assert result.status == "success"
            assert result.source == "Open-Meteo"
            assert result.location.name == "Delhi"
            assert result.current.temperature_c == 31.2
            assert result.current.weather_description == "Mainly clear"

    @respx.mock
    async def test_get_forecast_success(self, sample_open_meteo_forecast_raw):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            json=sample_open_meteo_forecast_raw,
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            result = await client.get_forecast(28.6139, 77.2090, forecast_days=7, location_name="Delhi")

            assert result.status == "success"
            assert len(result.forecast_hourly) == 4
            assert len(result.forecast_daily) == 2
            assert result.forecast_daily[0].temp_max_c == 36.2

    @respx.mock
    async def test_get_historical_weather_success(self, sample_open_meteo_archive_raw):
        respx.get(settings.OPEN_METEO_ARCHIVE_URL).respond(
            status_code=200,
            json=sample_open_meteo_archive_raw,
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            result = await client.get_historical_weather(
                28.6139, 77.2090, "2023-01-01", "2023-01-02", location_name="Delhi"
            )

            assert result.status == "success"
            assert len(result.historical_daily) == 2
            assert result.historical_daily[0].date == "2023-01-01"
            assert result.historical_daily[0].temp_max_c == 18.5

    @respx.mock
    async def test_geocode_location_success(self, sample_open_meteo_geocoding_raw):
        respx.get(settings.OPEN_METEO_GEOCODING_URL).respond(
            status_code=200,
            json=sample_open_meteo_geocoding_raw,
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            results = await client.geocode_location("Delhi", count=2)

            assert len(results) == 2
            assert results[0].name == "Delhi"
            assert results[0].country == "India"
            assert results[0].latitude == 28.65195

    @respx.mock
    async def test_api_400_bad_request(self):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=400,
            json={"error": True, "reason": "Invalid parameter timezone."},
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            with pytest.raises(WeatherApiError) as exc:
                await client.get_current_weather(28.6139, 77.2090)

            assert exc.value.status_code == 400
            assert exc.value.error_code == "BAD_REQUEST_PARAMETERS"

    @respx.mock
    async def test_api_429_rate_limit(self):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=429,
            text="Too Many Requests",
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            with pytest.raises(WeatherApiError) as exc:
                await client.get_current_weather(28.6139, 77.2090)

            assert exc.value.status_code == 429
            assert exc.value.error_code == "RATE_LIMIT_EXCEEDED"

    @respx.mock
    async def test_api_500_server_error_and_retry(self):
        # Respond with 500 for all retry attempts
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=500,
            text="Internal Server Error",
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            with pytest.raises(WeatherApiError) as exc:
                await client.get_current_weather(28.6139, 77.2090)

            assert exc.value.status_code == 502
            assert exc.value.error_code == "UPSTREAM_SERVER_ERROR"

    @respx.mock
    async def test_api_timeout(self):
        respx.get(settings.OPEN_METEO_FORECAST_URL).mock(
            side_effect=httpx.ConnectTimeout("Connection timed out")
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            with pytest.raises(WeatherApiError) as exc:
                await client.get_current_weather(28.6139, 77.2090)

            assert exc.value.status_code == 504
            assert exc.value.error_code == "UPSTREAM_TIMEOUT"

    @respx.mock
    async def test_malformed_json_response(self):
        respx.get(settings.OPEN_METEO_FORECAST_URL).respond(
            status_code=200,
            text="<html>Not JSON</html>",
            headers={"Content-Type": "text/html"},
        )

        async with httpx.AsyncClient() as http_client:
            client = OpenMeteoClient(client=http_client)
            with pytest.raises(WeatherApiError) as exc:
                await client.get_current_weather(28.6139, 77.2090)

            assert exc.value.error_code == "INVALID_JSON_RESPONSE"
