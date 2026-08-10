"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, orderBy, query, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { BookOpen, FileText, Headphones, Lock, Plus, RefreshCw, Search, UploadCloud, Video, X } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";

type PodcastItem = {
  id: string;
  surahNumber: number;
  surahNameEn: string;
  surahNameAr: string;
  title: string;
  description: string;
  mediaType: string;
  status: string;
  language: string;
  createdAt: Date | null;
};

type SurahBucket = {
  surahNumber: number;
  surahNameEn: string;
  surahNameAr: string;
  items: PodcastItem[];
};

export function SurahPodcastsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [items, setItems] = useState<PodcastItem[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        const loaded = await loadPodcastItems();
        if (mounted) setItems(activeOrAllItems(loaded));
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Failed to load content");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const buckets = useMemo(() => buildBuckets(items, search), [items, search]);
  const subtitle = `${items.length} item${items.length === 1 ? "" : "s"} across ${new Set(items.map((item) => item.surahNumber)).size} surah${new Set(items.map((item) => item.surahNumber)).size === 1 ? "" : "s"}`;

  if (access !== "allowed") {
    return <SurahAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Surah Podcasts" breadcrumb="Communication / Surah Podcasts">
      <main className="relative min-h-[calc(100vh-56px)] bg-[#F8FAFC] pb-24 text-[#0F172A]">
        <header className="border-b border-[#F3F4F6] bg-white lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">{initialsFor(user)}</span>
          </div>
        </header>

        <section className="px-4 pb-2 pt-6 sm:px-5">
          <div className="flex items-center gap-3">
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
              <BookOpen size={24} />
            </span>
            <div className="min-w-0 flex-1">
              <h1 className="truncate text-[22px] font-bold text-[#1E293B]">Surah Library</h1>
              <p className="mt-0.5 text-[13px] text-[#64748B]">{subtitle}</p>
            </div>
            <button
              type="button"
              aria-label="Refresh surah podcasts"
              onClick={() => void retryLoad(setLoading, setMessage, setItems, setSearch)}
              className="grid h-11 w-11 place-items-center rounded-xl text-[#94A3B8] hover:bg-white"
            >
              <RefreshCw size={22} />
            </button>
          </div>
        </section>

        <section className="px-4 py-2 sm:px-5">
          <label className="relative block h-12">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search by surah name or number..."
              aria-label="Search by surah name or number"
              className="h-full w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-10 text-sm text-[#0F172A] outline-none placeholder:text-[#94A3B8] focus:border-[#0E72ED] focus:ring-2 focus:ring-[#BFDBFE]"
            />
            {search ? (
              <button type="button" aria-label="Clear search" onClick={() => setSearch("")} className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-lg text-[#64748B] hover:bg-[#F1F5F9]">
                <X size={16} />
              </button>
            ) : null}
          </label>
        </section>

        {message ? <ErrorCard message={message} onRetry={() => void retryLoad(setLoading, setMessage, setItems, setSearch)} /> : null}

        {loading ? (
          <LoadingContent />
        ) : buckets.length === 0 && items.length === 0 ? (
          <EmptyContentCard />
        ) : buckets.length === 0 ? (
          <SearchEmptyCard />
        ) : (
          <section className="grid gap-3 px-4 py-1 sm:grid-cols-[repeat(auto-fill,minmax(210px,1fr))] sm:px-5 lg:grid-cols-[repeat(auto-fill,minmax(235px,1fr))]">
            {buckets.map((bucket) => (
              <SurahFolder key={bucket.surahNumber} bucket={bucket} />
            ))}
          </section>
        )}

        <button
          type="button"
          onClick={() => setDialogOpen(true)}
          className="fixed bottom-4 right-4 z-20 inline-flex min-h-14 items-center gap-2 rounded-2xl bg-[#0E72ED] px-6 text-base font-bold text-white shadow-xl"
        >
          <Plus size={22} />
          Add Content
        </button>

        {dialogOpen ? <AddContentDialog onClose={() => setDialogOpen(false)} /> : null}
      </main>
    </AdminDashboardShell>
  );
}

function SurahFolder({ bucket }: { bucket: SurahBucket }) {
  const audio = bucket.items.filter((item) => item.mediaType === "audio").length;
  const video = bucket.items.filter((item) => item.mediaType === "video").length;
  const pdf = bucket.items.filter((item) => item.mediaType === "pdf").length;
  const text = bucket.items.filter((item) => item.mediaType === "text").length;
  return (
    <article className="min-h-[184px] rounded-2xl border border-[#E2E8F0] bg-white p-3.5 shadow-[0_4px_10px_rgba(15,23,42,0.04)]">
      <div className="grid h-[42px] w-[42px] place-items-center rounded-xl bg-gradient-to-br from-[#1E3A5F] to-[#2E5A8F] text-base font-bold text-white">
        {bucket.surahNumber}
      </div>
      <h2 className="mt-3 truncate text-sm font-semibold text-[#111827]">{bucket.surahNameEn || `Surah ${bucket.surahNumber}`}</h2>
      {bucket.surahNameAr ? <p className="truncate text-[13px] text-[#6B7280]">{bucket.surahNameAr}</p> : null}
      <div className="mt-8 flex flex-wrap gap-1.5">
        {audio > 0 ? <ContentBadge icon={<Headphones size={12} />} count={audio} tone="blue" /> : null}
        {video > 0 ? <ContentBadge icon={<Video size={12} />} count={video} tone="purple" /> : null}
        {pdf > 0 ? <ContentBadge icon={<FileText size={12} />} count={pdf} tone="red" /> : null}
        {text > 0 ? <ContentBadge icon={<BookOpen size={12} />} count={text} tone="green" /> : null}
      </div>
    </article>
  );
}

function ContentBadge({ icon, count, tone }: { icon: React.ReactNode; count: number; tone: "blue" | "purple" | "red" | "green" }) {
  const styles = {
    blue: "bg-[#E7F3FF] text-[#0E72ED]",
    purple: "bg-[#F5F3FF] text-[#7C3AED]",
    red: "bg-[#FEF2F2] text-[#EF4444]",
    green: "bg-[#ECFDF5] text-[#10B981]",
  };
  return (
    <span className={`inline-flex items-center gap-1 rounded-md px-1.5 py-1 text-[11px] font-bold ${styles[tone]}`}>
      {icon}
      {count}
    </span>
  );
}

function EmptyContentCard() {
  return (
    <section className="grid min-h-[calc(100vh-270px)] place-items-center px-8 py-10">
      <div className="w-full max-w-[400px] translate-y-12 rounded-2xl bg-white px-7 py-7 text-center shadow-[0_4px_10px_rgba(15,23,42,0.04)] sm:translate-y-16">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#E7F3FF] text-[#7DB5F6]">
          <UploadCloud size={34} />
        </div>
        <h2 className="mt-4 text-base font-semibold text-[#374151]">No content uploaded yet</h2>
        <p className="mt-2 text-sm leading-6 text-[#6B7280]">Upload audio, video, or text content for any surah.</p>
      </div>
    </section>
  );
}

function SearchEmptyCard() {
  return (
    <section className="grid min-h-[360px] place-items-center px-8 py-10">
      <div className="text-center">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#F1F5F9] text-[#94A3B8]">
          <Search size={30} />
        </div>
        <h2 className="mt-5 text-base font-bold text-[#374151]">No results found</h2>
        <p className="mt-2 text-sm text-[#6B7280]">Try a different search term.</p>
      </div>
    </section>
  );
}

function LoadingContent() {
  return (
    <div className="grid min-h-[calc(100vh-220px)] place-items-center">
      <div className="h-11 w-11 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0E72ED]" />
    </div>
  );
}

function ErrorCard({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <section className="mx-auto mt-6 w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-sm">
      <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#FEE2E2] text-[#EF4444]">
        <X size={28} />
      </div>
      <p className="mt-4 text-sm font-semibold text-[#374151]">{message}</p>
      <button type="button" onClick={onRetry} className="mt-5 inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#0E72ED] px-5 text-sm font-semibold text-white">
        <RefreshCw size={16} />
        Try Again
      </button>
    </section>
  );
}

function AddContentDialog({ onClose }: { onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-40 grid place-items-center bg-black/35 p-4" role="dialog" aria-modal="true" aria-label="Add Content">
      <section className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-2xl">
        <div className="flex items-center gap-3">
          <h2 className="flex-1 text-xl font-bold text-[#111827]">Add Content</h2>
          <button type="button" aria-label="Close add content" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-lg hover:bg-[#F8FAFC]">
            <X size={18} />
          </button>
        </div>
        <div className="mt-5 grid grid-cols-2 gap-2">
          {["Audio", "Video", "Text", "PDF"].map((label) => (
            <button key={label} type="button" className="min-h-12 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] text-sm font-semibold text-[#334155]">
              {label}
            </button>
          ))}
        </div>
        <label className="mt-4 block text-sm font-semibold text-[#334155]">
          Title
          <input className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 outline-none focus:border-[#0E72ED]" />
        </label>
        <label className="mt-4 block text-sm font-semibold text-[#334155]">
          Description
          <textarea className="mt-2 min-h-24 w-full rounded-xl border border-[#CBD5E1] px-3 py-2 outline-none focus:border-[#0E72ED]" />
        </label>
        <button type="button" onClick={onClose} className="mt-5 min-h-11 w-full rounded-xl bg-[#0E72ED] text-sm font-bold text-white">
          Done
        </button>
      </section>
    </div>
  );
}

function SurahAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#E6EEF8] text-[#001E4E]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before opening surah podcasts."
              : "Your signed-in account does not have administrator permissions for this module."}
        </p>
        {!checking ? (
          <Link href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#001E4E] px-5 text-sm font-semibold text-white">
            Go to login
          </Link>
        ) : null}
      </section>
    </main>
  );
}

async function retryLoad(
  setLoading: (value: boolean) => void,
  setMessage: (value: string) => void,
  setItems: (value: PodcastItem[]) => void,
  setSearch: (value: string) => void,
) {
  setLoading(true);
  setMessage("");
  try {
    const loaded = await loadPodcastItems();
    setItems(activeOrAllItems(loaded));
    setSearch("");
  } catch (error) {
    setMessage(error instanceof Error ? error.message : "Failed to load content");
  } finally {
    setLoading(false);
  }
}

async function loadPodcastItems() {
  const snap = await getDocs(query(collection(db, "surah_podcasts"), orderBy("surahNumber"), limit(200)));
  return snap.docs.map((docSnap) => normalizePodcast(docSnap.id, docSnap.data() as Record<string, unknown>));
}

function activeOrAllItems(items: PodcastItem[]) {
  const active = items.filter((item) => item.status === "active");
  return active.length || items.length === 0 ? active : items;
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
    status: stringValue(data.status) || "active",
    language: stringValue(data.language) || "en",
    createdAt: dateValue(data.createdAt),
  };
}

function buildBuckets(items: PodcastItem[], search: string) {
  const map = new Map<number, PodcastItem[]>();
  for (const item of items) {
    const list = map.get(item.surahNumber) ?? [];
    list.push(item);
    map.set(item.surahNumber, list);
  }
  const term = search.trim().toLowerCase();
  return Array.from(map.entries())
    .map(([surahNumber, list]) => ({
      surahNumber,
      surahNameEn: list.find((item) => item.surahNameEn)?.surahNameEn || `Surah ${surahNumber}`,
      surahNameAr: list.find((item) => item.surahNameAr)?.surahNameAr || "",
      items: list,
    }))
    .filter((bucket) => {
      if (!term) return true;
      return [String(bucket.surahNumber), bucket.surahNameEn, bucket.surahNameAr, ...bucket.items.map((item) => item.title), ...bucket.items.map((item) => item.description)].some((value) =>
        value.toLowerCase().includes(term),
      );
    })
    .sort((a, b) => a.surahNumber - b.surahNumber);
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date && !Number.isNaN(parsed.getTime()) ? parsed : null;
  }
  return null;
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Administrator";
  return source
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}
