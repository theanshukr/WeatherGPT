import React from 'react';
import { Sprout, ChevronRight } from 'lucide-react';

const RECOMMENDATION_COLORS = {
  'OPTIMAL_SPRAY_WINDOW': 'var(--accent-emerald)',
  'AVOID_SPRAYING': 'var(--risk-high)',
  'DELAY_IRRIGATION': 'var(--accent-amber)',
  'SAFE_TO_IRRIGATE': 'var(--accent-emerald)',
  'HARVEST_IMMEDIATELY': 'var(--risk-severe)',
  'SAFE_TO_HARVEST': 'var(--accent-emerald)',
};

export default function FarmingCard({ data }) {
  if (!data) return null;

  const recColor = RECOMMENDATION_COLORS[data.recommendation] || 'var(--accent-emerald)';

  return (
    <div className="glass-card card-farming" style={{ marginTop: 8, maxWidth: 420 }}>
      <div className="card-header">
        <span className="card-title" style={{ color: 'var(--accent-emerald)' }}>
          <Sprout size={15} /> Farming Advisory
        </span>
        <span className="risk-badge" style={{
          background: `${recColor}1a`,
          color: recColor,
          border: `1px solid ${recColor}4d`,
        }}>
          {data.recommendation?.replace(/_/g, ' ')}
        </span>
      </div>

      <div style={{ fontSize: '0.82rem', marginBottom: 6, display: 'flex', gap: 12, color: 'var(--text-muted)' }}>
        <span>🌾 {data.crop}</span>
        <span>📍 {data.location}</span>
        <span>🕐 {data.time_frame}</span>
      </div>

      <div style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: 8 }}>
        {data.advisory_headline}
      </div>

      {data.reasons?.length > 0 && (
        <ul className="card-list">
          {data.reasons.map((r, i) => <li key={i}>{r}</li>)}
        </ul>
      )}

      {data.actionable_steps?.length > 0 && (
        <div style={{ marginTop: 8 }}>
          <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--accent-emerald)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Action Steps
          </div>
          <ul className="card-list">
            {data.actionable_steps.map((s, i) => (
              <li key={i}>
                <ChevronRight size={12} style={{ flexShrink: 0, marginTop: 2, color: 'var(--accent-emerald)' }} />
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
