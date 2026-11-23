"use client";

import { useState } from "react";
import { CalendarDays } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import {
  DISCOUNT_REASONS,
  discountLabel,
  discountToDraft,
  draftToDiscount,
  emptyDiscountDraft,
  formatStartDate,
  validateDiscount,
  type DiscountDraft,
  type StudentDiscount,
} from "@/lib/studentDiscount";

export function DiscountDialog({
  studentName,
  existing,
  familyExisting,
  canApplyToFamily,
  defaultStartDate,
  onSave,
  onRemove,
  onClose,
}: {
  studentName: string;
  existing: StudentDiscount | null;
  /** The household discount already on the parent, if there is one. */
  familyExisting: StudentDiscount | null;
  /** False when no parent is linked, so there is no household to attach to. */
  canApplyToFamily: boolean;
  defaultStartDate: Date;
  onSave: (draft: DiscountDraft) => Promise<void> | void;
  onRemove: () => Promise<void> | void;
  onClose: () => void;
}) {
  const [draft, setDraft] = useState<DiscountDraft>(() => {
    if (familyExisting) return discountToDraft(familyExisting);
    return existing ? discountToDraft(existing) : emptyDiscountDraft(defaultStartDate);
  });
  const [showError, setShowError] = useState(false);
  const error = validateDiscount(draft);
  const preview = error ? null : draftToDiscount(draft);
  const set = (patch: Partial<DiscountDraft>) => setDraft((current) => ({ ...current, ...patch }));

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Student discount">
      <div className="max-h-full w-full max-w-[520px] overflow-y-auto rounded-[28px] bg-white p-6 shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <h2 className="text-xl font-bold text-[#111827]">Student discount</h2>
        <p className="mt-1 text-[13px] text-[#64748B]">
          {studentName} · applies to every program this student takes
        </p>

        <div className="mt-5">
          <span className="block text-[11px] font-semibold text-[#1E293B]">Applies to</span>
          <div className="mt-1.5 grid grid-cols-2 gap-2.5">
            {([
              { scope: "student" as const, title: "This student", hint: "Two siblings on $10 off come to $20" },
              { scope: "family" as const, title: "The whole family", hint: "Taken off the invoice once" },
            ]).map((option) => {
              const active = draft.scope === option.scope;
              const disabled = option.scope === "family" && !canApplyToFamily;
              return (
                <button
                  key={option.scope}
                  type="button"
                  aria-pressed={active}
                  disabled={disabled}
                  onClick={() => set({ scope: option.scope })}
                  className={`rounded-lg border-[1.5px] p-3 text-left transition ${
                    active ? "border-[#3B82F6] bg-[#EFF6FF] text-[#1D4ED8]" : "border-[#E2E8F0] bg-white text-[#475569]"
                  } ${disabled ? "cursor-not-allowed opacity-50" : ""}`}
                >
                  <span className="block text-xs font-bold">{option.title}</span>
                  <span className="mt-0.5 block text-[11px] font-medium text-[#64748B]">{option.hint}</span>
                </button>
              );
            })}
          </div>
          {!canApplyToFamily ? (
            <p className="mt-1.5 text-[11px] font-medium text-[#64748B]">
              Link a parent to give the whole family one discount.
            </p>
          ) : null}
          {draft.scope === "family" ? (
            <p className="mt-1.5 text-[11px] font-medium text-[#64748B]">
              Saved on the parent, so it covers every child on the invoice.
            </p>
          ) : null}
        </div>

        <div className="mt-5 grid grid-cols-2 gap-2.5">
          {([
            { mode: "percent" as const, title: "Percentage", hint: "% off the monthly total" },
            { mode: "fixed" as const, title: "Fixed amount", hint: "$ off each month" },
          ]).map((option) => {
            const active = draft.mode === option.mode;
            return (
              <button
                key={option.mode}
                type="button"
                aria-pressed={active}
                onClick={() => set({ mode: option.mode })}
                className={`rounded-lg border-[1.5px] p-3 text-left transition ${
                  active ? "border-[#3B82F6] bg-[#EFF6FF] text-[#1D4ED8]" : "border-[#E2E8F0] bg-white text-[#475569]"
                }`}
              >
                <span className="block text-xs font-bold">{option.title}</span>
                <span className="mt-0.5 block text-[11px] font-medium text-[#64748B]">{option.hint}</span>
              </button>
            );
          })}
        </div>

        <div className="mt-4 flex items-end gap-2.5">
          <div>
            <label htmlFor="discount-value" className="block text-[11px] font-semibold text-[#1E293B]">Amount</label>
            <input
              id="discount-value"
              type="number"
              min="0"
              step="0.01"
              value={draft.value}
              onChange={(event) => set({ value: event.target.value })}
              className="mt-1 h-10 w-[110px] rounded border border-[#79747E] px-2.5 text-[15px] font-bold text-[#111827] outline-none focus:border-[#3B82F6]"
            />
          </div>
          <span className="pb-2.5 text-xs font-semibold text-[#64748B]">
            {draft.mode === "percent" ? "%" : "$ / month"}
          </span>
        </div>

        <fieldset className="mt-5">
          <legend className="text-[11px] font-semibold text-[#1E293B]">How long it lasts</legend>
          <div className="mt-1.5 grid gap-1.5">
            {([
              { duration: "months" as const, label: "First few months" },
              { duration: "ongoing" as const, label: "Ongoing, until removed" },
            ]).map((option) => (
              <label key={option.duration} className="flex items-center gap-2 text-xs font-medium text-[#334155]">
                <input
                  type="radio"
                  name="discount-duration"
                  checked={draft.duration === option.duration}
                  onChange={() => set({ duration: option.duration })}
                  className="h-[18px] w-[18px] accent-[#3B82F6]"
                />
                {option.label}
              </label>
            ))}
          </div>
          {draft.duration === "months" ? (
            <div className="mt-2 flex items-center gap-2">
              <label htmlFor="discount-months" className="sr-only">Number of months</label>
              <input
                id="discount-months"
                type="number"
                min="1"
                step="1"
                value={draft.months}
                onChange={(event) => set({ months: event.target.value })}
                className="h-10 w-20 rounded border border-[#79747E] px-2.5 text-[15px] font-bold text-[#111827] outline-none focus:border-[#3B82F6]"
              />
              <span className="text-xs text-[#64748B]">months from the start date below</span>
            </div>
          ) : null}
        </fieldset>

        <div className="mt-5">
          <label htmlFor="discount-start" className="block text-[11px] font-semibold text-[#1E293B]">Month 1 starts on</label>
          <input
            id="discount-start"
            type="date"
            value={draft.startDate}
            onChange={(event) => set({ startDate: event.target.value })}
            className="mt-1 h-10 rounded border border-[#79747E] px-2.5 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
          />
        </div>

        <div className="mt-3 flex gap-2 rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] p-3">
          <CalendarDays size={16} className="mt-0.5 shrink-0 text-[#1D4ED8]" />
          <p className="text-xs leading-[1.45] text-[#1E40AF]">
            {preview ? (
              <>
                Month 1 starts on <strong>{formatStartDate(preview.startDate)}</strong>. Every invoice from then on
                shows <strong>{discountLabel(preview)}</strong>.
              </>
            ) : (
              "Set an amount and a start date to see which invoices this covers."
            )}
          </p>
        </div>

        <div className="mt-4">
          <label htmlFor="discount-reason" className="block text-[11px] font-semibold text-[#1E293B]">Reason</label>
          <select
            id="discount-reason"
            value={draft.reason}
            onChange={(event) => set({ reason: event.target.value })}
            className="mt-1 h-10 w-full rounded border border-[#79747E] bg-white px-2.5 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
          >
            {DISCOUNT_REASONS.map((reason) => (
              <option key={reason} value={reason}>{reason}</option>
            ))}
          </select>
        </div>

        <div className="mt-4">
          <label htmlFor="discount-note" className="block text-[11px] font-semibold text-[#1E293B]">Note (optional)</label>
          <textarea
            id="discount-note"
            rows={2}
            value={draft.note}
            onChange={(event) => set({ note: event.target.value })}
            placeholder="Who approved it and why..."
            className="mt-1 w-full rounded border border-[#79747E] px-2.5 py-2 text-sm text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#3B82F6]"
          />
        </div>

        {showError && error ? (
          <p role="alert" className="mt-3 text-xs font-semibold text-[#DC2626]">{error}</p>
        ) : null}

        <div className="mt-6 flex items-center gap-3">
          {existing ? (
            <ActionButton
              label="Remove discount"
              busyLabel="Removing…"
              variant="ghost"
              onAction={() => onRemove()}
            />
          ) : null}
          <span className="flex-1" />
          <button type="button" onClick={onClose} className="px-3 py-2 text-sm font-semibold text-[#475569]">
            Cancel
          </button>
          <ActionButton
            label="Save discount"
            busyLabel="Saving…"
            onAction={async () => {
              if (error) {
                setShowError(true);
                return;
              }
              await onSave(draft);
            }}
            className="rounded-[20px] bg-[#0F172A] px-5 py-2.5 text-sm font-bold text-white hover:bg-[#1E293B]"
          />
        </div>
      </div>
    </div>
  );
}
