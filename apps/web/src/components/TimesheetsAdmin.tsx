"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, serverTimestamp, Timestamp, updateDoc, doc } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  CalendarDays,
  Check,
  CheckSquare,
  ChevronDown,
  Clock3,
  Download,
  FileDown,
  Filter,
  Lock,
  Search,
  SlidersHorizontal,
  X,
} from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TimesheetStatus = "draft" | "pending" | "approved" | "rejected";
type StatusFilter = "All" | "Pending" | "Approved" | "Rejected" | "Draft";
type DatePreset = "thisWeek" | "lastWeek" | "thisMonth";

type DateRange = {
  start: Date;
  end: Date;
};

type TimesheetEntry = {
  id: string;
  teacherId: string;
  teacherName: string;
  studentName: string;
  dateLabel: string;
  parsedDate: Date | null;
  start: string;
  end: string;
  totalHours: string;
  hourlyRate: number;
  paymentAmount: number | null;
  source: string;
  status: TimesheetStatus;
  shiftTitle: string;
  shiftId: string;
  isEdited: boolean;
  editApproved: boolean;
};

const statusFilters: StatusFilter[] = ["All", "Pending", "Approved", "Rejected", "Draft"];

export function TimesheetsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [timesheets, setTimesheets] = useState<TimesheetEntry[]>([]);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("Pending");
  const [search, setSearch] = useState("");
  const [dateRange, setDateRange] = useState<DateRange | null>(null);
  const [teacherFilter, setTeacherFilter] = useState("");
  const [editedOnly, setEditedOnly] = useState(false);
  const [needsAttention, setNeedsAttention] = useState(false);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");

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
        const loaded = await loadTimesheets();
        if (!mounted) return;
        setTimesheets(loaded);
        setFocusedId(loaded[0]?.id ?? null);
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load timesheets.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const counts = useMemo(() => statusCounts(timesheets), [timesheets]);
  const teachers = useMemo(() => Array.from(new Set(timesheets.map((entry) => entry.teacherName).filter(Boolean))).sort(), [timesheets]);

  const filteredTimesheets = useMemo(() => {
    const term = search.trim().toLowerCase();
    return timesheets.filter((entry) => {
      if (statusFilter !== "All" && entry.status !== statusFilter.toLowerCase()) return false;
      if (teacherFilter && entry.teacherName.toLowerCase() !== teacherFilter.toLowerCase()) return false;
      if (dateRange && (!entry.parsedDate || entry.parsedDate < dateRange.start || entry.parsedDate > endOfDay(dateRange.end))) return false;
      if (editedOnly && (!entry.isEdited || entry.editApproved)) return false;
      if (needsAttention && !entryNeedsAttention(entry)) return false;
      if (!term) return true;
      return [entry.teacherName, entry.studentName, entry.dateLabel, entry.shiftTitle, entry.shiftId, entry.status].some((value) =>
        value.toLowerCase().includes(term),
      );
    });
  }, [dateRange, editedOnly, needsAttention, search, statusFilter, teacherFilter, timesheets]);

  const visiblePendingIds = filteredTimesheets.filter((entry) => entry.status === "pending").map((entry) => entry.id);
  const focused = filteredTimesheets.find((entry) => entry.id === focusedId) ?? filteredTimesheets[0] ?? null;

  function toggleSelect(id: string, selected: boolean) {
    setSelectedIds((current) => {
      const next = new Set(current);
      if (selected) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  function selectAllPendingVisible() {
    setSelectedIds((current) => {
      const next = new Set(current);
      visiblePendingIds.forEach((id) => next.add(id));
      return next;
    });
  }

  function setPreset(preset: DatePreset) {
    setDateRange(presetDateRange(preset));
  }

  function exportCsv() {
    const headers = ["Teacher", "Date", "Student", "Hours", "Payment", "Source", "Status", "Shift"];
    const rows = filteredTimesheets.map((entry) => [
      entry.teacherName,
      entry.dateLabel,
      entry.studentName,
      entry.totalHours,
      paymentFor(entry).toFixed(2),
      entry.source,
      entry.status,
      entry.shiftTitle,
    ]);
    const csv = [headers, ...rows].map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `timesheets_${new Date().toISOString().slice(0, 10).replaceAll("-", "")}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  async function approveTimesheet(entry: TimesheetEntry) {
    await updateDoc(doc(db, "timesheet_entries", entry.id), {
      status: "approved",
      approved_at: serverTimestamp(),
      payment_amount: paymentFor(entry),
      updated_at: serverTimestamp(),
    });
    setTimesheets((current) => current.map((item) => (item.id === entry.id ? { ...item, status: "approved", paymentAmount: paymentFor(entry) } : item)));
    setMessage("Timesheet approved.");
  }

  async function rejectTimesheet(entry: TimesheetEntry) {
    await updateDoc(doc(db, "timesheet_entries", entry.id), {
      status: "rejected",
      rejected_at: serverTimestamp(),
      rejection_reason: "Reviewed from native web admin.",
      updated_at: serverTimestamp(),
    });
    setTimesheets((current) => current.map((item) => (item.id === entry.id ? { ...item, status: "rejected" } : item)));
    setMessage("Timesheet rejected.");
  }

  if (access !== "allowed") {
    return <TimesheetsAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Timesheets" breadcrumb="Operations / Timesheets">
      <main className="min-h-[calc(100vh-56px)] bg-[#FAFAFA] text-[#111827]">
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

        <section className="border-b border-[#E5E7EB] bg-white px-3 py-3 lg:px-4 lg:py-4">
          <div className="flex items-center gap-3">
            <h1 className="min-w-0 flex-1 text-[22px] font-bold text-[#1F2937]">Timesheet Review</h1>
            <button
              type="button"
              onClick={() => setFiltersOpen(true)}
              className="inline-flex min-h-10 items-center gap-2 rounded-xl px-3 text-sm font-semibold text-[#0386FF]"
            >
              <SlidersHorizontal size={18} />
              Filters
            </button>
            <button
              type="button"
              aria-label="Export timesheets"
              onClick={exportCsv}
              className="grid h-12 w-12 place-items-center rounded-full bg-[#E8EEF8] text-[#64748B] lg:h-11 lg:w-11"
            >
              <Download size={22} />
            </button>
          </div>

          <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
            {statusFilters.map((filter) => (
              <button
                key={filter}
                type="button"
                onClick={() => {
                  setStatusFilter(filter);
                  setSelectedIds(new Set());
                }}
                className={`inline-flex min-h-8 shrink-0 items-center gap-2 rounded-lg border px-4 text-xs font-bold ${
                  statusFilter === filter ? "border-[#0386FF] bg-[#0386FF] text-white" : "border-[#CBD5E1] bg-white text-[#0386FF]"
                }`}
              >
                {statusFilter === filter ? <Check size={14} /> : null}
                {filter === "All" ? "All" : filter} ({counts[filter]})
              </button>
            ))}
          </div>

          <div className="mt-1 text-xs text-[#6B7280]">{filteredTimesheets.length} shown</div>

          <div className="mt-3 flex flex-wrap items-center gap-3">
            <label className="relative block h-11 w-full max-w-[220px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#374151]" size={19} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Teacher, student, ..."
                aria-label="Search timesheets"
                className="h-full w-full rounded-xl border border-[#CBD5E1] bg-white pl-10 pr-3 text-base outline-none focus:border-[#0386FF]"
              />
            </label>
            <button
              type="button"
              onClick={selectAllPendingVisible}
              className="inline-flex min-h-10 items-center gap-2 rounded-xl px-2 text-sm font-medium text-[#0386FF]"
            >
              <CheckSquare size={18} />
              Select all pending (visible)
            </button>
          </div>

          <div className="mt-2 flex gap-2 overflow-x-auto pb-1">
            <button type="button" onClick={() => setPreset("thisWeek")} className="inline-flex min-h-9 shrink-0 items-center rounded-lg border border-[#CBD5E1] bg-white px-4 text-sm text-[#374151]">
              This Week
            </button>
            <button type="button" onClick={() => setPreset("lastWeek")} className="inline-flex min-h-9 shrink-0 items-center rounded-lg border border-[#CBD5E1] bg-white px-4 text-sm text-[#374151]">
              Last week
            </button>
            <button type="button" onClick={() => setPreset("thisMonth")} className="inline-flex min-h-9 shrink-0 items-center rounded-lg border border-[#CBD5E1] bg-white px-4 text-sm text-[#374151]">
              This Month
            </button>
            <button
              type="button"
              onClick={() => setDateRange(dateRange ? null : presetDateRange("thisWeek"))}
              className="inline-flex min-h-9 shrink-0 items-center gap-2 rounded-full border border-[#CBD5E1] bg-white px-4 text-sm text-[#0386FF]"
            >
              <CalendarDays size={16} />
              {dateRange ? dateRangeSummary(dateRange) : "Date Range"}
            </button>
          </div>
        </section>

        {message ? (
          <div className="mx-3 mt-3 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-4">
            {message}
          </div>
        ) : null}

        <section className="relative min-h-[560px]">
          {loading ? (
            <div className="grid min-h-[560px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : filteredTimesheets.length === 0 ? (
            <EmptyTimesheets />
          ) : (
            <div className="grid gap-3 p-3 xl:grid-cols-[minmax(0,1fr)_360px]">
              <TimesheetTable
                timesheets={filteredTimesheets}
                selectedIds={selectedIds}
                onSelect={toggleSelect}
                onFocus={setFocusedId}
                focusedId={focused?.id ?? null}
                onApprove={approveTimesheet}
                onReject={rejectTimesheet}
              />
              <TimesheetDetail entry={focused} onApprove={approveTimesheet} onReject={rejectTimesheet} />
            </div>
          )}
          {selectedIds.size > 0 ? (
            <div className="fixed bottom-4 left-1/2 z-20 flex -translate-x-1/2 items-center gap-3 rounded-2xl bg-[#111827] px-4 py-3 text-sm font-semibold text-white shadow-2xl">
              <span>{selectedIds.size} selected</span>
              <span className="text-white/70">Total pay: ${selectedTotal(timesheets, selectedIds).toFixed(2)}</span>
              <button type="button" onClick={() => setSelectedIds(new Set())} className="rounded-lg bg-white/10 px-3 py-1">
                Clear
              </button>
            </div>
          ) : null}
        </section>

        {filtersOpen ? (
          <div className="fixed inset-0 z-40 bg-black/30 p-4" role="dialog" aria-modal="true" aria-label="Timesheet filters">
            <div className="ml-auto mt-16 w-full max-w-sm rounded-2xl bg-white p-4 shadow-2xl">
              <div className="flex items-center gap-3">
                <h2 className="flex-1 text-lg font-bold">Filters</h2>
                <button type="button" aria-label="Close filters" onClick={() => setFiltersOpen(false)} className="grid h-9 w-9 place-items-center rounded-lg hover:bg-[#F8FAFC]">
                  <X size={18} />
                </button>
              </div>
              <label className="mt-4 block text-sm font-semibold text-[#374151]">
                Filter By Teacher
                <select
                  value={teacherFilter}
                  onChange={(event) => setTeacherFilter(event.target.value)}
                  className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] bg-white px-3 text-sm outline-none focus:border-[#0386FF]"
                >
                  <option value="">All Teachers</option>
                  {teachers.map((teacher) => (
                    <option key={teacher} value={teacher}>
                      {teacher}
                    </option>
                  ))}
                </select>
              </label>
              <label className="mt-4 flex items-center justify-between gap-3 text-sm font-medium text-[#374151]">
                Edited only
                <input type="checkbox" checked={editedOnly} onChange={(event) => setEditedOnly(event.target.checked)} className="h-5 w-5 accent-[#0386FF]" />
              </label>
              <label className="mt-4 flex items-center justify-between gap-3 text-sm font-medium text-[#374151]">
                Needs attention
                <input type="checkbox" checked={needsAttention} onChange={(event) => setNeedsAttention(event.target.checked)} className="h-5 w-5 accent-[#0386FF]" />
              </label>
              <button type="button" onClick={() => setFiltersOpen(false)} className="mt-5 min-h-11 w-full rounded-xl bg-[#0386FF] text-sm font-bold text-white">
                Close
              </button>
            </div>
          </div>
        ) : null}
      </main>
    </AdminDashboardShell>
  );
}

function TimesheetTable({
  timesheets,
  selectedIds,
  focusedId,
  onSelect,
  onFocus,
  onApprove,
  onReject,
}: {
  timesheets: TimesheetEntry[];
  selectedIds: Set<string>;
  focusedId: string | null;
  onSelect: (id: string, selected: boolean) => void;
  onFocus: (id: string) => void;
  onApprove: (entry: TimesheetEntry) => void;
  onReject: (entry: TimesheetEntry) => void;
}) {
  return (
    <div className="overflow-hidden rounded-xl bg-white shadow-[0_2px_10px_rgba(0,0,0,0.05)]">
      <div className="flex justify-end p-1">
        <button type="button" aria-label="More timesheet actions" className="grid h-9 w-9 place-items-center rounded-lg text-[#6B7280]">
          <ChevronDown size={18} />
        </button>
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-[1040px] table-fixed border-collapse text-left text-sm">
          <thead>
            <tr className="border-y border-[#E5E7EB] bg-white text-xs font-semibold text-[#374151]">
              <th className="w-[52px] px-3 py-3">
                <input type="checkbox" aria-label="Select all visible pending timesheets" className="h-4 w-4 accent-[#0386FF]" readOnly />
              </th>
              <th className="px-2 py-3">Teacher</th>
              <th className="w-[110px] px-2 py-3">Date</th>
              <th className="px-2 py-3">Student</th>
              <th className="w-[72px] px-2 py-3 text-center">Hours</th>
              <th className="w-[108px] px-2 py-3 text-center">Audit Month Hours</th>
              <th className="w-[88px] px-2 py-3 text-center">Payment</th>
              <th className="w-[108px] px-2 py-3 text-center">Source</th>
              <th className="w-[100px] px-2 py-3">Status</th>
              <th className="w-[128px] px-2 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {timesheets.map((entry) => (
              <tr key={entry.id} onClick={() => onFocus(entry.id)} className={`border-b border-[#E5E7EB] ${rowColor(entry.status)} ${focusedId === entry.id ? "outline outline-2 outline-[#BFDBFE]" : ""}`}>
                <td className="px-3 py-2 text-center" onClick={(event) => event.stopPropagation()}>
                  <input
                    type="checkbox"
                    aria-label={`Select ${entry.teacherName} timesheet`}
                    checked={selectedIds.has(entry.id)}
                    onChange={(event) => onSelect(entry.id, event.target.checked)}
                    className="h-4 w-4 accent-[#0386FF]"
                  />
                </td>
                <td className="truncate px-2 py-2 font-medium">{entry.teacherName || "-"}</td>
                <td className="truncate px-2 py-2">{entry.dateLabel || "-"}</td>
                <td className="truncate px-2 py-2">{entry.studentName || "-"}</td>
                <td className="px-2 py-2 text-center">{entry.totalHours || "0"}</td>
                <td className="px-2 py-2 text-center text-[#334155]">-</td>
                <td className="px-2 py-2 text-center font-semibold text-[#15803D]">${paymentFor(entry).toFixed(2)}</td>
                <td className="px-2 py-2 text-center">
                  <SourcePill source={entry.source} />
                </td>
                <td className="px-2 py-2">
                  <StatusPill status={entry.status} />
                </td>
                <td className="px-2 py-2" onClick={(event) => event.stopPropagation()}>
                  <div className="flex items-center gap-1">
                    <button type="button" aria-label={`Approve ${entry.teacherName} timesheet`} onClick={() => onApprove(entry)} className="grid h-8 w-8 place-items-center rounded-lg border border-[#BBF7D0] bg-white text-[#16A34A]">
                      <Check size={16} />
                    </button>
                    <button type="button" aria-label={`Reject ${entry.teacherName} timesheet`} onClick={() => onReject(entry)} className="grid h-8 w-8 place-items-center rounded-lg border border-[#FECACA] bg-white text-[#DC2626]">
                      <X size={16} />
                    </button>
                    <button type="button" aria-label={`View ${entry.teacherName} timesheet details`} onClick={() => onFocus(entry.id)} className="grid h-8 w-8 place-items-center rounded-lg border border-[#CBD5E1] bg-white text-[#0386FF]">
                      <Filter size={15} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function TimesheetDetail({
  entry,
  onApprove,
  onReject,
}: {
  entry: TimesheetEntry | null;
  onApprove: (entry: TimesheetEntry) => void;
  onReject: (entry: TimesheetEntry) => void;
}) {
  if (!entry) return null;
  return (
    <aside className="hidden rounded-xl bg-white p-4 shadow-[0_2px_10px_rgba(0,0,0,0.05)] xl:block">
      <div className="flex items-center gap-3">
        <h2 className="flex-1 text-lg font-bold">Timesheet Details</h2>
        <StatusPill status={entry.status} />
      </div>
      <div className="mt-4 space-y-3 text-sm">
        <DetailRow label="Teacher:" value={entry.teacherName || "-"} />
        <DetailRow label="Date:" value={entry.dateLabel || "-"} />
        <DetailRow label="Student:" value={entry.studentName || "-"} />
        <DetailRow label="Hours:" value={entry.totalHours || "0"} />
        <DetailRow label="Rate:" value={`$${entry.hourlyRate.toFixed(2)}`} />
        <DetailRow label="Payment:" value={`$${paymentFor(entry).toFixed(2)}`} />
        <DetailRow label="Start:" value={entry.start || "-"} />
        <DetailRow label="End:" value={entry.end || "-"} />
        <DetailRow label="Source:" value={entry.source || "manual"} />
        <DetailRow label="Shift:" value={entry.shiftTitle || entry.shiftId || "-"} />
      </div>
      <div className="mt-5 grid grid-cols-2 gap-2">
        <button type="button" onClick={() => onApprove(entry)} className="min-h-10 rounded-xl bg-[#16A34A] text-sm font-bold text-white">
          Approve
        </button>
        <button type="button" onClick={() => onReject(entry)} className="min-h-10 rounded-xl bg-[#DC2626] text-sm font-bold text-white">
          Reject
        </button>
      </div>
    </aside>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[120px_1fr] gap-2">
      <span className="text-[#6B7280]">{label}</span>
      <strong className="font-semibold text-[#111827]">{value}</strong>
    </div>
  );
}

function EmptyTimesheets() {
  return (
    <div className="grid min-h-[560px] place-items-center">
      <div className="text-center text-[#9CA3AF]">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-full border-[6px] border-[#BDBDBD] text-[#BDBDBD]">
          <Clock3 size={34} />
        </div>
        <div className="mt-5 text-xl font-bold text-[#737373]">No Timesheets Found</div>
        <div className="mt-1 text-base text-[#A3A3A3]">Try Changing The Filter Or Check</div>
      </div>
    </div>
  );
}

function StatusPill({ status }: { status: TimesheetStatus }) {
  const style =
    status === "approved"
      ? "bg-[#DCFCE7] text-[#15803D]"
      : status === "rejected"
        ? "bg-[#FEE2E2] text-[#B91C1C]"
        : status === "pending"
          ? "bg-[#FFEDD5] text-[#C2410C]"
          : "bg-[#F3F4F6] text-[#4B5563]";
  return <span className={`inline-flex rounded-full px-2 py-1 text-xs font-bold capitalize ${style}`}>{status}</span>;
}

function SourcePill({ source }: { source: string }) {
  const clockIn = source === "clock_in";
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-semibold ${clockIn ? "bg-[#DCFCE7] text-[#15803D]" : "bg-[#DBEAFE] text-[#1D4ED8]"}`}>
      {clockIn ? <Clock3 size={12} /> : <FileDown size={12} />}
      {source || "manual"}
    </span>
  );
}

function TimesheetsAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before reviewing timesheets."
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

async function loadTimesheets() {
  const snap = await getDocs(query(collection(db, "timesheet_entries"), limit(500)));
  return snap.docs
    .map((docSnap) => normalizeTimesheet(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => (b.parsedDate?.getTime() ?? 0) - (a.parsedDate?.getTime() ?? 0));
}

function normalizeTimesheet(id: string, data: Record<string, unknown>): TimesheetEntry {
  const status = parseStatus(stringValue(data.status));
  const dateLabel = dateLabelValue(data.date ?? data.timesheet_date ?? data.timesheetDate ?? data.created_at ?? data.createdAt);
  const parsedDate = parseTimesheetDate(dateLabel) ?? dateValue(data.clock_in_timestamp ?? data.clockInTimestamp ?? data.created_at ?? data.createdAt);
  const totalHours = stringValue(data.total_hours ?? data.totalHours ?? data.hours) || numericHours(data.total_hours ?? data.totalHours ?? data.hours);
  const hourlyRate = numberValue(data.hourly_rate ?? data.hourlyRate, 4);
  return {
    id,
    teacherId: stringValue(data.teacher_id ?? data.teacherId),
    teacherName: stringValue(data.teacher_name ?? data.teacherName) || "Unknown Teacher",
    studentName: stringValue(data.subject ?? data.student_name ?? data.studentName ?? data.student_display_name ?? data.studentDisplayName) || "N/A",
    dateLabel,
    parsedDate,
    start: timeLabel(data.start_time ?? data.startTime ?? data.start ?? data.clock_in_timestamp ?? data.clockInTimestamp),
    end: timeLabel(data.end_time ?? data.endTime ?? data.end ?? data.clock_out_timestamp ?? data.clockOutTimestamp),
    totalHours,
    hourlyRate,
    paymentAmount: numberOrNull(data.payment_amount ?? data.paymentAmount ?? data.total_pay ?? data.totalPay),
    source: stringValue(data.source) || "manual",
    status,
    shiftTitle: stringValue(data.shift_title ?? data.shiftTitle),
    shiftId: stringValue(data.shift_id ?? data.shiftId),
    isEdited: data.is_edited === true || data.isEdited === true,
    editApproved: data.edit_approved === true || data.editApproved === true,
  };
}

function statusCounts(entries: TimesheetEntry[]): Record<StatusFilter, number> {
  return {
    All: entries.length,
    Pending: entries.filter((entry) => entry.status === "pending").length,
    Approved: entries.filter((entry) => entry.status === "approved").length,
    Rejected: entries.filter((entry) => entry.status === "rejected").length,
    Draft: entries.filter((entry) => entry.status === "draft").length,
  };
}

function parseStatus(value: string): TimesheetStatus {
  const normalized = value.toLowerCase();
  if (normalized === "approved" || normalized === "rejected" || normalized === "pending") return normalized;
  return "draft";
}

function entryNeedsAttention(entry: TimesheetEntry) {
  return entry.status === "pending" && (!entry.end || entry.end === "N/A" || !entry.totalHours || entry.totalHours === "0");
}

function paymentFor(entry: TimesheetEntry) {
  if (entry.paymentAmount != null) return entry.paymentAmount;
  return hoursToNumber(entry.totalHours) * entry.hourlyRate;
}

function selectedTotal(entries: TimesheetEntry[], selectedIds: Set<string>) {
  return entries.filter((entry) => selectedIds.has(entry.id)).reduce((sum, entry) => sum + paymentFor(entry), 0);
}

function rowColor(status: TimesheetStatus) {
  if (status === "approved") return "bg-[#F0FDF4]";
  if (status === "rejected") return "bg-[#FEF2F2]";
  if (status === "pending") return "bg-[#FFF7ED]";
  return "bg-[#F9FAFB]";
}

function presetDateRange(preset: DatePreset): DateRange {
  const today = new Date();
  const start = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (preset === "thisWeek") {
    const monday = new Date(start);
    monday.setDate(start.getDate() - ((start.getDay() || 7) - 1));
    return { start: monday, end: addDays(monday, 6) };
  }
  if (preset === "lastWeek") {
    const monday = new Date(start);
    monday.setDate(start.getDate() - ((start.getDay() || 7) - 1) - 7);
    return { start: monday, end: addDays(monday, 6) };
  }
  return { start: new Date(start.getFullYear(), start.getMonth(), 1), end: new Date(start.getFullYear(), start.getMonth() + 1, 0) };
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function endOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999);
}

function dateRangeSummary(range: DateRange) {
  return `${formatShortDate(range.start)}-${formatShortDate(range.end)}`;
}

function formatShortDate(date: Date) {
  return date.toLocaleDateString("en-US", { month: "short", day: "2-digit" });
}

function dateLabelValue(value: unknown) {
  if (value instanceof Timestamp) return value.toDate().toISOString().slice(0, 10);
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === "string" && value.trim()) return value.trim();
  return new Date().toISOString().slice(0, 10);
}

function parseTimesheetDate(value: string): Date | null {
  const direct = new Date(value);
  if (!Number.isNaN(direct.getTime())) return new Date(direct.getFullYear(), direct.getMonth(), direct.getDate());
  const monthDay = value.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?$/);
  if (monthDay) {
    const year = monthDay[3] ? Number(monthDay[3]) : new Date().getFullYear();
    return new Date(year, Number(monthDay[1]) - 1, Number(monthDay[2]));
  }
  return null;
}

function dateValue(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (value && typeof value === "object" && "toDate" in value && typeof value.toDate === "function") {
    const parsed = value.toDate();
    return parsed instanceof Date && !Number.isNaN(parsed.getTime()) ? parsed : null;
  }
  return null;
}

function timeLabel(value: unknown) {
  const parsed = dateValue(value);
  if (parsed) return parsed.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  return stringValue(value) || "N/A";
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown, fallback: number) {
  return numberOrNull(value) ?? fallback;
}

function numberOrNull(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() && !Number.isNaN(Number(value))) return Number(value);
  return null;
}

function numericHours(value: unknown) {
  const n = numberOrNull(value);
  return n == null ? "0" : String(n);
}

function hoursToNumber(value: string) {
  const normalized = value.trim();
  if (!normalized) return 0;
  if (/^\d+(\.\d+)?$/.test(normalized)) return Number(normalized);
  const parts = normalized.split(":").map(Number);
  if (parts.length >= 2 && parts.every((part) => Number.isFinite(part))) {
    return parts[0] + parts[1] / 60 + (parts[2] ?? 0) / 3600;
  }
  return 0;
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
