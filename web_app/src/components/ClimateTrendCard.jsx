import React from 'react';
import { TrendingUp, TrendingDown, Minus, Thermometer, CloudRain, Calendar } from 'lucide-react';

function TrendIcon({ trend }) {
  const t = (trend || '').toLowerCase();
  if (t === 'increasing') return <TrendingUp size={14} className="trend-up" />;
  if (t === 'decreasing') return <TrendingDown size={14} className="trend-down" />;
  return <Minus size={14} className="trend-stable" />;
}

function trendLabel(trend) {
  const t = (trend || '').toLowerCase();
  if (t === 'increasing') return 'Increasing ↑';
  if (t === 'decreasing') return 'Decreasing ↓';
  return 'Stable →';
}

function trendColor(trend) {
  const t = (trend || '').toLowerCase();
  if (t === 'increasing') return 'var(--risk-high)';
  if (t === 'decreasing') return 'var(--accent-cyan)';
  return 'var(--accent-emerald)';
}

export default function ClimateTrendCard({ data }) {
  if (!data) return null;

  const yearsText = data.years_covered?.length
    ? `${Math.min(...data.years_covered)}–${Math.max(...data.years_covered)}`
    : '';

  return (
    <div className="glass-card card-climate" style={{ marginTop: 8, maxWidth: 420 }}>
      <div className="card-header">
        <span className="card-title" style={{ color: 'var(--accent-amber)' }}>
          <Calendar size={15} /> Climate Trend
        </span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <TrendIcon trend={data.rainfall_trend} />
          <span className="risk-badge" style={{
            background: `color-mix(in srgb, ${trendColor(data.rainfall_trend)} 15%, transparent)`,
            color: trendColor(data.rainfall_trend),
            border: `1px solid color-mix(in srgb, ${trendColor(data.rainfall_trend)} 30%, transparent)`,
          }}>
            {trendLabel(data.rainfall_trend)}
          </span>
        </div>
      </div>

      <div style={{ fontSize: '0.82rem', marginBottom: 8, display: 'flex', gap: 12, color: 'var(--text-muted)', flexWrap: 'wrap' }}>
        <span>📍 {data.location}</span>
        <span>📅 {data.month}</span>
        {yearsText && <span>📊 {yearsText}</span>}
      </div>

      {/* Stat grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10, marginBottom: 10 }}>
        {data.avg_total_rainfall_mm != null && (
          <div style={{ background: 'rgba(255,255,255,0.04)', padding: '8px 10px', borderRadius: 8 }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--text-dim)', marginBottom: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
              <CloudRain size={11} color="var(--accent-cyan)" /> Avg Rainfall
            </div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700 }}>{data.avg_total_rainfall_mm.toFixed(1)} mm</div>
          </div>
        )}
        {data.max_total_rainfall_mm != null && (
          <div style={{ background: 'rgba(255,255,255,0.04)', padding: '8px 10px', borderRadius: 8 }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--text-dim)', marginBottom: 2 }}>Max Rainfall</div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700 }}>{data.max_total_rainfall_mm.toFixed(1)} mm</div>
          </div>
        )}
        {data.avg_temp_max != null && (
          <div style={{ background: 'rgba(255,255,255,0.04)', padding: '8px 10px', borderRadius: 8 }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--text-dim)', marginBottom: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
              <Thermometer size={11} color="var(--accent-rose)" /> Avg High
            </div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700 }}>{data.avg_temp_max.toFixed(1)}°C</div>
          </div>
        )}
        {data.avg_temp_min != null && (
          <div style={{ background: 'rgba(255,255,255,0.04)', padding: '8px 10px', borderRadius: 8 }}>
            <div style={{ fontSize: '0.68rem', color: 'var(--text-dim)', marginBottom: 2 }}>Avg Low</div>
            <div style={{ fontSize: '1.05rem', fontWeight: 700 }}>{data.avg_temp_min.toFixed(1)}°C</div>
          </div>
        )}
      </div>

      {data.typical_condition && (
        <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: 6 }}>
          <strong style={{ color: 'var(--accent-amber)' }}>Typical:</strong> {data.typical_condition}
        </div>
      )}

      {data.summary && (
        <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', lineHeight: 1.5, fontStyle: 'italic', borderTop: '1px solid rgba(255,255,255,0.06)', paddingTop: 8 }}>
          {data.summary}
        </div>
      )}
    </div>
  );
}
