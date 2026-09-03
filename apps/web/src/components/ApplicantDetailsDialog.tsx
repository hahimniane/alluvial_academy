"use client";

import { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { StickyNote, X } from "lucide-react";
import { db } from "@/lib/firebase";

/**
 * The whole record, for the questions the card cannot answer.
 *
 * Read straight from the enrollment document rather than from the list's
 * normalised copy, so nothing an admin needs is missing because the list had no
 * use for it. The scheduling notes lead, because that is usually the field that
 * decides the schedule.
 */
export function ApplicantDetailsDialog({
  enrollmentId,
  studentName,
  onClose,
}: {
  enrollmentId: string;
  studentName: string;
  onClose: () => void;
}) {
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState("");
  const [showRaw, setShowRaw] = useState(false);

  useEffect(() => {
    let alive = true;
    getDoc(doc(db, "enrollments", enrollmentId))
      .then((snapshot) => {
        if (!alive) return;
        if (!snapshot.exists()) setError("This application no longer exists.");
        else setData(snapshot.data() as Record<string, unknown>);
      })
      .catch((issue) => alive && setError(issue instanceof Error ? issue.message : "Could not load the application."));
    return () => {
      alive = false;
    };
  }, [enrollmentId]);

  const sub = (key: string) => record(data?.[key]);
  const contact = sub("contact");
  const student = sub("student");
  const program = sub("program");
  const preferences = sub("preferences");
  const metadata = sub("metadata");
  const country = record(contact.country);
  const notes = str(preferences.schedulingNotes ?? data?.schedulingNotes);

  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4" role="dialog" aria-modal="true" aria-label="Applicant details">
      <div className="flex max-h-[90vh] w-full max-w-[560px] flex-col overflow-hidden rounded-2xl bg-white shadow-[0_24px_60px_rgba(0,0,0,0.32)]">
        <header className="flex shrink-0 items-center gap-2 border-b border-[#E5E7EB] px-5 py-4">
          <h2 className="min-w-0 flex-1 truncate text-lg font-bold text-[#111827]">
            {studentName || "Applicant details"}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="grid h-8 w-8 place-items-center rounded-lg text-[#64748B] hover:bg-[#F1F5F9]"
          >
            <X size={18} />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-5 py-4">
          {error ? <p className="text-sm font-semibold text-[#DC2626]">{error}</p> : null}
          {!data && !error ? <p className="text-sm text-[#64748B]">Loading…</p> : null}

          {data ? (
            <>
              {notes ? (
                <section className="rounded-xl border border-[#FDE68A] bg-[#FFFBEB] p-3.5">
                  <div className="flex items-center gap-1.5">
                    <StickyNote size={18} className="text-[#B45309]" />
                    <p className="text-[11px] font-extrabold uppercase tracking-[0.4px] text-[#92400E]">
                      Scheduling notes
                    </p>
                  </div>
                  <p className="mt-1.5 whitespace-pre-wrap text-[13px] leading-6 text-[#451A03]">{notes}</p>
                </section>
              ) : null}

              <Section
                title="Student"
                rows={[
                  ["Name", str(student.name ?? data.studentName)],
                  ["Age", str(student.age ?? data.studentAge)],
                  ["Gender", str(student.gender ?? data.gender)],
                  ["Grade level", str(data.gradeLevel)],
                  ["Adult student", bool(metadata.isAdult)],
                  ["Knows Zoom", bool(student.knowsZoom ?? data.knowsZoom)],
                ]}
              />
              <Section
                title="Contact"
                rows={[
                  ["Email", str(contact.email ?? data.email)],
                  ["Phone", str(contact.phone ?? data.phoneNumber)],
                  ["WhatsApp", str(contact.whatsApp ?? data.whatsAppNumber)],
                  ["Parent / guardian", str(contact.parentName ?? data.parentName)],
                  ["Guardian ID", str(contact.guardianId)],
                  ["City", str(contact.city ?? data.city)],
                  ["Country", str(country.name ?? data.countryName)],
                  ["Country code", str(country.code ?? data.countryCode)],
                ]}
              />
              <Section
                title="Program"
                rows={[
                  ["Program", str(data.programTitle ?? data.subject)],
                  ["Subject (internal)", str(data.subject)],
                  ["Specific language", str(data.specificLanguage)],
                  ["Level", str(data.gradeLevel ?? program.level)],
                  ["Class type", str(program.classType ?? data.classType)],
                  ["Session duration", str(program.sessionDuration)],
                  ["Sessions per week", str(program.sessionsPerWeek)],
                  ["Hours per week", str(program.hoursPerWeek)],
                ]}
              />
              <Section
                title="Preferences"
                rows={[
                  ["Preferred language", str(preferences.preferredLanguage ?? data.preferredLanguage)],
                  ["Days", joinList(preferences.days ?? data.preferredDays)],
                  ["Time zone", str(preferences.timeZone ?? data.timeZone)],
                  ["Time slots", joinList(preferences.timeSlots)],
                  ["Time of day", str(preferences.timeOfDayPreference ?? data.timeOfDayPreference)],
                ]}
              />
              <Section
                title="Pricing"
                rows={[
                  ["Track", str(metadata.trackId)],
                  ["Plan", str(metadata.pricingPlanLabel ?? metadata.pricingPlanId)],
                  ...pricingRows(record(metadata.pricingSnapshot)),
                ]}
              />
              <Section
                title="Record"
                rows={[
                  ["Status", str(metadata.status)],
                  ["Submitted", timestamp(metadata.submittedAt)],
                  ["Source", str(metadata.source)],
                  ["Matched teacher", str(metadata.matchedTeacherName)],
                  ["Matched at", timestamp(metadata.matchedAt)],
                  ["Student account", str(metadata.studentUserId)],
                  ["Application ID", enrollmentId],
                ]}
              />

              <section>
                <button
                  type="button"
                  onClick={() => setShowRaw((value) => !value)}
                  aria-expanded={showRaw}
                  className="text-[11px] font-bold text-[#475569] underline"
                >
                  {showRaw ? "Hide" : "Show"} raw application data
                </button>
                {showRaw ? (
                  <pre className="mt-2 max-h-64 overflow-auto rounded-lg bg-[#0F172A] p-3 text-[10px] leading-4 text-[#E2E8F0]">
                    {JSON.stringify(data, replacer, 2)}
                  </pre>
                ) : null}
              </section>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function Section({ title, rows }: { title: string; rows: [string, string][] }) {
  const filled = rows.filter(([, value]) => value !== "");
  if (filled.length === 0) return null;
  return (
    <section>
      <h3 className="text-[11px] font-extrabold uppercase tracking-[0.4px] text-[#64748B]">{title}</h3>
      <dl className="mt-1.5 grid gap-1">
        {filled.map(([label, value]) => (
          <div key={label} className="flex gap-2 text-[12px]">
            <dt className="w-40 shrink-0 font-semibold text-[#64748B]">{label}</dt>
            <dd className="min-w-0 flex-1 break-words text-[#1E293B]">{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

const str = (value: unknown): string => {
  if (value === null || value === undefined) return "";
  if (typeof value === "string") return value.trim();
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return "";
};

const bool = (value: unknown): string => (value === true ? "Yes" : value === false ? "No" : "");

const joinList = (value: unknown): string =>
  Array.isArray(value) ? value.filter((item) => typeof item === "string").join(", ") : "";

/** Firestore Timestamps arrive as objects with a toDate(); anything else is left alone. */
const timestamp = (value: unknown): string => {
  const candidate = value as { toDate?: () => Date } | null;
  if (candidate && typeof candidate.toDate === "function") return candidate.toDate().toLocaleString();
  return str(value);
};

const pricingRows = (snapshot: Record<string, unknown>): [string, string][] => {
  if (Object.keys(snapshot).length === 0) return [];
  return [
    ["Hours per week", str(snapshot.hoursPerWeek)],
    ["Hourly rate (USD)", str(snapshot.hourlyRateUsd)],
    ["Monthly (USD)", str(snapshot.monthlyUsd)],
  ];
};

/** Timestamps would otherwise serialise as {} in the raw view. */
const replacer = (_key: string, value: unknown) => {
  const candidate = value as { toDate?: () => Date } | null;
  if (candidate && typeof candidate.toDate === "function") return candidate.toDate().toISOString();
  return value;
};
