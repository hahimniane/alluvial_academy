"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, doc, getDocs, limit, orderBy, query, Timestamp, updateDoc, where } from "firebase/firestore";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  ArrowLeft,
  BookOpen,
  Check,
  Clock3,
  FileText,
  Headphones,
  Library,
  Menu,
  MoreHorizontal,
  Podcast,
  RefreshCw,
  Search,
  Share2,
  Shuffle,
  Users,
  Video,
  X,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;
type TabKey = "library" | "shared";

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type PodcastItem = {
  id: string;
  surahNumber: number;
  surahNameEn: string;
  surahNameAr: string;
  language: string;
  title: string;
  description: string;
  mediaType: string;
  textContent: string;
  downloadUrl: string;
  fileSizeBytes: number;
  durationSeconds: number;
  status: string;
  createdAt: Date | null;
};

type PodcastAssignment = {
  id: string;
  podcastId: string;
  surahNumber: number;
  surahNameEn: string;
  podcastTitle: string;
  teacherId: string;
  teacherName: string;
  studentIds: string[];
  active: boolean;
  assignedAt: Date | null;
};

type StudentOption = {
  id: string;
  name: string;
};

type SurahBucket = {
  surahNumber: number;
  surahNameEn: string;
  surahNameAr: string;
  items: PodcastItem[];
};

export function TeacherSurahPodcastsPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [teacherId, setTeacherId] = useState("");
  const [teacherName, setTeacherName] = useState("Teacher");
  const [items, setItems] = useState<PodcastItem[]>([]);
  const [assignments, setAssignments] = useState<PodcastAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [search, setSearch] = useState("");
  const [activeTab, setActiveTab] = useState<TabKey>("library");
  const [selectedSurah, setSelectedSurah] = useState<number | null>(null);
  const [shareItem, setShareItem] = useState<PodcastItem | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        const nextSummary = summaryForUser(nextUser, userRecord);
        setSummary(nextSummary);
        setTeacherId(nextUser.uid);
        setTeacherName(nextSummary.displayName);
        setAccess("allowed");
        const loaded = await loadTeacherSurahData(nextUser.uid);
        if (!mounted) return;
        setItems(activeOrAllItems(loaded.items));
        setAssignments(loaded.assignments);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Failed to load content");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const buckets = useMemo(() => buildBuckets(items, search), [items, search]);
  const selectedBucket = selectedSurah === null ? null : buckets.find((bucket) => bucket.surahNumber === selectedSurah) ?? buildBuckets(items, "").find((bucket) => bucket.surahNumber === selectedSurah) ?? null;

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Surah Podcasts" breadcrumb={selectedBucket ? `Communication / Surah Podcasts / ${selectedBucket.surahNameEn}` : "Communication / Surah Podcasts"} summary={summary}>
      <main className="min-h-screen bg-[#F8FAFC] text-[#0F172A] lg:min-h-[calc(100vh-56px)]">
        <MobileTeacherTopBar summary={summary} />
        {selectedBucket ? (
          <SurahDetail
            bucket={selectedBucket}
            onBack={() => setSelectedSurah(null)}
            onShare={setShareItem}
          />
        ) : (
          <>
            <section className="px-4 pb-2 pt-6 sm:px-5">
              <div className="flex items-center gap-3">
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
                  <Podcast size={24} />
                </span>
                <h1 className="min-w-0 flex-1 truncate text-[22px] font-bold text-[#1E293B]">Surah Content</h1>
                <button type="button" onClick={() => void refresh(teacherId, setLoading, setMessage, setItems, setAssignments, setSearch)} aria-label="Refresh surah podcasts" className="grid h-11 w-11 place-items-center rounded-xl text-[#94A3B8] hover:bg-white">
                  <RefreshCw size={22} />
                </button>
              </div>
            </section>

            <section className="px-4 sm:px-5">
              <div className="grid min-h-[50px] grid-cols-2 overflow-hidden rounded-xl border border-[#E2E8F0] bg-white">
                <TabButton active={activeTab === "library"} onClick={() => setActiveTab("library")}>
                  Library ({buckets.length})
                </TabButton>
                <TabButton active={activeTab === "shared"} onClick={() => setActiveTab("shared")}>
                  Shared ({assignments.length})
                </TabButton>
              </div>
            </section>

            {message ? <ErrorCard message={message} onRetry={() => void refresh(teacherId, setLoading, setMessage, setItems, setAssignments, setSearch)} /> : null}

            {loading ? (
              <LoadingContent />
            ) : activeTab === "library" ? (
              <LibraryTab items={items} buckets={buckets} search={search} onSearch={setSearch} onSelect={setSelectedSurah} />
            ) : (
              <SharedTab assignments={assignments} onRemove={(assignment) => void removeAssignment(assignment, teacherId, setAssignments, setMessage)} />
            )}
          </>
        )}

        {shareItem ? (
          <SharePodcastDialog
            item={shareItem}
            teacherId={teacherId}
            teacherName={teacherName}
            onClose={() => setShareItem(null)}
            onSaved={(saved) => {
              setAssignments((current) => upsertAssignment(current, saved));
              setShareItem(null);
            }}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-14 grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-base font-bold text-[#111827]">Alluwal Academy</div>
      <div className="flex items-center justify-end gap-3">
        <Shuffle size={20} className="text-[#111827]" />
        <span className="grid h-9 w-9 place-items-center rounded-full bg-[#009688] text-xs font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function TabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`min-h-[50px] border-b-2 px-4 text-sm font-semibold ${active ? "border-[#0E72ED] text-[#0E72ED]" : "border-transparent text-[#94A3B8]"}`}
    >
      {children}
    </button>
  );
}

function LibraryTab({
  items,
  buckets,
  search,
  onSearch,
  onSelect,
}: {
  items: PodcastItem[];
  buckets: SurahBucket[];
  search: string;
  onSearch: (value: string) => void;
  onSelect: (value: number) => void;
}) {
  if (items.length === 0) {
    return (
      <EmptyState
        className="min-h-[calc(100vh-260px)]"
        icon={<Library size={34} />}
        title="No content available"
        subtitle="The admin has not uploaded any surah content yet."
      />
    );
  }

  return (
    <>
      <section className="px-4 py-3 sm:px-5">
        <SearchBox value={search} onChange={onSearch} />
      </section>
      {buckets.length === 0 ? (
        <EmptyState className="min-h-[360px]" icon={<Search size={32} />} title="No results found" subtitle="Try a different search term." />
      ) : (
        <section className="grid gap-3 px-4 py-1 sm:grid-cols-[repeat(auto-fill,minmax(210px,1fr))] sm:px-5 lg:grid-cols-[repeat(auto-fill,minmax(235px,1fr))]">
          {buckets.map((bucket) => (
            <SurahFolder key={bucket.surahNumber} bucket={bucket} onSelect={() => onSelect(bucket.surahNumber)} />
          ))}
        </section>
      )}
    </>
  );
}

function SharedTab({ assignments, onRemove }: { assignments: PodcastAssignment[]; onRemove: (assignment: PodcastAssignment) => void }) {
  if (assignments.length === 0) {
    return (
      <EmptyState
        className="min-h-[calc(100vh-260px)]"
        icon={<Share2 size={34} />}
        title="Nothing shared yet"
        subtitle="Open a surah and share content with your students."
      />
    );
  }
  return (
    <section className="px-4 py-3 sm:px-5">
      <div className="mx-auto grid max-w-3xl gap-2">
        {assignments.map((assignment) => (
          <article key={assignment.id} className="flex items-center gap-3 rounded-[14px] border border-[#E2E8F0] bg-white px-4 py-3 shadow-[0_2px_8px_rgba(15,23,42,0.03)]">
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
              <Podcast size={22} />
            </span>
            <div className="min-w-0 flex-1">
              <h2 className="truncate text-sm font-semibold text-[#111827]">{assignment.podcastTitle || "Surah content"}</h2>
              <p className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[#6B7280]">
                <span className="inline-flex items-center gap-1">
                  <Users size={14} className="text-[#94A3B8]" />
                  {assignment.studentIds.length} student{assignment.studentIds.length === 1 ? "" : "s"}
                </span>
                {assignment.assignedAt ? (
                  <span className="inline-flex items-center gap-1">
                    <Clock3 size={14} className="text-[#94A3B8]" />
                    {shortDate(assignment.assignedAt)}
                  </span>
                ) : null}
              </p>
            </div>
            <button type="button" onClick={() => onRemove(assignment)} aria-label={`Remove ${assignment.podcastTitle}`} className="grid h-10 w-10 place-items-center rounded-xl text-[#EF4444] hover:bg-[#FEF2F2]">
              <X size={20} />
            </button>
          </article>
        ))}
      </div>
    </section>
  );
}

function SearchBox({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return (
    <label className="relative block h-12">
      <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={20} />
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder="Search by surah name or number..."
        aria-label="Search by surah name or number"
        className="h-full w-full rounded-xl border border-[#E2E8F0] bg-white pl-11 pr-10 text-sm text-[#0F172A] outline-none placeholder:text-[#94A3B8] focus:border-[#0E72ED] focus:ring-2 focus:ring-[#BFDBFE]"
      />
      {value ? (
        <button type="button" aria-label="Clear search" onClick={() => onChange("")} className="absolute right-2 top-1/2 grid h-8 w-8 -translate-y-1/2 place-items-center rounded-lg text-[#64748B] hover:bg-[#F1F5F9]">
          <X size={16} />
        </button>
      ) : null}
    </label>
  );
}

function SurahFolder({ bucket, onSelect }: { bucket: SurahBucket; onSelect: () => void }) {
  const audio = bucket.items.filter((item) => item.mediaType === "audio").length;
  const video = bucket.items.filter((item) => item.mediaType === "video").length;
  const pdf = bucket.items.filter((item) => item.mediaType === "pdf").length;
  const text = bucket.items.filter((item) => item.mediaType === "text").length;
  return (
    <button type="button" onClick={onSelect} className="min-h-[184px] rounded-2xl border border-[#E2E8F0] bg-white p-3.5 text-left shadow-[0_4px_10px_rgba(15,23,42,0.04)]">
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
    </button>
  );
}

function ContentBadge({ icon, count, tone }: { icon: ReactNode; count: number; tone: "blue" | "purple" | "red" | "green" }) {
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

function SurahDetail({
  bucket,
  onBack,
  onShare,
}: {
  bucket: SurahBucket;
  onBack: () => void;
  onShare: (item: PodcastItem) => void;
}) {
  const audio = bucket.items.filter((item) => item.mediaType === "audio");
  const video = bucket.items.filter((item) => item.mediaType === "video");
  const pdf = bucket.items.filter((item) => item.mediaType === "pdf");
  const text = bucket.items.filter((item) => item.mediaType === "text");
  return (
    <section className="min-h-[calc(100vh-56px)]">
      <header className="flex min-h-[61px] items-center gap-1 border-b border-[#E2E8F0] bg-white px-2">
        <button type="button" onClick={onBack} aria-label="Back to surah library" className="grid h-12 w-12 place-items-center rounded-xl text-[#1E293B] hover:bg-[#F8FAFC]">
          <ArrowLeft size={22} />
        </button>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-[17px] font-bold text-[#1E293B]">
            {bucket.surahNumber}. {bucket.surahNameEn || `Surah ${bucket.surahNumber}`}
          </h1>
          {bucket.surahNameAr ? <p className="truncate text-xs text-[#64748B]">{bucket.surahNameAr}</p> : null}
        </div>
      </header>
      <div className="px-4 py-3 sm:px-5">
        {bucket.items.length === 0 ? (
          <EmptyState className="min-h-[420px]" icon={<Library size={34} />} title="No content yet" subtitle="Content for this surah has not been added yet." />
        ) : (
          <div className="mx-auto grid max-w-3xl gap-5">
            {audio.length ? <DetailSection title="Audio" icon={<Headphones size={18} />} items={audio} onShare={onShare} /> : null}
            {video.length ? <DetailSection title="Video" icon={<Video size={18} />} items={video} onShare={onShare} /> : null}
            {pdf.length ? <DetailSection title="PDF" icon={<FileText size={18} />} items={pdf} onShare={onShare} /> : null}
            {text.length ? <DetailSection title="Text" icon={<BookOpen size={18} />} items={text} onShare={onShare} /> : null}
          </div>
        )}
      </div>
    </section>
  );
}

function DetailSection({
  title,
  icon,
  items,
  onShare,
}: {
  title: string;
  icon: ReactNode;
  items: PodcastItem[];
  onShare: (item: PodcastItem) => void;
}) {
  return (
    <section>
      <div className="mb-2 flex items-center gap-2">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-[#EAF1F8] text-[#1E3A5F]">{icon}</span>
        <h2 className="text-base font-bold text-[#1E3A5F]">
          {title} ({items.length})
        </h2>
      </div>
      <div className="grid gap-2">
        {items.map((item) => (
          <PodcastDetailCard key={item.id} item={item} onShare={() => onShare(item)} />
        ))}
      </div>
    </section>
  );
}

function PodcastDetailCard({ item, onShare }: { item: PodcastItem; onShare: () => void }) {
  return (
    <article className="rounded-[14px] border border-[#E2E8F0] bg-white p-3.5 shadow-[0_2px_8px_rgba(15,23,42,0.03)]">
      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-start gap-2">
            <h3 className="min-w-0 flex-1 text-sm font-semibold text-[#111827]">{item.title || "Untitled content"}</h3>
            <LanguageBadge language={item.language} />
            <button type="button" onClick={onShare} aria-label={`Share ${item.title || "content"} with students`} className="grid h-8 w-8 shrink-0 place-items-center rounded-lg text-[#94A3B8] hover:bg-[#F8FAFC] hover:text-[#0E72ED]">
              <MoreHorizontal size={20} />
            </button>
          </div>
          {item.description ? <p className="mt-1 line-clamp-2 text-xs text-[#6B7280]">{item.description}</p> : null}
          <MetaRow item={item} />
        </div>
      </div>
      {item.mediaType === "text" ? (
        <div className="mt-3 rounded-[10px] border border-[#E2E8F0] bg-[#F8FAFC] p-3 text-sm leading-6 text-[#374151]">{item.textContent}</div>
      ) : item.mediaType === "audio" && item.downloadUrl ? (
        <audio controls src={item.downloadUrl} className="mt-3 w-full" />
      ) : item.mediaType === "video" && item.downloadUrl ? (
        <video controls src={item.downloadUrl} className="mt-3 aspect-video w-full rounded-xl bg-black" />
      ) : item.mediaType === "pdf" && item.downloadUrl ? (
        <a href={item.downloadUrl} target="_blank" rel="noreferrer" className="mt-3 inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-xl bg-[#EF4444] px-4 text-sm font-semibold text-white">
          <FileText size={17} />
          Open PDF
        </a>
      ) : null}
      <button type="button" onClick={onShare} className="mt-3 inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#E7F3FF] px-4 text-sm font-semibold text-[#0E72ED]">
        <Share2 size={16} />
        Share with Students
      </button>
    </article>
  );
}

function MetaRow({ item }: { item: PodcastItem }) {
  const details = [
    item.durationSeconds > 0 ? formatDuration(item.durationSeconds) : "",
    item.fileSizeBytes > 0 ? formatBytes(item.fileSizeBytes) : "",
    item.createdAt ? shortDate(item.createdAt) : "",
  ].filter(Boolean);
  if (!details.length) return null;
  return <p className="mt-2 text-[11px] text-[#94A3B8]">{details.join("  |  ")}</p>;
}

function LanguageBadge({ language }: { language: string }) {
  const label = language === "en" ? "EN" : language === "fr" ? "FR" : language === "ar" ? "AR" : language.toUpperCase();
  return <span className="rounded bg-[#ECFDF5] px-1.5 py-1 text-[10px] font-bold text-[#10B981]">{label || "EN"}</span>;
}

function SharePodcastDialog({
  item,
  teacherId,
  teacherName,
  onClose,
  onSaved,
}: {
  item: PodcastItem;
  teacherId: string;
  teacherName: string;
  onClose: () => void;
  onSaved: (assignment: PodcastAssignment) => void;
}) {
  const [students, setStudents] = useState<StudentOption[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    void (async () => {
      setLoading(true);
      setMessage("");
      try {
        const [loadedStudents, assignedIds] = await Promise.all([loadStudentsForTeacher(teacherId), loadAssignedStudentIds(item.id, teacherId)]);
        if (!mounted) return;
        setStudents(loadedStudents);
        setSelectedIds(new Set(assignedIds));
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Failed to load students");
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [item.id, teacherId]);

  const filtered = students.filter((student) => student.name.toLowerCase().includes(search.trim().toLowerCase()));
  const allSelected = students.length > 0 && selectedIds.size === students.length;

  function toggleStudent(id: string) {
    setSelectedIds((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    setSelectedIds(allSelected ? new Set() : new Set(students.map((student) => student.id)));
  }

  async function save() {
    if (!selectedIds.size) return;
    setSaving(true);
    setMessage("");
    try {
      const saved = await assignPodcast(item, teacherId, teacherName, Array.from(selectedIds));
      onSaved(saved);
    } catch (error) {
      setMessage(surahActionError(error, "Failed to share this content."));
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-40 grid place-items-end bg-black/35 sm:place-items-center sm:p-4" role="dialog" aria-modal="true" aria-label="Share with Students">
      <section className="flex max-h-[90vh] w-full max-w-[480px] flex-col rounded-t-[20px] bg-white p-5 shadow-2xl sm:max-h-[85vh] sm:rounded-[20px]">
        <div className="flex items-center gap-3">
          <span className="grid h-11 w-11 place-items-center rounded-xl bg-[#E7F3FF] text-[#0E72ED]">
            <Share2 size={22} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#1E293B]">Share with Students</h2>
            <p className="truncate text-[13px] text-[#64748B]">{item.title || "Surah content"}</p>
          </div>
          <button type="button" onClick={onClose} disabled={saving} aria-label="Close share dialog" className="grid h-9 w-9 place-items-center rounded-lg text-[#94A3B8] hover:bg-[#F8FAFC]">
            <X size={19} />
          </button>
        </div>

        <div className="mt-5">
          <label className="relative block h-11">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={19} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search students..."
              aria-label="Search students"
              className="h-full w-full rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] pl-10 pr-3 text-sm outline-none focus:border-[#0E72ED] focus:ring-2 focus:ring-[#BFDBFE]"
            />
          </label>
        </div>

        {!loading && students.length > 0 ? (
          <div className="mt-3 flex items-center justify-between">
            <p className="text-[13px] text-[#64748B]">
              {selectedIds.size} of {students.length} selected
            </p>
            <button type="button" onClick={toggleAll} className="min-h-9 rounded-lg px-2 text-[13px] font-semibold text-[#0E72ED]">
              {allSelected ? "Deselect All" : "Select All"}
            </button>
          </div>
        ) : null}

        <div className="mt-2 min-h-[240px] flex-1 overflow-y-auto">
          {loading ? (
            <div className="grid h-56 place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0E72ED]" />
            </div>
          ) : students.length === 0 ? (
            <EmptyState className="min-h-[240px]" icon={<Users size={30} />} title="No students found" subtitle="No students in your assigned classes." compact />
          ) : filtered.length === 0 ? (
            <EmptyState className="min-h-[240px]" icon={<Search size={30} />} title="No students found" subtitle="Try a different search term." compact />
          ) : (
            <div className="grid gap-1">
              {filtered.map((student) => {
                const selected = selectedIds.has(student.id);
                return (
                  <button
                    type="button"
                    key={student.id}
                    onClick={() => toggleStudent(student.id)}
                    className={`flex min-h-11 items-center gap-3 rounded-[10px] px-2 text-left ${selected ? "bg-[#E7F3FF]" : "hover:bg-[#F8FAFC]"}`}
                  >
                    <span className={`grid h-5 w-5 place-items-center rounded border ${selected ? "border-[#0E72ED] bg-[#0E72ED] text-white" : "border-[#CBD5E1] bg-white text-transparent"}`}>
                      <Check size={14} />
                    </span>
                    <span className={`min-w-0 flex-1 truncate text-sm ${selected ? "font-semibold text-[#111827]" : "font-normal text-[#111827]"}`}>{student.name}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {message ? <p className="mt-2 rounded-lg border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-[13px] text-[#EF4444]">{message}</p> : null}

        <div className="mt-4 flex justify-end gap-3">
          <button type="button" onClick={onClose} disabled={saving} className="min-h-11 rounded-xl px-5 text-sm font-semibold text-[#6B7280] disabled:opacity-60">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => void save()}
            disabled={saving || selectedIds.size === 0}
            className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-[#0E72ED] px-6 text-sm font-semibold text-white disabled:bg-[#93C5FD] disabled:text-white/80"
          >
            {saving ? <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/50 border-t-white" /> : <Check size={18} />}
            {saving ? "Saving..." : `Share (${selectedIds.size})`}
          </button>
        </div>
      </section>
    </div>
  );
}

function EmptyState({
  icon,
  title,
  subtitle,
  className = "",
  compact = false,
}: {
  icon: ReactNode;
  title: string;
  subtitle: string;
  className?: string;
  compact?: boolean;
}) {
  return (
    <section className={`grid place-items-center px-8 py-10 ${className}`}>
      <div className={`w-full max-w-[410px] rounded-2xl bg-white text-center shadow-[0_4px_10px_rgba(15,23,42,0.04)] ${compact ? "px-5 py-6" : "px-7 py-7"}`}>
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-[#E7F3FF] text-[#7DB5F6]">{icon}</div>
        <h2 className="mt-4 text-base font-semibold text-[#374151]">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-[#6B7280]">{subtitle}</p>
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

async function refresh(
  teacherId: string,
  setLoading: (value: boolean) => void,
  setMessage: (value: string) => void,
  setItems: (value: PodcastItem[]) => void,
  setAssignments: (value: PodcastAssignment[]) => void,
  setSearch: (value: string) => void,
) {
  if (!teacherId) return;
  setLoading(true);
  setMessage("");
  try {
    const loaded = await loadTeacherSurahData(teacherId);
    setItems(activeOrAllItems(loaded.items));
    setAssignments(loaded.assignments);
    setSearch("");
  } catch (error) {
    setMessage(error instanceof Error ? error.message : "Failed to load content");
  } finally {
    setLoading(false);
  }
}

async function loadTeacherSurahData(teacherId: string) {
  const [items, assignments] = await Promise.all([loadPodcastItems(), loadTeacherAssignments(teacherId)]);
  return { items, assignments };
}

async function loadPodcastItems() {
  try {
    const snap = await getDocs(query(collection(db, "surah_podcasts"), orderBy("surahNumber"), limit(100)));
    return snap.docs.map((docSnap) => normalizePodcast(docSnap.id, docSnap.data() as Record<string, unknown>));
  } catch {
    const snap = await getDocs(query(collection(db, "surah_podcasts"), limit(100)));
    return snap.docs.map((docSnap) => normalizePodcast(docSnap.id, docSnap.data() as Record<string, unknown>)).sort((a, b) => a.surahNumber - b.surahNumber);
  }
}

async function loadTeacherAssignments(teacherId: string) {
  const snap = await getDocs(query(collection(db, "podcast_assignments"), where("teacherId", "==", teacherId), where("active", "==", true)));
  return snap.docs
    .map((docSnap) => normalizeAssignment(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.assignedAt?.getTime() ?? 0) - (a.assignedAt?.getTime() ?? 0));
}

async function loadStudentsForTeacher(teacherId: string) {
  const snap = await getDocs(query(collection(db, "teaching_shifts"), where("teacher_id", "==", teacherId), where("status", "in", ["scheduled", "active"])));
  const students = new Map<string, string>();
  for (const docSnap of snap.docs) {
    const data = docSnap.data() as Record<string, unknown>;
    const ids = arrayValue(data.student_ids);
    const names = arrayValue(data.student_names);
    ids.forEach((id, index) => {
      if (!students.has(id)) students.set(id, names[index] || "Student");
    });
  }
  return Array.from(students.entries())
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

async function loadAssignedStudentIds(podcastId: string, teacherId: string) {
  const snap = await getDocs(query(collection(db, "podcast_assignments"), where("podcastId", "==", podcastId), where("teacherId", "==", teacherId), where("active", "==", true), limit(1)));
  if (snap.empty) return [];
  return arrayValue(snap.docs[0].data().studentIds);
}

async function assignPodcast(item: PodcastItem, teacherId: string, teacherName: string, studentIds: string[]) {
  if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
  const existing = await getDocs(query(collection(db, "podcast_assignments"), where("podcastId", "==", item.id), where("teacherId", "==", teacherId), limit(1)));
  if (!existing.empty) {
    const ref = existing.docs[0].ref;
    await updateDoc(ref, {
      studentIds,
      active: true,
      assignedAt: new Date(),
    });
    return normalizeAssignment(existing.docs[0].id, {
      ...existing.docs[0].data(),
      podcastId: item.id,
      surahNumber: item.surahNumber,
      surahNameEn: item.surahNameEn,
      podcastTitle: item.title,
      teacherId,
      teacherName,
      studentIds,
      active: true,
      assignedAt: new Date(),
    });
  }
  const docRef = await addDoc(collection(db, "podcast_assignments"), {
    podcastId: item.id,
    surahNumber: item.surahNumber,
    surahNameEn: item.surahNameEn,
    podcastTitle: item.title,
    teacherId,
    teacherName: teacherName || "Teacher",
    studentIds,
    active: true,
    assignedAt: new Date(),
  });
  return normalizeAssignment(docRef.id, {
    podcastId: item.id,
    surahNumber: item.surahNumber,
    surahNameEn: item.surahNameEn,
    podcastTitle: item.title,
    teacherId,
    teacherName,
    studentIds,
    active: true,
    assignedAt: new Date(),
  });
}

async function removeAssignment(
  assignment: PodcastAssignment,
  teacherId: string,
  setAssignments: (value: (current: PodcastAssignment[]) => PodcastAssignment[]) => void,
  setMessage: (value: string) => void,
) {
  if (!navigator.onLine) {
    setMessage("You appear to be offline. Reconnect and try again.");
    return;
  }
  try {
    await updateDoc(doc(db, "podcast_assignments", assignment.id), { active: false });
  } catch {
    try {
      const snap = await getDocs(query(collection(db, "podcast_assignments"), where("teacherId", "==", teacherId), where("podcastId", "==", assignment.podcastId), limit(1)));
      if (!snap.empty) await updateDoc(snap.docs[0].ref, { active: false });
    } catch (error) {
      setMessage(surahActionError(error, "Failed to remove shared content."));
      return;
    }
  }
  setAssignments((current) => current.filter((item) => item.id !== assignment.id));
}

function activeOrAllItems(items: PodcastItem[]) {
  const active = items.filter((item) => item.status === "active");
  return active.length || items.length === 0 ? active : items;
}

function surahActionError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error || "");
  if (/permission-denied|insufficient permissions/i.test(message)) return "You do not have permission to change this shared content. Contact an administrator if this continues.";
  if (/unavailable|network|offline/i.test(message) || !navigator.onLine) return "You appear to be offline. Reconnect and try again.";
  return message.replace(/^Firebase:\s*/i, "").trim() || fallback;
}

function upsertAssignment(assignments: PodcastAssignment[], saved: PodcastAssignment) {
  const without = assignments.filter((assignment) => assignment.id !== saved.id);
  return [saved, ...without].sort((a, b) => (b.assignedAt?.getTime() ?? 0) - (a.assignedAt?.getTime() ?? 0));
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

function normalizePodcast(id: string, data: Record<string, unknown>): PodcastItem {
  return {
    id,
    surahNumber: numberValue(data.surahNumber),
    surahNameEn: stringValue(data.surahNameEn),
    surahNameAr: stringValue(data.surahNameAr),
    language: stringValue(data.language) || "en",
    title: stringValue(data.title),
    description: stringValue(data.description),
    mediaType: stringValue(data.mediaType) || "audio",
    textContent: stringValue(data.textContent),
    downloadUrl: stringValue(data.downloadUrl),
    fileSizeBytes: numberValue(data.fileSizeBytes),
    durationSeconds: numberValue(data.durationSeconds),
    status: stringValue(data.status) || "active",
    createdAt: dateValue(data.createdAt),
  };
}

function normalizeAssignment(id: string, data: Record<string, unknown>): PodcastAssignment {
  return {
    id,
    podcastId: stringValue(data.podcastId),
    surahNumber: numberValue(data.surahNumber),
    surahNameEn: stringValue(data.surahNameEn),
    podcastTitle: stringValue(data.podcastTitle),
    teacherId: stringValue(data.teacherId),
    teacherName: stringValue(data.teacherName),
    studentIds: arrayValue(data.studentIds),
    active: data.active === true,
    assignedAt: dateValue(data.assignedAt),
  };
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const firstName = stringValue(data?.first_name) || stringValue(data?.firstName);
  const lastName = stringValue(data?.last_name) || stringValue(data?.lastName);
  const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
  const displayName = fullName || user.displayName || user.email || "Teacher";
  return {
    displayName,
    firstName: firstName || displayName.split(/\s+/)[0] || "Teacher",
    initials: initialsFor(displayName),
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function arrayValue(value: unknown) {
  return Array.isArray(value) ? value.map((item) => String(item).trim()).filter(Boolean) : [];
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

function initialsFor(name: string) {
  return (
    name
      .split(/[^a-zA-Z0-9]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .join("") || "TE"
  );
}

function shortDate(value: Date) {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(value);
}

function formatDuration(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(rest).padStart(2, "0")}`;
}

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
