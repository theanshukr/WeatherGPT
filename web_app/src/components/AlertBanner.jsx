import React, { useEffect, useState } from 'react';
import { AlertTriangle, X } from 'lucide-react';

export default function AlertBanner({ alert, onDismiss }) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setVisible(false);
      onDismiss?.();
    }, 30000);
    return () => clearTimeout(timer);
  }, [onDismiss]);

  if (!visible || !alert) return null;

  const isSevere = (alert.severity || '').toUpperCase() === 'SEVERE';

  return (
    <div className="alert-banner" style={isSevere ? {
      background: 'linear-gradient(135deg, rgba(239, 68, 68, 0.25), rgba(220, 38, 38, 0.2))',
      borderColor: 'rgba(239, 68, 68, 0.5)',
    } : undefined}>
      <AlertTriangle
        size={20}
        color={isSevere ? '#ef4444' : '#f97316'}
        style={{ flexShrink: 0 }}
      />
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: '0.82rem', fontWeight: 700, color: isSevere ? '#fca5a5' : '#fed7aa', marginBottom: 2 }}>
          ⚠️ {alert.type || 'Weather Alert'} — {alert.location || 'Your Area'}
        </div>
        <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
          {alert.description || alert.message || 'Severe weather conditions detected. Please take precautions.'}
        </div>
      </div>
      <button
        className="alert-banner-close"
        onClick={() => { setVisible(false); onDismiss?.(); }}
        aria-label="Dismiss alert"
      >
        <X size={16} />
      </button>
    </div>
  );
}
