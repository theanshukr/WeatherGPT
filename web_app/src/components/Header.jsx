import React from 'react';
import {
  CloudRain,
  Sparkles,
  Volume2,
  VolumeX,
  RotateCcw,
} from 'lucide-react';

export default function Header({
  persona,
  autoSpeak,
  language,
  showProfile,
  profile,
  onToggleAutoSpeak,
  onToggleLanguage,
  onToggleProfile,
  onClearChat,
}) {
  const personaLabel =
    persona === 'farmer'
      ? '🌾 Auto: Farmer Intelligence'
      : persona === 'traveler' || persona === 'daily_commuter'
        ? '🚗 Auto: Travel & Transit'
        : persona === 'urban_worker'
          ? '🏗️ Auto: Urban Worker'
          : '⚡ Auto-Adaptive Context';

  return (
    <header
      className="glass-panel"
      style={{
        padding: '12px 20px',
        marginBottom: 12,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: 10,
      }}
    >
      {/* Logo */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div
          style={{
            background: 'linear-gradient(135deg, #0284c7, #2563eb)',
            padding: 10,
            borderRadius: 12,
            display: 'flex',
            boxShadow: '0 0 15px rgba(2, 132, 199, 0.5)',
          }}
        >
          <CloudRain size={24} color="#fff" />
        </div>
        <div>
          <h1
            style={{
              fontSize: '1.25rem',
              fontWeight: 800,
              letterSpacing: '-0.02em',
              background: 'linear-gradient(90deg, #fff, #93c5fd)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              margin: 0,
            }}
          >
            WeatherGPT — मेघा (Megha)
          </h1>
          <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            AI Weather & Disaster Intelligence Platform
          </span>
        </div>
      </div>

      {/* Controls */}
      <div className="header-controls" style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        {/* Automatic Persona Badge */}
        <div
          style={{
            background: 'rgba(56, 189, 248, 0.12)',
            color: '#38bdf8',
            border: '1px solid rgba(56, 189, 248, 0.3)',
            borderRadius: 8,
            padding: '6px 12px',
            fontSize: '0.85rem',
            fontWeight: 600,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          <Sparkles size={14} />
          {personaLabel}
        </div>

        {/* Voice Auto-Read Toggle */}
        <button
          className="chip-btn"
          onClick={onToggleAutoSpeak}
          style={{
            borderColor: autoSpeak ? '#38bdf8' : 'rgba(255,255,255,0.1)',
            color: autoSpeak ? '#38bdf8' : '#fff',
            fontWeight: 600,
          }}
          title="Auto-read AI responses aloud"
        >
          {autoSpeak ? <Volume2 size={14} color="#38bdf8" /> : <VolumeX size={14} />}
          Auto-Voice: {autoSpeak ? 'ON' : 'OFF'}
        </button>

        {/* Language Switcher */}
        <button
          className="chip-btn"
          onClick={onToggleLanguage}
          style={{ fontWeight: 600 }}
        >
          🌐 {language === 'hi' ? 'हिन्दी (Hindi)' : 'English'}
        </button>

        {/* Profile Drawer Toggle */}
        <button
          className="chip-btn"
          onClick={onToggleProfile}
          style={{
            borderColor: showProfile ? 'var(--accent-cyan)' : 'rgba(255,255,255,0.1)',
          }}
        >
          📊 AI Profile{' '}
          {profile?.confirmed_personas?.length
            ? `(${profile.confirmed_personas[0]})`
            : ''}
        </button>

        {/* Reset Chat */}
        <button className="chip-btn" onClick={onClearChat} title="Reset session">
          <RotateCcw size={15} />
        </button>
      </div>
    </header>
  );
}
