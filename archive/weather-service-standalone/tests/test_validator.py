"""
Unit tests for WeatherDataValidator.
Tests coordinate boundaries, physical sanity limits, date formats, and payload structure.
"""

import pytest
from app.validator import WeatherDataValidator, ValidationError


class TestCoordinateValidation:
    def test_valid_coordinates_delhi(self):
        lat, lon = WeatherDataValidator.validate_coordinates(28.6139, 77.2090)
        assert lat == 28.6139
        assert lon == 77.2090

    def test_valid_boundary_coordinates(self):
        # Extreme valid poles and international date line
        lat, lon = WeatherDataValidator.validate_coordinates(90.0, 180.0)
        assert lat == 90.0
        assert lon == 180.0

        lat, lon = WeatherDataValidator.validate_coordinates(-90.0, -180.0)
        assert lat == -90.0
        assert lon == -180.0

    def test_invalid_latitude_overflow(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates(90.1, 77.0)
        assert exc.value.error_code == "INVALID_LATITUDE_RANGE"

    def test_invalid_latitude_underflow(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates(-91.0, 77.0)
        assert exc.value.error_code == "INVALID_LATITUDE_RANGE"

    def test_invalid_longitude_overflow(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates(28.0, 180.5)
        assert exc.value.error_code == "INVALID_LONGITUDE_RANGE"

    def test_invalid_longitude_underflow(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates(28.0, -180.1)
        assert exc.value.error_code == "INVALID_LONGITUDE_RANGE"

    def test_non_numeric_coordinates(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates("invalid_lat", 77.0)
        assert exc.value.error_code == "INVALID_COORDINATES_TYPE"

    def test_missing_coordinates(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_coordinates(None, None)
        assert exc.value.error_code == "MISSING_COORDINATES"


class TestForecastDaysValidation:
    def test_valid_forecast_days(self):
        assert WeatherDataValidator.validate_forecast_days(1) == 1
        assert WeatherDataValidator.validate_forecast_days(7) == 7
        assert WeatherDataValidator.validate_forecast_days(16) == 16

    def test_forecast_days_out_of_bounds(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_forecast_days(0)
        assert exc.value.error_code == "FORECAST_DAYS_OUT_OF_BOUNDS"

        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_forecast_days(17)
        assert exc.value.error_code == "FORECAST_DAYS_OUT_OF_BOUNDS"


class TestHistoricalDateValidation:
    def test_valid_historical_dates(self):
        s, e = WeatherDataValidator.validate_historical_dates("2023-01-01", "2023-01-07")
        assert s == "2023-01-01"
        assert e == "2023-01-07"

    def test_invalid_date_format(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_historical_dates("01-01-2023", "2023-01-07")
        assert exc.value.error_code == "INVALID_DATE_FORMAT"

    def test_invalid_chronology(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_historical_dates("2023-01-10", "2023-01-05")
        assert exc.value.error_code == "INVALID_DATE_CHRONOLOGY"

    def test_date_before_archive_epoch(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_historical_dates("1920-01-01", "1920-01-05")
        assert exc.value.error_code == "DATE_PRIOR_TO_ARCHIVE_EPOCH"


class TestPhysicalSanitization:
    def test_temperature_limits(self):
        assert WeatherDataValidator.sanitize_physical_value("temperature", 25.5) == 25.5
        assert WeatherDataValidator.sanitize_physical_value("temperature", -40.0) == -40.0
        assert WeatherDataValidator.sanitize_physical_value("temperature", 150.0) is None  # Impossible Earth temp
        assert WeatherDataValidator.sanitize_physical_value("temperature", -120.0) is None

    def test_humidity_limits(self):
        assert WeatherDataValidator.sanitize_physical_value("humidity", 50) == 50.0
        assert WeatherDataValidator.sanitize_physical_value("humidity", 100) == 100.0
        assert WeatherDataValidator.sanitize_physical_value("humidity", -5) is None
        assert WeatherDataValidator.sanitize_physical_value("humidity", 105) is None

    def test_rain_limits(self):
        assert WeatherDataValidator.sanitize_physical_value("rain", 12.4) == 12.4
        assert WeatherDataValidator.sanitize_physical_value("rain", -3.0) == 0.0  # Floor negative rain to 0.0

    def test_wind_speed_limits(self):
        assert WeatherDataValidator.sanitize_physical_value("wind_speed", 25.0) == 25.0
        assert WeatherDataValidator.sanitize_physical_value("wind_speed", 600.0) is None  # Impossible Earth wind speed


class TestResponseValidation:
    def test_valid_open_meteo_dict(self, sample_open_meteo_forecast_raw):
        validated = WeatherDataValidator.validate_open_meteo_response(sample_open_meteo_forecast_raw)
        assert "latitude" in validated
        assert "longitude" in validated

    def test_open_meteo_api_error_payload(self):
        error_payload = {"error": True, "reason": "Latitude must be in range of -90 to 90°."}
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_open_meteo_response(error_payload)
        assert exc.value.error_code == "OPEN_METEO_API_ERROR"

    def test_malformed_response_type(self):
        with pytest.raises(ValidationError) as exc:
            WeatherDataValidator.validate_open_meteo_response(["not", "a", "dict"])
        assert exc.value.error_code == "MALFORMED_API_RESPONSE"
