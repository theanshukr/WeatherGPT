import React from 'react';
import { Send, Mic, MicOff } from 'lucide-react';

export default function ChatInput({
  inputText,
  setInputText,
  isListening,
  loading,
  language,
  onSend,
  onToggleListening,
}) {
  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      onSend();
    }
  };

  return (
    <div style={{ marginTop: 12, display: 'flex', gap: 8, alignItems: 'center' }}>
      <input
        type="text"
        value={inputText}
        onChange={(e) => setInputText(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder={
          isListening
            ? '🎙️ Listening... speak in Hindi, English, or any language'
            : 'Type your question or click the mic to speak... (e.g. Shaam ko Delhi se Gurgaon jana h?)'
        }
        className={`chat-input ${isListening ? 'chat-input-listening' : ''}`}
      />

      {/* Voice Mic Button */}
      <button
        onClick={onToggleListening}
        className="chip-btn"
        style={{
          borderRadius: 12,
          padding: '0 16px',
          height: 46,
          background: isListening ? 'rgba(239, 68, 68, 0.25)' : 'rgba(255,255,255,0.06)',
          border: isListening ? '1px solid #ef4444' : '1px solid var(--border-glass)',
          color: isListening ? '#f87171' : '#38bdf8',
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          cursor: 'pointer',
        }}
        title={isListening ? 'Stop listening' : 'Speak in Hindi or English (Voice input)'}
      >
        {isListening ? <MicOff size={18} /> : <Mic size={18} />}
        {isListening && <span style={{ fontSize: '0.8rem', fontWeight: 700 }}>बोलिए...</span>}
      </button>

      {/* Send Button */}
      <button
        onClick={onSend}
        disabled={loading || !inputText.trim()}
        className="glow-button"
        style={{
          borderRadius: 12,
          padding: '0 20px',
          height: 46,
          border: 'none',
          color: '#fff',
          cursor: loading || !inputText.trim() ? 'not-allowed' : 'pointer',
          opacity: loading || !inputText.trim() ? 0.5 : 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Send size={18} />
      </button>
    </div>
  );
}
