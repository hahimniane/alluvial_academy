"use client";

import { useMemo, useState } from "react";
import { CheckCircle2, ChevronDown, Circle, Search, X } from "lucide-react";
import { formatTimezoneForDisplay, timezonesByRegion } from "@/lib/timezones";

/**
 * Replica of the Flutter TimezoneSelectorDialog: search across every IANA
 * timezone, or browse them grouped by region in expandable sections. Options
 * render as radio tiles in the Flutter format
 * "City (Zone/Id) - ABBR (UTC±HH:MM)".
 */
export function TimezoneSelectorDialog({
  title = "Select Timezone",
  initialTimezone,
  onSelect,
  onClose,
}: {
  title?: string;
  initialTimezone: string;
  onSelect: (timezone: string) => void;
  onClose: () => void;
}) {
  const [search, setSearch] = useState("");
  const regions = useMemo(() => timezonesByRegion(), []);
  const options = useMemo(
    () =>
      regions.map(([region, ids]) =>
        [region, ids.map((id) => ({ id, display: formatTimezoneForDisplay(id) }))] as const,
      ),
    [regions],
  );
  const initialRegion = initialTimezone.includes("/") ? initialTimezone.split("/")[0] : initialTimezone === "UTC" ? "UTC" : "Other";
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set([initialRegion]));

  const query = search.trim().toLowerCase();
  const flat = useMemo(() => {
    if (!query) return [];
    return options.flatMap(([, opts]) => opts).filter((option) => option.display.toLowerCase().includes(query));
  }, [options, query]);

  const optionTile = (option: { id: string; display: string }) => {
    const selected = option.id === initialTimezone;
    return (
      <button
        key={option.id}
        type="button"
        onClick={() => onSelect(option.id)}
        className={`mb-2 flex w-full items-center gap-2.5 rounded-[10px] border px-3 py-2.5 text-left ${
          selected ? "border-[#0386FF] bg-[#0386FF]/10" : "border-[#E2E8F0] bg-white hover:bg-[#F8FAFC]"
        }`}
      >
        {selected ? (
          <CheckCircle2 size={18} className="shrink-0 text-[#0386FF]" />
        ) : (
          <Circle size={18} className="shrink-0 text-[#9CA3AF]" />
        )}
        <span className="min-w-0 flex-1 truncate text-[13px] font-semibold text-[#111827]">{option.display}</span>
      </button>
    );
  };

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" onMouseDown={onClose}>
      <div
        className="flex h-[min(600px,90vh)] max-h-[90vh] w-[520px] max-w-full flex-col rounded-2xl bg-white p-5 shadow-xl"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="mb-2.5 flex items-center">
          <h2 className="flex-1 text-lg font-bold text-[#111827]">{title}</h2>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#374151] hover:bg-[#F3F4F6]" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <label className="mb-3 flex items-center gap-2 rounded-[10px] border border-[#E2E8F0] px-3 py-2.5 focus-within:border-[#0386FF]">
          <Search size={16} className="shrink-0 text-[#6B7280]" />
          <input
            autoFocus
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by city, timezone id or abbreviation"
            className="w-full bg-transparent text-sm outline-none placeholder:text-[#9CA3AF]"
          />
        </label>
        <div className="min-h-0 flex-1 overflow-y-auto pr-1">
          {query ? (
            flat.length ? (
              flat.map(optionTile)
            ) : (
              <p className="px-2 py-6 text-center text-sm text-[#6B7280]">No timezones match &ldquo;{search.trim()}&rdquo;.</p>
            )
          ) : (
            options.map(([region, opts]) => {
              const isOpen = expanded.has(region);
              return (
                <div key={region} className="mb-2.5 rounded-xl border border-[#E2E8F0] bg-white">
                  <button
                    type="button"
                    onClick={() =>
                      setExpanded((prev) => {
                        const next = new Set(prev);
                        if (next.has(region)) next.delete(region);
                        else next.add(region);
                        return next;
                      })
                    }
                    className="flex w-full items-center px-3 py-2.5 text-left"
                  >
                    <span className="flex-1 text-[13px] font-bold text-[#111827]">
                      {region} ({opts.length})
                    </span>
                    <ChevronDown size={16} className={`text-[#6B7280] transition-transform ${isOpen ? "rotate-180" : ""}`} />
                  </button>
                  {isOpen ? <div className="px-3 pb-3">{opts.map(optionTile)}</div> : null}
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
