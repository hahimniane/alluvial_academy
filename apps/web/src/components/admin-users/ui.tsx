"use client";

import type { ReactNode } from "react";
import type { TypeTone, UserRow } from "@/lib/adminUsers";
import { initialsOf, typeInfo } from "@/lib/adminUsers";

export const TONES: Record<TypeTone, { bg: string; fg: string }> = {
  student: { bg: "#ECFDF5", fg: "#047857" },
  teacher: { bg: "#EFF6FF", fg: "#1D4ED8" },
  parent: { bg: "#F5F3FF", fg: "#6D28D9" },
  admin: { bg: "#FFFBEB", fg: "#B45309" },
  other: { bg: "#F1F5F9", fg: "#475569" },
};

export function Pill({ bg, fg, children }: { bg: string; fg: string; children: ReactNode }) {
  return (
    <span className="inline-block whitespace-nowrap rounded-full px-2.5 py-[3px] text-xs font-semibold" style={{ background: bg, color: fg }}>
      {children}
    </span>
  );
}

export function TypePill({ row }: { row: UserRow }) {
  const t = typeInfo(row);
  return <Pill {...TONES[t.tone]}>{t.label}</Pill>;
}

export function ArchivedBadge() {
  return <span className="ml-1.5 inline-block rounded-full bg-[#FEF2F2] px-2 py-0.5 text-[11px] font-semibold text-[#B91C1C]">Archived</span>;
}

export function Avatar({ row, size }: { row: UserRow; size: 36 | 40 | 56 }) {
  const t = TONES[typeInfo(row).tone];
  const big = size > 40;
  return (
    <span
      aria-hidden="true"
      className="grid flex-none place-items-center font-bold"
      style={{
        width: size,
        height: size,
        borderRadius: big ? 14 : 10,
        background: t.bg,
        color: t.fg,
        fontSize: big ? 18 : 13,
      }}
    >
      {initialsOf(row)}
    </span>
  );
}

export function Chip({ on, onClick, children }: { on: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-pressed={on}
      onClick={onClick}
      className={`min-h-9 flex-none cursor-pointer rounded-full border px-3.5 text-[13px] font-semibold transition-colors ${
        on ? "border-[#0369D9] bg-[#0369D9] text-white" : "border-[#CBD5E1] bg-white text-[#334155] hover:border-[#94A3B8]"
      }`}
    >
      {children}
    </button>
  );
}

export function Spinner({ label }: { label: string }) {
  return (
    <div role="status" className="flex items-center justify-center gap-3 p-12 text-sm text-[#64748B]">
      <span className="h-5 w-5 animate-spin rounded-full border-2 border-[#CBD5E1] border-t-[#0369D9]" aria-hidden="true" />
      {label}
    </div>
  );
}
