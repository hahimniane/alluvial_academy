"use client";

import { useMemo, useState } from "react";
import { CheckCircle2, ChevronDown, Circle, Search, X } from "lucide-react";

/**
 * The ONE way to pick a teacher or a student anywhere in the admin.
 *
 * Ported from the Flutter EmployeeSelectionDialog, which serves both roles
 * (single-select for a teacher, multi-select for students) so the two never
 * drift apart. Students always show their ID in green: names repeat across
 * families — one parent here has two children both called "Soulaymane Barry" —
 * so a name alone can't identify anybody.
 *
 * Search matches name (either order), email, and any id/code, exactly like the
 * Flutter AppSearch helper.
 */

export type PersonOption = {
  id: string;
  name: string;
  email: string;
  /** student_code / kiosk_code. Present = render as a student row. */
  code?: string;
  isStudent?: boolean;
};

export function personMatches(person: PersonOption, query: string): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  const parts = person.name.split(/\s+/).filter(Boolean);
  const reversed = parts.length > 1 ? [...parts].reverse().join(" ") : person.name;
  return [person.name, reversed, person.email, person.code ?? "", person.id]
    .filter(Boolean)
    .some((field) => field.toLowerCase().includes(q));
}

/** The tappable field that opens the picker — Flutter's _PickerField. */
export function PersonPickerField({
  label,
  value,
  placeholder,
  onOpen,
  disabled,
}: {
  label?: string;
  value: string;
  placeholder: string;
  onOpen: () => void;
  disabled?: boolean;
}) {
  return (
    <div>
      {label ? <p className="mb-1 text-xs font-bold uppercase tracking-wide text-[#64748B]">{label}</p> : null}
      <button
        type="button"
        onClick={onOpen}
        disabled={disabled}
        className="flex w-full items-center gap-2 rounded-xl border border-[#D1D5DB] bg-white px-3 py-2.5 text-left text-sm disabled:opacity-60"
      >
        <span className={`min-w-0 flex-1 truncate ${value ? "font-semibold text-[#111827]" : "text-[#6B7280]"}`}>
          {value || placeholder}
        </span>
        <ChevronDown size={16} className="shrink-0 text-[#6B7280]" />
      </button>
    </div>
  );
}

export function PersonSelectDialog({
  title,
  people,
  selectedIds,
  multiSelect = false,
  clearLabel,
  onConfirm,
  onClose,
}: {
  title: string;
  people: PersonOption[];
  selectedIds: string[];
  multiSelect?: boolean;
  /** Shown as a first row that clears the selection (for filters). */
  clearLabel?: string;
  onConfirm: (ids: string[]) => void;
  onClose: () => void;
}) {
  const [search, setSearch] = useState("");
  const [chosen, setChosen] = useState<Set<string>>(() => new Set(selectedIds));
  const [selectedOnly, setSelectedOnly] = useState(false);

  const visible = useMemo(() => {
    const base = selectedOnly ? people.filter((p) => chosen.has(p.id)) : people;
    return base.filter((p) => personMatches(p, search));
  }, [people, search, selectedOnly, chosen]);

  // Clicking away (or the X) confirms what is ticked rather than throwing it
  // away — a multi-select picker should never silently discard work.
  const dismiss = () => {
    if (multiSelect) onConfirm([...chosen]);
    else onClose();
  };

  const toggle = (person: PersonOption) => {
    if (!multiSelect) {
      onConfirm([person.id]); // single select auto-confirms, like Flutter
      return;
    }
    setChosen((prev) => {
      const next = new Set(prev);
      if (next.has(person.id)) next.delete(person.id);
      else next.add(person.id);
      return next;
    });
  };

  return (
    <div className="fixed inset-0 z-[80] grid place-items-center bg-black/40 p-4" onMouseDown={dismiss}>
      <div
        className="flex h-[min(600px,90vh)] max-h-[90vh] w-[520px] max-w-full flex-col rounded-2xl bg-white p-5 shadow-xl"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="mb-2.5 flex items-center gap-2">
          <h2 className="flex-1 text-lg font-bold text-[#111827]">{title}</h2>
          <button type="button" onClick={dismiss} className="grid h-8 w-8 place-items-center rounded-full text-[#374151] hover:bg-[#F3F4F6]" aria-label="Close">
            <X size={18} />
          </button>
        </div>

        <label className="mb-3 flex items-center gap-2 rounded-[10px] border border-[#E2E8F0] px-3 py-2.5 focus-within:border-[#0386FF]">
          <Search size={16} className="shrink-0 text-[#6B7280]" />
          <input
            autoFocus
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by name, ID or email"
            className="w-full bg-transparent text-sm outline-none placeholder:text-[#9CA3AF]"
          />
        </label>

        {multiSelect ? (
          <button
            type="button"
            onClick={() => setSelectedOnly((v) => !v)}
            className={`mb-3 self-start rounded-full px-3 py-1.5 text-xs font-semibold ${
              selectedOnly ? "bg-[#EFF6FF] text-[#0386FF]" : "bg-[#F3F4F6] text-[#4B5563]"
            }`}
          >
            {chosen.size} selected
          </button>
        ) : null}

        <div className="min-h-0 flex-1 overflow-y-auto pr-1">
          {clearLabel && !search ? (
            <button
              type="button"
              onClick={() => onConfirm([])}
              className="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2.5 text-left hover:bg-[#F8FAFC]"
            >
              <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#F3F4F6] text-sm font-bold text-[#6B7280]">
                ∗
              </span>
              <span className="text-sm font-semibold text-[#334155]">{clearLabel}</span>
            </button>
          ) : null}

          {visible.length === 0 ? (
            <p className="px-2 py-8 text-center text-sm text-[#9CA3AF]">
              {selectedOnly ? "No users selected" : "No users found"}
            </p>
          ) : (
            visible.map((person) => {
              const isSelected = chosen.has(person.id);
              const isStudent = person.isStudent ?? Boolean(person.code);
              return (
                <button
                  key={person.id}
                  type="button"
                  onClick={() => toggle(person)}
                  className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-[#F8FAFC]"
                >
                  <span
                    className={`grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-bold ${
                      isSelected ? "bg-[#0386FF] text-white" : "bg-[#F3F4F6] text-[#6B7280]"
                    }`}
                  >
                    {person.name.trim().charAt(0).toUpperCase() || "?"}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium text-[#111827]">{person.name}</span>
                    {isStudent ? (
                      <span className="block truncate text-xs font-semibold text-[#059669]">
                        ID: {person.code || person.id}
                      </span>
                    ) : null}
                    {person.email ? (
                      <span className="block truncate text-xs text-[#6B7280]">{person.email}</span>
                    ) : null}
                  </span>
                  {isSelected ? (
                    <CheckCircle2 size={18} className="shrink-0 text-[#0386FF]" />
                  ) : multiSelect ? (
                    <Circle size={18} className="shrink-0 text-[#D1D5DB]" />
                  ) : null}
                </button>
              );
            })
          )}
        </div>

        {multiSelect ? (
          <div className="mt-3 flex shrink-0 items-center gap-2 border-t border-[#E2E8F0] pt-3">
            <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
              Cancel
            </button>
            <button
              type="button"
              onClick={() => onConfirm([...chosen])}
              className="ml-auto rounded-xl bg-[#0386FF] px-5 py-2.5 text-sm font-bold text-white"
            >
              Done ({chosen.size})
            </button>
          </div>
        ) : null}
      </div>
    </div>
  );
}
