import React from 'react';
import { HardHat, ShieldAlert, ChevronRight } from 'lucide-react';

function riskClass(level) {
  const l = (level || 'LOW').toUpperCase();
  if (l === 'SEVERE') return 'risk-severe';
  if (l === 'HIGH') return 'risk-high';
  if (l === 'MODERATE') return 'risk-moderate';
  return 'risk-low';
}

export default function UrbanAdvisoryCard({ data }) {
  if (!data) return null;

  return (
    <div className="glass-card card-urban" style={{ marginTop: 8, maxWidth: 420 }}>
      <div className="card-header">
        <span className="card-title" style={{ color: 'var(--accent-indigo)' }}>
          <HardHat size={15} /> Urban Advisory
        </span>
        <span className={`risk-badge ${riskClass(data.risk_level)}`}>
          <ShieldAlert size={12} /> {data.risk_level}
        </span>
      </div>

      <div style={{ fontSize: '0.82rem', marginBottom: 6, display: 'flex', gap: 12, color: 'var(--text-muted)' }}>
        <span>📍 {data.location}</span>
        <span>🕐 {data.time_frame}</span>
        {data.activity && data.activity !== 'general' && <span>🏗️ {data.activity}</span>}
      </div>

      <div style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: 4 }}>
        {data.advisory_headline}
      </div>

      <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: 8 }}>
        {data.verdict}
      </div>

      {data.reasons?.length > 0 && (
        <ul className="card-list">
          {data.reasons.map((r, i) => <li key={i}>{r}</li>)}
        </ul>
      )}

      {data.actionable_steps?.length > 0 && (
        <div style={{ marginTop: 8 }}>
          <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--accent-indigo)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Recommended Actions
          </div>
          <ul className="card-list">
            {data.actionable_steps.map((s, i) => (
              <li key={i}>
                <ChevronRight size={12} style={{ flexShrink: 0, marginTop: 2, color: 'var(--accent-indigo)' }} />
                <span>{s}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
