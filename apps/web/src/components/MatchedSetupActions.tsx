"use client";

import { useState } from "react";
import { KeyRound, UserPlus } from "lucide-react";
import { ActionButton } from "@/components/ActionButton";
import { createStudentAccount, inviteParentForEnrollment } from "@/lib/enrollmentSetup";
import { parentInviteProblem, type ParentInvite } from "@/lib/enrollmentSetupRules";

/**
 * The two actions that move a match forward: give the student a login, then
 * link a parent to it. They are ordered because the second needs the first —
 * there is no account to attach a parent to until one exists.
 */
export function MatchedSetupActions({
  enrollmentId,
  studentName,
  studentUserId,
  parentLinked,
  defaultParentEmail,
  defaultParentName,
  defaultParentPhone,
  onChanged,
  onMessage,
}: {
  enrollmentId: string;
  studentName: string;
  studentUserId: string;
  parentLinked: boolean;
  defaultParentEmail: string;
  defaultParentName: string;
  defaultParentPhone: string;
  onChanged: () => void;
  onMessage: (text: string) => void;
}) {
  const [inviting, setInviting] = useState(false);

  return (
    <div className="mb-3 flex flex-wrap items-center gap-2">
      {!studentUserId ? (
        <ActionButton
          label="Create student account"
          busyLabel="Creating…"
          icon={<KeyRound size={16} />}
          onAction={async () => {
            const created = await createStudentAccount(enrollmentId);
            onMessage(
              created.studentCode
                ? `Account created for ${studentName}. Student ID ${created.studentCode}.`
                : `Account created for ${studentName}.`,
            );
            onChanged();
          }}
        />
      ) : !parentLinked ? (
        <button
          type="button"
          onClick={() => setInviting(true)}
          className="inline-flex min-h-9 items-center gap-2 rounded-lg border border-black/10 px-3 text-xs font-semibold text-[#1D4ED8] hover:bg-[#EFF6FF]"
        >
          <UserPlus size={16} />
          Invite parent
        </button>
      ) : null}

      {inviting ? (
        <InviteParentDialog
          studentName={studentName}
          initial={{
            email: defaultParentEmail,
            firstName: defaultParentName.split(/\s+/)[0] ?? "",
            lastName: defaultParentName.split(/\s+/).slice(1).join(" "),
            phone: defaultParentPhone,
            countryCode: "",
          }}
          onSend={async (invite) => {
            const result = await inviteParentForEnrollment(enrollmentId, studentUserId, invite);
            onMessage(
              result.message ||
                (result.status === "linked"
                  ? "Parent account linked."
                  : "Invite sent. The parent can set a password from the email."),
            );
            setInviting(false);
            onChanged();
          }}
          onClose={() => setInviting(false)}
        />
      ) : null}
    </div>
  );
}

function InviteParentDialog({
  studentName,
  initial,
  onSend,
  onClose,
}: {
  studentName: string;
  initial: ParentInvite;
  onSend: (invite: ParentInvite) => Promise<void>;
  onClose: () => void;
}) {
  const [invite, setInvite] = useState<ParentInvite>(initial);
  const [error, setError] = useState("");
  const problem = parentInviteProblem(invite);
  const set = (patch: Partial<ParentInvite>) => setInvite((current) => ({ ...current, ...patch }));

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Invite parent">
      <div className="flex max-h-[90vh] w-full max-w-[460px] flex-col overflow-hidden rounded-2xl bg-white shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <header className="shrink-0 border-b border-[#E5E7EB] px-5 py-4">
          <h2 className="text-lg font-bold text-[#111827]">Invite parent</h2>
          <p className="mt-0.5 text-xs text-[#64748B]">
            Links a parent to {studentName}&apos;s account. If they already have a login, it is linked
            rather than re-invited.
          </p>
        </header>

        <div className="min-h-0 flex-1 space-y-3 overflow-y-auto px-5 py-4">
          <Field label="Email" required value={invite.email} onChange={(v) => set({ email: v })} type="email" />
          <div className="grid grid-cols-2 gap-2.5">
            <Field label="First name" value={invite.firstName} onChange={(v) => set({ firstName: v })} />
            <Field label="Last name" value={invite.lastName} onChange={(v) => set({ lastName: v })} />
          </div>
          <Field label="Phone" value={invite.phone} onChange={(v) => set({ phone: v })} />
          {error ? <p role="alert" className="text-xs font-semibold text-[#DC2626]">{error}</p> : null}
        </div>

        <footer className="shrink-0 border-t border-[#E5E7EB] px-5 py-3">
          {problem ? <p className="mb-2 text-[11px] font-semibold text-[#B45309]">{problem}</p> : null}
          <div className="flex items-center gap-3">
            <span className="flex-1" />
            <button type="button" onClick={onClose} className="px-3 py-2 text-sm font-semibold text-[#475569]">
              Cancel
            </button>
            <ActionButton
              label="Send invite"
              busyLabel="Sending…"
              disabled={Boolean(problem)}
              onAction={async () => {
                setError("");
                try {
                  await onSend(invite);
                } catch (issue) {
                  setError(issue instanceof Error ? issue.message : "Could not send the invite.");
                }
              }}
            />
          </div>
        </footer>
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
  required,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
}) {
  const id = `invite-${label.toLowerCase().replace(/\s+/g, "-")}`;
  return (
    <div>
      <label htmlFor={id} className="block text-[11px] font-semibold text-[#1E293B]">
        {label}
        {required ? " *" : ""}
      </label>
      <input
        id={id}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="mt-1 h-9 w-full rounded-lg border border-[#E2E8F0] px-2.5 text-sm text-[#111827] outline-none focus:border-[#3B82F6]"
      />
    </div>
  );
}
