"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Calendar, GraduationCap, Loader2, RefreshCw, School } from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { ParentClassCard } from "@/components/ParentClassCard";
import { ParentAppBar, useNow } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { groupClasses, historyGroups, upcomingGroups, type ChildClasses } from "@/lib/parentClasses";
import { parentClassesText } from "@/lib/parentClassesText";
import { watchChildShifts } from "@/lib/parentData";
import type { ParentShift } from "@/lib/parentHome";
import { parentHomeText } from "@/lib/parentHomeText";
import { fetchParentChildren } from "@/lib/parentSession";
import type { ParentChild } from "@/lib/parentWeb";

type Children = { state: "loading" } | { state: "error" } | { state: "ready"; list: ParentChild[] };

/**
 * Classes (ParentClassesScreen, C-001…C-030): every class of every linked
 * child, live, teaching classes only; siblings in the same room share one
 * card; Upcoming (live, then joinable, then by start) and History (newest
 * first). Join opens /parent/classroom/, which joins exactly as Flutter does.
 */
export default function ParentClassesPage() {
  const session = useParentSession();
  const fr = useLocale() === "fr";
  const text = parentClassesText(fr);
  const homeText = parentHomeText(fr);
  const now = useNow(30_000);
  const [children, setChildren] = useState<Children>({ state: "loading" });
  const [showUpcoming, setShowUpcoming] = useState(true);
  const [byChild, setByChild] = useState<Record<string, ParentShift[]>>({});

  // C-003…C-006: the child lookup; refresh re-reads it without a spinner.
  const loadChildren = useCallback(
    (quiet: boolean) => {
      if (!quiet) setChildren({ state: "loading" });
      fetchParentChildren(session.uid)
        .then((list) => setChildren((current) => (current.state === "ready" && sameIds(current.list, list) ? current : { state: "ready", list })))
        .catch(() => setChildren((current) => (quiet && current.state === "ready" ? current : { state: "error" })));
    },
    [session.uid],
  );
  useEffect(() => loadChildren(false), [loadChildren]);

  // C-007: one live listener per child; rebuilt only when the child set changes.
  const childList = children.state === "ready" ? children.list : null;
  useEffect(() => {
    if (!childList) return;
    setByChild({});
    const stops = childList
      .filter((child) => child.id)
      .map((child) =>
        watchChildShifts(
          child.id,
          (shifts) => setByChild((current) => ({ ...current, [child.id]: shifts })),
          () => setByChild((current) => ({ ...current, [child.id]: current[child.id] ?? [] })),
        ),
      );
    return () => stops.forEach((stop) => stop());
  }, [childList]);

  const groups = useMemo(() => {
    if (!childList) return [];
    const entries: ChildClasses[] = childList
      .filter((child) => child.id && byChild[child.id])
      .map((child) => ({ childId: child.id, childName: child.name, shifts: byChild[child.id] }));
    return groupClasses(entries, now);
  }, [childList, byChild, now]);

  const list = showUpcoming ? upcomingGroups(groups, now) : historyGroups(groups, now);
  const initialLoading = childList !== null && childList.some((c) => c.id) && Object.keys(byChild).length === 0;

  return (
    <div className="flex min-h-full flex-col bg-[#F8FAFC]">
      <ParentAppBar
        title={text.classes}
        action={
          <button type="button" onClick={() => loadChildren(true)} aria-label={text.refresh} title={text.refresh} className="grid h-12 w-12 place-items-center rounded-full text-[#64748B] hover:bg-black/5">
            <RefreshCw size={22} />
          </button>
        }
      />
      {children.state === "loading" ? (
        <div className="grid flex-1 place-items-center py-16" role="status" aria-label={homeText.loading}>
          <Loader2 size={36} className="animate-spin text-[#0386FF]" />
        </div>
      ) : children.state === "error" ? (
        <div className="grid flex-1 place-items-center p-6 text-center" role="alert">
          <p className="font-semibold text-[#6B7280]">{text.childrenFailed}</p>
        </div>
      ) : children.list.length === 0 ? (
        <div className="grid flex-1 place-items-center p-6">
          <div className="flex flex-col items-center gap-3 text-center">
            <School size={56} className="text-[#9CA3AF]" />
            <p className="text-[15px] font-semibold text-[#6B7280]">{text.noChildren}</p>
          </div>
        </div>
      ) : (
        <div className="p-4">
          <div className="flex items-center gap-2.5">
            <span className="grid h-[34px] w-[34px] place-items-center rounded-[10px] bg-[#EFF6FF] text-[#1D4ED8]">
              <GraduationCap size={18} />
            </span>
            <h2 className="min-w-0 flex-1 text-base font-extrabold text-[#1E293B]">{text.classes}</h2>
            <div className="flex rounded-lg bg-[#F3F4F6] p-[3px]" role="group">
              {([true, false] as const).map((upcoming) => (
                <button
                  key={String(upcoming)}
                  type="button"
                  aria-pressed={showUpcoming === upcoming}
                  onClick={() => setShowUpcoming(upcoming)}
                  className={`rounded-md px-2.5 py-1.5 text-xs ${showUpcoming === upcoming ? "bg-white font-bold text-[#111827] shadow-[0_0_4px_rgba(0,0,0,0.06)]" : "font-medium text-[#6B7280]"}`}
                >
                  {upcoming ? "Upcoming" : "History"}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-3">
            {initialLoading ? (
              <div className="flex justify-center py-6" role="status" aria-label={homeText.loading}>
                <Loader2 size={36} className="animate-spin text-[#0386FF]" />
              </div>
            ) : list.length === 0 ? (
              <div className="flex items-center gap-2.5 rounded-xl border border-[#E5E7EB] bg-white p-4">
                <Calendar size={18} className="shrink-0 text-[#9CA3AF]" />
                <p className="text-[13px] text-[#6B7280]">{showUpcoming ? "No upcoming classes" : "No class history"}</p>
              </div>
            ) : (
              <div className="grid gap-3">
                {list.map((group) => (
                  <ParentClassCard key={group.key} shift={group.shift} now={now} text={homeText} childNames={group.childNames} />
                ))}
              </div>
            )}
          </div>
          <div className="h-6" />
        </div>
      )}
    </div>
  );
}

function sameIds(a: ParentChild[], b: ParentChild[]) {
  return a.map((c) => c.id).join("|") === b.map((c) => c.id).join("|");
}
