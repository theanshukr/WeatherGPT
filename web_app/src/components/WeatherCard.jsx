import React from 'react';
import { Droplets, Wind, CloudRain, MapPin, Sun, CloudSnow, CloudLightning, Cloud, CloudDrizzle } from 'lucide-react';

const WEATHER_ICONS = {
  0: Sun,       // Clear
  1: Sun, 2: Cloud, 3: Cloud,     // Partly/mostly cloudy
  45: Cloud, 48: Cloud,            // Fog
  51: CloudDrizzle, 53: CloudDrizzle, 55: CloudDrizzle, // Drizzle
  61: CloudRain, 63: CloudRain, 65: CloudRain,           // Rain
  71: CloudSnow, 73: CloudSnow, 75: CloudSnow,           // Snow
  80: CloudRain, 81: CloudRain, 82: CloudRain,           // Showers
  95: CloudLightning, 96: CloudLightning, 99: CloudLightning, // Thunderstorm
};

export default function WeatherCard({ data }) {
  if (!data) return null;

  const IconComponent = WEATHER_ICONS[data.weather_code] || Cloud;

  return (
    <div className="glass-card card-weather" style={{ marginTop: 8, width: 'fit-content', minWidth: 280 }}>
      <div className="card-header">
        <span className="card-title" style={{ color: 'var(--accent-cyan)' }}>
          <MapPin size={14} /> {data.location}
        </span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <IconComponent size={20} color="var(--accent-amber)" />
          <span style={{ fontSize: '1.3rem', fontWeight: 700 }}>{data.temperature}°C</span>
        </div>
      </div>
      <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: 8 }}>
        {data.condition}
      </div>
      <div className="card-metrics">
        <div className="card-metric">
          <Droplets size={13} color="#38bdf8" /> {data.humidity ?? 0}% Humidity
        </div>
        <div className="card-metric">
          <Wind size={13} color="#818cf8" /> {data.wind_speed ?? 0} km/h
        </div>
        <div className="card-metric">
          <CloudRain size={13} color="#34d399" /> {data.precipitation ?? 0} mm Rain
        </div>
      </div>
    </div>
  );
}
