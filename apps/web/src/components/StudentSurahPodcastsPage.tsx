"use client";

import { onAuthStateChanged } from "firebase/auth";
import { collection, documentId, getDocs, query, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, Download, FileText, Headphones, Library, Loader2, RefreshCw, Search, Video } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { cachedStudentSession, resolveStudentSession } from "@/lib/studentSession";
import { StudentAccessPrompt, StudentShell } from "@/components/StudentDashboardHome";

type AccessState = "checking" | "signedOut" | "denied" | "allowed";

type PodcastItem = {
  id: string;
  surahNumber: number;
  surahNameEn: string;
  surahNameAr: string;
  title: string;
  description: string;
  mediaType: string;
  language: string;
  status: string;
  downloadUrl: string;
  durationSeconds: number;
};

export default function StudentSurahPodcastsPage() {
  const [access, setAccess] = useState<AccessState>(() => (cachedStudentSession() ? "allowed" : "checking"));
  const [summary, setSummary] = useState(() => cachedStudentSession()?.summary ?? { displayName: "Student", firstName: "Student", initials: "ST" });
  const [isAdultStudent, setIsAdultStudent] = useState(() => cachedStudentSession()?.isAdultStudent ?? false);
  const [items, setItems] = useState<PodcastItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [openSurah, setOpenSurah] = useState<number | null>(null);

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }
      const session = await resolveStudentSession(nextUser);
      if (!session.isStudent) {
        setAccess("denied");
        setLoading(false);
        return;
      }
      setSummary(session.summary);
      setIsAdultStudent(session.isAdultStudent);
      setAccess("allowed");
      await load(nextUser.uid);
    });
  }, []);

  async function load(uid: string) {
    setLoading(true);
    try {
      setItems(await loadAssignedPodcasts(uid));
    } catch {
      setItems([]);
    } finally {
      setLoading(false);
    }
  }

  const grouped = useMemo(() => {
    const term = search.trim().toLowerCase();
    const map = new Map<number, PodcastItem[]>();
    items.forEach((item) => {
      const list = map.get(item.surahNumber) ?? [];
      list.push(item);
      map.set(item.surahNumber, list);
    });
    return [...map.entries()]
      .filter(([number, list]) => {
        if (!term) return true;
        const surah = list[0];
        return (
          surah.surahNameEn.toLowerCase().includes(term) ||
          surah.surahNameAr.includes(search.trim()) ||
          String(number).includes(term)
        );
      })
      .sort((a, b) => a[0] - b[0]);
  }, [items, search]);

  if (access !== "allowed") return <StudentAccessPrompt access={access} />;

  const surahCount = new Set(items.map((item) => item.surahNumber)).size;
  const open = openSurah !== null ? items.filter((item) => item.surahNumber === openSurah) : [];

  return (
    <StudentShell activeLabel="Surah Podcasts" breadcrumb="Learning / Surah Podcasts" summary={summary} isAdultStudent={isAdultStudent}>
      <div className="mx-auto w-full max-w-[1180px] px-4 py-4 md:px-6">
        <header className="flex items-center gap-4 rounded-2xl bg-[linear-gradient(120deg,#1E3A8A_0%,#28439B_100%)] px-5 py-4 text-white">
          <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-white/15">
            <Library size={22} />
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="text-xl font-black">Surah Content</h1>
            <p className="text-xs font-semibold text-white/80">
              {surahCount} surah{surahCount === 1 ? "" : "s"} · {items.length} item{items.length === 1 ? "" : "s"}
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load(auth.currentUser?.uid ?? "")}
            aria-label="Refresh surah content"
            className="grid h-10 w-10 shrink-0 place-items-center rounded-xl text-white hover:bg-white/15"
          >
            <RefreshCw size={18} />
          </button>
        </header>

        {openSurah === null ? (
          <>
            <div className="relative mt-3">
              <Search aria-hidden="true" className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={17} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search by surah name or number..."
                aria-label="Search surah content"
                className="h-11 w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-4 text-sm text-[#334155] outline-none focus:border-[#2563EB]"
              />
            </div>

            {loading ? (
              <div className="grid min-h-[40vh] place-items-center text-[#64748B]">
                <span className="inline-flex items-center gap-2 text-sm font-bold">
                  <Loader2 className="animate-spin" size={18} />
                  Loading your surah content…
                </span>
              </div>
            ) : grouped.length === 0 ? (
              <p className="mt-8 rounded-2xl border border-dashed border-[#CBD5E1] px-4 py-10 text-center text-sm font-semibold text-[#94A3B8]">
                {items.length === 0
                  ? "No surah content has been shared with you yet."
                  : "No surah matches that search."}
              </p>
            ) : (
              <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {grouped.map(([number, list]) => (
                  <SurahCard key={number} number={number} items={list} onOpen={() => setOpenSurah(number)} />
                ))}
              </div>
            )}
          </>
        ) : (
          <SurahDetail items={open} onBack={() => setOpenSurah(null)} />
        )}
      </div>
    </StudentShell>
  );
}

function SurahCard({ number, items, onOpen }: { number: number; items: PodcastItem[]; onOpen: () => void }) {
  const counts = countByType(items);
  return (
    <button
      type="button"
      onClick={onOpen}
      className="flex flex-col rounded-2xl border border-black/5 bg-white p-3 text-left shadow-[0_6px_18px_rgba(15,23,42,0.05)] transition hover:border-[#BFDBFE]"
    >
      <span className="grid h-10 w-10 place-items-center rounded-xl bg-[#1E3A8A] text-sm font-black text-white">{number}</span>
      <h2 className="mt-3 truncate text-sm font-black text-[#0F172A]">{items[0].surahNameEn || `Surah ${number}`}</h2>
      {items[0].surahNameAr ? (
        <p className="truncate text-xs font-semibold text-[#64748B]" dir="rtl">
          {items[0].surahNameAr}
        </p>
      ) : null}
      <div className="flex-1" />
      <div className="mt-4 flex flex-wrap gap-1.5">
        {counts.map(({ type, count }) => (
          <span key={type} className={`inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[10px] font-black ${typeTone(type)}`}>
            <TypeIcon type={type} />
            {count}
          </span>
        ))}
      </div>
    </button>
  );
}

function SurahDetail({ items, onBack }: { items: PodcastItem[]; onBack: () => void }) {
  return (
    <div className="mt-4">
      <button type="button" onClick={onBack} className="inline-flex min-h-9 items-center gap-1.5 text-sm font-bold text-[#2563EB]">
        <ArrowLeft size={16} />
        All surahs
      </button>
      <div className="mt-3 grid gap-3">
        {items.map((item) => (
          <article key={item.id} className="flex items-center gap-3 rounded-2xl border border-black/5 bg-white px-4 py-3.5 shadow-[0_6px_18px_rgba(15,23,42,0.05)]">
            <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl ${typeTone(item.mediaType)}`}>
              <TypeIcon type={item.mediaType} size={18} />
            </span>
            <div className="min-w-0 flex-1">
              <h3 className="truncate text-sm font-black text-[#0F172A]">{item.title || item.surahNameEn}</h3>
              <p className="truncate text-xs font-semibold text-[#64748B]">
                {item.mediaType}
                {item.durationSeconds > 0 ? ` · ${formatDuration(item.durationSeconds)}` : ""}
                {item.language ? ` · ${item.language.toUpperCase()}` : ""}
              </p>
            </div>
            {item.downloadUrl ? (
              <a
                href={item.downloadUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex min-h-9 shrink-0 items-center gap-1.5 rounded-xl bg-[#0E72ED] px-3 text-xs font-black text-white"
              >
                <Download size={14} />
                Open
              </a>
            ) : null}
          </article>
        ))}
      </div>
    </div>
  );
}

function TypeIcon({ type, size = 12 }: { type: string; size?: number }) {
  if (type === "video") return <Video size={size} />;
  if (type === "audio") return <Headphones size={size} />;
  return <FileText size={size} />;
}

function typeTone(type: string) {
  if (type === "video") return "bg-[#EDE9FE] text-[#6D28D9]";
  if (type === "audio") return "bg-[#DBEAFE] text-[#1D4ED8]";
  return "bg-[#DCFCE7] text-[#166534]";
}

function countByType(items: PodcastItem[]) {
  const counts = new Map<string, number>();
  items.forEach((item) => counts.set(item.mediaType, (counts.get(item.mediaType) ?? 0) + 1));
  return [...counts.entries()].map(([type, count]) => ({ type, count }));
}

/**
 * Students see only what has been assigned to them, never the whole library.
 *
 * SurahPodcastService.getAssignedPodcasts reads podcast_assignments where
 * studentIds contains the student, keeps the entries with active === true, then
 * fetches those podcasts by id. The library holds eight active items across
 * three surahs; this account is assigned two of them, and showing the rest
 * would expose material their teacher has not shared.
 */
async function loadAssignedPodcasts(uid: string): Promise<PodcastItem[]> {
  const assignments = await getDocs(
    query(collection(db, "podcast_assignments"), where("studentIds", "array-contains", uid)),
  );
  const podcastIds = [
    ...new Set(
      assignments.docs
        .filter((entry) => (entry.data() as Record<string, unknown>).active === true)
        .map((entry) => stringValue((entry.data() as Record<string, unknown>).podcastId))
        .filter(Boolean),
    ),
  ];
  if (podcastIds.length === 0) return [];

  const items: PodcastItem[] = [];
  // documentId() 'in' takes at most 30 values per query, same chunking as Flutter.
  for (let i = 0; i < podcastIds.length; i += 30) {
    const chunk = podcastIds.slice(i, i + 30);
    const snap = await getDocs(query(collection(db, "surah_podcasts"), where(documentId(), "in", chunk)));
    snap.docs.forEach((entry) => items.push(normalizePodcast(entry.id, entry.data() as Record<string, unknown>)));
  }
  return items.sort((a, b) => a.surahNumber - b.surahNumber);
}

function normalizePodcast(id: string, data: Record<string, unknown>): PodcastItem {
  return {
    id,
    surahNumber: numberValue(data.surahNumber),
    surahNameEn: stringValue(data.surahNameEn),
    surahNameAr: stringValue(data.surahNameAr),
    title: stringValue(data.title),
    description: stringValue(data.description),
    mediaType: stringValue(data.mediaType) || "audio",
    language: stringValue(data.language),
    status: stringValue(data.status) || "active",
    downloadUrl: stringValue(data.downloadUrl),
    durationSeconds: numberValue(data.durationSeconds),
  };
}

function formatDuration(seconds: number) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.round(seconds % 60);
  return `${mins}:${String(secs).padStart(2, "0")}`;
}

function numberValue(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "ST";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
