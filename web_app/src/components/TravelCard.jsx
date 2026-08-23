import React from 'react';
import { Car, ShieldAlert, ChevronRight } from 'lucide-react';

function riskClass(level) {
  const l = (level || 'LOW').toUpperCase();
  if (l === 'SEVERE') return 'risk-severe';
  if (l === 'HIGH') return 'risk-high';
  if (l === 'MODERATE') return 'risk-moderate';
  return 'risk-low';
}

export default function TravelCard({ data }) {
  if (!data) return null;

  return (
    <div className="glass-card card-travel" style={{ marginTop: 8, maxWidth: 420 }}>
      <div className="card-header">
        <span className="card-title" style={{ color: 'var(--accent-blue)' }}>
          <Car size={15} /> Travel Assessment
        </span>
        <span className={`risk-badge ${riskClass(data.travel_risk)}`}>
          <ShieldAlert size={12} /> {data.travel_risk}
        </span>
      </div>

      <div style={{ fontSize: '0.82rem', marginBottom: 6, display: 'flex', gap: 12, color: 'var(--text-muted)' }}>
        <span>📍 {data.destination}</span>
        <span>🕐 {data.time_frame}</span>
        {data.activity && <span>🚗 {data.activity}</span>}
      </div>

      <div style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: 8 }}>
        {data.verdict}
      </div>

      {data.reasons?.length > 0 && (
        <ul className="card-list">
          {data.reasons.map((r, i) => <li key={i}>{r}</li>)}
        </ul>
      )}

      {data.guidelines?.length > 0 && (
        <div style={{ marginTop: 8 }}>
          <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--accent-amber)', marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Safety Guidelines
          </div>
          <ul className="card-list">
            {data.guidelines.map((g, i) => (
              <li key={i} style={{ color: 'var(--accent-amber)' }}>
                <ChevronRight size={12} style={{ flexShrink: 0, marginTop: 2 }} /> 
                <span style={{ color: 'var(--text-muted)' }}>{g}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
