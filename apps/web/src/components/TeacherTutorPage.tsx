"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  runTransaction,
  serverTimestamp,
  Timestamp,
  where,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { Room, RoomEvent, Track, type RemoteParticipant } from "livekit-client";
import {
  AlertTriangle,
  Bot,
  Headphones,
  Menu,
  MessageSquare,
  Mic,
  MicOff,
  Presentation,
  RefreshCw,
  Send,
  Settings2,
  Square,
  Volume2,
  X,
} from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import {
  TeacherAccessPrompt,
  TeacherShell,
  openTeacherMobileMenu,
} from "@/components/TeacherDashboardHome";
import { auth, db, functions } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import {
  TeacherTutorWhiteboard,
  type TutorWhiteboardProject,
} from "@/components/TeacherTutorWhiteboard";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type Mode = "voice" | "text";
type Voice = "blake" | "jacqueline" | "robyn";
type Background = "none" | "forest" | "city" | "office" | "hold_music";
type ConnectionState =
  | "idle"
  | "connecting"
  | "connected"
  | "disconnected"
  | "error";
type ChatMessage = { id: string; sender: "user" | "ai"; content: string };
type TutorToken = {
  success: boolean;
  livekitUrl: string;
  token: string;
  roomName: string;
  userRole?: string;
  interactionMode?: string;
  voicePreference?: string;
  backgroundPreference?: string;
};

const enc = new TextEncoder();
const dec = new TextDecoder();

export function TeacherTutorPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [enabled, setEnabled] = useState(false);
  const [summary, setSummary] = useState({
    displayName: "Teacher",
    firstName: "Teacher",
    initials: "TE",
  });
  const [mode, setMode] = useState<Mode | null>(null);
  const [voice, setVoice] = useState<Voice>("blake");
  const [background, setBackground] = useState<Background>("forest");
  const [connection, setConnection] = useState<ConnectionState>("idle");
  const [roomName, setRoomName] = useState("");
  const [agentJoined, setAgentJoined] = useState(false);
  const [micEnabled, setMicEnabled] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState("");
  const [whiteboardOpen, setWhiteboardOpen] = useState(false);
  const [drawingEnabled, setDrawingEnabled] = useState(true);
  const [whiteboard, setWhiteboard] = useState<TutorWhiteboardProject>({
    strokes: [],
    texts: [],
    version: 2,
  });
  const roomRef = useRef<Room | null>(null);
  const whiteboardRef = useRef(whiteboard);
  useEffect(() => {
    whiteboardRef.current = whiteboard;
  }, [whiteboard]);

  const endSession = useCallback(async () => {
    const room = roomRef.current;
    roomRef.current = null;
    const endingRoom = roomName;
    setRoomName("");
    setAgentJoined(false);
    setMicEnabled(false);
    setConnection("disconnected");
    if (room) {
      try {
        await room.localParticipant.setMicrophoneEnabled(false);
      } catch {}
      await room.disconnect().catch(() => undefined);
      room.removeAllListeners();
    }
    if (endingRoom)
      await httpsCallable(
        functions,
        "endAITutorSession",
      )({ roomName: endingRoom }).catch(() => undefined);
  }, [roomName]);

  useEffect(
    () =>
      onAuthStateChanged(auth, async (user) => {
        if (!user) {
          setAccess("signedOut");
          return;
        }
        if (!(await isCurrentUserTeacher(user))) {
          setAccess("denied");
          return;
        }
        const record = await getCurrentUserRecord(user);
        const displayName =
          text(record?.fullName) ||
          text(record?.displayName) ||
          `${text(record?.first_name)} ${text(record?.last_name)}`.trim() ||
          user.displayName ||
          user.email ||
          "Teacher";
        setSummary({
          displayName,
          firstName: displayName.split(/\s+/)[0] || "Teacher",
          initials:
            displayName
              .split(/\s+/)
              .slice(0, 2)
              .map((part) => part[0])
              .join("")
              .toUpperCase() || "TE",
        });
        setEnabled(record?.ai_tutor_enabled === true);
        const storedMode = window.localStorage.getItem(
          "ai_tutor.interaction_mode",
        );
        const storedVoice = window.localStorage.getItem(
          "ai_tutor.voice_preference",
        );
        const storedBackground = window.localStorage.getItem(
          "ai_tutor.background_preference",
        );
        if (storedMode === "voice" || storedMode === "text")
          setMode(storedMode);
        if (
          storedVoice === "blake" ||
          storedVoice === "jacqueline" ||
          storedVoice === "robyn"
        )
          setVoice(storedVoice);
        if (
          ["none", "forest", "city", "office", "hold_music"].includes(
            storedBackground || "",
          )
        )
          setBackground(storedBackground as Background);
        setAccess("allowed");
      }),
    [],
  );

  useEffect(
    () => () => {
      const room = roomRef.current;
      if (room) {
        void room.disconnect();
        room.removeAllListeners();
      }
    },
    [],
  );

  async function startSession(selectedMode: Mode = mode || "voice") {
    if (!enabled) {
      setError(
        "AI Tutor access has not been enabled for your account. Please contact an administrator.",
      );
      return;
    }
    await endSession();
    setMode(selectedMode);
    setConnection("connecting");
    setError("");
    setMessages([]);
    window.localStorage.setItem("ai_tutor.interaction_mode", selectedMode);
    window.localStorage.setItem("ai_tutor.voice_preference", voice);
    window.localStorage.setItem("ai_tutor.background_preference", background);
    let requestedRoomName = "";
    try {
      const timezone =
        Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
      const response = await httpsCallable<Record<string, unknown>, TutorToken>(
        functions,
        "getAITutorToken",
      )({
        interactionMode: selectedMode,
        aiVoice: voice,
        aiBackground: background,
        clientTimezone: timezone,
        clientLocalIso: new Date().toISOString(),
        clientNowEpochMs: Date.now(),
      });
      if (!response.data.success)
        throw new Error("Failed to start AI Tutor session");
      requestedRoomName = response.data.roomName;
      setRoomName(requestedRoomName);
      const room = new Room({ adaptiveStream: true, dynacast: true });
      attachRoomListeners(room);
      await room.connect(response.data.livekitUrl, response.data.token, {
        autoSubscribe: true,
      });
      roomRef.current = room;
      setConnection("connected");
      if (selectedMode === "voice") {
        try {
          await room.startAudio();
          await room.localParticipant.setMicrophoneEnabled(true);
          setMicEnabled(true);
        } catch {
          setMicEnabled(false);
          setError(
            "Microphone permission is required for voice mode. You can switch to text mode in Tutor preferences.",
          );
        }
      }
      setAgentJoined(room.remoteParticipants.size > 0);
    } catch (cause) {
      if (requestedRoomName)
        await httpsCallable(
          functions,
          "endAITutorSession",
        )({ roomName: requestedRoomName }).catch(() => undefined);
      setRoomName("");
      setConnection("error");
      setError(tutorError(cause));
    }
  }

  function attachRoomListeners(room: Room) {
    room.on(RoomEvent.ParticipantConnected, (participant) => {
      setAgentJoined(true);
      void publishWhiteboard(whiteboardRef.current, [participant.identity]);
    });
    room.on(RoomEvent.ParticipantDisconnected, () =>
      setAgentJoined(room.remoteParticipants.size > 0),
    );
    room.on(RoomEvent.Disconnected, () => {
      setAgentJoined(false);
      setConnection("disconnected");
    });
    room.on(RoomEvent.TrackSubscribed, (track) => {
      if (track.kind === Track.Kind.Audio) setAgentJoined(true);
    });
    room.on(RoomEvent.DataReceived, (payload, participant, _kind, topic) =>
      handleData(payload, participant, topic),
    );
  }

  function handleData(
    payload: Uint8Array,
    participant?: RemoteParticipant,
    topic?: string,
  ) {
    if (topic === "ai_tutor_whiteboard" || topic === "alluwal_whiteboard") {
      try {
        const message = JSON.parse(dec.decode(payload)) as Record<
          string,
          unknown
        >;
        const type = text(message.type);
        const data = objectValue(message.payload);
        if (type === "project") {
          const next = normalizeWhiteboard(data);
          setWhiteboard(next);
          setWhiteboardOpen(true);
        } else if (type === "student_drawing_permission")
          setDrawingEnabled(data.enabled === true);
      } catch {}
      return;
    }
    if (topic === "ai_tutor_teacher_actions") {
      void handleTeacherAction(payload);
      return;
    }
    if (topic !== "ai_tutor_transcription" && topic !== "ai_tutor_chat_text")
      return;
    try {
      const raw = dec.decode(payload);
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const content =
        text(parsed.text) ||
        text(parsed.content) ||
        text(parsed.transcript) ||
        raw;
      const senderRaw = text(parsed.sender).toLowerCase();
      const sender: "user" | "ai" =
        senderRaw === "user" || participant?.identity === auth.currentUser?.uid
          ? "user"
          : "ai";
      if (content)
        setMessages((current) => [
          ...current,
          { id: `${Date.now()}-${current.length}`, sender, content },
        ]);
    } catch {
      const content = dec.decode(payload).trim();
      if (content)
        setMessages((current) => [
          ...current,
          { id: `${Date.now()}-${current.length}`, sender: "ai", content },
        ]);
    }
  }

  async function sendMessage() {
    const content = draft.trim();
    const room = roomRef.current;
    if (!content || !room || connection !== "connected") return;
    setDraft("");
    setMessages((current) => [
      ...current,
      { id: `${Date.now()}-user`, sender: "user", content },
    ]);
    try {
      await room.localParticipant.publishData(
        enc.encode(
          JSON.stringify({
            type: "chat_text",
            text: content,
            content,
            sender: "user",
            timestamp: new Date().toISOString(),
          }),
        ),
        { reliable: true, topic: "ai_tutor_chat_text" },
      );
    } catch {
      setDraft(content);
      setError(
        "Your message could not be sent. It has been restored so you can retry.",
      );
    }
  }

  async function publishWhiteboard(
    project: TutorWhiteboardProject,
    destinationIdentities?: string[],
  ) {
    const room = roomRef.current;
    if (!room) return;
    setWhiteboard(project);
    whiteboardRef.current = project;
    const payload = enc.encode(
      JSON.stringify({ type: "project", payload: project }),
    );
    for (const topic of ["ai_tutor_whiteboard", "alluwal_whiteboard"])
      await room.localParticipant
        .publishData(payload, { reliable: true, topic, destinationIdentities })
        .catch(() => undefined);
  }

  async function handleTeacherAction(payload: Uint8Array) {
    const room = roomRef.current;
    if (!room) return;
    let requestId = "";
    let action = "";
    try {
      const envelope = JSON.parse(dec.decode(payload)) as Record<
        string,
        unknown
      >;
      if (text(envelope.type) !== "teacher_action") return;
      const data = objectValue(envelope.payload);
      requestId = text(data.requestId);
      action = text(data.action).toLowerCase();
      const args = objectValue(data.args);
      if (!requestId || !action) return;
      const result = await executeTeacherAction(action, args);
      await room.localParticipant.publishData(
        enc.encode(
          JSON.stringify({
            type: "teacher_action_result",
            payload: {
              requestId,
              action,
              ...result,
              timestamp: new Date().toISOString(),
            },
          }),
        ),
        { reliable: true, topic: "ai_tutor_teacher_action_results" },
      );
      setMessages((current) => [
        ...current,
        { id: `${Date.now()}-action`, sender: "ai", content: result.message },
      ]);
    } catch {
      if (requestId && action)
        await room.localParticipant
          .publishData(
            enc.encode(
              JSON.stringify({
                type: "teacher_action_result",
                payload: {
                  requestId,
                  action,
                  success: false,
                  message:
                    "The requested teacher action could not be completed.",
                  timestamp: new Date().toISOString(),
                },
              }),
            ),
            { reliable: true, topic: "ai_tutor_teacher_action_results" },
          )
          .catch(() => undefined);
    }
  }

  async function toggleMicrophone() {
    const room = roomRef.current;
    if (!room) return;
    try {
      const next = !micEnabled;
      await room.localParticipant.setMicrophoneEnabled(next);
      setMicEnabled(next);
      setError("");
    } catch {
      setError(
        "Could not change microphone access. Check your browser permissions.",
      );
    }
  }

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;
  return (
    <TeacherShell
      activeLabel="AI Tutor"
      breadcrumb="Learning / AI Tutor"
      summary={summary}
    >
      <div className="flex min-h-full flex-col bg-[#F8FAFC]">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] bg-white px-4 py-3">
          <button
            type="button"
            aria-label="Open teacher menu"
            onClick={openTeacherMobileMenu}
            className="grid h-11 w-11 place-items-center rounded-xl lg:hidden"
          >
            <Menu size={22} />
          </button>
          <Bot className="text-[#0E72ED]" />
          <h1 className="min-w-0 flex-1 truncate text-lg font-extrabold">
            AI Tutor
          </h1>
          {connection === "connected" ? (
            <button
              type="button"
              aria-label="Open AI Tutor whiteboard"
              onClick={() => setWhiteboardOpen(true)}
              className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]"
            >
              <Presentation size={21} />
            </button>
          ) : null}
          <button
            type="button"
            aria-label="Tutor preferences"
            onClick={() => setSettingsOpen(true)}
            className="grid h-11 w-11 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]"
          >
            <Settings2 size={21} />
          </button>
          {connection === "connected" ? (
            <button
              type="button"
              onClick={() => void endSession()}
              className="inline-flex min-h-11 items-center gap-2 rounded-xl border border-red-200 px-3 font-bold text-red-600"
            >
              <Square size={16} />
              End
            </button>
          ) : null}
        </header>
        <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col p-4 sm:p-6">
          {!enabled ? (
            <ErrorCard message="AI Tutor access has not been enabled for your account. Please contact an administrator." />
          ) : connection === "idle" || connection === "disconnected" ? (
            <ModeSelection
              voice={voice}
              background={background}
              onSelect={(next) => void startSession(next)}
            />
          ) : connection === "connecting" ? (
            <div className="grid flex-1 place-items-center text-center">
              <div>
                <RefreshCw
                  className="mx-auto animate-spin text-[#0E72ED]"
                  size={42}
                />
                <h2 className="mt-5 text-xl font-extrabold">
                  Connecting to Alluwal…
                </h2>
                <p className="mt-2 text-[#64748B]">
                  Preparing your private tutor session.
                </p>
              </div>
            </div>
          ) : connection === "error" ? (
            <div className="grid flex-1 place-items-center">
              <ErrorCard message={error} onRetry={() => void startSession()} />
            </div>
          ) : (
            <ConnectedView
              mode={mode || "voice"}
              agentJoined={agentJoined}
              micEnabled={micEnabled}
              messages={messages}
              draft={draft}
              error={error}
              onDraft={setDraft}
              onSend={() => void sendMessage()}
              onToggleMic={() => void toggleMicrophone()}
            />
          )}
        </main>
        {settingsOpen ? (
          <TutorSettings
            mode={mode || "voice"}
            voice={voice}
            background={background}
            connected={connection === "connected"}
            onClose={() => setSettingsOpen(false)}
            onApply={(nextMode, nextVoice, nextBackground, restart) => {
              setMode(nextMode);
              setVoice(nextVoice);
              setBackground(nextBackground);
              window.localStorage.setItem(
                "ai_tutor.interaction_mode",
                nextMode,
              );
              window.localStorage.setItem(
                "ai_tutor.voice_preference",
                nextVoice,
              );
              window.localStorage.setItem(
                "ai_tutor.background_preference",
                nextBackground,
              );
              setSettingsOpen(false);
              if (restart) void startSession(nextMode);
            }}
          />
        ) : null}
        {whiteboardOpen ? (
          <TeacherTutorWhiteboard
            project={whiteboard}
            drawingEnabled={drawingEnabled}
            onChange={(project) => void publishWhiteboard(project)}
            onClose={() => setWhiteboardOpen(false)}
          />
        ) : null}
      </div>
    </TeacherShell>
  );
}

function ModeSelection({
  voice,
  background,
  onSelect,
}: {
  voice: Voice;
  background: Background;
  onSelect: (mode: Mode) => void;
}) {
  return (
    <div className="grid flex-1 place-items-center">
      <div className="w-full max-w-xl text-center">
        <span className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-gradient-to-br from-[#0E72ED] to-[#6366F1] text-white">
          <Bot size={42} />
        </span>
        <h2 className="mt-5 text-2xl font-extrabold">
          How would you like to interact?
        </h2>
        <p className="mt-2 text-[#64748B]">
          Choose your preferred way to communicate with Alluwal.
        </p>
        <div className="mt-5 rounded-2xl border border-[#E2E8F0] bg-white p-4 text-left text-sm text-[#475569]">
          <p>
            <strong>Voice:</strong> {voiceLabel(voice)}
          </p>
          <p className="mt-1">
            <strong>Background:</strong> {backgroundLabel(background)}
          </p>
        </div>
        <div className="mt-5 grid gap-3 sm:grid-cols-2">
          <ModeButton
            icon={Mic}
            title="Voice"
            subtitle="Speak and listen to Alluwal"
            color="emerald"
            onClick={() => onSelect("voice")}
          />
          <ModeButton
            icon={MessageSquare}
            title="Text"
            subtitle="Type messages to Alluwal"
            color="blue"
            onClick={() => onSelect("text")}
          />
        </div>
      </div>
    </div>
  );
}
function ModeButton({
  icon: Icon,
  title,
  subtitle,
  color,
  onClick,
}: {
  icon: typeof Mic;
  title: string;
  subtitle: string;
  color: "emerald" | "blue";
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex min-h-24 items-center gap-4 rounded-2xl border border-[#E2E8F0] bg-white p-4 text-left shadow-sm hover:border-[#0E72ED]"
    >
      <span
        className={`grid h-14 w-14 shrink-0 place-items-center rounded-full ${color === "emerald" ? "bg-emerald-100 text-emerald-600" : "bg-blue-100 text-blue-600"}`}
      >
        <Icon size={27} />
      </span>
      <span>
        <strong className="block text-lg text-[#111827]">{title}</strong>
        <span className="text-sm text-[#64748B]">{subtitle}</span>
      </span>
    </button>
  );
}
function ConnectedView({
  mode,
  agentJoined,
  micEnabled,
  messages,
  draft,
  error,
  onDraft,
  onSend,
  onToggleMic,
}: {
  mode: Mode;
  agentJoined: boolean;
  micEnabled: boolean;
  messages: ChatMessage[];
  draft: string;
  error: string;
  onDraft: (value: string) => void;
  onSend: () => void;
  onToggleMic: () => void;
}) {
  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <div className="mb-4 flex items-center gap-3 rounded-2xl border border-[#E2E8F0] bg-white p-4">
        <span
          className={`relative grid h-12 w-12 place-items-center rounded-full ${agentJoined ? "bg-emerald-100 text-emerald-600" : "bg-amber-100 text-amber-600"}`}
        >
          <Headphones size={24} />
          {agentJoined ? (
            <span className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-white bg-emerald-500" />
          ) : null}
        </span>
        <div className="min-w-0 flex-1">
          <p className="font-extrabold">
            {agentJoined ? "Alluwal is ready" : "Waiting for the tutor agent"}
          </p>
          <p className="text-sm text-[#64748B]">
            {mode === "voice"
              ? micEnabled
                ? "Listening — speak now"
                : "Microphone is off"
              : "Text conversation"}
          </p>
        </div>
        {mode === "voice" ? (
          <button
            type="button"
            aria-label={
              micEnabled ? "Turn microphone off" : "Turn microphone on"
            }
            onClick={onToggleMic}
            className={`grid h-12 w-12 place-items-center rounded-full ${micEnabled ? "bg-[#0E72ED] text-white" : "bg-red-100 text-red-600"}`}
          >
            {micEnabled ? <Mic size={22} /> : <MicOff size={22} />}
          </button>
        ) : (
          <Volume2 className="text-[#64748B]" />
        )}
      </div>
      {error ? (
        <p
          role="alert"
          className="mb-4 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm font-semibold text-amber-900"
        >
          {error}
        </p>
      ) : null}
      <div
        className="min-h-64 flex-1 space-y-3 overflow-y-auto rounded-2xl border border-[#E2E8F0] bg-white p-4"
        aria-label="Tutor conversation"
      >
        {messages.length ? (
          messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${message.sender === "user" ? "justify-end" : "justify-start"}`}
            >
              <p
                className={`max-w-[84%] rounded-2xl px-4 py-3 text-sm ${message.sender === "user" ? "bg-[#0E72ED] text-white" : "bg-[#F1F5F9] text-[#334155]"}`}
              >
                {message.content}
              </p>
            </div>
          ))
        ) : (
          <div className="grid h-full min-h-56 place-items-center text-center text-[#94A3B8]">
            <div>
              <Bot className="mx-auto" size={34} />
              <p className="mt-3">Your conversation will appear here.</p>
            </div>
          </div>
        )}
      </div>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          onSend();
        }}
        className="mt-4 flex gap-2"
      >
        <label className="sr-only" htmlFor="tutor-message">
          Message Alluwal
        </label>
        <input
          id="tutor-message"
          value={draft}
          onChange={(event) => onDraft(event.target.value)}
          disabled={!agentJoined}
          placeholder={agentJoined ? "Type a message…" : "Waiting for agent…"}
          className="h-12 min-w-0 flex-1 rounded-xl border border-[#CBD5E1] bg-white px-4 outline-none focus:border-[#0E72ED] disabled:bg-[#F1F5F9]"
        />
        <button
          type="submit"
          disabled={!draft.trim() || !agentJoined}
          aria-label="Send tutor message"
          className="grid h-12 w-12 place-items-center rounded-xl bg-[#0E72ED] text-white disabled:opacity-40"
        >
          <Send size={20} />
        </button>
      </form>
    </div>
  );
}
function TutorSettings({
  mode,
  voice,
  background,
  connected,
  onClose,
  onApply,
}: {
  mode: Mode;
  voice: Voice;
  background: Background;
  connected: boolean;
  onClose: () => void;
  onApply: (
    mode: Mode,
    voice: Voice,
    background: Background,
    restart: boolean,
  ) => void;
}) {
  const [nextMode, setNextMode] = useState(mode);
  const [nextVoice, setNextVoice] = useState(voice);
  const [nextBackground, setNextBackground] = useState(background);
  return (
    <section
      className="fixed inset-0 z-[90] grid items-end bg-black/45 sm:place-items-center"
      role="dialog"
      aria-modal="true"
      aria-label="Tutor preferences"
    >
      <div className="w-full rounded-t-3xl bg-white p-6 shadow-2xl sm:max-w-md sm:rounded-3xl">
        <header className="flex items-center">
          <h2 className="flex-1 text-xl font-extrabold">Tutor preferences</h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close tutor preferences"
            className="grid h-10 w-10 place-items-center"
          >
            <X size={20} />
          </button>
        </header>
        <label className="mt-5 block text-sm font-bold">
          Interaction mode
          <select
            value={nextMode}
            onChange={(event) => setNextMode(event.target.value as Mode)}
            className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3"
          >
            <option value="voice">Voice</option>
            <option value="text">Text</option>
          </select>
        </label>
        <label className="mt-4 block text-sm font-bold">
          Tutor voice
          <select
            value={nextVoice}
            onChange={(event) => setNextVoice(event.target.value as Voice)}
            className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3"
          >
            <option value="blake">Blake (Default)</option>
            <option value="jacqueline">Jacqueline</option>
            <option value="robyn">Robyn</option>
          </select>
        </label>
        <label className="mt-4 block text-sm font-bold">
          Background sound
          <select
            value={nextBackground}
            onChange={(event) =>
              setNextBackground(event.target.value as Background)
            }
            className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3"
          >
            {(
              ["none", "forest", "city", "office", "hold_music"] as Background[]
            ).map((item) => (
              <option key={item} value={item}>
                {backgroundLabel(item)}
              </option>
            ))}
          </select>
        </label>
        {connected ? (
          <p className="mt-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-900">
            Applying changes restarts the current tutor session.
          </p>
        ) : null}
        <button
          type="button"
          onClick={() =>
            onApply(nextMode, nextVoice, nextBackground, connected)
          }
          className="mt-5 min-h-11 w-full rounded-xl bg-[#0E72ED] font-bold text-white"
        >
          Apply preferences
        </button>
      </div>
    </section>
  );
}
function ErrorCard({
  message,
  onRetry,
}: {
  message: string;
  onRetry?: () => void;
}) {
  return (
    <div className="w-full max-w-lg rounded-2xl border border-red-200 bg-red-50 p-6 text-center text-red-900">
      <AlertTriangle className="mx-auto" size={34} />
      <h2 className="mt-3 text-lg font-extrabold">AI Tutor unavailable</h2>
      <p className="mt-2 text-sm">{message}</p>
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-5 min-h-11 rounded-xl bg-red-600 px-5 font-bold text-white"
        >
          Try Again
        </button>
      ) : null}
    </div>
  );
}
function voiceLabel(value: Voice) {
  return value === "blake"
    ? "Blake (Default)"
    : value === "jacqueline"
      ? "Jacqueline"
      : "Robyn";
}
function backgroundLabel(value: Background) {
  return value === "hold_music"
    ? "Music"
    : value[0].toUpperCase() + value.slice(1);
}
function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
function tutorError(cause: unknown) {
  const code =
    typeof cause === "object" && cause && "code" in cause
      ? String((cause as { code: unknown }).code)
      : "";
  const message = cause instanceof Error ? cause.message : "";
  if (
    code.includes("permission-denied") ||
    message.toLowerCase().includes("permission")
  )
    return "AI Tutor access has not been enabled for your account. Please contact an administrator.";
  if (code.includes("unavailable"))
    return "AI Tutor is not available at this time. Please try again later.";
  if (code.includes("network"))
    return "You appear to be offline. Check your connection and try again.";
  return "Could not connect to AI Tutor. Please try again.";
}

export async function executeTeacherAction(action: string, args: Record<string, unknown>): Promise<{ success: boolean; message: string; data?: Record<string, unknown> }> {
  if (action === "clock_in") return executeTutorClockIn(args);
  if (action === "reschedule_shift" || action === "reschedule_shift_future") return executeTutorReschedule(action, args);
  return { success: false, message: `Unsupported teacher action: ${action}` };
}

async function executeTutorClockIn(args: Record<string, unknown>) {
  const user = auth.currentUser;
  if (!user) return { success: false, message: "Unable to clock in because the user is not authenticated." };
  let shiftId = firstText(args, ["shiftId", "shift_id"]);
  if (!shiftId) {
    const snapshot = await getDocs(query(collection(db, "teaching_shifts"), where("teacher_id", "==", user.uid), limit(200)));
    const now = Date.now();
    const candidate = snapshot.docs.map((item) => ({ id: item.id, data: item.data() as Record<string, unknown>, start: dateValue(item.data().shift_start ?? item.data().start_time), end: dateValue(item.data().shift_end ?? item.data().end_time) })).filter((item) => item.start && item.end && now >= item.start.getTime() - 60_000 && now <= item.end.getTime()).sort((a, b) => (a.start?.getTime() || 0) - (b.start?.getTime() || 0))[0];
    shiftId = candidate?.id || "";
  }
  if (!shiftId) return { success: false, message: "No valid shift is available to clock in right now." };
  const shiftRef = doc(db, "teaching_shifts", shiftId);
  const shiftSnap = await getDoc(shiftRef);
  if (!shiftSnap.exists() || text(shiftSnap.data().teacher_id) !== user.uid) return { success: false, message: "Unable to find the requested shift for this teacher account." };
  const shift = shiftSnap.data() as Record<string, unknown>;
  const start = dateValue(shift.shift_start ?? shift.start_time);
  const end = dateValue(shift.shift_end ?? shift.end_time);
  const now = new Date();
  if (!start || !end || now.getTime() < start.getTime() - 60_000 || now > end) return { success: false, message: "The requested shift is not available for clock-in right now." };
  const location = await browserLocation();
  if (!location) return { success: false, message: "Unable to get your location for clock in. Please enable location and try again." };
  const title = text(shift.display_name) || text(shift.title) || text(shift.custom_name) || "Teaching Shift";
  const studentNames = stringList(shift.student_names ?? shift.studentNames);
  const hourlyRate = numberValue(shift.hourly_rate ?? shift.hourlyRate);
  const timesheetRef = doc(collection(db, "timesheet_entries"));
  try {
    await runTransaction(db, async (transaction) => {
      const fresh = await transaction.get(shiftRef);
      if (!fresh.exists()) throw new Error("This shift is no longer available.");
      const current = fresh.data() as Record<string, unknown>;
      if (dateValue(current.clock_in_time ?? current.clockInTime) && !dateValue(current.clock_out_time ?? current.clockOutTime)) throw new Error("You are already clocked in to this shift.");
      transaction.set(timesheetRef, { teacher_id: user.uid, teacher_email: user.email, teacher_name: text(shift.teacher_name) || user.displayName || user.email, shift_id: shiftId, shift_category: text(shift.shift_category ?? shift.category) || "teaching", date: formatDate(now), student_name: studentNames.join(", ") || title, start_time: formatClock(now), end_time: "", total_hours: "00:00", hourly_rate: hourlyRate, pay_rate_source: hourlyRate > 0 ? "teaching_shift_rate" : "timesheet_fallback_rate", is_subject_billable: true, description: `Teaching session: ${text(shift.subject) || title} - ${title}`, status: "pending", source: "shift_clock_in", completion_method: "pending", clock_in_timestamp: Timestamp.fromDate(now), clock_in_status: clockDeviationStatus(now, start), clock_in_deviation_minutes: Math.round((now.getTime() - start.getTime()) / 60_000), clock_in_platform: "web", clock_in_latitude: location.latitude, clock_in_longitude: location.longitude, clock_in_address: "Browser location", clock_in_neighborhood: "", shift_title: title, scheduled_start: Timestamp.fromDate(start), scheduled_end: Timestamp.fromDate(end), scheduled_duration_minutes: Math.max(0, Math.round((end.getTime() - start.getTime()) / 60_000)), created_at: serverTimestamp(), updated_at: serverTimestamp() });
      transaction.update(shiftRef, { last_modified: Timestamp.fromDate(now), status: "active", clock_out_time: null, clock_in_time: Timestamp.fromDate(now), last_clock_in_platform: "web" });
    });
    return { success: true, message: `Successfully clocked in to ${title}`, data: { shiftId, title } };
  } catch (cause) { return { success: false, message: cause instanceof Error ? cause.message : "Unable to clock in." }; }
}

async function executeTutorReschedule(action: string, args: Record<string, unknown>) {
  const confirmed = boolArg(args, ["confirmed", "confirm", "isConfirmed"]);
  if (confirmed !== true) return { success: false, message: "Please confirm the change explicitly before I update your schedule." };
  const rawScope = firstText(args, ["scope", "rescheduleScope", "reschedule_scope"]);
  const scope = action === "reschedule_shift_future" || ["future", "all_future", "all-future", "series", "recurring"].includes(rawScope.toLowerCase()) ? "future" : ["single", "today", "today_only", "today-only", "one_time", "one-time"].includes(rawScope.toLowerCase()) ? "single" : "";
  if (!scope) return { success: false, message: "Please confirm if this change is for today only or for all future classes." };
  const shiftId = firstText(args, ["shiftId", "shift_id"]);
  const newStart = firstText(args, ["newStartTime", "new_start_time", "newStartIso", "new_start_iso"]);
  const newEnd = firstText(args, ["newEndTime", "new_end_time", "newEndIso", "new_end_iso"]);
  const newStartLocal = firstText(args, ["newStartLocal", "new_start_local", "newStartLocalIso", "new_start_local_iso"]);
  const newEndLocal = firstText(args, ["newEndLocal", "new_end_local", "newEndLocalIso", "new_end_local_iso"]);
  if (!(newStart && newEnd) && !(newStartLocal && newEndLocal)) return { success: false, message: "Missing new class time. Please provide a complete start and end time." };
  if (!shiftId && scope === "single") return { success: false, message: "Unable to find the class to reschedule. Please specify the class." };
  const payload: Record<string, unknown> = { confirm: true, scope };
  for (const [target, keys] of Object.entries({ shiftId: ["shiftId", "shift_id"], timezone: ["timezone", "teacherTimezone", "teacher_timezone", "userTimezone", "user_timezone"], reason: ["reason"], studentId: ["studentId", "student_id"], studentName: ["studentName", "student_name"], applyFromDate: ["applyFromDate", "apply_from_date", "targetDateLocal", "target_date_local", "classDate", "class_date", "date"] })) { const value = firstText(args, keys); if (value) payload[target] = value; }
  if (newStartLocal && newEndLocal) { payload.newStartLocal = newStartLocal; payload.newEndLocal = newEndLocal; } else { payload.newStartTime = newStart; payload.newEndTime = newEnd; }
  try { const response = await httpsCallable<Record<string, unknown>, Record<string, unknown>>(functions, scope === "future" ? "teacherRescheduleFutureShifts" : "teacherRescheduleShift")(payload); const success = response.data.success === true; return { success, message: text(response.data.message) || (success ? "Shift rescheduled successfully." : "Unable to reschedule shift."), data: { scope, shiftId: text(payload.shiftId) } }; }
  catch (cause) { return { success: false, message: `Unable to reschedule class: ${callableMessage(cause)}` }; }
}

export function normalizeWhiteboard(data: Record<string, unknown>): TutorWhiteboardProject { const strokes = Array.isArray(data.strokes) ? data.strokes.map((raw) => objectValue(raw)).map((stroke) => ({ id: text(stroke.id) || `${Date.now()}-${Math.random()}`, points: Array.isArray(stroke.points) ? stroke.points.map((raw) => objectValue(raw)).map((point) => ({ x: numberValue(point.x), y: numberValue(point.y) })) : [], color: numberValue(stroke.color) || 0xff111827, strokeWidth: numberValue(stroke.strokeWidth) || 3, normalized: stroke.normalized === true })) : []; return { strokes, texts: Array.isArray(data.texts) ? data.texts.map(objectValue) : [], version: 2 }; }
function objectValue(value: unknown): Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : {}; }
function firstText(source: Record<string, unknown>, keys: string[]) { for (const key of keys) { const value = text(source[key]); if (value) return value; } return ""; }
function boolArg(source: Record<string, unknown>, keys: string[]) { for (const key of keys) { const value = source[key]; if (typeof value === "boolean") return value; if (["true", "yes", "y", "1"].includes(text(value).toLowerCase())) return true; if (["false", "no", "n", "0"].includes(text(value).toLowerCase())) return false; } return null; }
function dateValue(value: unknown): Date | null { if (value instanceof Date) return value; if (value instanceof Timestamp) return value.toDate(); if (typeof value === "object" && value && "toDate" in value && typeof (value as { toDate?: unknown }).toDate === "function") return (value as { toDate: () => Date }).toDate(); if (typeof value === "string" || typeof value === "number") { const date = new Date(value); return Number.isNaN(date.getTime()) ? null : date; } return null; }
function numberValue(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : Number(value) || 0; }
function stringList(value: unknown) { return Array.isArray(value) ? value.map(text).filter(Boolean) : text(value) ? [text(value)] : []; }
function browserLocation() { return new Promise<{ latitude: number; longitude: number } | null>((resolve) => { if (!navigator.geolocation) { resolve(null); return; } navigator.geolocation.getCurrentPosition((position) => resolve({ latitude: position.coords.latitude, longitude: position.coords.longitude }), () => resolve(null), { enableHighAccuracy: true, timeout: 15000, maximumAge: 30_000 }); }); }
function formatDate(value: Date) { return `${String(value.getMonth() + 1).padStart(2, "0")}/${String(value.getDate()).padStart(2, "0")}/${value.getFullYear()}`; }
function formatClock(value: Date) { return new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit", hour12: true }).format(value); }
function clockDeviationStatus(now: Date, start: Date) { const minutes = Math.round((now.getTime() - start.getTime()) / 60_000); return minutes < -1 ? "early" : minutes > 5 ? "late" : "on_time"; }
function callableMessage(cause: unknown) { return cause instanceof Error && cause.message ? cause.message : "The scheduling service is unavailable."; }
