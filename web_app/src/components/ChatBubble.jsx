import React from 'react';
import { Volume2, VolumeX, Mic, MicOff } from 'lucide-react';
import WeatherCard from './WeatherCard';
import TravelCard from './TravelCard';
import FarmingCard from './FarmingCard';
import UrbanAdvisoryCard from './UrbanAdvisoryCard';
import ClimateTrendCard from './ClimateTrendCard';
import PersonaConfirmation from './PersonaConfirmation';

/** Render **bold** markers inside text as <strong> tags */
function renderBoldText(text) {
  if (!text) return null;
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return parts.map((part, i) => {
    if (part.startsWith('**') && part.endsWith('**')) {
      return <strong key={i}>{part.slice(2, -2)}</strong>;
    }
    return <span key={i}>{part}</span>;
  });
}

export default function ChatBubble({
  msg,
  speakingMsgId,
  isListening,
  onSpeak,
  onToggleListening,
  onPersonaAction,
  onSuggestionClick,
}) {
  const isUser = msg.role === 'user';

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: isUser ? 'flex-end' : 'flex-start',
      maxWidth: '100%',
    }}>
      {/* Bubble */}
      <div className={isUser ? 'bubble-user' : 'bubble-ai msg-text'} style={{ whiteSpace: 'pre-line' }}>
        {renderBoldText(msg.text)}
      </div>

      {/* AI Bubble Extras */}
      {!isUser && (
        <>
          {/* Action bar: Voice */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 6, flexWrap: 'wrap' }}>
            <button
              className={`voice-btn ${speakingMsgId === msg.id ? 'voice-btn-active' : ''}`}
              onClick={() => onSpeak(msg.text, msg.id, msg.audio_base64, msg.audio_chunks)}
              title="Listen to this response"
            >
              {speakingMsgId === msg.id
                ? <><VolumeX size={14} color="#38bdf8" /> Stop Voice</>
                : <><Volume2 size={14} color="#38bdf8" /> 🔊 Megha Voice</>
              }
            </button>

            {msg.id === 'welcome' && (
              <button
                className="voice-btn"
                onClick={onToggleListening}
                style={isListening ? {
                  background: 'rgba(239, 68, 68, 0.2)',
                  borderColor: '#ef4444',
                } : {
                  background: 'linear-gradient(135deg, rgba(2, 132, 199, 0.4), rgba(59, 130, 246, 0.4))',
                  borderColor: '#38bdf8',
                }}
              >
                {isListening
                  ? <><MicOff size={14} color="#ef4444" /> Listening...</>
                  : <><Mic size={14} color="#38bdf8" /> 🎙️ Start Talking / बात करें</>
                }
              </button>
            )}

            <span style={{ fontSize: '0.7rem', color: 'var(--text-dim)' }}>{msg.timestamp}</span>
          </div>

          {/* Advisory cards */}
          {msg.weather_data && <WeatherCard data={msg.weather_data} />}
          {msg.travel_assessment && <TravelCard data={msg.travel_assessment} />}
          {msg.farming_advisory && <FarmingCard data={msg.farming_advisory} />}
          {msg.urban_advisory && <UrbanAdvisoryCard data={msg.urban_advisory} />}
          {msg.climate_trend && <ClimateTrendCard data={msg.climate_trend} />}

          {/* Persona confirmation */}
          {msg.persona_confirmation && (
            <PersonaConfirmation
              data={msg.persona_confirmation}
              onAction={onPersonaAction}
            />
          )}

          {/* Follow-up suggestions */}
          {msg.suggestions?.length > 0 && (
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 8 }}>
              {msg.suggestions.map((sug, idx) => (
                <button key={idx} className="chip-btn" onClick={() => onSuggestionClick(sug)}>
                  {sug}
                </button>
              ))}
            </div>
          )}
        </>
      )}

      {/* User message timestamp */}
      {isUser && (
        <span style={{ fontSize: '0.7rem', color: 'var(--text-dim)', marginTop: 4 }}>{msg.timestamp}</span>
      )}
    </div>
  );
}
