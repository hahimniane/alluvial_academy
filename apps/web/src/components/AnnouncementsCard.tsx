"use client";

import { onAuthStateChanged } from "firebase/auth";
import { Megaphone, Pin, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { auth } from "@/lib/firebase";
import { activeAnnouncements, nextUnseenPinned, type Announcement, type AnnouncementRole } from "@/lib/announcements";
import { fetchAnnouncements, fetchSeenAnnouncementIds, markAnnouncementSeen } from "@/lib/announcementsData";
import { dateLocale, useT } from "@/lib/i18n";

type Load = { state: "loading" } | { state: "error" } | { state: "ready"; items: Announcement[] };

const LONG_BODY = 220;

function formatDate(date: Date | null): string {
  if (!date) return "";
  return new Intl.DateTimeFormat(dateLocale(), { month: "short", day: "numeric", year: "numeric" }).format(date);
}

/**
 * School announcements addressed to `role`: pinned first, then newest, expired
 * ones hidden. An unseen pinned announcement opens once as a pop-up; closing it
 * records it in users/{uid}/announcement_reads.
 */
export function AnnouncementsCard({ role, className = "mt-5" }: { role: AnnouncementRole; className?: string }) {
  const t = useT();
  const [uid, setUid] = useState<string | null>(null);
  const [load, setLoad] = useState<Load>({ state: "loading" });
  const [reloadKey, setReloadKey] = useState(0);
  const [seen, setSeen] = useState<Set<string> | null>(null);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  useEffect(() => onAuthStateChanged(auth, (user) => setUid(user?.uid ?? null)), []);

  useEffect(() => {
    if (!uid) return;
    let active = true;
    setLoad({ state: "loading" });
    setSeen(null);
    fetchAnnouncements(role)
      .then(async (items) => {
        if (!active) return;
        setLoad({ state: "ready", items });
        const pinnedIds = activeAnnouncements(items, role, new Date()).filter((item) => item.pinned).map((item) => item.id);
        const seenIds = await fetchSeenAnnouncementIds(uid, pinnedIds);
        if (active) setSeen(seenIds);
      })
      .catch(() => {
        if (active) setLoad({ state: "error" });
      });
    return () => {
      active = false;
    };
  }, [uid, role, reloadKey]);

  const items = useMemo(() => (load.state === "ready" ? activeAnnouncements(load.items, role, new Date()) : []), [load, role]);
  const popup = seen ? nextUnseenPinned(items, seen) : null;

  const dismiss = (item: Announcement) => {
    setSeen((current) => new Set([...(current ?? []), item.id]));
    if (uid) void markAnnouncementSeen(uid, item.id).catch(() => undefined);
  };

  const toggle = (id: string) =>
    setExpanded((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  if (!uid || load.state === "loading") return null;

  return (
    <>
      <section className={`${className} rounded-2xl border border-black/5 bg-white p-4 shadow-[0_6px_18px_rgba(15,23,42,0.05)]`} aria-labelledby={`announcements-${role}`}>
        <div className="mb-3 flex items-center gap-3">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-blue-50 text-[#0386FF]">
            <Megaphone size={18} />
          </span>
          <h2 id={`announcements-${role}`} className="text-base font-black text-[#0F172A]">
            {t("Announcements")}
          </h2>
        </div>

        {load.state === "error" ? (
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm font-semibold text-amber-800" role="alert">
            <span className="min-w-0 flex-1">{t("Could not load announcements.")}</span>
            <button type="button" onClick={() => setReloadKey((k) => k + 1)} className="min-h-9 rounded-lg bg-amber-700 px-3 text-xs font-bold text-white">
              {t("Try again")}
            </button>
          </div>
        ) : items.length === 0 ? (
          <p className="rounded-xl bg-[#F8FAFC] px-3 py-3 text-sm font-semibold text-[#64748B]">{t("No announcements right now.")}</p>
        ) : (
          <ul className="grid max-h-[420px] gap-2 overflow-y-auto">
            {items.map((item) => {
              const long = item.body.length > LONG_BODY || item.body.split("\n").length > 4;
              const open = expanded.has(item.id);
              return (
                <li key={item.id} className={`rounded-xl border px-3 py-2.5 ${item.pinned ? "border-blue-200 bg-blue-50/60" : "border-black/5 bg-[#F8FAFC]"}`}>
                  <div className="flex items-start gap-2">
                    {item.pinned ? <Pin size={14} className="mt-1 shrink-0 text-[#0386FF]" aria-label={t("Pinned")} /> : null}
                    <p className="min-w-0 flex-1 text-sm font-bold text-[#0F172A]">{item.title}</p>
                  </div>
                  <p className="mt-0.5 text-xs font-semibold text-[#94A3B8]">
                    {[item.createdByName, formatDate(item.createdAt)].filter(Boolean).join(" · ")}
                  </p>
                  {item.body ? (
                    <p className={`mt-1.5 whitespace-pre-line break-words text-sm text-[#334155] ${long && !open ? "line-clamp-4" : ""}`}>{item.body}</p>
                  ) : null}
                  {long ? (
                    <button type="button" onClick={() => toggle(item.id)} className="mt-1 text-xs font-bold text-[#0386FF]">
                      {open ? t("Show less") : t("Show more")}
                    </button>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {popup ? <AnnouncementPopup item={popup} onClose={() => dismiss(popup)} /> : null}
    </>
  );
}

function AnnouncementPopup({ item, onClose }: { item: Announcement; onClose: () => void }) {
  const t = useT();
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[95] grid items-end bg-black/45 sm:place-items-center" role="dialog" aria-modal="true" aria-labelledby="announcement-popup-title">
      <div className="max-h-[85vh] w-full overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:max-w-lg sm:rounded-3xl">
        <header className="flex items-start gap-3 border-b border-[#E2E8F0] p-5">
          <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-blue-50 text-[#0386FF]">
            <Megaphone size={22} />
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-xs font-bold uppercase tracking-wide text-[#0386FF]">{t("Announcement")}</p>
            <h2 id="announcement-popup-title" className="text-lg font-extrabold text-[#111827]">{item.title}</h2>
            <p className="text-xs font-semibold text-[#94A3B8]">{[item.createdByName, formatDate(item.createdAt)].filter(Boolean).join(" · ")}</p>
          </div>
          <button type="button" aria-label={t("Close")} onClick={onClose} className="grid h-10 w-10 shrink-0 place-items-center rounded-xl text-[#64748B] hover:bg-[#F1F5F9]">
            <X size={20} />
          </button>
        </header>
        {item.body ? <p className="max-h-[50vh] overflow-y-auto whitespace-pre-line break-words p-5 text-sm leading-6 text-[#334155]">{item.body}</p> : null}
        <div className="border-t border-[#E2E8F0] p-4">
          <button type="button" onClick={onClose} className="min-h-11 w-full rounded-xl bg-[#0386FF] text-sm font-bold text-white">
            {t("Got it")}
          </button>
        </div>
      </div>
    </div>
  );
}
