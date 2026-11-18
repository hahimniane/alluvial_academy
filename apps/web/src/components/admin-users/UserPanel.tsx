"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { X } from "lucide-react";
import {
  adminTypeLabel,
  dayOrText,
  displayNameOf,
  firstClassText,
  formatDay,
  isAdminRow,
  isNeverLoggedIn,
  isStudentType,
  loginEmailOf,
  phoneDisplay,
  typeInfo,
  type ListRow,
  type ParentLinks,
  type UserRow,
} from "@/lib/adminUsers";
import {
  decisionActor,
  decisionLabel,
  deleteErrorMessage,
  deleteSuccessMessage,
  failed,
  fallbackDecisions,
  mergeDecisions,
  panelActions,
  selfGuard,
  switchToast,
  zoomResultMessage,
  type Decision,
} from "@/lib/adminUsersActions";
import {
  archiveUser,
  deleteUser,
  listenDecisions,
  resetStudentPassword,
  restoreUser,
  setAdminTeacher,
  setTeacherZoom,
  setUserSwitch,
} from "@/lib/adminUsersActionsData";
import { readStudentPassword } from "@/lib/studentCredentials";
import { guardiansOfStudent, sideNote, studentsOfParent } from "@/lib/guardians";
import { Avatar, Pill, TypePill } from "./ui";
import { SendLoginDialog } from "./LoginDetails";
import { PanelFacts } from "./PanelFacts";
import {
  ArchiveDialog,
  DeleteDialog,
  MakeAdminTeacherDialog,
  RemoveAdminDialog,
  ResetPasswordDialog,
  ResetResultDialog,
  RestoreDialog,
  ZoomOffDialog,
  ZoomOnDialog,
} from "./UserDialogs";

export type Say = (text: string, tone?: "ok" | "error") => void;

function Fact({ label, children, wide, mono }: { label: string; children: ReactNode; wide?: boolean; mono?: boolean }) {
  return (
    <div className={`flex min-w-0 flex-col gap-0.5 ${wide ? "col-span-2" : ""}`}>
      <span className="text-xs text-[#64748B]">{label}</span>
      <span className={`break-words ${mono ? "font-mono text-[13px]" : ""}`}>{children}</span>
    </div>
  );
}

function Line({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex justify-between gap-3">
      <span className="flex-none text-[#64748B]">{label}</span>
      <span className="min-w-0 text-right">{children}</span>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-2 border-b border-[#F1F5F9] px-5 py-4 last:border-b-0">
      <div className="font-bold">{title}</div>
      {children}
    </div>
  );
}

function Switch({ label, help, on, busy, onFlip }: { label: string; help: string; on: boolean; busy: boolean; onFlip: () => void }) {
  return (
    <div className="flex min-h-12 items-center justify-between gap-3">
      <span className="flex flex-col">
        <span className="font-semibold">{label}</span>
        <span className="text-xs text-[#64748B]">{help}</span>
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label={label}
        aria-busy={busy}
        disabled={busy}
        onClick={onFlip}
        className={`flex h-7 w-12 flex-none rounded-full p-[3px] transition-colors disabled:cursor-wait disabled:opacity-60 ${on ? "bg-[#059669]" : "bg-[#CBD5E1]"}`}
      >
        <span className={`h-[22px] w-[22px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,0.2)] transition-transform ${on ? "translate-x-5" : ""}`} />
      </button>
    </div>
  );
}

function PersonLink({ row, id, onSelect }: { row: UserRow | undefined; id: string; onSelect: (id: string) => void }) {
  if (!row) return <span className="text-[#64748B]">Account not found</span>;
  return (
    <button type="button" onClick={() => onSelect(id)} className="text-right font-semibold text-[#0369D9] hover:text-[#024E96] hover:underline">
      {displayNameOf(row)}
      {!row.isActive ? <span className="ml-1.5 text-[11px] font-semibold text-[#B91C1C]">Archived</span> : null}
    </button>
  );
}

type PasswordView = { state: "hidden" } | { state: "loading" } | { state: "shown"; value: string } | { state: "error"; text: string };

function PasswordBox({ studentId }: { studentId: string }) {
  const [view, setView] = useState<PasswordView>({ state: "hidden" });
  const show = async () => {
    setView({ state: "loading" });
    try {
      setView({ state: "shown", value: await readStudentPassword(studentId) });
    } catch (e) {
      setView({ state: "error", text: failed("The password could not be read", e) });
    }
  };
  const shown = view.state === "shown";
  return (
    <>
      <div className="flex items-center gap-2.5 rounded-[10px] bg-[#F8FAFC] px-3 py-2.5">
        <div className="min-w-0 flex-1">
          <div className="text-xs text-[#64748B]">Password</div>
          <div className="break-all font-mono tracking-[0.04em]" data-testid="stored-password">
            {view.state === "shown" ? (view.value || <span className="font-sans tracking-normal text-[#64748B]">Not stored. Reset it to make one.</span>) : view.state === "loading" ? "…" : "••••••••"}
          </div>
        </div>
        <button
          type="button"
          disabled={view.state === "loading"}
          onClick={() => (shown ? setView({ state: "hidden" }) : show())}
          className="min-h-9 rounded-lg border border-[#CBD5E1] bg-white px-3 font-semibold text-[#334155] disabled:opacity-60"
        >
          {shown ? "Hide" : "Show"}
        </button>
      </div>
      {view.state === "error" ? (
        <div role="alert" className="text-xs font-semibold text-[#B91C1C]">
          {view.text}
        </div>
      ) : null}
    </>
  );
}

function RecentDecisions({ row, byId }: { row: UserRow; byId: Map<string, UserRow> }) {
  const [recorded, setRecorded] = useState<Decision[] | null>(null);
  const [failedToLoad, setFailedToLoad] = useState(false);
  useEffect(() => {
    setRecorded(null);
    setFailedToLoad(false);
    return listenDecisions(row.id, 5, setRecorded, () => {
      setRecorded([]);
      setFailedToLoad(true);
    });
  }, [row.id]);
  const events = useMemo(() => mergeDecisions(recorded ?? [], fallbackDecisions(row), 5), [recorded, row]);
  if (recorded === null) return null;
  return (
    <Section title="Recent decisions">
      {events.length === 0 ? (
        <div className="text-[13px] text-[#64748B]">{failedToLoad ? "Decisions could not be loaded." : "No decisions recorded yet."}</div>
      ) : (
        events.map((e) => {
          const known = byId.get(e.actorUid);
          const actor = decisionActor(e.actorName || (known ? displayNameOf(known) : ""), e.actorUid, e.actorKind);
          return (
            <div key={e.id} className="flex justify-between gap-2 text-[13px]">
              <span className="min-w-0">
                {decisionLabel(e.action)}
                {actor ? <span className="text-[#64748B]"> · {actor}</span> : null}
              </span>
              <span className="flex-none whitespace-nowrap text-[#64748B]">{e.at ? formatDay(e.at) : ""}</span>
            </div>
          );
        })
      )}
    </Section>
  );
}

type Dialog =
  | null
  | "archive"
  | "restore"
  | "promote"
  | "revoke"
  | "reset"
  | { kind: "resetDone"; password: string; studentCode: string; emailedTo: string[] }
  | "zoomOn"
  | "zoomOff"
  | "delete"
  | "sendLogin";

const roleText = (row: UserRow) => (row.isAdminTeacher ? "Admin-teacher" : typeInfo(row).label);

/** Everything about one person, and every action on them. */
export function UserPanel({
  row,
  byId,
  links,
  viewerUid,
  say,
  onClose,
  onSelect,
  onEdit,
}: {
  row: ListRow;
  byId: Map<string, UserRow>;
  links: ParentLinks;
  viewerUid: string;
  say: Say;
  onClose: () => void;
  onSelect: (id: string) => void;
  onEdit: (id: string) => void;
}) {
  const student = isStudentType(row);
  const parent = row.userType.toLowerCase() === "parent";
  const never = isNeverLoggedIn(row);
  const all = useMemo(() => [...byId.values()], [byId]);
  // Both sides of every link (the student's lists and the parent's children list), as Edit user shows them.
  const guardians = useMemo(() => (student ? guardiansOfStudent(row, all, byId) : []), [student, row, all, byId]);
  const linkedStudents = useMemo(() => (parent ? studentsOfParent(row, all, byId) : []), [parent, row, all, byId]);
  const actions = panelActions(row);
  const name = displayNameOf(row);
  const [dialog, setDialog] = useState<Dialog>(null);
  const [busySwitch, setBusySwitch] = useState<string | null>(null);
  // A reset puts the Login section's password back behind Show, so it never shows the old one.
  const [passwordVersion, setPasswordVersion] = useState(0);
  const guardianNames = guardians.filter((g) => g.row).map((g) => g.name);
  const closeDialog = () => setDialog(null);

  const flip = async (key: "ai_tutor_enabled" | "tontine_enabled", label: string, current: boolean) => {
    if (busySwitch) return;
    setBusySwitch(key);
    try {
      await setUserSwitch(row.id, key, !current);
      say(switchToast(label, !current, row));
    } catch (e) {
      say(failed(`${label} could not be changed for ${name}`, e), "error");
    } finally {
      setBusySwitch(null);
    }
  };

  const guarded = (action: "archive" | "delete" | "removeAdminAccess", open: Dialog) => {
    const refusal = selfGuard(row, viewerUid, action);
    if (refusal) say(refusal, "error");
    else setDialog(open);
  };

  const attempt = async (work: () => Promise<void>, success: string, failure: string): Promise<string | null> => {
    try {
      await work();
      say(success);
      return null;
    } catch (e) {
      return failed(failure, e);
    }
  };

  return (
    <div className="flex flex-col">
      <div className="flex items-start gap-3.5 border-b border-[#F1F5F9] p-5">
        <Avatar row={row} size={56} />
        <div className="flex min-w-0 flex-1 flex-col gap-1.5">
          <h2 className={`m-0 break-words text-lg font-bold ${row.isActive ? "" : "text-[#64748B] line-through"}`}>{name}</h2>
          <div className="flex flex-wrap gap-1.5">
            <TypePill row={row} />
            {row.isActive ? <Pill bg="#ECFDF5" fg="#047857">Active</Pill> : <Pill bg="#FEF2F2" fg="#B91C1C">Archived</Pill>}
          </div>
        </div>
        <button type="button" onClick={onClose} aria-label="Close panel" className="grid h-10 w-10 flex-none place-items-center rounded-[10px] bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]">
          <X size={18} aria-hidden="true" />
        </button>
      </div>

      <div className="grid grid-cols-2 gap-x-4 gap-y-3 border-b border-[#F1F5F9] px-5 py-4">
        <Fact label="Email" wide>
          {row.email || "—"}
        </Fact>
        <Fact label="Phone">{phoneDisplay(row) || "—"}</Fact>
        <Fact label="Kiosk code" mono>
          {row.kioskCode || "—"}
        </Fact>
        <Fact label="Added">{row.dateAdded ? dayOrText(row.dateAdded, row.dateAddedText) : row.dateAddedText === "Never" ? "—" : row.dateAddedText}</Fact>
        <Fact label="Last login">
          <span className={never ? "font-semibold text-[#B45309]" : ""}>{never ? "Never" : dayOrText(row.lastLogin, row.lastLoginText)}</span>
        </Fact>
        {row.title ? <Fact label="Title">{row.title}</Fact> : null}
        {row.secondaryRoles.length > 0 ? <Fact label="Other roles">{row.secondaryRoles.join(", ")}</Fact> : null}
      </div>

      <PanelFacts key={row.id} row={row} />

      {student ? (
        <>
          <Section title="Login">
            <div className="grid grid-cols-2 gap-2.5">
              <div className="rounded-[10px] bg-[#F8FAFC] px-3 py-2.5">
                <div className="text-xs text-[#64748B]">Student ID</div>
                <div className="break-all font-mono">{row.storedStudentCode || "Not set"}</div>
              </div>
              <div className="rounded-[10px] bg-[#F8FAFC] px-3 py-2.5">
                <div className="text-xs text-[#64748B]">Login email</div>
                <div className="break-all font-mono text-xs">{loginEmailOf(row) || "Not available"}</div>
              </div>
            </div>
            <PasswordBox key={`${row.id}:${passwordVersion}`} studentId={row.id} />
            <div className="text-xs text-[#64748B]">
              {row.storedStudentCode ? "Only admins and this student's parent can see it." : "This student has no Student ID yet. Reset the password to make one."}
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setDialog("reset")}
                className="flex min-h-10 items-center rounded-[10px] border border-[#BFDBFE] bg-[#EFF6FF] px-3.5 font-semibold text-[#1D4ED8] hover:bg-[#DBEAFE]"
              >
                Reset password
              </button>
              <button
                type="button"
                onClick={() => setDialog("sendLogin")}
                className="flex min-h-10 items-center rounded-[10px] border border-[#BBF7D0] bg-[#F0FDF4] px-3.5 font-semibold text-[#15803D] hover:bg-[#DCFCE7]"
              >
                Send login details
              </button>
            </div>
          </Section>
          <Section title="Family and classes">
            {guardians.length === 0 ? (
              <Line label="Guardian">None linked</Line>
            ) : (
              guardians.map((g, i) => (
                <Line key={g.id} label={i === 0 ? (guardians.length > 1 ? "Guardians" : "Guardian") : ""}>
                  <PersonLink row={g.row} id={g.id} onSelect={onSelect} />
                  {g.side !== "both" ? <span className="block text-[11px] font-semibold text-[#B45309]">{sideNote(g.side, "student")}</span> : null}
                </Line>
              ))
            )}
            <button type="button" onClick={() => onEdit(row.id)} className="self-start text-[13px] font-semibold text-[#0369D9] hover:underline">
              Manage guardians
            </button>
            <Line label="Teacher this week">{row.teacherNames || "No classes this week"}</Line>
            {row.weeklyHoursLabel ? <Line label="Hours this week">{row.weeklyHoursLabel}</Line> : null}
            <Line label="First class">{firstClassText(row)}</Line>
          </Section>
        </>
      ) : null}

      {parent ? (
        <Section title="Linked students">
          {linkedStudents.length === 0 ? (
            <div className="text-[#64748B]">No students linked</div>
          ) : (
            <div className="flex flex-col gap-1.5">
              {linkedStudents.map((s) => (
                <div key={s.id} className="flex flex-col items-start">
                  <PersonLink row={s.row} id={s.id} onSelect={onSelect} />
                  {s.side !== "both" ? <span className="text-[11px] font-semibold text-[#B45309]">{sideNote(s.side, "parent")}</span> : null}
                </div>
              ))}
            </div>
          )}
          <button type="button" onClick={() => onEdit(row.id)} className="self-start text-[13px] font-semibold text-[#0369D9] hover:underline">
            Manage linked students
          </button>
        </Section>
      ) : null}

      {isAdminRow(row) ? (
        <Section title="Admin">
          <Line label="Admin type">{adminTypeLabel(row)}</Line>
        </Section>
      ) : null}

      {actions.aiTutor || actions.tontine || actions.zoom ? (
        <Section title="Access">
          {actions.aiTutor ? (
            <Switch label="AI Tutor" help="Can use the AI Tutor" on={row.aiTutorEnabled} busy={busySwitch === "ai_tutor_enabled"} onFlip={() => flip("ai_tutor_enabled", "AI Tutor", row.aiTutorEnabled)} />
          ) : null}
          {actions.tontine ? (
            <Switch label="Tontine" help="Savings circles in the phone app" on={row.tontineEnabled} busy={busySwitch === "tontine_enabled"} onFlip={() => flip("tontine_enabled", "Tontine", row.tontineEnabled)} />
          ) : null}
          {actions.zoom ? (
            <Switch
              label="Zoom classes"
              help={row.useZoom && row.zoomHostAccount ? `Host: ${row.zoomHostAccount}` : "Asks for the host account and which classes"}
              on={row.useZoom}
              busy={dialog === "zoomOn" || dialog === "zoomOff"}
              onFlip={() => setDialog(row.useZoom ? "zoomOff" : "zoomOn")}
            />
          ) : null}
        </Section>
      ) : null}

      <RecentDecisions row={row} byId={byId} />

      <div className="flex flex-wrap gap-2 px-5 py-4">
        <button type="button" onClick={() => onEdit(row.id)} className="flex min-h-11 items-center rounded-[10px] bg-[#0369D9] px-3.5 font-semibold text-white hover:bg-[#024E96]">
          Edit details
        </button>
        {actions.makeAdminTeacher ? (
          <button type="button" onClick={() => setDialog("promote")} className="flex min-h-11 items-center rounded-[10px] border border-[#FDE68A] bg-[#FFFBEB] px-3.5 font-semibold text-[#92400E] hover:bg-[#FEF3C7]">
            Make admin-teacher
          </button>
        ) : null}
        {actions.removeAdminAccess ? (
          <button type="button" onClick={() => guarded("removeAdminAccess", "revoke")} className="flex min-h-11 items-center rounded-[10px] border border-[#FECACA] bg-[#FEF2F2] px-3.5 font-semibold text-[#B91C1C] hover:bg-[#FEE2E2]">
            Remove admin access
          </button>
        ) : null}
        {actions.archive ? (
          <button type="button" onClick={() => guarded("archive", "archive")} className="flex min-h-11 items-center rounded-[10px] border border-[#CBD5E1] bg-white px-3.5 font-semibold text-[#334155] hover:bg-[#F8FAFC]">
            Archive
          </button>
        ) : null}
        {actions.restore ? (
          <button type="button" onClick={() => setDialog("restore")} className="flex min-h-11 items-center rounded-[10px] border border-[#A7F3D0] bg-[#ECFDF5] px-3.5 font-semibold text-[#047857] hover:bg-[#D1FAE5]">
            Restore
          </button>
        ) : null}
        <button type="button" onClick={() => guarded("delete", "delete")} className="flex min-h-11 items-center rounded-[10px] px-3.5 font-semibold text-[#B91C1C] hover:bg-[#FEF2F2]">
          Delete…
        </button>
      </div>

      {dialog === "archive" ? (
        <ArchiveDialog row={row} showsAdminPay={isAdminRow(row)} onClose={closeDialog} onConfirm={() => attempt(() => archiveUser(row.id), `${name} was archived.`, `${name} could not be archived`)} />
      ) : null}
      {dialog === "restore" ? (
        <RestoreDialog row={row} showsAdminPay={isAdminRow(row)} onClose={closeDialog} onConfirm={() => attempt(() => restoreUser(row.id), `${name} was restored.`, `${name} could not be restored`)} />
      ) : null}
      {dialog === "promote" ? (
        <MakeAdminTeacherDialog row={row} onClose={closeDialog} onConfirm={() => attempt(() => setAdminTeacher(row.id, true), `${name} is now an admin-teacher.`, `${name} could not be made an admin-teacher`)} />
      ) : null}
      {dialog === "revoke" ? (
        <RemoveAdminDialog row={row} onClose={closeDialog} onConfirm={() => attempt(() => setAdminTeacher(row.id, false), `Admin access removed from ${name}.`, `Admin access could not be removed from ${name}`)} />
      ) : null}
      {dialog === "reset" ? (
        <ResetPasswordDialog
          row={row}
          guardianNames={guardianNames}
          onClose={closeDialog}
          onReset={async (password) => {
            try {
              const result = await resetStudentPassword(row.id, password);
              setPasswordVersion((v) => v + 1);
              setDialog({ kind: "resetDone", password: result.newPassword, studentCode: result.studentCode, emailedTo: result.emailedTo });
              return null;
            } catch (e) {
              return failed("The password could not be reset", e);
            }
          }}
        />
      ) : null}
      {dialog && typeof dialog === "object" && dialog.kind === "resetDone" ? (
        <ResetResultDialog password={dialog.password} studentCode={dialog.studentCode} emailedTo={dialog.emailedTo} onClose={closeDialog} />
      ) : null}
      {dialog === "zoomOn" ? (
        <ZoomOnDialog
          row={row}
          onClose={closeDialog}
          onEnable={async ({ zoomHostAccount, studentIds }) => {
            try {
              const r = await setTeacherZoom({ teacherId: row.id, enabled: true, zoomHostAccount, ...(studentIds ? { studentIds } : {}) });
              say(zoomResultMessage(name, true, r.updatedShiftCount));
              return null;
            } catch (e) {
              return failed("Zoom could not be turned on", e);
            }
          }}
        />
      ) : null}
      {dialog === "zoomOff" ? (
        <ZoomOffDialog
          row={row}
          onClose={closeDialog}
          onConfirm={async () => {
            try {
              const r = await setTeacherZoom({ teacherId: row.id, enabled: false });
              say(zoomResultMessage(name, false, r.updatedShiftCount));
              return null;
            } catch (e) {
              return failed("Zoom could not be turned off", e);
            }
          }}
        />
      ) : null}
      {dialog === "sendLogin" ? <SendLoginDialog row={row} rows={all} byId={byId} say={say} onClose={closeDialog} /> : null}
      {dialog === "delete" ? (
        <DeleteDialog
          row={row}
          roleText={roleText(row)}
          onClose={closeDialog}
          onDelete={async (deleteClasses) => {
            try {
              const result = await deleteUser(row.id, row.isActive, deleteClasses);
              say(deleteSuccessMessage(name, result, deleteClasses));
              setDialog(null);
              onClose();
              return null;
            } catch (e) {
              return deleteErrorMessage(e, name);
            }
          }}
        />
      ) : null}
    </div>
  );
}
