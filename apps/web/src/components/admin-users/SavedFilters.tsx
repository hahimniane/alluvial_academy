"use client";

import { useEffect, useRef, useState } from "react";
import { Bookmark, Check, Pencil, Trash2 } from "lucide-react";
import type { UserFilters, UsersTab } from "@/lib/adminUsers";
import { errorReason } from "@/lib/adminUsersActions";
import {
  describeFilter,
  filterFromView,
  isApplied,
  isEmptyView,
  nameProblem,
  newFilterId,
  removeFilter,
  renameFilter,
  upsertFilter,
  MAX_SAVED_FILTERS,
  type SavedFilter,
} from "@/lib/savedFilters";
import { changeSavedFilters, listenSavedFilters } from "@/lib/usersExtrasData";
import type { Say } from "./UserPanel";

/**
 * Saved filters (F7): this admin's own list, the same on every device
 * (admin_saved_filters/{uid}). Save the current view, apply, rename, delete.
 */
export function SavedFiltersMenu({
  viewerUid,
  tab,
  filters,
  parentName,
  onApply,
  say,
}: {
  viewerUid: string;
  tab: UsersTab;
  filters: UserFilters;
  parentName: (id: string) => string | null;
  onApply: (saved: SavedFilter) => void;
  say: Say;
}) {
  const [open, setOpen] = useState(false);
  const [list, setList] = useState<SavedFilter[] | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [editing, setEditing] = useState<{ id: string | null; name: string } | null>(null);
  const [problem, setProblem] = useState("");
  const [busy, setBusy] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(
    () =>
      listenSavedFilters(
        viewerUid,
        (l) => {
          setList(l);
          setLoadError(false);
        },
        () => setLoadError(true),
      ),
    [viewerUid],
  );

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) {
        setOpen(false);
        setEditing(null);
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
        setEditing(null);
      }
    };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const save = async () => {
    if (!editing || busy || !list) return;
    const p = nameProblem(editing.name, list, editing.id);
    if (p) {
      setProblem(p);
      return;
    }
    setBusy(true);
    try {
      const id = editing.id;
      const name = editing.name.trim();
      await changeSavedFilters(viewerUid, (current) => {
        const clash = nameProblem(name, current, id);
        if (clash) return clash;
        if (id) return renameFilter(current, id, name);
        const next = upsertFilter(current, filterFromView(newFilterId(), name, tab, filters));
        return next === "full" ? `You can keep up to ${MAX_SAVED_FILTERS} saved filters. Delete one first.` : next;
      });
      say(id ? `Renamed to “${name}”.` : `Saved “${name}”.`);
      setEditing(null);
      setProblem("");
    } catch (e) {
      setProblem((e as { code?: string }).code === "refused" ? (e as Error).message : `Could not save: ${errorReason(e)}.`);
    } finally {
      setBusy(false);
    }
  };

  const remove = async (f: SavedFilter) => {
    if (busy) return;
    setBusy(true);
    try {
      await changeSavedFilters(viewerUid, (current) => removeFilter(current, f.id));
      say(`Deleted “${f.name}”.`);
    } catch (e) {
      say(`“${f.name}” could not be deleted: ${errorReason(e)}.`, "error");
    } finally {
      setBusy(false);
    }
  };

  const emptyView = isEmptyView(tab, filters);

  return (
    <div className="relative" ref={boxRef}>
      <button
        type="button"
        onClick={() => {
          setOpen((o) => !o);
          setEditing(null);
          setProblem("");
        }}
        aria-expanded={open}
        className="flex min-h-9 items-center gap-1.5 rounded-full border border-[#CBD5E1] bg-white px-3.5 text-[13px] font-semibold text-[#334155] hover:border-[#94A3B8]"
      >
        <Bookmark size={14} aria-hidden="true" />
        Saved filters{list && list.length > 0 ? ` · ${list.length}` : ""}
      </button>
      {open ? (
        <div role="menu" aria-label="Saved filters" className="absolute left-0 top-[44px] z-30 flex w-[min(340px,calc(100vw-32px))] flex-col gap-1 rounded-xl border border-[#E2E8F0] bg-white p-2 shadow-[0_12px_32px_rgba(15,23,42,0.12)]">
          {loadError ? <p className="m-0 px-2 py-1.5 text-[13px] font-semibold text-[#B91C1C]">Saved filters could not be loaded.</p> : null}
          {!list && !loadError ? <p className="m-0 px-2 py-1.5 text-[13px] text-[#64748B]">Loading…</p> : null}
          {list && list.length === 0 ? <p className="m-0 px-2 py-1.5 text-[13px] text-[#64748B]">No saved filters yet.</p> : null}
          {list?.map((f) =>
            editing?.id === f.id ? (
              <NameBox key={f.id} value={editing.name} busy={busy} problem={problem} label="Rename" onChange={(name) => setEditing({ id: f.id, name })} onSave={save} onCancel={() => setEditing(null)} />
            ) : (
              <div key={f.id} className="group flex items-center gap-1 rounded-lg hover:bg-[#F1F5F9]">
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    onApply(f);
                    setOpen(false);
                  }}
                  className="flex min-h-11 min-w-0 flex-1 flex-col items-start px-2 py-1.5 text-left"
                >
                  <span className="flex items-center gap-1.5 font-semibold">
                    {isApplied(f, tab, filters) ? <Check size={14} className="text-[#047857]" aria-label="Showing now" /> : null}
                    <span className="truncate">{f.name}</span>
                  </span>
                  <span className="max-w-full truncate text-xs text-[#64748B]">{describeFilter(f, parentName)}</span>
                </button>
                <button type="button" aria-label={`Rename ${f.name}`} disabled={busy} onClick={() => setEditing({ id: f.id, name: f.name })} className="grid h-9 w-9 flex-none place-items-center rounded-lg text-[#475569] hover:bg-white">
                  <Pencil size={14} aria-hidden="true" />
                </button>
                <button type="button" aria-label={`Delete ${f.name}`} disabled={busy} onClick={() => remove(f)} className="grid h-9 w-9 flex-none place-items-center rounded-lg text-[#B91C1C] hover:bg-white">
                  <Trash2 size={14} aria-hidden="true" />
                </button>
              </div>
            ),
          )}
          <div className="mt-1 border-t border-[#F1F5F9] pt-1.5">
            {editing && editing.id === null ? (
              <NameBox value={editing.name} busy={busy} problem={problem} label="Save" onChange={(name) => setEditing({ id: null, name })} onSave={save} onCancel={() => setEditing(null)} />
            ) : (
              <button
                type="button"
                disabled={!list || emptyView}
                onClick={() => {
                  setEditing({ id: null, name: "" });
                  setProblem("");
                }}
                className="min-h-10 w-full rounded-lg px-2 text-left text-[13px] font-semibold text-[#0369D9] hover:bg-[#EFF6FF] disabled:cursor-not-allowed disabled:text-[#94A3B8]"
              >
                {emptyView ? "Pick filters, then save them here" : "Save the current filters…"}
              </button>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function NameBox({
  value,
  busy,
  problem,
  label,
  onChange,
  onSave,
  onCancel,
}: {
  value: string;
  busy: boolean;
  problem: string;
  label: string;
  onChange: (v: string) => void;
  onSave: () => void;
  onCancel: () => void;
}) {
  return (
    <form
      className="flex flex-col gap-1.5 px-1 py-1"
      onSubmit={(e) => {
        e.preventDefault();
        onSave();
      }}
    >
      <input
        autoFocus
        value={value}
        maxLength={60}
        placeholder="Name, e.g. Minors never logged in"
        aria-label="Filter name"
        onChange={(e) => onChange(e.target.value)}
        className="min-h-10 rounded-lg border border-[#CBD5E1] px-2.5 text-sm"
      />
      {problem ? (
        <span role="alert" className="text-xs font-semibold text-[#B91C1C]">
          {problem}
        </span>
      ) : null}
      <span className="flex justify-end gap-1.5">
        <button type="button" onClick={onCancel} className="min-h-9 rounded-lg px-3 text-[13px] font-semibold text-[#475569] hover:bg-[#F1F5F9]">
          Cancel
        </button>
        <button type="submit" disabled={busy} className="min-h-9 rounded-lg bg-[#0369D9] px-3 text-[13px] font-semibold text-white disabled:opacity-60">
          {busy ? "Saving…" : label}
        </button>
      </span>
    </form>
  );
}
