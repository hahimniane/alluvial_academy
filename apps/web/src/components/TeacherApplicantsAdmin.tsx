"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, doc, getDocs, limit, orderBy, query, serverTimestamp, Timestamp, updateDoc } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  Calendar,
  Check,
  ChevronDown,
  Download,
  Eye,
  Inbox,
  Lock,
  MoreVertical,
  Users,
  X,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TeacherStatus = "All" | "Pending" | "Reviewed" | "Approved" | "Rejected";

export type TeacherApplicationRow = {
  id: string;
  firstName: string;
  lastName: string;
  fullName: string;
  email: string;
  phoneNumber: string;
  currentLocation: string;
  gender: string;
  nationality: string;
  currentStatus: string;
  teachingPrograms: string[];
  englishSubjects: string[];
  languages: string[];
  timeDiscipline: string;
  scheduleBalance: string;
  tajwidLevel: string;
  quranMemorization: string;
  arabicProficiency: string;
  interestReason: string;
  electricityAccess: string;
  teachingComfort: string;
  availabilityStart: string;
  teachingDevice: string;
  internetAccess: string;
  status: string;
  submittedAt: Date | null;
};

const filters: TeacherStatus[] = ["All", "Pending", "Reviewed", "Approved", "Rejected"];

export function TeacherApplicantsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [applications, setApplications] = useState<TeacherApplicationRow[]>([]);
  const [activeFilter, setActiveFilter] = useState<TeacherStatus>("Pending");
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [details, setDetails] = useState<TeacherApplicationRow | null>(null);
  const [showDateControls, setShowDateControls] = useState(false);
  const [dateStart, setDateStart] = useState("");
  const [dateEnd, setDateEnd] = useState("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        const rows = await loadTeacherApplications();
        if (mounted) setApplications(rows);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load teacher applications.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const filteredApplications = useMemo(() => {
    return applications.filter((application) => {
      const statusMatches = activeFilter === "All" || application.status.toLowerCase() === activeFilter.toLowerCase();
      const submitted = application.submittedAt;
      const startMatches = !dateStart || (submitted && submitted >= startOfDay(dateStart));
      const endMatches = !dateEnd || (submitted && submitted <= endOfDay(dateEnd));
      return statusMatches && startMatches && endMatches;
    });
  }, [activeFilter, applications, dateEnd, dateStart]);

  useEffect(() => {
    setSelectedIds((current) => new Set([...current].filter((id) => filteredApplications.some((application) => application.id === id))));
  }, [filteredApplications]);

  async function refreshApplications() {
    setLoading(true);
    setMessage("");
    try {
      setApplications(await loadTeacherApplications());
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load teacher applications.");
    } finally {
      setLoading(false);
    }
  }

  async function updateApplicationStatus(application: TeacherApplicationRow, nextStatus: Exclude<TeacherStatus, "All">) {
    if (!auth.currentUser) {
      setMessage("Sign in with an administrator account before updating applications.");
      return;
    }
    setMessage("");
    try {
      await updateDoc(doc(db, "teacher_applications", application.id), {
        status: nextStatus,
        reviewed_by: auth.currentUser.uid,
        reviewed_at: serverTimestamp(),
      });
      setMessage(`Status updated to ${nextStatus}`);
      await refreshApplications();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not update status.");
    }
  }

  async function markSelectedReviewed() {
    const selected = filteredApplications.filter((application) => selectedIds.has(application.id));
    for (const application of selected) {
      await updateApplicationStatus(application, "Reviewed");
    }
    setSelectedIds(new Set());
  }

  function exportCsv() {
    const headers = ["ID", "Name", "Email", "Phone", "Location", "Nationality", "Programs", "Languages", "Status", "Submitted At"];
    const rows = filteredApplications.map((application) => [
      application.id,
      application.fullName,
      application.email,
      application.phoneNumber,
      application.currentLocation,
      application.nationality,
      application.teachingPrograms.join(", "),
      application.languages.join(", "),
      application.status,
      formatDateTime(application.submittedAt),
    ]);
    const csv = [headers, ...rows]
      .map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(","))
      .join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `teacher_applications_${new Date().toISOString().slice(0, 10).replaceAll("-", "")}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  if (access !== "allowed") {
    return <TeacherApplicantsAccessPrompt access={access} />;
  }

  const allVisibleSelected = filteredApplications.length > 0 && filteredApplications.every((application) => selectedIds.has(application.id));

  return (
    <AdminDashboardShell activeLabel="Teacher Applicants" breadcrumb="People / Teacher Applicants">
      <main className="min-h-[calc(100vh-56px)] bg-white text-[#111827]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Education Hub</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="border-b border-[#E5E7EB] bg-white px-6 py-6">
          <div className="flex items-center gap-4">
            <Users className="shrink-0 text-[#8B5CF6]" size={32} />
            <div className="min-w-0 flex-1">
              <h1 className="text-2xl font-bold leading-tight text-[#111827]">Teacher Applicants</h1>
              <p className="mt-1 text-sm text-[#6B7280]">{applications.length} total applications</p>
            </div>
            {selectedIds.size > 0 ? (
              <button
                type="button"
                onClick={markSelectedReviewed}
                className="hidden min-h-10 items-center gap-2 rounded-lg bg-[#8B5CF6] px-4 text-sm font-semibold text-white sm:inline-flex"
              >
                <Check size={17} />
                Mark As Reviewed
              </button>
            ) : null}
            <button
              type="button"
              onClick={exportCsv}
              className="grid h-10 w-10 place-items-center rounded-lg text-[#6B7280] hover:bg-[#F3F4F6]"
              aria-label="Export To Csv"
            >
              <Download size={20} />
            </button>
          </div>
        </section>

        <section className="overflow-x-auto border-b border-[#E5E7EB] bg-[#F9FAFB] px-6 py-4">
          <div className="flex min-w-max items-center gap-2 lg:min-w-0">
            {filters.map((filter) => {
              const selected = activeFilter === filter;
              return (
                <button
                  key={filter}
                  type="button"
                  onClick={() => {
                    setActiveFilter(filter);
                    setSelectedIds(new Set());
                  }}
                  className={`inline-flex min-h-9 items-center gap-2 rounded-lg border px-4 text-sm ${
                    selected ? "border-[#DDD6FE] bg-[#EDE9FE] text-[#5B21B6]" : "border-[#D1D5DB] bg-white text-[#374151]"
                  }`}
                >
                  {selected ? <Check size={15} /> : null}
                  {filter}
                </button>
              );
            })}
            <div className="hidden flex-1 lg:block" />
            <div className="relative">
              <button
                type="button"
                onClick={() => setShowDateControls((current) => !current)}
                className="inline-flex min-h-9 items-center gap-2 rounded-full border border-[#9CA3AF] bg-white px-5 text-sm text-[#007AFF]"
              >
                <Calendar size={16} />
                {dateStart || dateEnd ? `${shortDateLabel(dateStart) || "Start"} - ${shortDateLabel(dateEnd) || "End"}` : "Select Date Range"}
                <ChevronDown size={15} className="text-[#6B7280]" />
              </button>
              {showDateControls ? (
                <div className="absolute right-0 z-20 mt-2 w-[280px] rounded-xl border border-black/10 bg-white p-3 shadow-xl">
                  <label className="block text-xs font-bold text-[#6B7280]" htmlFor="teacher-applications-start">
                    Start date
                  </label>
                  <input
                    id="teacher-applications-start"
                    type="date"
                    value={dateStart}
                    onChange={(event) => setDateStart(event.target.value)}
                    className="mt-1 h-10 w-full rounded-lg border border-[#D1D5DB] px-3 text-sm"
                  />
                  <label className="mt-3 block text-xs font-bold text-[#6B7280]" htmlFor="teacher-applications-end">
                    End date
                  </label>
                  <input
                    id="teacher-applications-end"
                    type="date"
                    value={dateEnd}
                    onChange={(event) => setDateEnd(event.target.value)}
                    className="mt-1 h-10 w-full rounded-lg border border-[#D1D5DB] px-3 text-sm"
                  />
                  <div className="mt-3 flex justify-end gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        setDateStart("");
                        setDateEnd("");
                      }}
                      className="rounded-lg px-3 py-2 text-sm font-semibold text-[#6B7280]"
                    >
                      Clear
                    </button>
                    <button
                      type="button"
                      onClick={() => setShowDateControls(false)}
                      className="rounded-lg bg-[#111827] px-3 py-2 text-sm font-semibold text-white"
                    >
                      Apply
                    </button>
                  </div>
                </div>
              ) : null}
            </div>
          </div>
        </section>

        {message ? (
          <div className="mx-6 mt-4 rounded-xl border border-[#C7D2FE] bg-[#EEF2FF] px-4 py-3 text-sm font-semibold text-[#3730A3]">
            {message}
          </div>
        ) : null}

        {loading ? (
          <div className="grid min-h-[360px] place-items-center">
            <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#EDE9FE] border-t-[#8B5CF6]" />
          </div>
        ) : filteredApplications.length === 0 ? (
          <EmptyState />
        ) : (
          <section className="overflow-x-auto">
            <table className="min-w-[1080px] border-collapse text-left text-sm">
              <thead className="bg-[#F3F4F6] text-sm font-semibold text-[#374151]">
                <tr>
                  <th className="w-[60px] border border-[#E5E7EB] px-5 py-4">
                    <input
                      type="checkbox"
                      aria-label="Select all applications"
                      checked={allVisibleSelected}
                      onChange={(event) => {
                        if (event.target.checked) setSelectedIds(new Set(filteredApplications.map((application) => application.id)));
                        else setSelectedIds(new Set());
                      }}
                      className="h-5 w-5 rounded border-[#6B7280]"
                    />
                  </th>
                  {["Name", "Programs", "Languages", "Location", "Status", "Submitted", "Actions"].map((heading) => (
                    <th key={heading} className="border border-[#E5E7EB] px-3 py-4">
                      {heading}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredApplications.map((application) => (
                  <TeacherApplicationTableRow
                    key={application.id}
                    application={application}
                    selected={selectedIds.has(application.id)}
                    onSelect={(selected) => {
                      setSelectedIds((current) => {
                        const next = new Set(current);
                        if (selected) next.add(application.id);
                        else next.delete(application.id);
                        return next;
                      });
                    }}
                    onView={() => setDetails(application)}
                    onStatusUpdate={(status) => updateApplicationStatus(application, status)}
                  />
                ))}
              </tbody>
            </table>
          </section>
        )}

        {details ? <TeacherApplicationDetails application={details} onClose={() => setDetails(null)} /> : null}
      </main>
    </AdminDashboardShell>
  );
}

function TeacherApplicationTableRow({
  application,
  selected,
  onSelect,
  onView,
  onStatusUpdate,
}: {
  application: TeacherApplicationRow;
  selected: boolean;
  onSelect: (selected: boolean) => void;
  onView: () => void;
  onStatusUpdate: (status: Exclude<TeacherStatus, "All">) => void;
}) {
  return (
    <tr className="text-[#374151]">
      <td className="border border-[#E5E7EB] px-5 py-3">
        <input
          type="checkbox"
          aria-label={`Select ${application.fullName}`}
          checked={selected}
          onChange={(event) => onSelect(event.target.checked)}
          className="h-5 w-5 rounded border-[#6B7280]"
        />
      </td>
      <TableCell>{application.fullName}</TableCell>
      <TableCell>{application.teachingPrograms.join(", ")}</TableCell>
      <TableCell>{application.languages.join(", ")}</TableCell>
      <TableCell>{application.currentLocation}</TableCell>
      <td className="border border-[#E5E7EB] px-3 py-3">
        <StatusPill status={application.status} />
      </td>
      <TableCell>{formatDate(application.submittedAt)}</TableCell>
      <td className="border border-[#E5E7EB] px-3 py-3">
        <div className="flex items-center justify-center gap-4">
          <button type="button" onClick={onView} className="text-[#6B7280] hover:text-[#111827]" aria-label={`View ${application.fullName}`}>
            <Eye size={18} />
          </button>
          <label className="relative grid h-8 w-8 place-items-center text-[#6B7280]" aria-label={`Change status for ${application.fullName}`}>
            <MoreVertical size={18} />
            <select
              aria-label={`Change status for ${application.fullName}`}
              value=""
              onChange={(event) => {
                const value = event.target.value as Exclude<TeacherStatus, "All">;
                if (value) onStatusUpdate(value);
              }}
              className="absolute inset-0 cursor-pointer opacity-0"
            >
              <option value="" disabled>
                Actions
              </option>
              <option value="Reviewed">Mark As Reviewed</option>
              <option value="Approved">Approve</option>
              <option value="Rejected">Reject</option>
              <option value="Pending">Mark As Pending</option>
            </select>
          </label>
        </div>
      </td>
    </tr>
  );
}

function TableCell({ children }: { children: string }) {
  return (
    <td className="max-w-[190px] overflow-hidden text-ellipsis whitespace-nowrap border border-[#E5E7EB] px-3 py-3 text-[13px]">
      {children || "-"}
    </td>
  );
}

function StatusPill({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const colors =
    normalized === "approved"
      ? "border-[#86EFAC] bg-[#DCFCE7] text-[#16A34A]"
      : normalized === "rejected"
        ? "border-[#FCA5A5] bg-[#FEE2E2] text-[#DC2626]"
        : normalized === "reviewed"
          ? "border-[#93C5FD] bg-[#DBEAFE] text-[#2563EB]"
          : "border-[#FDBA74] bg-[#FFEDD5] text-[#F97316]";
  return <span className={`inline-flex rounded-full border px-2 py-1 text-xs font-semibold ${colors}`}>{status || "pending"}</span>;
}

function EmptyState() {
  return (
    <div className="grid min-h-[420px] place-items-center text-center">
      <div>
        <Inbox className="mx-auto text-[#9CA3AF]" size={64} />
        <p className="mt-4 text-lg text-[#6B7280]">No Applications Found</p>
      </div>
    </div>
  );
}

function TeacherApplicationDetails({ application, onClose }: { application: TeacherApplicationRow; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 px-4 py-8">
      <section className="max-h-full w-full max-w-[700px] overflow-y-auto rounded-2xl bg-white p-6 shadow-2xl">
        <header className="flex items-center gap-4">
          <h2 className="min-w-0 flex-1 text-xl font-bold">Application Details</h2>
          <button type="button" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-lg text-[#6B7280] hover:bg-[#F3F4F6]" aria-label="Close details">
            <X size={20} />
          </button>
        </header>
        <div className="my-4 border-t border-[#E5E7EB]" />
        <DetailSection title="Personal Info" />
        <DetailRow label="Name" value={application.fullName} />
        <DetailRow label="Email" value={application.email} />
        <DetailRow label="Phone" value={application.phoneNumber} />
        <DetailRow label="Location" value={application.currentLocation} />
        <DetailRow label="Nationality" value={application.nationality} />
        <DetailRow label="Gender" value={application.gender} />
        <DetailRow label="Status" value={application.currentStatus} />

        <DetailSection title="Teaching Program" />
        <DetailRow label="Programs" value={application.teachingPrograms.join(", ")} />
        {application.englishSubjects.length > 0 ? <DetailRow label="English Subjects" value={application.englishSubjects.join(", ")} /> : null}
        <DetailRow label="Languages" value={application.languages.join(", ")} />

        {application.teachingPrograms.some((program) => program.toLowerCase().includes("islamic")) ? (
          <>
            <DetailSection title="Islamic Studies" />
            <DetailRow label="Tajwid Level" value={application.tajwidLevel} />
            <DetailRow label="Quran Memorization" value={application.quranMemorization} />
            <DetailRow label="Arabic Proficiency" value={application.arabicProficiency} />
          </>
        ) : null}

        <DetailSection title="Experience & Commitment" />
        <DetailRow label="Time Discipline" value={application.timeDiscipline} />
        <DetailRow label="Schedule Balance" value={application.scheduleBalance} />
        <DetailRow label="Electricity Access" value={application.electricityAccess} />
        <DetailRow label="Teaching Comfort" value={application.teachingComfort} />
        <DetailRow label="Start Date" value={application.availabilityStart} />

        <DetailSection title="Technical" />
        <DetailRow label="Device" value={application.teachingDevice} />
        <DetailRow label="Internet" value={application.internetAccess} />

        <DetailSection title="Motivation" />
        <div className="rounded-lg border border-[#E5E7EB] bg-[#F9FAFB] p-3 text-sm leading-6 text-[#111827]">
          {application.interestReason || "-"}
        </div>

        <footer className="mt-6 flex justify-end">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#374151] hover:bg-[#F3F4F6]">
            Close
          </button>
        </footer>
      </section>
    </div>
  );
}

function DetailSection({ title }: { title: string }) {
  return <h3 className="pb-3 pt-4 text-base font-bold text-[#8B5CF6]">{title}</h3>;
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid gap-1 pb-3 text-sm sm:grid-cols-[160px_1fr]">
      <dt className="font-semibold text-[#6B7280]">{label}</dt>
      <dd className="text-[#111827]">{value || "-"}</dd>
    </div>
  );
}

function TeacherApplicantsAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#E6EEF8] text-[#001E4E]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before managing teacher applicants."
              : "Your signed-in account does not have administrator permissions for this module."}
        </p>
        {!checking ? (
          <Link href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#001E4E] px-5 text-sm font-semibold text-white">
            Go to login
          </Link>
        ) : null}
      </section>
    </main>
  );
}

export async function loadTeacherApplications() {
  const snap = await getDocs(query(collection(db, "teacher_applications"), orderBy("submitted_at", "desc"), limit(150)));
  return snap.docs.map((docSnap) => normalizeTeacherApplication(docSnap.id, docSnap.data() as Record<string, unknown>));
}

function normalizeTeacherApplication(id: string, data: Record<string, unknown>): TeacherApplicationRow {
  const firstName = stringValue(data.first_name ?? data.firstName);
  const lastName = stringValue(data.last_name ?? data.lastName);
  const fullName = [firstName, lastName].filter(Boolean).join(" ") || stringValue(data.email) || "Applicant";
  return {
    id,
    firstName,
    lastName,
    fullName,
    email: stringValue(data.email),
    phoneNumber: stringValue(data.phone_number ?? data.phoneNumber),
    currentLocation: stringValue(data.current_location ?? data.currentLocation),
    gender: stringValue(data.gender),
    nationality: stringValue(data.nationality),
    currentStatus: stringValue(data.current_status ?? data.currentStatus),
    teachingPrograms: stringArray(data.teaching_programs ?? data.teachingPrograms),
    englishSubjects: stringArray(data.english_subjects ?? data.englishSubjects),
    languages: stringArray(data.languages),
    timeDiscipline: stringValue(data.time_discipline ?? data.timeDiscipline),
    scheduleBalance: stringValue(data.schedule_balance ?? data.scheduleBalance),
    tajwidLevel: stringValue(data.tajwid_level ?? data.tajwidLevel),
    quranMemorization: stringValue(data.quran_memorization ?? data.quranMemorization),
    arabicProficiency: stringValue(data.arabic_proficiency ?? data.arabicProficiency),
    interestReason: stringValue(data.interest_reason ?? data.interestReason),
    electricityAccess: stringValue(data.electricity_access ?? data.electricityAccess),
    teachingComfort: stringValue(data.teaching_comfort ?? data.teachingComfort),
    availabilityStart: stringValue(data.availability_start ?? data.availabilityStart),
    teachingDevice: stringValue(data.teaching_device ?? data.teachingDevice),
    internetAccess: stringValue(data.internet_access ?? data.internetAccess),
    status: stringValue(data.status) || "pending",
    submittedAt: dateValue(data.submitted_at ?? data.submittedAt),
  };
}

function stringArray(value: unknown) {
  return Array.isArray(value) ? value.map((item) => stringValue(item)).filter(Boolean) : [];
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function dateValue(value: unknown) {
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === "string") return new Date(value);
  return null;
}

function formatDate(value: Date | null) {
  if (!value) return "-";
  return value.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function formatDateTime(value: Date | null) {
  if (!value) return "";
  return value.toISOString().replace("T", " ").slice(0, 19);
}

function shortDateLabel(value: string) {
  if (!value) return "";
  return new Date(`${value}T00:00:00`).toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function startOfDay(value: string) {
  return new Date(`${value}T00:00:00`);
}

function endOfDay(value: string) {
  return new Date(`${value}T23:59:59.999`);
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
