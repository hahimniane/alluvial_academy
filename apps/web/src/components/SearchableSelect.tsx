"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Check, ChevronDown, Search } from "lucide-react";

export type SearchableOption = {
  value: string;
  label: string;
  /** Secondary line, e.g. a student ID or email. */
  sub?: string;
};

/**
 * A single-select dropdown with a type-to-filter box, matching the Flutter
 * search-select dialogs. Filters on label AND sub, so students are findable
 * by name, code, or email.
 */
export function SearchableSelect({
  options,
  value,
  onChange,
  placeholder = "All",
  emptyOption = "All",
}: {
  options: SearchableOption[];
  value: string | null;
  onChange: (value: string | null) => void;
  placeholder?: string;
  emptyOption?: string;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDocClick = (event: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, [open]);

  const selected = useMemo(() => options.find((o) => o.value === value) ?? null, [options, value]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return options;
    return options.filter((o) => o.label.toLowerCase().includes(q) || (o.sub ?? "").toLowerCase().includes(q));
  }, [options, query]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center gap-2 rounded-lg border border-[#E2E8F0] bg-white px-2.5 py-1.5 text-left text-sm"
      >
        <span className={`flex-1 truncate ${selected ? "text-[#0F172A]" : "text-[#94A3B8]"}`}>
          {selected ? selected.label : placeholder}
        </span>
        <ChevronDown size={15} className="shrink-0 text-[#94A3B8]" />
      </button>

      {open ? (
        <div className="absolute z-30 mt-1 w-full min-w-[220px] overflow-hidden rounded-xl border border-[#E2E8F0] bg-white shadow-lg">
          <label className="flex items-center gap-2 border-b border-[#E2E8F0] px-3 py-2">
            <Search size={14} className="text-[#94A3B8]" />
            <input
              autoFocus
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search…"
              className="w-full text-sm outline-none"
            />
          </label>
          <div className="max-h-56 overflow-y-auto p-1">
            <Row
              label={emptyOption}
              selected={value === null}
              onClick={() => {
                onChange(null);
                setOpen(false);
                setQuery("");
              }}
            />
            {filtered.map((option) => (
              <Row
                key={option.value}
                label={option.label}
                sub={option.sub}
                selected={option.value === value}
                onClick={() => {
                  onChange(option.value);
                  setOpen(false);
                  setQuery("");
                }}
              />
            ))}
            {filtered.length === 0 ? <p className="px-2.5 py-2 text-sm text-[#94A3B8]">No matches.</p> : null}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function Row({
  label,
  sub,
  selected,
  onClick,
}: {
  label: string;
  sub?: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-sm ${
        selected ? "bg-[#EAF5FF] font-semibold text-[#0369A1]" : "text-[#334155] hover:bg-[#F8FAFC]"
      }`}
    >
      <span className="min-w-0 flex-1">
        <span className="block truncate">{label}</span>
        {sub ? <span className="block truncate text-xs text-[#94A3B8]">{sub}</span> : null}
      </span>
      {selected ? <Check size={14} className="shrink-0 text-[#0386FF]" /> : null}
    </button>
  );
}
