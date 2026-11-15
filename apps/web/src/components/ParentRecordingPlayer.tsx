"use client";

import { useEffect, useRef, useState } from "react";
import { AlertCircle, ArrowLeft, Loader2, Maximize, Minimize, Pause, Play, RefreshCw, RotateCcw, RotateCw } from "lucide-react";
import { playerTime, skipTo } from "@/lib/parentRecordings";

/**
 * The recording player Flutter shows inside a fragment card (VideoPlayerWidget,
 * lib/features/surah_podcast/widgets/video_player_widget.dart): a dark box with
 * a spinner while it loads; then the video (at most 360 px high on the web)
 * with an overlay of back 10 s / play-pause / forward 10 s that a click on the
 * video shows or hides; a seek bar, play, ±10 s, elapsed / total and a
 * full-screen button below. On a load error, a grey box "Failed to load video"
 * with Retry, which retries the same link. There is no download control (the
 * browser's own controls, which offer one, are not used).
 */
export function ParentRecordingPlayer({ url, title }: { url: string; title: string }) {
  const frameRef = useRef<HTMLDivElement | null>(null);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [fullscreen, setFullscreen] = useState(false);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const onChange = () => setFullscreen(document.fullscreenElement === frameRef.current);
    document.addEventListener("fullscreenchange", onChange);
    return () => document.removeEventListener("fullscreenchange", onChange);
  }, []);

  const video = () => videoRef.current;
  const togglePlay = () => {
    const v = video();
    if (!v) return;
    if (v.paused) void v.play().catch(() => undefined);
    else v.pause();
  };
  const skip = (delta: number) => {
    const v = video();
    if (!v) return;
    v.currentTime = skipTo(v.currentTime, v.duration, delta);
  };
  const toggleFullscreen = () => {
    const frame = frameRef.current;
    if (!frame || !ready) return;
    if (document.fullscreenElement) void document.exitFullscreen().catch(() => undefined);
    else void frame.requestFullscreen?.().catch(() => undefined);
  };
  const retry = () => {
    setFailed(false);
    setReady(false);
    setAttempt((n) => n + 1);
  };

  if (failed) {
    return (
      <div className="grid h-[200px] place-items-center rounded-xl border border-[#E2E8F0] bg-[#F1F5F9]" role="alert">
        <div className="flex flex-col items-center gap-2 px-4 text-center">
          <AlertCircle size={36} className="text-[#EF4444]" />
          <p className="text-sm text-[#6B7280]">Failed to load video</p>
          <button type="button" onClick={retry} className="inline-flex items-center gap-1.5 rounded-lg bg-[#0E72ED] px-4 py-2 text-[13px] text-white hover:bg-[#0C63CF]">
            <RefreshCw size={16} />
            Retry
          </button>
        </div>
      </div>
    );
  }

  const overlay = showControls || !playing;
  const progress = duration > 0 ? Math.min(1, Math.max(0, position / duration)) : 0;

  return (
    <div ref={frameRef} className={`relative overflow-hidden bg-black ${fullscreen ? "flex h-full w-full flex-col justify-center" : "rounded-xl"}`}>
      {fullscreen ? (
        <div className="absolute inset-x-0 top-0 z-10 flex items-center gap-2 bg-gradient-to-b from-black/70 to-transparent px-2 py-2 text-white">
          <button type="button" onClick={toggleFullscreen} aria-label="Exit full screen" className="grid h-11 w-11 place-items-center rounded-full hover:bg-white/10">
            <ArrowLeft size={22} />
          </button>
          <p className="min-w-0 flex-1 truncate text-sm font-semibold">{title}</p>
        </div>
      ) : null}
      <div className="relative flex justify-center" onClick={() => setShowControls((value) => !value)}>
        <video
          key={attempt}
          ref={videoRef}
          src={url}
          preload="metadata"
          playsInline
          disablePictureInPicture
          controlsList="nodownload noplaybackrate noremoteplayback"
          onContextMenu={(event) => event.preventDefault()}
          onLoadedMetadata={(event) => {
            setDuration(event.currentTarget.duration);
            setReady(true);
          }}
          onTimeUpdate={(event) => setPosition(event.currentTarget.currentTime)}
          onDurationChange={(event) => setDuration(event.currentTarget.duration)}
          onPlay={() => setPlaying(true)}
          onPause={() => setPlaying(false)}
          onEnded={() => setPlaying(false)}
          onError={() => setFailed(true)}
          className={`block w-full object-contain ${fullscreen ? "max-h-[calc(100vh-72px)]" : "max-h-[360px]"} ${ready ? "" : "invisible"}`}
          style={{ aspectRatio: "16 / 9" }}
        />
        {!ready ? (
          <div className="absolute inset-0 grid place-items-center bg-[#0F172A]" role="status" aria-label="Loading video">
            <Loader2 size={28} className="animate-spin text-white" />
          </div>
        ) : overlay ? (
          <div className="absolute inset-0 flex items-center justify-center gap-6 bg-black/40">
            <OverlayButton label="Back 10 seconds" size={40} onClick={() => skip(-10)}>
              <RotateCcw size={22} />
            </OverlayButton>
            <OverlayButton label={playing ? "Pause" : "Play"} size={56} onClick={togglePlay}>
              {playing ? <Pause size={30} fill="currentColor" /> : <Play size={30} fill="currentColor" />}
            </OverlayButton>
            <OverlayButton label="Forward 10 seconds" size={40} onClick={() => skip(10)}>
              <RotateCw size={22} />
            </OverlayButton>
          </div>
        ) : null}
      </div>
      {ready ? (
        <div className="bg-[#0F172A] px-3 pb-1.5 pt-1.5">
          <input
            type="range"
            min={0}
            max={1000}
            value={Math.round(progress * 1000)}
            aria-label="Seek"
            onChange={(event) => {
              const v = video();
              if (v && duration > 0) v.currentTime = (Number(event.target.value) / 1000) * duration;
            }}
            className="h-1 w-full cursor-pointer accent-[#0E72ED]"
          />
          <div className="mt-1 flex items-center text-white">
            <button type="button" onClick={togglePlay} aria-label={playing ? "Pause" : "Play"} className="grid h-8 w-8 place-items-center">
              {playing ? <Pause size={20} fill="currentColor" /> : <Play size={20} fill="currentColor" />}
            </button>
            <button type="button" onClick={() => skip(-10)} aria-label="Back 10 seconds" className="ml-2 grid h-8 w-8 place-items-center text-white/70">
              <RotateCcw size={18} />
            </button>
            <button type="button" onClick={() => skip(10)} aria-label="Forward 10 seconds" className="grid h-8 w-8 place-items-center text-white/70">
              <RotateCw size={18} />
            </button>
            <span className="ml-3 text-[11px] font-medium text-white/70">{playerTime(position)}</span>
            <span className="text-[11px] text-white/40">&nbsp;/&nbsp;</span>
            <span className="text-[11px] font-medium text-white/70">{playerTime(duration)}</span>
            <span className="flex-1" />
            <button type="button" onClick={toggleFullscreen} aria-label={fullscreen ? "Exit full screen" : "Full screen"} className="grid h-8 w-8 place-items-center text-white/70">
              {fullscreen ? <Minimize size={20} /> : <Maximize size={20} />}
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

function OverlayButton({ label, size, onClick, children }: { label: string; size: number; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={(event) => {
        event.stopPropagation();
        onClick();
      }}
      className="grid place-items-center rounded-full bg-white/20 text-white hover:bg-white/30"
      style={{ width: size, height: size }}
    >
      {children}
    </button>
  );
}
