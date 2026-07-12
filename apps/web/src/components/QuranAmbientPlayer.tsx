"use client";

import { usePathname } from "next/navigation";
import { ChevronDown, ChevronUp, Pause, Play, SkipBack, SkipForward, Volume2, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { isPublicMarketingPath } from "@/lib/publicRoutes";

const PREF_KEY = "alluwal-quran-audio";
const SETTINGS_KEY = "alluwal-quran-settings";

const reciters = [
  { id: "afs", name: "Mishary Rashid Alafasy", base: "https://server8.mp3quran.net/afs" },
  { id: "basit", name: "Abdul Basit Abdus-Samad", base: "https://server7.mp3quran.net/basit" },
  { id: "sds", name: "Abdur-Rahman As-Sudais", base: "https://server11.mp3quran.net/sds" },
];

const surahs = [
  { num: "001", name: "Al-Fatiha", arabic: "الفاتحة", meaning: "The Opening" },
  { num: "012", name: "Yusuf", arabic: "يوسف", meaning: "Joseph" },
  { num: "018", name: "Al-Kahf", arabic: "الكهف", meaning: "The Cave" },
  { num: "019", name: "Maryam", arabic: "مريم", meaning: "Mary" },
  { num: "036", name: "Ya-Sin", arabic: "يس", meaning: "Ya-Sin" },
  { num: "055", name: "Ar-Rahman", arabic: "الرحمن", meaning: "The Most Merciful" },
  { num: "056", name: "Al-Waqi'ah", arabic: "الواقعة", meaning: "The Inevitable" },
  { num: "067", name: "Al-Mulk", arabic: "الملك", meaning: "The Sovereignty" },
  { num: "078", name: "An-Naba", arabic: "النبأ", meaning: "The Tidings" },
  { num: "093", name: "Ad-Duha", arabic: "الضحى", meaning: "The Morning Light" },
];

function formatTime(seconds: number) {
  if (!Number.isFinite(seconds) || seconds <= 0) return "0:00";
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function loadSettings() {
  try {
    const raw = window.localStorage.getItem(SETTINGS_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as { reciter?: string; surah?: string; volume?: number };
  } catch {
    return null;
  }
}

export function QuranAmbientPlayer() {
  const pathname = usePathname();
  const audioRef = useRef<HTMLAudioElement>(null);
  const pendingPlayRef = useRef(false);
  const [reciterId, setReciterId] = useState("afs");
  const [surahIndex, setSurahIndex] = useState(5);
  const [playing, setPlaying] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [ready, setReady] = useState(false);
  const [volume, setVolume] = useState(0.35);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);

  const allowed = isPublicMarketingPath(pathname ?? "/");
  const reciter = reciters.find((r) => r.id === reciterId) ?? reciters[0];
  const surah = surahs[surahIndex];
  const src = `${reciter.base}/${surah.num}.mp3`;

  useEffect(() => {
    if (!allowed) return;
    const audio = audioRef.current;
    if (!audio) return;

    const settings = loadSettings();
    if (settings?.reciter && reciters.some((r) => r.id === settings.reciter)) setReciterId(settings.reciter);
    if (settings?.surah) {
      const index = surahs.findIndex((s) => s.num === settings.surah);
      if (index >= 0) setSurahIndex(index);
    }
    const startVolume = typeof settings?.volume === "number" ? Math.min(Math.max(settings.volume, 0), 1) : 0.35;
    setVolume(startVolume);
    audio.volume = startVolume;

    const pref = window.localStorage.getItem(PREF_KEY);
    setReady(true);
    if (pref === "off") return;

    let started = false;
    const start = () => {
      if (started) return;
      const attempt = audioRef.current?.play();
      if (!attempt) return;
      attempt
        .then(() => {
          started = true;
          removeListeners();
        })
        .catch(() => {
          /* keep waiting for a user gesture */
        });
    };
    const removeListeners = () => {
      window.removeEventListener("pointerdown", start);
      window.removeEventListener("keydown", start);
    };

    start();
    window.addEventListener("pointerdown", start);
    window.addEventListener("keydown", start);
    return () => {
      removeListeners();
      audioRef.current?.pause();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [allowed]);

  useEffect(() => {
    if (!ready) return;
    window.localStorage.setItem(SETTINGS_KEY, JSON.stringify({ reciter: reciterId, surah: surah.num, volume }));
  }, [ready, reciterId, surah.num, volume]);

  useEffect(() => {
    if (!pendingPlayRef.current) return;
    pendingPlayRef.current = false;
    const audio = audioRef.current;
    if (!audio) return;
    audio.volume = volume;
    audio
      .play()
      .then(() => window.localStorage.setItem(PREF_KEY, "on"))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src]);

  const syncFromElement = (element: HTMLAudioElement) => {
    setPlaying(!element.paused);
    setCurrentTime(element.currentTime);
    setDuration(Number.isFinite(element.duration) ? element.duration : 0);
  };

  if (!allowed || dismissed) return null;

  const playCurrent = () => {
    audioRef.current
      ?.play()
      .then(() => window.localStorage.setItem(PREF_KEY, "on"))
      .catch(() => {});
  };

  const toggle = () => {
    const audio = audioRef.current;
    if (!audio) return;
    if (playing) {
      audio.pause();
      window.localStorage.setItem(PREF_KEY, "off");
    } else {
      playCurrent();
    }
  };

  const selectSurah = (index: number) => {
    pendingPlayRef.current = true;
    setSurahIndex((index + surahs.length) % surahs.length);
    setCurrentTime(0);
    setDuration(0);
  };

  const selectReciter = (id: string) => {
    if (id === reciterId) return;
    pendingPlayRef.current = playing;
    setReciterId(id);
    setCurrentTime(0);
    setDuration(0);
  };

  const seek = (value: number) => {
    const audio = audioRef.current;
    if (!audio || !Number.isFinite(audio.duration)) return;
    audio.currentTime = value;
    setCurrentTime(value);
  };

  const changeVolume = (value: number) => {
    setVolume(value);
    if (audioRef.current) audioRef.current.volume = value;
  };

  const close = () => {
    audioRef.current?.pause();
    setDismissed(true);
    window.localStorage.setItem(PREF_KEY, "off");
  };

  return (
    <div
      className={`quran-player fixed bottom-4 left-4 z-40 max-w-[calc(100vw-32px)] transition-opacity duration-500 ${ready ? "opacity-100" : "opacity-0"}`}
    >
      <audio
        ref={audioRef}
        src={src}
        preload="none"
        onPlay={(event) => syncFromElement(event.currentTarget)}
        onPause={(event) => syncFromElement(event.currentTarget)}
        onTimeUpdate={(event) => syncFromElement(event.currentTarget)}
        onLoadedMetadata={(event) => syncFromElement(event.currentTarget)}
        onEmptied={(event) => syncFromElement(event.currentTarget)}
        onEnded={() => selectSurah(surahIndex + 1)}
      />

      {expanded ? (
        <div className="quran-card mb-2 w-[314px] rounded-3xl border border-white/12 bg-[#0B1B3A]/95 p-4 text-white shadow-[0_24px_70px_rgba(2,8,32,0.5)] backdrop-blur">
          <div className="flex items-start justify-between gap-3">
            <div>
              <div className="text-[10.5px] font-black uppercase tracking-[0.16em] text-[#FBBF24]">Now reciting</div>
              <div className="mt-1 flex items-baseline gap-2.5">
                <span className="font-display text-lg font-bold leading-none">{surah.name}</span>
                <span className="text-lg leading-none text-white/85" dir="rtl">
                  {surah.arabic}
                </span>
              </div>
              <div className="mt-1 text-[11.5px] font-semibold text-white/55">{surah.meaning}</div>
            </div>
            <div className="flex gap-1">
              <button
                type="button"
                onClick={() => setExpanded(false)}
                className="inline-flex h-7 w-7 items-center justify-center rounded-full text-white/55 transition hover:bg-white/10 hover:text-white"
                aria-label="Collapse Quran player"
              >
                <ChevronDown size={15} />
              </button>
              <button
                type="button"
                onClick={close}
                className="inline-flex h-7 w-7 items-center justify-center rounded-full text-white/55 transition hover:bg-white/10 hover:text-white"
                aria-label="Hide Quran player"
              >
                <X size={15} />
              </button>
            </div>
          </div>

          <div className="mt-3">
            <input
              type="range"
              min={0}
              max={duration || 1}
              step={1}
              value={Math.min(currentTime, duration || 1)}
              onChange={(event) => seek(Number(event.target.value))}
              className="quran-range w-full"
              aria-label="Seek recitation"
            />
            <div className="mt-1 flex justify-between text-[10.5px] font-semibold text-white/50">
              <span>{formatTime(currentTime)}</span>
              <span>{formatTime(duration)}</span>
            </div>
          </div>

          <div className="mt-2 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => selectSurah(surahIndex - 1)}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-white/8 text-white/85 transition hover:bg-white/16"
                aria-label="Previous surah"
              >
                <SkipBack size={15} fill="currentColor" />
              </button>
              <button
                type="button"
                onClick={toggle}
                className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-[#FBBF24] text-[#78350F] shadow-[0_10px_26px_rgba(251,191,36,0.35)] transition hover:brightness-105"
                aria-label={playing ? "Pause Quran recitation" : "Play Quran recitation"}
              >
                {playing ? <Pause size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" className="ml-0.5" />}
              </button>
              <button
                type="button"
                onClick={() => selectSurah(surahIndex + 1)}
                className="inline-flex h-9 w-9 items-center justify-center rounded-full bg-white/8 text-white/85 transition hover:bg-white/16"
                aria-label="Next surah"
              >
                <SkipForward size={15} fill="currentColor" />
              </button>
            </div>
            <div className="flex items-center gap-1.5">
              <Volume2 size={14} className="text-white/55" />
              <input
                type="range"
                min={0}
                max={1}
                step={0.05}
                value={volume}
                onChange={(event) => changeVolume(Number(event.target.value))}
                className="quran-range w-[74px]"
                aria-label="Volume"
              />
            </div>
          </div>

          <div className="mt-3.5">
            <div className="text-[10.5px] font-black uppercase tracking-[0.14em] text-white/45">Reciter</div>
            <div className="mt-1.5 grid gap-1">
              {reciters.map(({ id, name }) => (
                <button
                  key={id}
                  type="button"
                  onClick={() => selectReciter(id)}
                  className={`rounded-lg px-2.5 py-1.5 text-left text-[12px] font-bold transition ${
                    id === reciterId ? "bg-[#FBBF24]/16 text-[#FBBF24]" : "text-white/70 hover:bg-white/8"
                  }`}
                >
                  {name}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-3">
            <div className="text-[10.5px] font-black uppercase tracking-[0.14em] text-white/45">Surahs</div>
            <div className="mt-1.5 max-h-[164px] overflow-y-auto pr-1">
              {surahs.map(({ num, name, arabic }, index) => (
                <button
                  key={num}
                  type="button"
                  onClick={() => selectSurah(index)}
                  className={`flex w-full items-center justify-between rounded-lg px-2.5 py-1.5 text-[12px] font-bold transition ${
                    index === surahIndex ? "bg-white/10 text-white" : "text-white/65 hover:bg-white/6"
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <span className={`w-6 text-[10.5px] font-black ${index === surahIndex ? "text-[#FBBF24]" : "text-white/35"}`}>
                      {Number(num)}
                    </span>
                    {name}
                  </span>
                  <span className="text-[13px] text-white/75" dir="rtl">
                    {arabic}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      <div className="flex items-center gap-3 rounded-full border border-white/14 bg-[#0B1B3A]/92 py-2 pl-4 pr-2 text-white shadow-[0_18px_50px_rgba(2,8,32,0.45)] backdrop-blur">
        <button
          type="button"
          onClick={() => setExpanded((value) => !value)}
          className="flex items-center gap-3 text-left"
          aria-expanded={expanded}
          aria-label="Open Quran player"
        >
          <span className="flex h-4 items-end gap-[2.5px]" aria-hidden="true">
            {[0, 1, 2, 3].map((bar) => (
              <span key={bar} className={`eq-bar h-full ${playing ? "" : "eq-bar-paused"}`} />
            ))}
          </span>
          <span className="leading-tight">
            <span className="block text-[12px] font-extrabold">Quran · {surah.name}</span>
            <span className="block text-[10.5px] font-semibold text-white/62">{reciter.name}</span>
          </span>
          <ChevronUp size={14} className={`text-white/45 transition-transform ${expanded ? "rotate-180" : ""}`} />
        </button>
        <button
          type="button"
          onClick={toggle}
          className="ml-1 inline-flex h-9 w-9 items-center justify-center rounded-full bg-[#FBBF24] text-[#78350F] transition hover:brightness-105"
          aria-label={playing ? "Pause Quran recitation" : "Play Quran recitation"}
        >
          {playing ? <Pause size={16} fill="currentColor" /> : <Play size={16} fill="currentColor" className="ml-0.5" />}
        </button>
        <button
          type="button"
          onClick={close}
          className="inline-flex h-7 w-7 items-center justify-center rounded-full text-white/55 transition hover:bg-white/10 hover:text-white"
          aria-label="Hide Quran player"
        >
          <X size={15} />
        </button>
      </div>
    </div>
  );
}
