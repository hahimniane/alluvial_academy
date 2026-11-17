"use client";

import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Eye, EyeOff } from "lucide-react";
import { displayNameOf, type UserRow } from "@/lib/adminUsers";
import {
  DELETE_CONFIRM_WORD,
  ZOOM_HOST_ACCOUNTS,
  chosenZoomHost,
  deleteConfirmed,
  joinNames,
  resetPasswordProblem,
  upcomingStudents,
  zoomHostDefaults,
} from "@/lib/adminUsersActions";
import { loadTeacherUpcomingShifts } from "@/lib/adminUsersActionsData";

// ─── Building blocks ───────────────────────────────────────────────────────

const BTN = "min-h-11 rounded-[10px] px-4 font-semibold disabled:cursor-not-allowed disabled:opacity-60";
export const BTN_SECONDARY = `${BTN} border border-[#CBD5E1] bg-white text-[#334155] hover:bg-[#F8FAFC]`;
const BTN_PRIMARY = `${BTN} bg-[#0369D9] text-white hover:bg-[#024E96]`;

export function DialogShell({
  label,
  title,
  danger,
  busy,
  onClose,
  children,
}: {
  label: string;
  title: string;
  danger?: boolean;
  busy?: boolean;
  onClose: () => void;
  children: ReactNode;
}) {
  const boxRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const first = boxRef.current?.querySelector<HTMLElement>("input, button[data-autofocus]");
    first?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !busy) onClose();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [busy, onClose]);
  return (
    <div className="fixed inset-0 z-[60] grid place-items-center p-4">
      <button type="button" aria-label="Close" className="absolute inset-0 cursor-default bg-[rgba(15,23,42,0.45)]" onClick={() => !busy && onClose()} />
      <div
        ref={boxRef}
        role="dialog"
        aria-modal="true"
        aria-label={label}
        className={`relative flex max-h-[calc(100vh-32px)] w-full max-w-[460px] flex-col gap-3.5 overflow-y-auto rounded-2xl bg-white p-6 shadow-[0_12px_32px_rgba(15,23,42,0.16)] ${
          danger ? "border-t-4 border-[#B91C1C]" : ""
        }`}
      >
        <h2 className="m-0 text-lg font-bold">{title}</h2>
        {children}
      </div>
    </div>
  );
}

function Actions({ children }: { children: ReactNode }) {
  return <div className="flex flex-wrap justify-end gap-2.5">{children}</div>;
}

function Confirm({
  label,
  busyLabel,
  color,
  busy,
  disabled,
  onClick,
}: {
  label: string;
  busyLabel: string;
  color: string;
  busy: boolean;
  disabled?: boolean;
  onClick: () => void;
}) {
  return (
    <button type="button" data-autofocus disabled={busy || disabled} onClick={onClick} className={`${BTN} text-white`} style={{ background: color }}>
      {busy ? busyLabel : label}
    </button>
  );
}

function ErrorLine({ text }: { text: string }) {
  return text ? (
    <p role="alert" className="m-0 rounded-[10px] bg-[#FEF2F2] px-3 py-2 text-[13px] font-semibold text-[#B91C1C]">
      {text}
    </p>
  ) : null;
}

/** Runs the action once at a time; a second click while it runs does nothing. */
export function useOnce() {
  const [busy, setBusy] = useState(false);
  const running = useRef(false);
  const run = async (fn: () => Promise<void>) => {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    try {
      await fn();
    } finally {
      running.current = false;
      setBusy(false);
    }
  };
  return { busy, run };
}

type SimpleProps = { row: UserRow; onClose: () => void; onConfirm: () => Promise<string | null> };

/** A confirm dialog whose action returns an error text (stays open) or null (closes). */
function SimpleConfirm({
  onClose,
  onConfirm,
  label,
  title,
  body,
  confirmLabel,
  busyLabel,
  color,
}: Omit<SimpleProps, "row"> & { label: string; title: string; body: ReactNode; confirmLabel: string; busyLabel: string; color: string }) {
  const { busy, run } = useOnce();
  const [error, setError] = useState("");
  return (
    <DialogShell label={label} title={title} busy={busy} onClose={onClose}>
      {body}
      <ErrorLine text={error} />
      <Actions>
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <Confirm
          label={confirmLabel}
          busyLabel={busyLabel}
          color={color}
          busy={busy}
          onClick={() =>
            run(async () => {
              const problem = await onConfirm();
              if (problem) setError(problem);
              else onClose();
            })
          }
        />
      </Actions>
    </DialogShell>
  );
}

const Bullets = ({ items }: { items: string[] }) => (
  <ul className="m-0 flex flex-col gap-1 pl-[18px] text-[#475569]">
    {items.map((t) => (
      <li key={t}>{t}</li>
    ))}
  </ul>
);

// ─── Archive / restore / admin-teacher ─────────────────────────────────────

export function ArchiveDialog(props: SimpleProps & { showsAdminPay: boolean }) {
  const name = displayNameOf(props.row);
  return (
    <SimpleConfirm
      {...props}
      label="Archive user"
      title={`Archive ${name}?`}
      body={
        <Bullets
          items={[
            "They can't sign in from their next login.",
            "Nothing is deleted. Classes, pay and history stay.",
            ...(props.showsAdminPay ? ["Administrator pay pauses automatically."] : []),
            "You can restore them at any time.",
          ]}
        />
      }
      confirmLabel="Archive"
      busyLabel="Archiving…"
      color="#C2410C"
    />
  );
}

export function RestoreDialog(props: SimpleProps & { showsAdminPay: boolean }) {
  const name = displayNameOf(props.row);
  return (
    <SimpleConfirm
      {...props}
      label="Restore user"
      title={`Restore ${name}?`}
      body={
        <Bullets
          items={[
            "They can sign in again.",
            "Their classes, pay and history are as they were.",
            ...(props.showsAdminPay ? ["Administrator pay does not restart by itself; turn it back on in Finance."] : []),
          ]}
        />
      }
      confirmLabel="Restore"
      busyLabel="Restoring…"
      color="#047857"
    />
  );
}

export function MakeAdminTeacherDialog(props: SimpleProps) {
  const name = displayNameOf(props.row);
  return (
    <SimpleConfirm
      {...props}
      label="Make admin-teacher"
      title={`Make ${name} an admin-teacher?`}
      body={
        <p className="m-0 text-[#475569]">
          They keep teaching and get full admin access, including this Users page. They can switch between the two from their dashboard.
        </p>
      }
      confirmLabel="Make admin-teacher"
      busyLabel="Saving…"
      color="#B45309"
    />
  );
}

export function RemoveAdminDialog(props: SimpleProps) {
  const name = displayNameOf(props.row);
  return (
    <SimpleConfirm
      {...props}
      label="Remove admin access"
      title={`Remove admin access from ${name}?`}
      body={<p className="m-0 text-[#475569]">They stay a teacher with the same classes, and no longer see the admin pages, this one included.</p>}
      confirmLabel="Remove admin access"
      busyLabel="Saving…"
      color="#B91C1C"
    />
  );
}

// ─── Reset password (U-038 – U-040) ────────────────────────────────────────

export function ResetPasswordDialog({
  row,
  guardianNames,
  onClose,
  onReset,
}: {
  row: UserRow;
  guardianNames: string[];
  onClose: () => void;
  onReset: (password: string) => Promise<string | null>;
}) {
  const { busy, run } = useOnce();
  const [pw, setPw] = useState("");
  const [show, setShow] = useState(false);
  const [error, setError] = useState("");
  const [touched, setTouched] = useState(false);
  const problem = resetPasswordProblem(pw);
  const name = displayNameOf(row);
  const who = joinNames(guardianNames);
  return (
    <DialogShell label="Reset password" title={`Reset ${name}'s password`} busy={busy} onClose={onClose}>
      <p className="m-0 text-[#475569]">
        Leave the box empty and an easy-to-type password is made for you.{" "}
        {who ? `${who} ${guardianNames.length > 1 ? "are" : "is"} emailed the new login.` : "No parent is linked, so share it with the student yourself."}
      </p>
      <label className="flex flex-col gap-1.5">
        <span className="text-[13px] font-semibold text-[#334155]">New password (optional)</span>
        <span className="relative flex items-center">
          <input
            type={show ? "text" : "password"}
            value={pw}
            autoComplete="new-password"
            placeholder="At least 6 characters"
            onChange={(e) => setPw(e.target.value)}
            onBlur={() => setTouched(true)}
            aria-invalid={!!(touched && problem)}
            className="min-h-11 w-full rounded-[10px] border border-[#CBD5E1] pl-3 pr-11 text-sm"
          />
          <button
            type="button"
            onClick={() => setShow((s) => !s)}
            aria-label={show ? "Hide password" : "Show password"}
            className="absolute right-1 grid h-9 w-9 place-items-center rounded-lg text-[#475569] hover:bg-[#F1F5F9]"
          >
            {show ? <EyeOff size={17} aria-hidden="true" /> : <Eye size={17} aria-hidden="true" />}
          </button>
        </span>
        {touched && problem ? <span className="text-xs font-semibold text-[#B91C1C]">{problem}</span> : null}
      </label>
      <ErrorLine text={error} />
      <Actions>
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <Confirm
          label="Reset password"
          busyLabel="Resetting…"
          color="#0369D9"
          busy={busy}
          onClick={() => {
            setTouched(true);
            if (problem) return;
            run(async () => {
              const failure = await onReset(pw);
              if (failure) setError(failure);
            });
          }}
        />
      </Actions>
    </DialogShell>
  );
}

export function ResetResultDialog({
  password,
  studentCode,
  emailedTo,
  onClose,
}: {
  password: string;
  studentCode: string;
  emailedTo: string[];
  onClose: () => void;
}) {
  const [copied, setCopied] = useState("");
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(password);
      setCopied("Copied");
    } catch {
      setCopied("Select the password and copy it");
    }
  };
  return (
    <DialogShell label="Password reset" title="New password ready" onClose={onClose}>
      <p className="m-0 text-[#475569]">You can see it again any time from the student&apos;s Login section.</p>
      <div className="flex items-center gap-2 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] px-3.5 py-3">
        <span className="min-w-0 flex-1 select-all break-all font-mono text-lg font-semibold tracking-[0.04em]" data-testid="new-password">
          {password}
        </span>
        <button type="button" onClick={copy} className="min-h-10 rounded-[10px] border border-[#CBD5E1] bg-white px-3 font-semibold">
          Copy
        </button>
      </div>
      {copied ? <span className="-mt-2 text-xs text-[#64748B]" role="status">{copied}</span> : null}
      {emailedTo.length > 0 ? (
        <div className="flex flex-col gap-1 rounded-xl bg-[#ECFDF5] px-3.5 py-2.5 text-[#065F46]">
          <span className="font-semibold">Emailed to {joinNames(emailedTo)}</span>
          {studentCode ? <span className="text-[13px]">Student ID {studentCode}</span> : null}
        </div>
      ) : (
        <div className="flex flex-col gap-1 rounded-xl bg-[#FFFBEB] px-3.5 py-2.5 text-[#92400E]">
          <span className="font-semibold">Share it with the student or their parent.</span>
          {studentCode ? <span className="text-[13px]">Student ID {studentCode}</span> : null}
        </div>
      )}
      <button type="button" data-autofocus onClick={onClose} className={`${BTN_PRIMARY} self-end`}>
        Done
      </button>
    </DialogShell>
  );
}

// ─── Zoom (U-043 – U-045) ──────────────────────────────────────────────────

export function ZoomOnDialog({
  row,
  onClose,
  onEnable,
}: {
  row: UserRow;
  onClose: () => void;
  onEnable: (input: { zoomHostAccount: string; studentIds?: string[] }) => Promise<string | null>;
}) {
  const name = displayNameOf(row);
  const defaults = useMemo(() => zoomHostDefaults(row.zoomHostAccount), [row.zoomHostAccount]);
  const [selected, setSelected] = useState(defaults.selected);
  const [custom, setCustom] = useState(defaults.custom);
  const [scope, setScope] = useState<"all" | "some">("all");
  const [students, setStudents] = useState<{ id: string; name: string }[] | null>(null);
  const [loadError, setLoadError] = useState("");
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [error, setError] = useState("");
  const { busy, run } = useOnce();

  useEffect(() => {
    if (scope !== "some" || students !== null) return;
    let live = true;
    loadTeacherUpcomingShifts(row.id)
      .then((shifts) => live && setStudents(upcomingStudents(shifts, new Date())))
      .catch(() => live && setLoadError("The teacher's classes could not be loaded. Try again."));
    return () => {
      live = false;
    };
  }, [scope, students, row.id]);

  const host = chosenZoomHost(selected, custom);
  const canSubmit = !!host && (scope === "all" || picked.size > 0);
  return (
    <DialogShell label="Turn on Zoom classes" title={`Turn on Zoom for ${name}`} busy={busy} onClose={onClose}>
      <fieldset className="m-0 flex flex-col gap-2 border-0 p-0">
        <legend className="mb-1.5 text-[13px] font-semibold text-[#334155]">Zoom host account</legend>
        {ZOOM_HOST_ACCOUNTS.map((account) => (
          <label key={account} className="flex min-h-10 items-center gap-2.5">
            <input type="radio" name="zoom-host" className="h-[18px] w-[18px]" checked={!custom.trim() && selected === account} onChange={() => { setSelected(account); setCustom(""); }} />
            <span className="break-all">{account}</span>
          </label>
        ))}
        <input
          value={custom}
          onChange={(e) => setCustom(e.target.value)}
          placeholder="Or type another host email"
          aria-label="Other host email"
          className="min-h-11 rounded-[10px] border border-[#CBD5E1] px-3 text-sm"
        />
      </fieldset>
      <fieldset className="m-0 flex flex-col gap-2 border-0 p-0">
        <legend className="mb-1.5 text-[13px] font-semibold text-[#334155]">Which upcoming classes</legend>
        <label className="flex min-h-10 items-center gap-2.5">
          <input type="radio" name="zoom-scope" className="h-[18px] w-[18px]" checked={scope === "all"} onChange={() => setScope("all")} />
          All of them
        </label>
        <label className="flex min-h-10 items-center gap-2.5">
          <input type="radio" name="zoom-scope" className="h-[18px] w-[18px]" checked={scope === "some"} onChange={() => setScope("some")} />
          Only some students&apos; classes
        </label>
        {scope === "some" ? (
          <div className="ml-7 flex max-h-48 flex-col gap-1 overflow-y-auto">
            {loadError ? (
              <span className="text-[13px] font-semibold text-[#B91C1C]">{loadError}</span>
            ) : students === null ? (
              <span className="text-[13px] text-[#64748B]">Loading the teacher&apos;s classes…</span>
            ) : students.length === 0 ? (
              <span className="text-[13px] text-[#64748B]">This teacher has no upcoming classes.</span>
            ) : (
              students.map((s) => (
                <label key={s.id} className="flex min-h-9 items-center gap-2.5">
                  <input
                    type="checkbox"
                    className="h-[18px] w-[18px]"
                    checked={picked.has(s.id)}
                    onChange={(e) =>
                      setPicked((cur) => {
                        const next = new Set(cur);
                        if (e.target.checked) next.add(s.id);
                        else next.delete(s.id);
                        return next;
                      })
                    }
                  />
                  {s.name}
                </label>
              ))
            )}
          </div>
        ) : null}
      </fieldset>
      <p className="m-0 text-xs text-[#64748B]">Turning Zoom off later moves all of their upcoming classes back.</p>
      <ErrorLine text={error} />
      <Actions>
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <Confirm
          label="Turn on Zoom"
          busyLabel="Turning on…"
          color="#0369D9"
          busy={busy}
          disabled={!canSubmit}
          onClick={() =>
            run(async () => {
              const failure = await onEnable({ zoomHostAccount: host, studentIds: scope === "some" ? [...picked] : undefined });
              if (failure) setError(failure);
              else onClose();
            })
          }
        />
      </Actions>
    </DialogShell>
  );
}

export function ZoomOffDialog(props: SimpleProps) {
  const name = displayNameOf(props.row);
  return (
    <SimpleConfirm
      {...props}
      label="Turn off Zoom classes"
      title={`Turn off Zoom for ${name}?`}
      body={<p className="m-0 text-[#475569]">All of their upcoming classes move back to the school&apos;s own classroom.</p>}
      confirmLabel="Turn off Zoom"
      busyLabel="Turning off…"
      color="#0369D9"
    />
  );
}

// ─── Delete (U-050 – U-052, D3) ────────────────────────────────────────────

export function DeleteDialog({
  row,
  roleText,
  onClose,
  onDelete,
}: {
  row: UserRow;
  roleText: string;
  onClose: () => void;
  onDelete: (deleteClasses: boolean) => Promise<string | null>;
}) {
  const { busy, run } = useOnce();
  const [typed, setTyped] = useState("");
  const [classes, setClasses] = useState(false);
  const [error, setError] = useState("");
  const name = displayNameOf(row);
  const type = row.userType.toLowerCase();
  const canDeleteClasses = type === "teacher" || type === "student";
  return (
    <DialogShell label="Delete user" title={`Permanently delete ${name}?`} danger busy={busy} onClose={onClose}>
      <p className="m-0 text-[#475569]">
        This can&apos;t be undone. Their account, login, form submissions and drafts are removed, and they are taken off every task.
        {row.isActive ? " They are archived first." : ""}
      </p>
      <div className="flex flex-col gap-0.5 rounded-xl bg-[#F8FAFC] px-3.5 py-2.5 text-[13px]">
        <span className="break-all">
          <span className="text-[#64748B]">Email </span>
          {row.email || "—"}
        </span>
        <span>
          <span className="text-[#64748B]">Role </span>
          {roleText} · {row.isActive ? "Active" : "Archived"}
        </span>
      </div>
      {canDeleteClasses ? (
        <label className="flex items-start gap-2.5 rounded-xl border border-[#FECACA] bg-[#FEF2F2] p-3">
          <input type="checkbox" className="mt-0.5 h-[18px] w-[18px] flex-none" checked={classes} onChange={(e) => setClasses(e.target.checked)} />
          <span className="flex flex-col gap-0.5">
            <span className="font-semibold text-[#7F1D1D]">{type === "teacher" ? "Also delete this teacher's upcoming classes" : "Also delete this student's upcoming classes"}</span>
            <span className="text-xs text-[#991B1B]">
              {type === "student" ? "Group classes stay for the other students. " : ""}Past classes, timesheets and class reports are kept for pay records.
            </span>
          </span>
        </label>
      ) : null}
      <label className="flex flex-col gap-1.5">
        <span className="text-[13px] font-semibold text-[#334155]">Type {DELETE_CONFIRM_WORD} to confirm</span>
        <input value={typed} onChange={(e) => setTyped(e.target.value)} autoComplete="off" className="min-h-11 rounded-[10px] border border-[#CBD5E1] px-3 text-sm" />
      </label>
      <ErrorLine text={error} />
      <Actions>
        <button type="button" className={BTN_SECONDARY} disabled={busy} onClick={onClose}>
          Cancel
        </button>
        <Confirm
          label="Delete permanently"
          busyLabel="Deleting…"
          color="#B91C1C"
          busy={busy}
          disabled={!deleteConfirmed(typed)}
          onClick={() =>
            run(async () => {
              const failure = await onDelete(classes);
              if (failure) setError(failure);
            })
          }
        />
      </Actions>
    </DialogShell>
  );
}
