import React from 'react';
import { Sparkles } from 'lucide-react';

export default function ProfilePanel({ profile }) {
  return (
    <aside className="glass-panel" style={{ padding: 16, overflowY: 'auto' }}>
      <h3 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: 12, color: 'var(--accent-cyan)', display: 'flex', alignItems: 'center', gap: 6 }}>
        <Sparkles size={16} /> User AI Intelligence
      </h3>

      {/* Confirmed Persona */}
      <div style={{ marginBottom: 16, background: 'rgba(0,0,0,0.2)', padding: 10, borderRadius: 10 }}>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: 4 }}>Confirmed Role</div>
        <div style={{ fontWeight: 600, color: '#34d399', textTransform: 'capitalize' }}>
          {profile?.confirmed_personas?.length
            ? `✅ ${profile.confirmed_personas.join(', ')}`
            : 'None (Inferring...)'}
        </div>
      </div>

      {/* Live Inferred Persona Scores */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: 8 }}>Inferred Persona Scores</div>
        {profile?.inferred_personas ? (
          Object.entries(profile.inferred_personas).map(([k, val]) => (
            <div key={k} style={{ marginBottom: 8 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', marginBottom: 2 }}>
                <span style={{ textTransform: 'capitalize' }}>{k.replace('_', ' ')}</span>
                <span style={{ color: 'var(--accent-cyan)', fontWeight: 600 }}>{Math.round(val * 100)}%</span>
              </div>
              <div className="profile-score-bar">
                <div
                  className="profile-score-fill"
                  style={{
                    width: `${Math.min(100, Math.round(val * 100))}%`,
                    background: val >= 0.65 ? 'var(--accent-cyan)' : 'var(--accent-indigo)',
                  }}
                />
              </div>
            </div>
          ))
        ) : (
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            Send messages to see live AI scores!
          </div>
        )}
      </div>

      {/* Active Location */}
      {profile?.active_location && (
        <div style={{ marginBottom: 16, background: 'rgba(0,0,0,0.2)', padding: 10, borderRadius: 10 }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: 4 }}>Last Active Location</div>
          <div style={{ fontSize: '0.85rem', fontWeight: 600 }}>📍 {profile.active_location}</div>
        </div>
      )}

      {/* Recent Intent */}
      {profile?.recent_intent && (
        <div style={{ marginBottom: 16, background: 'rgba(0,0,0,0.2)', padding: 10, borderRadius: 10 }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: 4 }}>Recent Intent</div>
          <div style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--accent-blue)' }}>
            {profile.recent_intent?.replace(/_/g, ' ')}
          </div>
        </div>
      )}

      {/* Time Decay Info */}
      <div style={{
        fontSize: '0.7rem',
        color: 'rgba(255,255,255,0.4)',
        lineHeight: 1.4,
        background: 'rgba(255,255,255,0.03)',
        padding: 8,
        borderRadius: 8,
      }}>
        ⏱️ <strong>Exponential Decay:</strong> Old inquiries automatically fade over 14 days so you are never permanently classified.
      </div>
    </aside>
  );
}
