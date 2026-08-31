"use client";

import { useEffect, useMemo, useState } from "react";
import { BookOpen, Loader2, Pencil, Plus, RotateCcw, Search, Trash2, X } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import {
  type SubjectInput,
  type SubjectRecord,
  addSubject,
  deleteSubject,
  loadAllSubjects,
  setSubjectActive,
  updateSubject,
} from "@/lib/subjects";

/**
 * Port of the Flutter SubjectManagementDialog: add, rename, re-price, retire
 * or delete the subjects that classes are scheduled against. The default wage
 * set here is what prefills the hourly rate in the shift editor.
 */

const EMPTY_FORM: SubjectInput = { displayName: "", arabicName: "", description: "", defaultWage: null };

export function SubjectManagerDialog({ onClose, onChanged }: { onClose: () => void; onChanged: () => void }) {
  const [subjects, setSubjects] = useState<SubjectRecord[] | null>(null);
  const [search, setSearch] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<SubjectInput>(EMPTY_FORM);
  const [wageText, setWageText] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");

  const refresh = async () => {
    try {
      setSubjects(await loadAllSubjects());
    } catch {
      setError("Could not load subjects.");
    }
  };

  useEffect(() => {
    void refresh();
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!subjects) return [];
    if (!q) return subjects;
    return subjects.filter(
      (s) => s.displayName.toLowerCase().includes(q) || s.arabicName.toLowerCase().includes(q),
    );
  }, [subjects, search]);

  const openAdd = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setWageText("");
    setError("");
    setShowForm(true);
  };

  const openEdit = (subject: SubjectRecord) => {
    setEditingId(subject.id);
    setForm({
      displayName: subject.displayName,
      arabicName: subject.arabicName,
      description: subject.description,
      defaultWage: subject.defaultWage,
    });
    setWageText(subject.defaultWage != null ? String(subject.defaultWage) : "");
    setError("");
    setShowForm(true);
  };

  const save = async () => {
    setError("");
    const trimmedWage = wageText.trim();
    let wage: number | null = null;
    if (trimmedWage) {
      wage = Number(trimmedWage);
      if (!Number.isFinite(wage) || wage < 0) {
        setError("Enter a valid hourly rate.");
        return;
      }
    }
    setBusy(true);
    try {
      const payload = { ...form, defaultWage: wage };
      if (editingId) {
        await updateSubject(editingId, payload);
        setToast(`"${payload.displayName.trim()}" updated.`);
      } else {
        await addSubject(payload);
        setToast(`"${payload.displayName.trim()}" added.`);
      }
      setShowForm(false);
      await refresh();
      onChanged();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save the subject.");
    } finally {
      setBusy(false);
    }
  };

  const toggleActive = async (subject: SubjectRecord) => {
    setBusy(true);
    try {
      await setSubjectActive(subject.id, !subject.isActive);
      setToast(subject.isActive ? `"${subject.displayName}" retired.` : `"${subject.displayName}" restored.`);
      await refresh();
      onChanged();
    } catch {
      setError("Could not update the subject.");
    } finally {
      setBusy(false);
    }
  };

  const remove = async (subject: SubjectRecord) => {
    if (!window.confirm(`Permanently delete "${subject.displayName}"? This cannot be undone.`)) return;
    setBusy(true);
    try {
      await deleteSubject(subject.id);
      setToast(`"${subject.displayName}" deleted.`);
      await refresh();
      onChanged();
    } catch {
      setError("Could not delete the subject.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[70] grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true">
      <div className="flex max-h-[90vh] w-full max-w-xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center gap-3 border-b border-[#E2E8F0] px-6 py-4">
          <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-[#EAF5FF] text-[#0386FF]">
            <BookOpen size={18} />
          </span>
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-bold text-[#0F172A]">Manage Subjects</h2>
            <p className="text-xs text-[#64748B]">Subjects and their default hourly rate</p>
          </div>
          <button type="button" onClick={onClose} className="grid h-8 w-8 place-items-center rounded-full text-[#334155] hover:bg-[#F1F5F9]" aria-label="Close">
            <X size={18} />
          </button>
        </header>

        {showForm ? (
          <div className="space-y-3 px-6 py-5">
            <p className="text-sm font-bold text-[#111827]">{editingId ? "Edit subject" : "Add subject"}</p>
            <label className="block text-xs font-bold uppercase tracking-wide text-[#64748B]">
              Subject name *
              <input
                autoFocus
                value={form.displayName}
                onChange={(event) => setForm((f) => ({ ...f, displayName: event.target.value }))}
                placeholder="e.g. Tajweed"
                className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
              />
            </label>
            <label className="block text-xs font-bold uppercase tracking-wide text-[#64748B]">
              Arabic name (optional)
              <input
                value={form.arabicName}
                onChange={(event) => setForm((f) => ({ ...f, arabicName: event.target.value }))}
                dir="rtl"
                className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
              />
            </label>
            <label className="block text-xs font-bold uppercase tracking-wide text-[#64748B]">
              Description (optional)
              <input
                value={form.description}
                onChange={(event) => setForm((f) => ({ ...f, description: event.target.value }))}
                className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
              />
            </label>
            <label className="block text-xs font-bold uppercase tracking-wide text-[#64748B]">
              Default hourly rate ($, optional)
              <input
                type="number"
                min="0"
                step="0.5"
                value={wageText}
                onChange={(event) => setWageText(event.target.value)}
                placeholder="Prefills the rate when scheduling"
                className="mt-1 w-full rounded-xl border border-[#E2E8F0] px-3 py-2 text-sm font-normal normal-case tracking-normal text-[#0F172A]"
              />
            </label>
            {error ? (
              <p className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">
                {error}
              </p>
            ) : null}
            <div className="flex items-center gap-2 pt-1">
              <button type="button" onClick={() => setShowForm(false)} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
                Back
              </button>
              <ActionButton
                variant="primary"
                className="ml-auto"
                label={editingId ? "Save changes" : "Add subject"}
                busyLabel="Saving…"
                disabled={busy}
                onAction={() => save()}
              />
            </div>
          </div>
        ) : (
          <>
            <div className="flex items-center gap-2 border-b border-[#E2E8F0] px-6 py-3">
              <label className="flex flex-1 items-center gap-2 rounded-xl border border-[#E2E8F0] px-3 py-2">
                <Search size={14} className="shrink-0 text-[#94A3B8]" />
                <input
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Search subjects"
                  className="w-full bg-transparent text-sm outline-none"
                />
              </label>
              <button
                type="button"
                onClick={openAdd}
                className="inline-flex items-center gap-1.5 rounded-xl bg-[#0386FF] px-4 py-2.5 text-sm font-bold text-white"
              >
                <Plus size={15} />
                Add
              </button>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
              {subjects === null ? (
                <p className="px-2 py-6 text-center text-sm text-[#64748B]">Loading subjects…</p>
              ) : filtered.length === 0 ? (
                <p className="px-2 py-6 text-center text-sm text-[#64748B]">No subjects match.</p>
              ) : (
                filtered.map((subject) => (
                  <div
                    key={subject.id}
                    className={`mb-2 flex items-center gap-3 rounded-xl border px-3.5 py-2.5 ${
                      subject.isActive ? "border-[#E2E8F0] bg-white" : "border-[#E2E8F0] bg-[#F8FAFC]"
                    }`}
                  >
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-2">
                        <span className={`truncate text-sm font-semibold ${subject.isActive ? "text-[#111827]" : "text-[#94A3B8]"}`}>
                          {subject.displayName}
                        </span>
                        {subject.arabicName ? (
                          <span className="shrink-0 text-xs text-[#94A3B8]" dir="rtl">
                            {subject.arabicName}
                          </span>
                        ) : null}
                        {!subject.isActive ? (
                          <span className="shrink-0 rounded-full bg-[#F1F5F9] px-2 py-0.5 text-[10px] font-bold uppercase text-[#64748B]">
                            Retired
                          </span>
                        ) : null}
                      </span>
                      <span className="block text-xs text-[#64748B]">
                        {subject.defaultWage != null ? `Rate: $${subject.defaultWage.toFixed(2)}/hr` : "No default rate"}
                        {subject.description ? ` · ${subject.description}` : ""}
                      </span>
                    </span>
                    <button
                      type="button"
                      onClick={() => openEdit(subject)}
                      disabled={busy}
                      title="Edit subject"
                      className="grid h-8 w-8 place-items-center rounded-lg text-[#475569] hover:bg-[#F1F5F9]"
                    >
                      <Pencil size={15} />
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void toggleActive(subject)}
                      title={subject.isActive ? "Retire (hide from scheduling)" : "Restore"}
                      className="grid h-8 w-8 place-items-center rounded-lg text-[#475569] hover:bg-[#F1F5F9]"
                    >
                      <RotateCcw size={15} />
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void remove(subject)}
                      title="Delete permanently"
                      className="grid h-8 w-8 place-items-center rounded-lg text-[#DC2626] hover:bg-[#FEF2F2]"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                ))
              )}
            </div>

            {error ? (
              <p className="mx-6 mb-3 rounded-xl border border-[#FECACA] bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">
                {error}
              </p>
            ) : null}
            {toast ? <p className="mx-6 mb-3 text-xs font-semibold text-[#059669]">{toast}</p> : null}

            <footer className="flex justify-end border-t border-[#E2E8F0] px-6 py-3.5">
              <button type="button" onClick={onClose} className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]">
                Done
              </button>
            </footer>
          </>
        )}
      </div>
    </div>
  );
}
