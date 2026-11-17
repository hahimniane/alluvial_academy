"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Check, X } from "lucide-react";
import { parentMatches, type ParentChoice } from "@/lib/adminUsers";

/** "Filter by parent": pick a parent to list only the students linked to them. */
export function ParentPicker({
  parents,
  selectedId,
  onPick,
  onClear,
  onClose,
}: {
  parents: ParentChoice[];
  selectedId: string | null;
  onPick: (id: string) => void;
  onClear: () => void;
  onClose: () => void;
}) {
  const [q, setQ] = useState("");
  const boxRef = useRef<HTMLDivElement>(null);
  const shown = useMemo(() => parents.filter((p) => parentMatches(p, q)), [parents, q]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) onClose();
    };
    document.addEventListener("keydown", onKey);
    document.addEventListener("mousedown", onDown);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("mousedown", onDown);
    };
  }, [onClose]);

  return (
    <div
      ref={boxRef}
      role="dialog"
      aria-label="Pick a parent"
      className="absolute left-0 top-[46px] z-30 flex max-h-[min(520px,75vh)] w-[min(380px,calc(100vw-32px))] flex-col gap-2 rounded-[14px] border border-[#E2E8F0] bg-white p-3 shadow-[0_16px_40px_rgba(15,23,42,0.14)]"
    >
      <div className="flex items-center justify-between gap-2">
        <div className="font-bold">Pick a parent</div>
        <button type="button" onClick={onClose} aria-label="Close" className="grid h-9 w-9 place-items-center rounded-lg text-[#334155] hover:bg-[#F1F5F9]">
          <X size={16} aria-hidden="true" />
        </button>
      </div>
      <input
        type="search"
        autoFocus
        aria-label="Search parents"
        placeholder="Search by name, email, phone or ID"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        className="min-h-10 rounded-[10px] border border-[#CBD5E1] px-3 text-sm"
      />
      <div className="text-xs text-[#64748B]">{shown.length === 1 ? "1 parent" : `${shown.length} parents`}</div>
      <div className="-mx-1 flex min-h-0 flex-1 flex-col gap-1.5 overflow-y-auto px-1">
        {shown.length === 0 ? (
          <div className="py-8 text-center text-sm text-[#64748B]">No parents found</div>
        ) : (
          shown.map((p) => {
            const on = p.id === selectedId;
            return (
              <button
                key={p.id}
                type="button"
                onClick={() => onPick(p.id)}
                aria-pressed={on}
                className={`flex min-h-12 w-full items-center gap-2.5 rounded-[10px] border p-2 text-left ${on ? "border-[#C4B5FD] bg-[#F5F3FF]" : "border-[#F1F5F9] hover:bg-[#F8FAFC]"}`}
              >
                <span aria-hidden="true" className="grid h-[34px] w-[34px] flex-none place-items-center rounded-[10px] bg-[#EDE9FE] font-bold text-[#5B21B6]">
                  {(p.name || p.email || "?").charAt(0).toUpperCase()}
                </span>
                <span className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-semibold text-[#0F172A]">
                    {p.name || p.email || p.id}
                    {!p.isActive ? <span className="ml-1.5 text-[11px] font-semibold text-[#B91C1C]">Archived</span> : null}
                  </span>
                  <span className="truncate text-xs text-[#64748B]">{p.email}</span>
                </span>
                <span className="flex-none rounded-full bg-[#EDE9FE] px-2 py-0.5 text-xs font-semibold text-[#5B21B6]">
                  {p.studentCount === 1 ? "1 student" : `${p.studentCount} students`}
                </span>
                {on ? <Check size={16} className="flex-none text-[#5B21B6]" aria-label="Selected" /> : null}
              </button>
            );
          })
        )}
      </div>
      {selectedId ? (
        <button type="button" onClick={onClear} className="min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white font-semibold text-[#334155] hover:bg-[#F8FAFC]">
          Clear parent filter
        </button>
      ) : null}
    </div>
  );
}
