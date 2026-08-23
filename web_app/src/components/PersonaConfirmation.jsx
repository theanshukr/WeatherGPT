import React from 'react';
import { Sparkles } from 'lucide-react';

export default function PersonaConfirmation({ data, onAction }) {
  if (!data) return null;

  const confidencePct = Math.round((data.confidence || 0) * 100);

  return (
    <div className="persona-card" style={{ marginTop: 8, maxWidth: 400 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <Sparkles size={16} color="var(--accent-emerald)" />
        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--accent-emerald)' }}>
          {data.title || `AI Detected: ${data.persona}`}
        </span>
      </div>

      <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: 10, lineHeight: 1.5 }}>
        {data.message}
      </div>

      {/* Confidence bar */}
      <div style={{ marginBottom: 10 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.72rem', marginBottom: 4 }}>
          <span style={{ color: 'var(--text-dim)' }}>Confidence</span>
          <span style={{ color: 'var(--accent-cyan)', fontWeight: 600 }}>{confidencePct}%</span>
        </div>
        <div className="persona-confidence-bar">
          <div className="persona-confidence-fill" style={{ width: `${confidencePct}%` }} />
        </div>
      </div>

      {/* Action chips */}
      {data.action_chips?.length > 0 && (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {data.action_chips.map((chip, i) => {
            const isConfirm = chip.action?.includes('confirm');
            return (
              <button
                key={i}
                className={`action-chip ${isConfirm ? 'action-chip-primary' : ''}`}
                onClick={() => onAction?.(chip.action)}
              >
                {chip.label}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
