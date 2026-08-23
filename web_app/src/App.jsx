import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Sparkles } from 'lucide-react';
import Header from './components/Header';
import ChatBubble from './components/ChatBubble';
import ChatInput from './components/ChatInput';
import ProfilePanel from './components/ProfilePanel';
import AlertBanner from './components/AlertBanner';

const API_BASE = '/api/v1';

// ── WebSocket for live alerts ──
function useWebSocketAlerts() {
  const [alerts, setAlerts] = useState([]);
  const wsRef = useRef(null);
  const reconnectTimer = useRef(null);
  const retryCount = useRef(0);

  const connect = useCallback(() => {
    try {
      const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
      const host = window.location.hostname || 'localhost';
      const ws = new WebSocket(`${proto}://${host}:8000/api/v1/ws/live`);
      wsRef.current = ws;

      ws.onopen = () => {
        retryCount.current = 0;
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.type === 'alert_broadcast' || data.type === 'alert') {
            setAlerts((prev) => [...prev, { ...data, id: Date.now() }]);
          }
        } catch (e) { /* ignore non-JSON */ }
      };

      ws.onclose = () => {
        const delay = Math.min(30000, 1000 * Math.pow(2, retryCount.current));
        retryCount.current += 1;
        reconnectTimer.current = setTimeout(connect, delay);
      };

      ws.onerror = () => {
        ws.close();
      };
    } catch (e) {
      // WebSocket not available or blocked
    }
  }, []);

  useEffect(() => {
    connect();
    return () => {
      if (wsRef.current) wsRef.current.close();
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
    };
  }, [connect]);

  const dismissAlert = useCallback((alertId) => {
    setAlerts((prev) => prev.filter((a) => a.id !== alertId));
  }, []);

  return { alerts, dismissAlert };
}

export default function App() {
  // ── State ──
  const [serverTarget, setServerTarget] = useState('local'); // 'local' or 'render'
  const effectiveApiBase = serverTarget === 'render'
    ? 'https://weathergpt-backend-3n4b.onrender.com/api/v1'
    : '/api/v1';

  const [messages, setMessages] = useState([
    {
      id: 'welcome',
      role: 'ai',
      text: 'नमस्ते! मैं आपकी वेदर दोस्त मेघा (Megha) हूँ। मैं आपके शहर और एरिया के मौसम, बारिश, फसल या सफर के बारे में जानने में आपकी क्या मदद कर सकती हूँ?',
      suggestions: [
        'Hi Megha, kaise ho?',
        'mujhe shaam ko delhi se gurgaon jana h barish toh nhi hogi?',
        'kya Lucknow me parso baarish hogi?',
        'Kal wheat crop mein pesticide spray karna safe hai?',
      ],
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    },
  ]);
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(false);
  const [sessionId, setSessionId] = useState(() => 'sess_' + Math.random().toString(36).substring(2, 9));
  const [userId] = useState(() => 'user_' + Math.random().toString(36).substring(2, 9));
  const [persona, setPersona] = useState('general');
  const [language, setLanguage] = useState('hi');
  const [profile, setProfile] = useState(null);
  const [showProfile, setShowProfile] = useState(false);

  // Voice state
  const [isListening, setIsListening] = useState(false);
  const [speakingMsgId, setSpeakingMsgId] = useState(null);
  const [autoSpeak, setAutoSpeak] = useState(true);
  const recognitionRef = useRef(null);
  const silenceTimerRef = useRef(null);
  const transcriptBufferRef = useRef('');
  const audioPlayerRef = useRef(null);
  const hasSpokenWelcomeRef = useRef(false);

  const messagesEndRef = useRef(null);

  // WebSocket alerts
  const { alerts, dismissAlert } = useWebSocketAlerts();

  // ── Pre-fetch Sarvam voice for welcome ──
  useEffect(() => {
    fetch(`${effectiveApiBase}/voice/tts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: 'नमस्ते! मैं आपकी वेदर दोस्त मेघा हूँ। मैं आपके शहर और एरिया के मौसम, बारिश, फसल या सफर के बारे में जानने में आपकी क्या मदद कर सकती हूँ?',
        language_code: 'hi-IN',
        speaker: 'anushka',
      }),
    })
      .then((res) => res.json())
      .then((data) => {
        if (data.status === 'success' && data.audio_base64) {
          setMessages((prev) =>
            prev.map((m) => (m.id === 'welcome' ? { ...m, audio_base64: data.audio_base64 } : m))
          );
        }
      })
      .catch((e) => console.log('Welcome TTS fetch error:', e));
  }, []);

  // ── Speak greeting on first user interaction ──
  useEffect(() => {
    const handleFirstClick = () => {
      if (autoSpeak && !hasSpokenWelcomeRef.current) {
        hasSpokenWelcomeRef.current = true;
        const welcomeMsg = messages.find((m) => m.id === 'welcome');
        if (welcomeMsg) {
          speakText(welcomeMsg.text, 'welcome', welcomeMsg.audio_base64);
        }
      }
      window.removeEventListener('click', handleFirstClick);
    };
    window.addEventListener('click', handleFirstClick);
    return () => window.removeEventListener('click', handleFirstClick);
  }, [messages, autoSpeak]);

  const isSendingRef = useRef(false);

  // ── Speech Recognition ──
  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SpeechRecognition) {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = language === 'hi' ? 'hi-IN' : 'en-IN';

      recognition.onstart = () => {
        setIsListening(true);
        transcriptBufferRef.current = '';
      };
      recognition.onend = () => setIsListening(false);
      recognition.onerror = () => {
        setIsListening(false);
        if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      };
      recognition.onresult = (event) => {
        let fullTranscript = '';
        for (let i = 0; i < event.results.length; ++i) {
          fullTranscript += event.results[i][0].transcript;
        }
        transcriptBufferRef.current = fullTranscript;
        setInputText(fullTranscript);

        if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
        silenceTimerRef.current = setTimeout(() => {
          if (transcriptBufferRef.current.trim() && !isSendingRef.current) {
            const finalQuery = transcriptBufferRef.current.trim();
            transcriptBufferRef.current = '';
            try { recognition.stop(); } catch (err) {}
            setIsListening(false);
            handleSendMessage(finalQuery);
          }
        }, 2200);
      };

      recognitionRef.current = recognition;
    }
  }, [language]);

  // ── Voice functions ──
  const toggleListening = useCallback(() => {
    if (!recognitionRef.current) {
      alert('Speech recognition is not supported in this browser. Please use Chrome, Edge, or a modern browser.');
      return;
    }
    if (isListening) {
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      try { recognitionRef.current.stop(); } catch (e) {}
      setIsListening(false);
      if (transcriptBufferRef.current.trim() && !isSendingRef.current) {
        const finalQuery = transcriptBufferRef.current.trim();
        transcriptBufferRef.current = '';
        handleSendMessage(finalQuery);
      }
    } else {
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);
      transcriptBufferRef.current = '';
      setInputText('');
      recognitionRef.current.lang = language === 'hi' ? 'hi-IN' : 'en-IN';
      try { recognitionRef.current.start(); } catch (err) {}
    }
  }, [isListening, language]);

  const activeUtterancesRef = useRef([]);
  const ttsKeepAliveTimerRef = useRef(null);
  const selectedVoiceRef = useRef(null);

  // Preload and cache consistent voice
  useEffect(() => {
    const updateVoice = () => {
      if (!window.speechSynthesis) return;
      const voices = window.speechSynthesis.getVoices();
      if (!voices || voices.length === 0) return;

      const targetLang = language === 'hi' ? 'hi' : 'en';

      let chosen = null;
      if (targetLang === 'hi') {
        // 1. Prioritize sweet natural Hindi female voices
        chosen = voices.find(
          (v) =>
            v.name.includes('Swara') ||
            v.name.includes('Google हिन्दी') ||
            v.name.includes('Heera') ||
            v.name.includes('Kalpana') ||
            v.name.includes('Aditi')
        );
        // 2. Any hi-IN voice
        if (!chosen) {
          chosen = voices.find((v) => v.lang && (v.lang === 'hi-IN' || v.lang === 'hi_IN' || v.lang.startsWith('hi')));
        }
        // 3. Indian English female voice (smooth for Hinglish)
        if (!chosen) {
          chosen = voices.find(
            (v) =>
              v.lang && v.lang.includes('IN') &&
              (v.name.toLowerCase().includes('female') || v.name.includes('Neerja') || v.name.includes('Aditi'))
          );
        }
      } else {
        chosen = voices.find(
          (v) =>
            v.lang && v.lang.startsWith('en') &&
            (v.name.includes('Neerja') || v.name.includes('Zira') || v.name.toLowerCase().includes('female'))
        );
      }

      selectedVoiceRef.current = chosen || voices.find((v) => v.lang && v.lang.startsWith(targetLang)) || voices[0];
    };

    updateVoice();
    if (window.speechSynthesis) {
      window.speechSynthesis.onvoiceschanged = updateVoice;
    }
  }, [language]);

  // ── Browser TTS with locked voice & sentence queueing ──
  const fallbackBrowserTTS = useCallback((text, msgId) => {
    if (!window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    if (ttsKeepAliveTimerRef.current) clearInterval(ttsKeepAliveTimerRef.current);

    // 1. Clean markdown & split into natural sentence chunks
    const clean = text
      .replace(/\*\*/g, '')
      .replace(/\*/g, '')
      .replace(/#/g, '')
      .replace(/•/g, '')
      .replace(/`/g, '')
      .replace(/\[.*?\]/g, '')
      .trim();

    // Match sentences ending in fullstop, exclamation, question mark, Hindi purna viram (।), or newline
    const sentenceMatches = clean.match(/[^।!?.\n]+[।!?.\n]*/g);
    const chunks = (sentenceMatches && sentenceMatches.length > 0)
      ? sentenceMatches.map((s) => s.trim()).filter(Boolean)
      : [clean];

    const targetVoice = selectedVoiceRef.current;
    const targetLang = targetVoice?.lang || (language === 'hi' ? 'hi-IN' : 'en-IN');

    setSpeakingMsgId(msgId);
    let chunkIndex = 0;
    activeUtterancesRef.current = [];

    // Keep-alive heartbeat: prevents Chromium's 15s timeout cutoff bug
    ttsKeepAliveTimerRef.current = setInterval(() => {
      if (window.speechSynthesis && window.speechSynthesis.speaking) {
        window.speechSynthesis.pause();
        window.speechSynthesis.resume();
      }
    }, 4000);

    const speakNextChunk = () => {
      if (chunkIndex >= chunks.length) {
        setSpeakingMsgId(null);
        if (ttsKeepAliveTimerRef.current) clearInterval(ttsKeepAliveTimerRef.current);
        activeUtterancesRef.current = [];
        return;
      }

      const chunkText = chunks[chunkIndex];
      chunkIndex += 1;

      const utterance = new SpeechSynthesisUtterance(chunkText);
      // Retain reference on window & ref to prevent Garbage Collection mid-speech
      activeUtterancesRef.current.push(utterance);
      window.__activeUtterance = utterance;

      // Lock single consistent voice and language explicitly on EVERY chunk
      if (targetVoice) {
        utterance.voice = targetVoice;
      }
      utterance.lang = targetLang;
      utterance.rate = 0.95;
      utterance.pitch = 1.15;

      utterance.onend = () => {
        speakNextChunk();
      };

      utterance.onerror = (e) => {
        console.warn('TTS chunk error:', e);
        if (chunkIndex < chunks.length) {
          speakNextChunk();
        } else {
          setSpeakingMsgId(null);
          if (ttsKeepAliveTimerRef.current) clearInterval(ttsKeepAliveTimerRef.current);
        }
      };

      window.speechSynthesis.speak(utterance);
    };

    speakNextChunk();
  }, [language]);

  const speakText = useCallback((text, msgId, audioBase64 = null, audioChunks = null) => {
    // If already speaking this message, stop it
    if (speakingMsgId === msgId) {
      if (audioPlayerRef.current) {
        audioPlayerRef.current.pause();
        audioPlayerRef.current = null;
      }
      if (window.speechSynthesis) window.speechSynthesis.cancel();
      if (ttsKeepAliveTimerRef.current) clearInterval(ttsKeepAliveTimerRef.current);
      setSpeakingMsgId(null);
      return;
    }

    // Stop any previous speech
    if (audioPlayerRef.current) {
      audioPlayerRef.current.pause();
      audioPlayerRef.current = null;
    }
    if (window.speechSynthesis) window.speechSynthesis.cancel();
    if (ttsKeepAliveTimerRef.current) clearInterval(ttsKeepAliveTimerRef.current);

    // 1. If Sarvam cloud audio chunks are available, play them sequentially
    const playlist = audioChunks && audioChunks.length > 0
      ? audioChunks
      : (audioBase64 ? [audioBase64] : null);

    if (playlist && playlist.length > 0) {
      let trackIdx = 0;
      const playNextAudio = () => {
        if (trackIdx >= playlist.length) {
          setSpeakingMsgId(null);
          audioPlayerRef.current = null;
          return;
        }
        try {
          const audio = new Audio(`data:audio/wav;base64,${playlist[trackIdx]}`);
          audioPlayerRef.current = audio;
          trackIdx += 1;
          audio.onended = playNextAudio;
          audio.onerror = () => {
            console.warn('Audio chunk error, fallback to browser TTS');
            fallbackBrowserTTS(text, msgId);
          };
          audio.play();
        } catch (e) {
          fallbackBrowserTTS(text, msgId);
        }
      };

      setSpeakingMsgId(msgId);
      playNextAudio();
      return;
    }

    // 2. Otherwise use the uninterrupted sentence-queue browser TTS
    fallbackBrowserTTS(text, msgId);
  }, [speakingMsgId, fallbackBrowserTTS]);

  // ── Auto scroll ──
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading]);

  // ── Profile fetch ──
  const fetchProfile = useCallback(async () => {
    try {
      const res = await fetch(`${effectiveApiBase}/user/profile/${userId}`);
      if (res.ok) {
        const data = await res.json();
        setProfile(data);
      }
    } catch (e) {
      console.log('Profile fetch error:', e);
    }
  }, [userId, effectiveApiBase]);

  useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);

  // ── Send message ──
  const handleSendMessage = useCallback(
    async (textToSend) => {
      const text = (textToSend || inputText).trim();
      if (!text || isSendingRef.current) return;
      isSendingRef.current = true;
      setLoading(true);

      const userMsg = {
        id: Date.now().toString(),
        role: 'user',
        text: text,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages((prev) => [...prev, userMsg]);
      setInputText('');
      transcriptBufferRef.current = '';
      if (silenceTimerRef.current) clearTimeout(silenceTimerRef.current);

      try {
        const res = await fetch(`${effectiveApiBase}/chat/message`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: text,
            session_id: sessionId,
            user_id: userId,
            persona: persona,
            language: language,
          }),
        });

        if (!res.ok) throw new Error('Backend response error');
        const data = await res.json();

        const aiMsg = {
          id: (Date.now() + 1).toString(),
          role: 'ai',
          text: data.response,
          weather_data: data.weather_data,
          travel_assessment: data.travel_assessment,
          farming_advisory: data.farming_advisory,
          urban_advisory: data.urban_advisory,
          climate_trend: data.climate_trend,
          risk_level: data.risk_level,
          suggestions: data.suggestions || [],
          audio_base64: data.audio_base64,
          audio_chunks: data.audio_chunks,
          persona_confirmation: data.persona_confirmation,
          inferred_personas: data.inferred_personas,
          timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        };

        // Update persona based on response data
        if (data.urban_advisory) {
          setPersona('urban_worker');
        } else if (data.farming_advisory) {
          setPersona('farmer');
        } else if (data.travel_assessment) {
          setPersona('traveler');
        }

        setMessages((prev) => [...prev, aiMsg]);
        if (autoSpeak && data.response) {
          speakText(data.response, aiMsg.id, data.audio_base64, data.audio_chunks);
        }
        fetchProfile();
      } catch (err) {
        setMessages((prev) => [
          ...prev,
          {
            id: (Date.now() + 1).toString(),
            role: 'ai',
            text: `⚠️ बैकएंड (${serverTarget === 'render' ? 'Render Cloud' : 'Localhost:8000'}) से कनेक्ट करने में परेशानी हुई।`,
            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          },
        ]);
      } finally {
        isSendingRef.current = false;
        setLoading(false);
      }
    },
    [inputText, sessionId, userId, persona, language, autoSpeak, speakText, fetchProfile, effectiveApiBase, serverTarget]
  );

  // ── Persona action ──
  const handlePersonaAction = useCallback(
    async (actionStr) => {
      const [action, targetPersona] = actionStr.split(':');
      let act = 'confirm';
      if (action.includes('decline')) act = 'decline';
      if (action.includes('defer')) act = 'defer';

      try {
        await fetch(`${effectiveApiBase}/user/profile/${userId}/persona`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: act, persona: targetPersona }),
        });
        fetchProfile();
        if (act === 'confirm') {
          setPersona(targetPersona);
          setMessages((prev) => [
            ...prev,
            {
              id: Date.now().toString(),
              role: 'ai',
              text: `✨ **${targetPersona.toUpperCase()} Mode Enabled!** अब आपको कृषि और फील्ड के अनुसार पर्सनलाइज़्ड जानकारी मिलेगी।`,
              timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            },
          ]);
        }
      } catch (e) {
        console.error(e);
      }
    },
    [userId, fetchProfile, effectiveApiBase]
  );

  // ── Clear chat ──
  const clearChat = useCallback(async () => {
    if (window.speechSynthesis) window.speechSynthesis.cancel();
    setSpeakingMsgId(null);
    try {
      await fetch(`${effectiveApiBase}/chat/sessions/${sessionId}`, { method: 'DELETE' });
    } catch (e) {}
    setSessionId('sess_' + Math.random().toString(36).substring(2, 9));
    setPersona('general');
    setMessages([
      {
        id: 'welcome',
        role: 'ai',
        text: 'सेशन रीसेट हो गया है! आप क्या जानना चाहते हैं?',
        suggestions: [
          'kya Lucknow me parso baarish hogi?',
          'Delhi se Gurgaon commute weather',
          'Wheat crop pesticide spray advice',
        ],
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      },
    ]);
  }, [sessionId, effectiveApiBase]);

  // ── Render ──
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100vh',
        width: '100vw',
        padding: 12,
        background: 'radial-gradient(ellipse at top, #0f172a 0%, #020617 100%)',
        boxSizing: 'border-box',
      }}
    >
      {/* Live WebSocket Alert Banners */}
      {alerts.map((alert) => (
        <AlertBanner key={alert.id} alert={alert} onDismiss={() => dismissAlert(alert.id)} />
      ))}

      {/* Header */}
      <Header
        persona={persona}
        autoSpeak={autoSpeak}
        language={language}
        showProfile={showProfile}
        profile={profile}
        serverTarget={serverTarget}
        onToggleServerTarget={() => setServerTarget(serverTarget === 'render' ? 'local' : 'render')}
        onToggleAutoSpeak={() => setAutoSpeak(!autoSpeak)}
        onToggleLanguage={() => setLanguage(language === 'hi' ? 'en' : 'hi')}
        onToggleProfile={() => setShowProfile(!showProfile)}
        onClearChat={clearChat}
      />

      {/* Main Layout */}
      <div
        className="app-grid"
        style={{
          display: 'grid',
          gridTemplateColumns: showProfile ? '1fr 300px' : '1fr',
          gap: 12,
          flex: 1,
          minHeight: 0,
        }}
      >
        {/* Chat Stream */}
        <div className="glass-panel" style={{ display: 'flex', flexDirection: 'column', padding: 16, minHeight: 0 }}>
          <div
            style={{
              flex: 1,
              overflowY: 'auto',
              paddingRight: 6,
              display: 'flex',
              flexDirection: 'column',
              gap: 16,
            }}
          >
            {messages.map((msg) => (
              <ChatBubble
                key={msg.id}
                msg={msg}
                speakingMsgId={speakingMsgId}
                isListening={isListening}
                onSpeak={speakText}
                onToggleListening={toggleListening}
                onPersonaAction={handlePersonaAction}
                onSuggestionClick={handleSendMessage}
              />
            ))}

            {/* Loading skeleton */}
            {loading && (
              <div className="shimmer-container">
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--accent-cyan)', fontSize: '0.85rem', marginBottom: 4 }}>
                  <Sparkles className="animate-spin" size={16} /> Megha is analyzing real-time data & crafting advice...
                </div>
                <div className="shimmer-line" />
                <div className="shimmer-line" />
                <div className="shimmer-line" />
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          {/* Quick Intent Test Chips */}
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 8, marginBottom: 4 }}>
            {[
              { label: '🚗 Delhi se Gurgaon Commute', query: 'mujhe shaam ko Delhi se Gurgaon jana h kya road pe traffic ya paani bharega?' },
              { label: '🌾 Wheat Spraying Advice', query: 'Kal subah meri gehu ki fasal par pesticide spray karna theek rahega?' },
              { label: '🏙️ Outdoor Work Risk', query: 'Kal Delhi me outdoor construction work ke liye weather safe hai?' },
              { label: '📈 August Climate Trends', query: 'Delhi me August ke mahine me pichle saalon me kitni barish hoti rhi h?' },
            ].map((chip, idx) => (
              <button
                key={idx}
                onClick={() => handleSendMessage(chip.query)}
                className="chip-btn"
                style={{ fontSize: '0.75rem', padding: '4px 10px', background: 'rgba(255,255,255,0.03)' }}
              >
                {chip.label}
              </button>
            ))}
          </div>

          {/* Input */}
          <ChatInput
            inputText={inputText}
            setInputText={setInputText}
            isListening={isListening}
            loading={loading}
            language={language}
            onSend={() => handleSendMessage()}
            onToggleListening={toggleListening}
          />
        </div>

        {/* Profile Panel */}
        {showProfile && <ProfilePanel profile={profile} />}
      </div>
    </div>
  );
}
