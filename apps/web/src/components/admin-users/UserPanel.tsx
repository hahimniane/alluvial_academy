"use client";

import type { ReactNode } from "react";
import { X } from "lucide-react";
import {
  adminTypeLabel,
  dayOrText,
  displayNameOf,
  firstClassText,
  isAdminRow,
  isNeverLoggedIn,
  isStudentType,
  loginEmailOf,
  phoneDisplay,
  type ListRow,
  type ParentLinks,
  type UserRow,
} from "@/lib/adminUsers";
import { Avatar, Pill, TypePill } from "./ui";

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

function OnOff({ label, help, on }: { label: string; help: string; on: boolean }) {
  return (
    <div className="flex min-h-12 items-center justify-between gap-3">
      <span className="flex flex-col">
        <span className="font-semibold">{label}</span>
        <span className="text-xs text-[#64748B]">{help}</span>
      </span>
      <Pill bg={on ? "#ECFDF5" : "#F1F5F9"} fg={on ? "#047857" : "#475569"}>
        {on ? "On" : "Off"}
      </Pill>
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

/** Everything about one person, read-only. */
export function UserPanel({
  row,
  byId,
  links,
  onClose,
  onSelect,
}: {
  row: ListRow;
  byId: Map<string, UserRow>;
  links: ParentLinks;
  onClose: () => void;
  onSelect: (id: string) => void;
}) {
  const student = isStudentType(row);
  const parent = row.userType.toLowerCase() === "parent";
  const type = row.userType.toLowerCase();
  const never = isNeverLoggedIn(row);
  const linkedStudents = parent ? [...new Set([...(links.studentsByParent.get(row.id) ?? []), ...row.childrenIds])] : [];

  return (
    <div className="flex flex-col">
      <div className="flex items-start gap-3.5 border-b border-[#F1F5F9] p-5">
        <Avatar row={row} size={56} />
        <div className="flex min-w-0 flex-1 flex-col gap-1.5">
          <h2 className={`m-0 break-words text-lg font-bold ${row.isActive ? "" : "text-[#64748B] line-through"}`}>{displayNameOf(row)}</h2>
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
          </Section>
          <Section title="Family and classes">
            {row.guardianIds.length === 0 ? (
              <Line label="Guardian">None linked</Line>
            ) : (
              row.guardianIds.map((id, i) => (
                <Line key={id} label={i === 0 ? (row.guardianIds.length > 1 ? "Guardians" : "Guardian") : ""}>
                  <PersonLink row={byId.get(id)} id={id} onSelect={onSelect} />
                </Line>
              ))
            )}
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
              {linkedStudents.map((id) => (
                <div key={id} className="flex justify-start">
                  <PersonLink row={byId.get(id)} id={id} onSelect={onSelect} />
                </div>
              ))}
            </div>
          )}
        </Section>
      ) : null}

      {isAdminRow(row) ? (
        <Section title="Admin">
          <Line label="Admin type">{adminTypeLabel(row)}</Line>
        </Section>
      ) : null}

      {row.isActive ? (
        <Section title="Access">
          {student || type === "teacher" ? <OnOff label="AI Tutor" help="Can use the AI Tutor" on={row.aiTutorEnabled} /> : null}
          <OnOff label="Tontine" help="Savings circles in the phone app" on={row.tontineEnabled} />
          {type === "teacher" ? <OnOff label="Zoom classes" help={row.useZoom && row.zoomHostAccount ? `Host: ${row.zoomHostAccount}` : "Classes run on Zoom"} on={row.useZoom} /> : null}
        </Section>
      ) : null}
    </div>
  );
}
