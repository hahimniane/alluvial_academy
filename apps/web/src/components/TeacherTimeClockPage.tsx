"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, doc, getDocs, limit, query, runTransaction, serverTimestamp, Timestamp, updateDoc, where } from "firebase/firestore";
import { type ReactNode, useEffect, useMemo, useState } from "react";
import { AlertTriangle, CalendarDays, Clock3, Download, Eye, LogIn, LogOut, MapPin, Menu, Pencil, Send, Shuffle, TimerReset, X } from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserRecord = Record<string, unknown>;

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type TimeFilter = "All Time" | "This Month" | "This Week";
type StatusFilter = "All" | "Draft" | "Pending" | "Approved" | "Rejected";

type TimesheetEntry = {
  id: string;
  date: string;
  parsedDate: Date | null;
  student: string;
  start: string;
  end: string;
  totalHours: string;
  clockInLocation: string;
  clockOutLocation: string;
  status: string;
  description: string;
  employeeNotes: string;
  hourlyRate: number;
  paymentAmount: number;
  clockInTimestamp: Date | null;
  clockOutTimestamp: Date | null;
};

type TeacherShift = {
  id: string;
  title: string;
  studentNames: string[];
  start: Date | null;
  end: Date | null;
  status: string;
  subject: string;
  category: string;
  leaderRole: string;
  teacherName: string;
  hourlyRate: number;
  clockInTime: Date | null;
  clockOutTime: Date | null;
};

const timeFilters: TimeFilter[] = ["All Time", "This Month", "This Week"];
const mobileTimeFilters = ["Today", "This Week", "This Month", "All Time"] as const;
const statusFilters: StatusFilter[] = ["All", "Draft", "Pending", "Approved", "Rejected"];

export function TeacherTimeClockPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [entries, setEntries] = useState<TimesheetEntry[]>([]);
  const [shifts, setShifts] = useState<TeacherShift[]>([]);
  const [timeFilter, setTimeFilter] = useState<TimeFilter>("All Time");
  const [mobileTimeFilter, setMobileTimeFilter] = useState<(typeof mobileTimeFilters)[number]>("All Time");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("All");
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [clockBusy, setClockBusy] = useState(false);
  const [submittingDrafts, setSubmittingDrafts] = useState(false);
  const [submittingEntryId, setSubmittingEntryId] = useState("");
  const [viewingEntry, setViewingEntry] = useState<TimesheetEntry | null>(null);
  const [editingEntry, setEditingEntry] = useState<TimesheetEntry | null>(null);
  const [submitEntry, setSubmitEntry] = useState<TimesheetEntry | null>(null);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      if (!nextUser) {
        setCurrentUser(null);
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setCurrentUser(nextUser);
      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserTeacher(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        const userRecord = await getCurrentUserRecord(nextUser);
        if (!mounted) return;
        setSummary(summaryForUser(nextUser, userRecord));
        setAccess("allowed");
        const [loadedEntries, loadedShifts] = await Promise.all([
          loadTeacherTimesheets(nextUser.uid),
          loadTeacherShifts(nextUser.uid).catch(() => []),
        ]);
        if (mounted) {
          setEntries(loadedEntries);
          setShifts(loadedShifts);
        }
      } catch {
        if (mounted) setEntries([]);
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const visibleEntries = useMemo(() => filterEntries(entries, timeFilter), [entries, timeFilter]);
  const visibleMobileEntries = useMemo(() => filterByStatus(filterEntries(entries, mobileTimeFilter), statusFilter), [entries, mobileTimeFilter, statusFilter]);
  const draftEntries = useMemo(() => entries.filter((entry) => entry.status.toLowerCase() === "draft"), [entries]);
  const activeShift = useMemo(() => findTimeClockShift(shifts), [shifts]);

  const showNotice = (message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(""), 3500);
  };

  const refreshData = async (user = currentUser) => {
    if (!user) return;
    const [loadedEntries, loadedShifts] = await Promise.all([
      loadTeacherTimesheets(user.uid),
      loadTeacherShifts(user.uid).catch(() => []),
    ]);
    setEntries(loadedEntries);
    setShifts(loadedShifts);
  };

  const handleClockAction = async () => {
    if (!currentUser || !activeShift || clockBusy) return;
    setClockBusy(true);
    try {
      const action = clockAction(activeShift);
      if (action.kind === "disabled") {
        showNotice(action.disabledMessage);
        return;
      }
      const location = await getBrowserLocation();
      const result = action.kind === "clockOut"
        ? await clockOutOfShift(currentUser, activeShift, location)
        : await clockInToShift(currentUser, activeShift, location);
      showNotice(result.message);
      await refreshData(currentUser);
    } catch (error) {
      showNotice(error instanceof Error ? error.message : "Could not update the clock.");
    } finally {
      setClockBusy(false);
    }
  };

  const submitDraftEntry = async (entry: TimesheetEntry) => {
    if (submittingEntryId) return;
    setSubmittingEntryId(entry.id);
    try {
      await submitDraftEntries([entry]);
      setEntries((current) => current.map((item) => item.id === entry.id ? { ...item, status: "pending" } : item));
      setSubmitEntry(null);
      showNotice("Timesheet submitted for review");
    } catch (error) {
      showNotice(writeFailureMessage(error, "Could not submit the timesheet."));
    } finally {
      setSubmittingEntryId("");
    }
  };

  const saveEditedEntry = async (entry: TimesheetEntry, values: TimesheetEditValues) => {
    const clockIn = mergeEntryDateAndTime(entry, values.start);
    const clockOut = mergeEntryDateAndTime(entry, values.end, clockIn);
    const totalMs = clockIn && clockOut ? Math.max(0, clockOut.getTime() - clockIn.getTime()) : durationMsFromLabel(values.totalHours);
    const totalHours = formatDurationHms(totalMs);
    const paymentAmount = (totalMs / 36e5) * entry.hourlyRate;
    const updateData: Record<string, unknown> = {
      start_time: values.start,
      end_time: values.end,
      total_hours: totalHours,
      employee_notes: values.employeeNotes.trim(),
      payment_amount: paymentAmount,
      total_pay: paymentAmount,
      edited_at: serverTimestamp(),
      edited_by: currentUser?.uid ?? null,
      is_edited: true,
      edit_approved: false,
      updated_at: serverTimestamp(),
    };
    if (clockIn) updateData.clock_in_timestamp = Timestamp.fromDate(clockIn);
    if (clockOut) {
      updateData.clock_out_timestamp = Timestamp.fromDate(clockOut);
      updateData.effective_end_timestamp = Timestamp.fromDate(clockOut);
    }

    await updateDoc(doc(db, "timesheet_entries", entry.id), updateData);
    setEntries((current) =>
      current.map((item) =>
        item.id === entry.id
          ? {
              ...item,
              start: values.start,
              end: values.end,
              totalHours,
              employeeNotes: values.employeeNotes.trim(),
              paymentAmount,
              clockInTimestamp: clockIn,
              clockOutTimestamp: clockOut,
            }
          : item,
      ),
    );
    setEditingEntry(null);
    showNotice("Timesheet updated successfully");
  };

  const submitAllDrafts = async () => {
    if (!draftEntries.length || submittingDrafts) return;
    const confirmed = window.confirm(`Submit ${draftEntries.length} draft entr${draftEntries.length === 1 ? "y" : "ies"} for review?`);
    if (!confirmed) return;
    setSubmittingDrafts(true);
    try {
      await submitDraftEntries(draftEntries);
      setEntries((current) => current.map((entry) => entry.status.toLowerCase() === "draft" ? { ...entry, status: "pending" } : entry));
      showNotice(`Submitted ${draftEntries.length} entr${draftEntries.length === 1 ? "y" : "ies"} for review`);
    } catch (error) {
      showNotice(writeFailureMessage(error, "Could not submit draft timesheets."));
    } finally {
      setSubmittingDrafts(false);
    }
  };

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Time Clock" breadcrumb="Work / Time Clock" summary={summary}>
      <main className="min-h-[calc(100vh-56px)] overflow-y-auto bg-[#F8FAFC] text-[#111827]">
        <MobileTeacherTopBar summary={summary} />
        <section className="pb-20 lg:pt-[52px]">
          {notice ? <NoticeBanner message={notice} /> : null}
          <ClockStatusPanel shift={activeShift} busy={clockBusy} onClockAction={handleClockAction} />
          <div className="hidden min-h-[calc(100vh-150px)] rounded-lg bg-white shadow-[0_2px_4px_rgba(0,0,0,0.10)] lg:flex lg:flex-col">
            <TimesheetToolbar
              timeFilter={timeFilter}
              onTimeFilterChange={setTimeFilter}
              draftCount={draftEntries.length}
              submittingDrafts={submittingDrafts}
              onSubmitDrafts={submitAllDrafts}
              onExport={() => exportCsv(visibleEntries)}
            />
            <TimesheetTable
              entries={visibleEntries}
              loading={loading}
              onEditEntry={setEditingEntry}
              onSubmitEntry={setSubmitEntry}
              onViewEntry={setViewingEntry}
            />
          </div>
          <div className="lg:hidden">
            <MobileTimesheetHeader
              timeFilter={mobileTimeFilter}
              statusFilter={statusFilter}
              onTimeFilterChange={setMobileTimeFilter}
              onStatusFilterChange={setStatusFilter}
            />
            <MobileTimesheetCards
              entries={visibleMobileEntries}
              loading={loading}
              onEditEntry={setEditingEntry}
              onSubmitEntry={setSubmitEntry}
              onViewEntry={setViewingEntry}
            />
          </div>
          {viewingEntry ? <TimesheetDetailsDialog entry={viewingEntry} onClose={() => setViewingEntry(null)} /> : null}
          {editingEntry ? (
            <TimesheetEditDialog
              entry={editingEntry}
              onClose={() => setEditingEntry(null)}
              onSave={(values) => saveEditedEntry(editingEntry, values)}
            />
          ) : null}
          {submitEntry ? (
            <SubmitTimesheetDialog
              entry={submitEntry}
              submitting={submittingEntryId === submitEntry.id}
              onClose={() => setSubmitEntry(null)}
              onConfirm={() => submitDraftEntry(submitEntry)}
            />
          ) : null}
        </section>
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-[68px] grid-cols-[56px_1fr_96px] items-center bg-white px-4 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={28} />
      </button>
      <div className="min-w-0 text-center text-[20px] font-black text-[#111827]">Alluwal Academy</div>
      <div className="flex items-center justify-end gap-3">
        <Shuffle size={24} className="text-[#111827]" />
        <span className="grid h-11 w-11 place-items-center rounded-full bg-[#009688] text-base font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function NoticeBanner({ message }: { message: string }) {
  return (
    <div className="mx-3 mt-3 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8] lg:mx-4">
      {message}
    </div>
  );
}

function ClockStatusPanel({ shift, busy, onClockAction }: { shift: TeacherShift | null; busy: boolean; onClockAction: () => void }) {
  if (!shift) return null;
  const visual = shiftStatusVisual(shift);
  const action = clockAction(shift);
  const actionStyle =
    action.kind === "clockOut"
      ? "bg-[#EF4444] hover:bg-[#DC2626]"
      : action.kind === "clockIn"
        ? "bg-[#10B981] hover:bg-[#059669]"
        : "bg-[#3B82F6] hover:bg-[#2563EB]";
  return (
    <div className="bg-white shadow-[0_2px_8px_rgba(15,23,42,0.06)]">
      <div className="p-3 lg:p-4">
        <div
          className="rounded-xl border p-4"
          style={{ backgroundColor: visual.background, borderColor: visual.border }}
        >
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
            <div className="flex min-w-0 flex-1 items-center gap-3">
              <div className="grid h-12 w-12 shrink-0 place-items-center rounded-xl" style={{ backgroundColor: visual.iconBackground, color: visual.accent }}>
                {action.kind === "clockOut" ? <LogOut size={24} /> : <Clock3 size={24} />}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-[11px] font-bold uppercase tracking-[0.05em]" style={{ color: visual.accent }}>
                    {visual.label}
                  </span>
                  <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: visual.accent }} />
                </div>
                <div className="truncate text-sm font-semibold text-[#1E293B]">{shift.title}</div>
                <div className="mt-0.5 text-[12px] font-medium text-[#64748B]">
                  {formatTimeRange(shift.start, shift.end)}{shift.studentNames.length ? ` · ${shift.studentNames.join(", ")}` : ""}
                </div>
              </div>
            </div>
            <button
              type="button"
              onClick={onClockAction}
              disabled={busy || action.kind === "disabled"}
              className={`inline-flex h-12 items-center justify-center gap-2 rounded-2xl px-5 text-sm font-bold text-white shadow-md transition disabled:cursor-not-allowed disabled:bg-[#CBD5E1] ${actionStyle}`}
            >
              {action.kind === "clockOut" ? <LogOut size={18} /> : <LogIn size={18} />}
              {busy ? "Processing..." : action.label}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function TimesheetToolbar({
  timeFilter,
  onTimeFilterChange,
  draftCount,
  submittingDrafts,
  onSubmitDrafts,
  onExport,
}: {
  timeFilter: TimeFilter;
  onTimeFilterChange: (value: TimeFilter) => void;
  draftCount: number;
  submittingDrafts: boolean;
  onSubmitDrafts: () => void;
  onExport: () => void;
}) {
  return (
    <div className="flex items-center justify-between gap-4 px-4 py-4">
      <h1 className="text-[18px] font-bold text-[#263238]">My Timesheet</h1>
      <div className="flex items-center gap-2">
        <label className="sr-only" htmlFor="teacher-time-filter">
          Timesheet range
        </label>
        <select
          id="teacher-time-filter"
          value={timeFilter}
          onChange={(event) => onTimeFilterChange(event.target.value as TimeFilter)}
          className="h-10 rounded-lg border border-[#E5E7EB] bg-white px-3 text-sm font-medium text-[#263238] outline-none"
        >
          {timeFilters.map((filter) => (
            <option key={filter} value={filter}>
              {filter}
            </option>
          ))}
        </select>
        <button
          type="button"
          onClick={onExport}
          className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#F3F4F6] px-4 text-sm font-semibold text-[#111827]"
        >
          <Download size={16} />
          Export
        </button>
        {draftCount ? (
          <button
            type="button"
            onClick={onSubmitDrafts}
            disabled={submittingDrafts}
            className="inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-[#10B981] px-4 text-sm font-semibold text-white disabled:bg-[#94A3B8]"
          >
            <Send size={16} />
            {submittingDrafts ? "Submitting..." : `Submit Drafts (${draftCount})`}
          </button>
        ) : null}
      </div>
    </div>
  );
}

function TimesheetTable({
  entries,
  loading,
  onEditEntry,
  onSubmitEntry,
  onViewEntry,
}: {
  entries: TimesheetEntry[];
  loading: boolean;
  onEditEntry: (entry: TimesheetEntry) => void;
  onSubmitEntry: (entry: TimesheetEntry) => void;
  onViewEntry: (entry: TimesheetEntry) => void;
}) {
  const columns = [
    "Date",
    "Student",
    "Start",
    "End",
    "Total Hours",
    "Clock-in Location",
    "Clock-out Location",
    "Status",
    "Actions",
  ];

  return (
    <div className="min-h-0 flex-1 overflow-x-auto">
      <table className="min-w-[1180px] table-fixed border-collapse text-left">
        <thead>
          <tr className="bg-[#E3F2FD]">
            {columns.map((column) => (
              <th key={column} className="border-r border-[#D7E5F0] px-2 py-4 text-center text-sm font-semibold text-[#263238] last:border-r-0">
                <span className="inline-flex items-center justify-center gap-2">
                  <span className="text-xl leading-none text-[#263238]">↕</span>
                  <span>{column}</span>
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td className="px-4 py-8 text-sm font-semibold text-[#64748B]" colSpan={columns.length}>
                Loading timesheet...
              </td>
            </tr>
          ) : entries.length ? (
            entries.map((entry) => (
              <tr key={entry.id} className="border-b border-[#EEF2F7]">
                <td className="px-3 py-3 text-sm">{entry.date || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.student || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.start || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.end || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.totalHours || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.clockInLocation || "-"}</td>
                <td className="px-3 py-3 text-sm">{entry.clockOutLocation || "-"}</td>
                <td className="px-3 py-3 text-sm capitalize">{entry.status || "-"}</td>
                <td className="px-3 py-3 text-sm">
                  <div className="flex items-center justify-center gap-2">
                    {entry.status.toLowerCase() === "draft" ? (
                      <>
                        <button
                          type="button"
                          onClick={() => onEditEntry(entry)}
                          className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold text-[#0386FF]"
                        >
                          <Pencil size={14} />
                          Edit
                        </button>
                        <button
                          type="button"
                          onClick={() => onSubmitEntry(entry)}
                          className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold text-[#10B981]"
                        >
                          <Send size={14} />
                          Submit
                        </button>
                      </>
                    ) : (
                      <button
                        type="button"
                        onClick={() => onViewEntry(entry)}
                        className="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-semibold text-[#6B7280]"
                      >
                        <Eye size={14} />
                        View
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))
          ) : (
            <tr>
              <td className="px-4 py-20 text-center text-sm font-semibold text-[#64748B]" colSpan={columns.length}>
                No timesheet entries found.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

function MobileTimesheetHeader({
  timeFilter,
  statusFilter,
  onTimeFilterChange,
  onStatusFilterChange,
}: {
  timeFilter: (typeof mobileTimeFilters)[number];
  statusFilter: StatusFilter;
  onTimeFilterChange: (value: (typeof mobileTimeFilters)[number]) => void;
  onStatusFilterChange: (value: StatusFilter) => void;
}) {
  return (
    <div className="bg-white px-4 py-3 shadow-[0_2px_8px_rgba(0,0,0,0.05)]">
      <div className="flex items-center gap-3">
        <h1 className="min-w-0 flex-1 text-[18px] font-bold text-[#111827]">Timesheet</h1>
        <label className="sr-only" htmlFor="teacher-mobile-status-filter">
          Timesheet status
        </label>
        <select
          id="teacher-mobile-status-filter"
          value={statusFilter}
          onChange={(event) => onStatusFilterChange(event.target.value as StatusFilter)}
          className="h-9 rounded-lg border border-transparent bg-[#F3F4F6] px-3 text-[13px] font-semibold text-[#374151] outline-none"
        >
          {statusFilters.map((filter) => (
            <option key={filter} value={filter}>
              {filter}
            </option>
          ))}
        </select>
      </div>
      <div className="mt-3 flex gap-2 overflow-x-auto pb-1">
        {mobileTimeFilters.map((filter) => {
          const selected = timeFilter === filter;
          return (
            <button
              key={filter}
              type="button"
              onClick={() => onTimeFilterChange(filter)}
              className={`shrink-0 rounded-full px-3 py-2 text-xs font-semibold ${selected ? "bg-[#0386FF] text-white" : "bg-[#F3F4F6] text-[#6B7280]"}`}
            >
              {filter}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function MobileTimesheetCards({
  entries,
  loading,
  onEditEntry,
  onSubmitEntry,
  onViewEntry,
}: {
  entries: TimesheetEntry[];
  loading: boolean;
  onEditEntry: (entry: TimesheetEntry) => void;
  onSubmitEntry: (entry: TimesheetEntry) => void;
  onViewEntry: (entry: TimesheetEntry) => void;
}) {
  if (loading) {
    return <div className="grid min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">Loading timesheet...</div>;
  }
  if (!entries.length) {
    return (
      <div className="grid min-h-[440px] place-items-center px-6 text-center">
        <div>
          <div className="mx-auto grid h-20 w-20 place-items-center rounded-full bg-[#F3F4F6] text-[#9CA3AF]">
            <TimerReset size={40} />
          </div>
          <h2 className="mt-4 text-base font-semibold text-[#6B7280]">No timesheet entries found</h2>
          <p className="mt-2 text-sm text-[#9CA3AF]">Clock in to create your first entry</p>
        </div>
      </div>
    );
  }
  return (
    <div className="space-y-3 px-4 py-4">
      {entries.map((entry) => (
        <article key={entry.id} className="overflow-hidden rounded-xl bg-white shadow-[0_2px_8px_rgba(0,0,0,0.05)]">
          <button type="button" onClick={() => onViewEntry(entry)} className="block w-full p-4 text-left">
            <div className="flex items-center justify-between gap-3">
              <div className="flex min-w-0 items-center gap-2">
                <CalendarDays size={16} className="shrink-0 text-[#6B7280]" />
                <span className="truncate text-sm font-semibold text-[#111827]">{entry.date || "-"}</span>
              </div>
              <StatusBadge status={entry.status} />
            </div>
            <div className="mt-3 truncate text-base font-semibold text-[#111827]">{entry.student || "-"}</div>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <InfoRow icon={<LogIn size={16} />} label="Clock In" value={entry.start || "-"} />
              <InfoRow icon={<LogOut size={16} />} label="Clock Out" value={entry.end || "-"} />
            </div>
            <div className="mt-2">
              <InfoRow icon={<Clock3 size={16} />} label="Total" value={entry.totalHours || "-"} />
            </div>
            {entry.clockInLocation ? (
              <div className="mt-2">
                <InfoRow icon={<MapPin size={16} />} label="Location" value={entry.clockInLocation} />
              </div>
            ) : null}
          </button>
          {entry.status.toLowerCase() === "draft" ? (
            <div className="flex justify-end gap-2 border-t border-[#EEF2F7] p-3">
              <button type="button" onClick={() => onEditEntry(entry)} className="inline-flex items-center gap-1 px-3 py-2 text-sm font-semibold text-[#0386FF]">
                <Pencil size={17} />
                Edit
              </button>
              <button
                type="button"
                onClick={() => onSubmitEntry(entry)}
                className="inline-flex items-center gap-1 px-3 py-2 text-sm font-semibold text-[#10B981]"
              >
                <Send size={17} />
                Submit
              </button>
            </div>
          ) : (
            <div className="flex justify-end border-t border-[#EEF2F7] p-3">
              <button type="button" onClick={() => onViewEntry(entry)} className="inline-flex items-center gap-1 px-3 py-2 text-sm font-semibold text-[#6B7280]">
                <Eye size={17} />
                View
              </button>
            </div>
          )}
        </article>
      ))}
    </div>
  );
}

type TimesheetEditValues = {
  start: string;
  end: string;
  totalHours: string;
  employeeNotes: string;
};

function TimesheetDetailsDialog({ entry, onClose }: { entry: TimesheetEntry; onClose: () => void }) {
  return (
    <DialogFrame title="Timesheet Details" icon={<Eye size={20} />} onClose={onClose}>
      <div className="space-y-2">
        <DetailRow label="Date" value={entry.date || "-"} />
        <DetailRow label="Student" value={entry.student || "-"} />
        <DetailRow label="Start Time" value={entry.start || "-"} />
        <DetailRow label="End Time" value={entry.end || "-"} />
        <DetailRow label="Total Hours" value={entry.totalHours || "-"} />
        <DetailRow label="Status" value={capitalize(entry.status || "draft")} />
        {entry.description ? <DetailRow label="Description" value={entry.description} /> : null}
        {entry.employeeNotes ? <DetailRow label="Notes" value={entry.employeeNotes} /> : null}
      </div>
      {(entry.clockInLocation || entry.clockOutLocation) ? (
        <div className="mt-4 rounded-xl border border-[#A7F3D0] bg-[#ECFDF5] p-4">
          <div className="mb-3 flex items-center gap-2 text-sm font-bold text-[#047857]">
            <MapPin size={16} />
            Location Information
          </div>
          {entry.clockInLocation ? <DetailRow label="Clock In" value={entry.clockInLocation} /> : null}
          {entry.clockOutLocation ? <DetailRow label="Clock Out" value={entry.clockOutLocation} /> : null}
        </div>
      ) : null}
      <div className="mt-5 flex justify-end">
        <button type="button" onClick={onClose} className="rounded-lg bg-[#F3F4F6] px-4 py-2 text-sm font-semibold text-[#374151]">
          Close
        </button>
      </div>
    </DialogFrame>
  );
}

function TimesheetEditDialog({
  entry,
  onClose,
  onSave,
}: {
  entry: TimesheetEntry;
  onClose: () => void;
  onSave: (values: TimesheetEditValues) => Promise<void>;
}) {
  const [start, setStart] = useState(toTimeInput(entry.start));
  const [end, setEnd] = useState(toTimeInput(entry.end));
  const [employeeNotes, setEmployeeNotes] = useState(entry.employeeNotes);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const displayStart = fromTimeInput(start);
  const displayEnd = fromTimeInput(end);
  const totalMs = previewDurationMs(entry, displayStart, displayEnd);
  const totalHours = formatDurationHms(totalMs);
  const pay = (totalMs / 36e5) * entry.hourlyRate;

  const handleSave = async () => {
    if (!displayStart || !displayEnd || totalMs <= 0) {
      setError("Clock out time must be after clock in time.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await onSave({ start: displayStart, end: displayEnd, totalHours, employeeNotes });
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Error updating timesheet.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <DialogFrame title="Edit Timesheet" icon={<Pencil size={20} />} onClose={onClose}>
      <div className="rounded-lg border border-[#FCD34D] bg-[#FEF3C7] p-3 text-[13px] text-[#92400E]">
        Edits update the timesheet and may need admin review before payment is finalized.
      </div>
      <div className="mt-4 rounded-xl border border-[#E2E8F0] bg-[#F8FAFC] p-4">
        <DetailRow label="Date" value={entry.date || "-"} />
        <DetailRow label="Student" value={entry.student || "-"} />
      </div>
      <label className="mt-4 block text-sm font-semibold text-[#64748B]" htmlFor="timesheet-start-time">
        Clock In Time
      </label>
      <input
        id="timesheet-start-time"
        type="time"
        value={start}
        onChange={(event) => setStart(event.target.value)}
        className="mt-2 h-12 w-full rounded-xl border border-[#E2E8F0] px-4 text-base font-semibold text-[#1E293B] outline-none focus:border-[#0386FF]"
      />
      <label className="mt-4 block text-sm font-semibold text-[#64748B]" htmlFor="timesheet-end-time">
        Clock Out Time
      </label>
      <input
        id="timesheet-end-time"
        type="time"
        value={end}
        onChange={(event) => setEnd(event.target.value)}
        className="mt-2 h-12 w-full rounded-xl border border-[#E2E8F0] px-4 text-base font-semibold text-[#1E293B] outline-none focus:border-[#0386FF]"
      />
      <div className="mt-4 rounded-xl border border-[#BBF7D0] bg-[#F0FDF4] p-4">
        <DetailRow label="Total Hours" value={`${totalHours} (${Math.floor(totalMs / 36e5)}h ${Math.floor((totalMs % 36e5) / 60000)}m)`} />
        <DetailRow label="Payment" value={`$${pay.toFixed(2)}`} />
      </div>
      <label className="mt-4 block text-sm font-semibold text-[#64748B]" htmlFor="timesheet-notes">
        Notes
      </label>
      <textarea
        id="timesheet-notes"
        value={employeeNotes}
        onChange={(event) => setEmployeeNotes(event.target.value)}
        rows={3}
        className="mt-2 w-full resize-none rounded-xl border border-[#E2E8F0] px-4 py-3 text-sm text-[#1E293B] outline-none focus:border-[#0386FF]"
      />
      {error ? <div className="mt-3 rounded-lg bg-[#FEE2E2] px-3 py-2 text-sm font-semibold text-[#B91C1C]">{error}</div> : null}
      <div className="mt-5 flex justify-end gap-2">
        <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#64748B]">
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="rounded-lg bg-[#0386FF] px-4 py-2 text-sm font-semibold text-white disabled:bg-[#94A3B8]"
        >
          {saving ? "Saving..." : "Save Changes"}
        </button>
      </div>
    </DialogFrame>
  );
}

function SubmitTimesheetDialog({ entry, submitting, onClose, onConfirm }: { entry: TimesheetEntry; submitting: boolean; onClose: () => void; onConfirm: () => void }) {
  return (
    <DialogFrame title="Submit for Review" icon={<Send size={20} />} onClose={onClose}>
      <p className="text-sm text-[#374151]">Submit this timesheet for admin review?</p>
      <div className="mt-4 rounded-xl bg-[#F3F4F6] p-4">
        <DetailRow label="Date" value={entry.date || "-"} />
        <DetailRow label="Student" value={entry.student || "-"} />
        <DetailRow label="Hours" value={entry.totalHours || "-"} />
      </div>
      <div className="mt-4 flex gap-2 rounded-xl border border-[#FCD34D] bg-[#FEF3C7] p-3 text-xs font-medium text-[#92400E]">
        <AlertTriangle size={16} className="shrink-0" />
        Once submitted, this entry moves to pending review.
      </div>
      <div className="mt-5 flex justify-end gap-2">
        <button type="button" onClick={onClose} disabled={submitting} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#64748B] disabled:opacity-60">
          Cancel
        </button>
        <button type="button" onClick={onConfirm} disabled={submitting} className="rounded-lg bg-[#10B981] px-4 py-2 text-sm font-semibold text-white disabled:bg-[#94A3B8]">
          {submitting ? "Submitting..." : "Submit for Review"}
        </button>
      </div>
    </DialogFrame>
  );
}

async function submitDraftEntries(entries: TimesheetEntry[]) {
  if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
  await runTransaction(db, async (transaction) => {
    const refs = entries.map((entry) => doc(db, "timesheet_entries", entry.id));
    const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
    snapshots.forEach((snapshot) => {
      if (!snapshot.exists()) throw new Error("A draft timesheet is no longer available. Refresh and try again.");
      if (stringValue(snapshot.data().status).toLowerCase() !== "draft") {
        throw new Error("This timesheet has already been submitted. Refresh to see its current status.");
      }
    });
    refs.forEach((ref) => {
      transaction.update(ref, {
        status: "pending",
        submitted_at: serverTimestamp(),
        updated_at: serverTimestamp(),
      });
    });
  });
}

function writeFailureMessage(error: unknown, fallback: string) {
  const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
  if (!navigator.onLine || code.includes("unavailable") || code.includes("network")) {
    return "You appear to be offline. Reconnect and try again.";
  }
  if (code.includes("permission-denied")) return "You do not have permission to update this timesheet.";
  return error instanceof Error && error.message ? error.message : fallback;
}

function DialogFrame({ title, icon, onClose, children }: { title: string; icon: ReactNode; onClose: () => void; children: ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/35 px-0 sm:items-center sm:px-4" role="dialog" aria-modal="true" aria-labelledby="timesheet-dialog-title">
      <div className="max-h-[90vh] w-full overflow-y-auto rounded-t-2xl bg-white p-5 shadow-2xl sm:max-w-[520px] sm:rounded-2xl sm:p-6">
        <div className="mb-5 flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-lg bg-[#E0F2FE] text-[#0386FF]">{icon}</div>
          <h2 id="timesheet-dialog-title" className="min-w-0 flex-1 text-xl font-bold text-[#1E293B]">
            {title}
          </h2>
          <button type="button" aria-label="Close" onClick={onClose} className="grid h-10 w-10 place-items-center rounded-lg text-[#64748B] hover:bg-[#F3F4F6]">
            <X size={20} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[112px_1fr] gap-3 py-1.5 text-sm">
      <span className="font-medium text-[#64748B]">{label}:</span>
      <span className="min-w-0 break-words font-semibold text-[#1E293B]">{value}</span>
    </div>
  );
}

function InfoRow({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex min-w-0 items-center gap-2">
      <span className="shrink-0 text-[#6B7280]">{icon}</span>
      <span className="min-w-0">
        <span className="block text-[11px] font-medium text-[#6B7280]">{label}</span>
        <span className="block truncate text-[13px] font-semibold text-[#374151]">{value}</span>
      </span>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const color = statusColor(status);
  return (
    <span className="shrink-0 rounded-md px-2.5 py-1 text-xs font-semibold capitalize" style={{ backgroundColor: `${color}1A`, color }}>
      {status || "draft"}
    </span>
  );
}

async function loadTeacherTimesheets(uid: string) {
  const snap = await getDocs(query(collection(db, "timesheet_entries"), where("teacher_id", "==", uid), limit(200)));
  return snap.docs
    .map((entry) => normalizeTimesheet(entry.id, entry.data() as Record<string, unknown>))
    .sort((a, b) => (b.parsedDate?.getTime() ?? 0) - (a.parsedDate?.getTime() ?? 0));
}

async function loadTeacherShifts(uid: string) {
  const queries = [
    query(collection(db, "teaching_shifts"), where("teacher_id", "==", uid), limit(100)),
    query(collection(db, "teaching_shifts"), where("teacherId", "==", uid), limit(100)),
  ];
  const results = await Promise.allSettled(queries.map((nextQuery) => getDocs(nextQuery)));
  const byId = new Map<string, TeacherShift>();
  results.forEach((result) => {
    if (result.status !== "fulfilled") return;
    result.value.docs.forEach((docSnap) => {
      byId.set(docSnap.id, normalizeShift(docSnap.id, docSnap.data() as Record<string, unknown>));
    });
  });
  return Array.from(byId.values()).sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0));
}

function normalizeTimesheet(id: string, data: Record<string, unknown>): TimesheetEntry {
  const parsedDate = dateValue(data.clock_in_timestamp ?? data.clockInTimestamp ?? data.date ?? data.created_at ?? data.createdAt);
  const clockInTimestamp = dateValue(data.clock_in_timestamp ?? data.clockInTimestamp);
  const clockOutTimestamp = dateValue(data.clock_out_timestamp ?? data.clockOutTimestamp);
  return {
    id,
    date: stringValue(data.date) || (parsedDate ? formatDate(parsedDate) : ""),
    parsedDate,
    student: stringValue(data.student_name ?? data.studentName ?? data.subject),
    start: stringValue(data.start_time ?? data.startTime) || formatTime(clockInTimestamp),
    end: stringValue(data.end_time ?? data.endTime) || formatTime(clockOutTimestamp),
    totalHours: stringValue(data.total_hours ?? data.totalHours) || hoursLabel(data.total_hours ?? data.totalHours ?? data.hours),
    clockInLocation: stringValue(data.clock_in_address ?? data.clockInAddress),
    clockOutLocation: stringValue(data.clock_out_address ?? data.clockOutAddress),
    status: stringValue(data.status) || "draft",
    description: stringValue(data.description),
    employeeNotes: stringValue(data.employee_notes ?? data.employeeNotes),
    hourlyRate: numberValue(data.hourly_rate ?? data.hourlyRate),
    paymentAmount: numberValue(data.payment_amount ?? data.paymentAmount ?? data.total_pay ?? data.totalPay),
    clockInTimestamp,
    clockOutTimestamp,
  };
}

function normalizeShift(id: string, data: Record<string, unknown>): TeacherShift {
  const studentNames = arrayOfStrings(data.student_names ?? data.studentNames);
  const subject = stringValue(data.subject_display_name ?? data.subjectDisplayName ?? data.subject);
  const title =
    stringValue(data.custom_name ?? data.customName) ||
    stringValue(data.auto_generated_name ?? data.autoGeneratedName) ||
    subject ||
    "Teaching Shift";
  return {
    id,
    title,
    studentNames,
    start: dateValue(data.shift_start ?? data.shiftStart ?? data.start_time ?? data.startTime),
    end: dateValue(data.shift_end ?? data.shiftEnd ?? data.end_time ?? data.endTime),
    status: stringValue(data.status) || "scheduled",
    subject,
    category: stringValue(data.shift_category ?? data.shiftCategory) || "teaching",
    leaderRole: stringValue(data.leader_role ?? data.leaderRole),
    teacherName: stringValue(data.teacher_name ?? data.teacherName),
    hourlyRate: numberValue(data.hourly_rate ?? data.hourlyRate),
    clockInTime: dateValue(data.clock_in_time ?? data.clockInTime),
    clockOutTime: dateValue(data.clock_out_time ?? data.clockOutTime),
  };
}

function filterEntries(entries: TimesheetEntry[], timeFilter: TimeFilter | "Today") {
  if (timeFilter === "All Time") return entries;
  const now = new Date();
  if (timeFilter === "Today") return entries.filter((entry) => entry.parsedDate && isSameDay(entry.parsedDate, now));
  if (timeFilter === "This Month") {
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    return entries.filter((entry) => entry.parsedDate && entry.parsedDate >= monthStart);
  }
  const weekStart = startOfWeek(now);
  const weekEnd = addDays(weekStart, 7);
  return entries.filter((entry) => entry.parsedDate && entry.parsedDate >= weekStart && entry.parsedDate < weekEnd);
}

function filterByStatus(entries: TimesheetEntry[], statusFilter: StatusFilter) {
  if (statusFilter === "All") return entries;
  return entries.filter((entry) => entry.status.toLowerCase() === statusFilter.toLowerCase());
}

type ClockAction =
  | { kind: "clockIn"; label: string }
  | { kind: "clockOut"; label: string }
  | { kind: "disabled"; label: string; disabledMessage: string };

function clockAction(shift: TeacherShift): ClockAction {
  if (isClockedIn(shift)) return { kind: "clockOut", label: "Clock Out" };
  if (canClockInNow(shift)) return { kind: "clockIn", label: "Clock In Now" };
  if (shift.start && shift.start > new Date()) {
    return { kind: "disabled", label: "Program Clock In", disabledMessage: "Too early to clock in. Please wait until the shift starts." };
  }
  return { kind: "disabled", label: "Clock In Unavailable", disabledMessage: "No valid shift is available for clock-in right now." };
}

function canClockInNow(shift: TeacherShift) {
  if (!shift.start || !shift.end || isClockedIn(shift)) return false;
  const now = new Date();
  const windowStart = new Date(shift.start.getTime() - 60_000);
  return now >= windowStart && now <= shift.end;
}

function isClockedIn(shift: TeacherShift) {
  return Boolean(shift.clockInTime && !shift.clockOutTime && shift.status === "active");
}

function findTimeClockShift(shifts: TeacherShift[]) {
  const clockedIn = shifts.find((shift) => isClockedIn(shift));
  if (clockedIn) return clockedIn;
  const now = new Date();
  return shifts
    .filter((shift) => shift.start && shift.end && now >= new Date(shift.start.getTime() - 60_000) && now <= shift.end)
    .sort((a, b) => (a.start?.getTime() ?? 0) - (b.start?.getTime() ?? 0))[0] ?? null;
}

function shiftStatusVisual(shift: TeacherShift) {
  if (isClockedIn(shift)) {
    return {
      label: "In Progress",
      accent: "#10B981",
      background: "#F0FDF4",
      border: "#BBF7D0",
      iconBackground: "rgba(16, 185, 129, 0.15)",
    };
  }
  if (canClockInNow(shift)) {
    return {
      label: "Active Shift",
      accent: "#10B981",
      background: "#F0FDF4",
      border: "#BBF7D0",
      iconBackground: "rgba(16, 185, 129, 0.15)",
    };
  }
  return {
    label: "Upcoming Shift",
    accent: "#F59E0B",
    background: "#FEF3C7",
    border: "#FDE68A",
    iconBackground: "rgba(245, 158, 11, 0.15)",
  };
}

type BrowserLocation = {
  latitude: number;
  longitude: number;
  address: string;
  neighborhood: string;
};

async function clockInToShift(user: User, shift: TeacherShift, location: BrowserLocation) {
  if (!canClockInNow(shift)) throw new Error("Shift not found or not valid for clock-in right now");
  const openEntry = await findOpenTimesheetEntry(user.uid, shift.id);
  if (openEntry) throw new Error("You are already clocked in to this shift");
  const now = new Date();
  const payRateSource = shift.hourlyRate > 0 ? "teaching_shift_rate" : "timesheet_fallback_rate";
  const timesheetRef = doc(collection(db, "timesheet_entries"));
  const shiftRef = doc(db, "teaching_shifts", shift.id);
  const timesheetData = {
    teacher_id: user.uid,
    teacher_email: user.email,
    teacher_name: shift.teacherName,
    shift_id: shift.id,
    shift_category: shift.category,
    leader_role: shift.leaderRole || null,
    date: formatTimesheetDate(now),
    student_name: shift.category === "teaching" && shift.studentNames.length ? shift.studentNames.join(", ") : shift.title,
    start_time: formatTime(now),
    end_time: "",
    total_hours: "00:00",
    hourly_rate: shift.hourlyRate,
    pay_rate_source: payRateSource,
    is_subject_billable: shift.category === "teaching",
    description: `Teaching session: ${shift.subject || shift.title} - ${shift.title}`,
    status: "pending",
    source: "shift_clock_in",
    completion_method: "pending",
    clock_in_timestamp: Timestamp.fromDate(now),
    clock_in_status: clockDeviationStatus(now, shift.start),
    clock_in_deviation_minutes: clockDeviationMinutes(now, shift.start),
    clock_in_platform: "web",
    clock_in_latitude: location.latitude,
    clock_in_longitude: location.longitude,
    clock_in_address: location.address,
    clock_in_neighborhood: location.neighborhood,
    clock_out_latitude: null,
    clock_out_longitude: null,
    clock_out_address: null,
    clock_out_neighborhood: null,
    shift_title: shift.title,
    shift_type: buildShiftTypeString(shift),
    scheduled_start: shift.start ? Timestamp.fromDate(shift.start) : null,
    scheduled_end: shift.end ? Timestamp.fromDate(shift.end) : null,
    scheduled_duration_minutes: scheduledDurationMinutes(shift),
    employee_notes: "",
    manager_notes: "",
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  };
  await runTransaction(db, async (transaction) => {
    const shiftSnap = await transaction.get(shiftRef);
    if (!shiftSnap.exists()) throw new Error("This shift is no longer available.");
    const current = shiftSnap.data() as Record<string, unknown>;
    const currentClockIn = dateValue(current.clock_in_time ?? current.clockInTime);
    const currentClockOut = dateValue(current.clock_out_time ?? current.clockOutTime);
    if (currentClockIn && !currentClockOut) throw new Error("You are already clocked in to this shift");
    transaction.set(timesheetRef, timesheetData);
    transaction.update(shiftRef, {
      last_modified: Timestamp.fromDate(now),
      status: "active",
      clock_out_time: null,
      clock_in_time: Timestamp.fromDate(now),
      last_clock_in_platform: "web",
    });
  });
  return { message: `Successfully clocked in to ${shift.title}` };
}

async function clockOutOfShift(user: User, shift: TeacherShift, location: BrowserLocation) {
  const openEntry = await findOpenTimesheetEntry(user.uid, shift.id);
  if (!openEntry) throw new Error("No active clock-in found for this shift.");
  const now = new Date();
  const clockIn = dateValue(openEntry.data.clock_in_timestamp) ?? shift.clockInTime ?? shift.start ?? now;
  const effectiveStart = shift.start && clockIn < shift.start ? shift.start : clockIn;
  const effectiveEnd = shift.end && now > shift.end ? shift.end : now;
  const rawDurationMs = effectiveEnd.getTime() - effectiveStart.getTime();
  const scheduledMs = shift.start && shift.end ? shift.end.getTime() - shift.start.getTime() : rawDurationMs;
  const validMs = Math.max(0, Math.min(rawDurationMs, Math.max(0, scheduledMs)));
  const hoursWorked = validMs / 36e5;
  const calculatedPay = hoursWorked * shift.hourlyRate;
  const clockOutStatus = clockDeviationStatus(now, shift.end);
  const clockOutDeviation = clockDeviationMinutes(now, shift.end);
  const shiftRef = doc(db, "teaching_shifts", shift.id);
  const entryUpdate = {
    end_time: formatTime(effectiveEnd),
    total_hours: formatDurationHms(validMs),
    clock_out_timestamp: Timestamp.fromDate(now),
    effective_end_timestamp: Timestamp.fromDate(effectiveEnd),
    total_pay: calculatedPay,
    payment_amount: calculatedPay,
    hourly_rate: shift.hourlyRate,
    pay_rate_source: shift.hourlyRate > 0 ? "teaching_shift_rate" : "timesheet_fallback_rate",
    is_subject_billable: shift.category === "teaching",
    status: "pending",
    completion_method: "manual",
    clock_out_status: clockOutStatus,
    clock_out_deviation_minutes: clockOutDeviation,
    requires_clock_out_note: isLeadershipShift(shift) && clockOutStatus !== "on_time",
    clock_out_latitude: location.latitude,
    clock_out_longitude: location.longitude,
    clock_out_address: location.address,
    clock_out_neighborhood: location.neighborhood,
    clock_out_platform: "web",
    updated_at: serverTimestamp(),
  };
  await runTransaction(db, async (transaction) => {
    const entrySnap = await transaction.get(openEntry.ref);
    if (!entrySnap.exists()) throw new Error("No active clock-in found for this shift.");
    const entry = entrySnap.data() as Record<string, unknown>;
    if (dateValue(entry.clock_out_timestamp) || stringValue(entry.end_time)) {
      throw new Error("This shift has already been clocked out.");
    }
    const shiftSnap = await transaction.get(shiftRef);
    if (!shiftSnap.exists()) throw new Error("This shift is no longer available.");
    transaction.update(openEntry.ref, entryUpdate);
    transaction.update(shiftRef, {
      last_modified: Timestamp.fromDate(now),
      clock_out_time: Timestamp.fromDate(now),
    });
  });
  return { message: `Successfully clocked out from ${shift.title}` };
}

async function findOpenTimesheetEntry(teacherId: string, shiftId: string) {
  const base = [where("teacher_id", "==", teacherId), where("shift_id", "==", shiftId), limit(1)] as const;
  const empty = await getDocs(query(collection(db, "timesheet_entries"), where("end_time", "==", ""), ...base));
  const docSnap = empty.docs[0];
  if (docSnap) return { ref: docSnap.ref, data: docSnap.data() as Record<string, unknown> };
  const nullResult = await getDocs(query(collection(db, "timesheet_entries"), where("end_time", "==", null), ...base));
  const nullDoc = nullResult.docs[0];
  return nullDoc ? { ref: nullDoc.ref, data: nullDoc.data() as Record<string, unknown> } : null;
}

async function getBrowserLocation(): Promise<BrowserLocation> {
  if (!("geolocation" in navigator)) {
    throw new Error("Location access is required to clock in or out. Enable location services and try again.");
  }
  try {
    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject, { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 });
    });
    const { latitude, longitude } = position.coords;
    return {
      latitude,
      longitude,
      address: `Location: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`,
      neighborhood: "GPS coordinates",
    };
  } catch {
    throw new Error("Location access is required to clock in or out. Allow location access and try again.");
  }
}

function isLeadershipShift(shift: TeacherShift) {
  return ["leadership", "meeting", "training"].includes(shift.category.toLowerCase());
}

function clockDeviationMinutes(actual: Date, scheduled: Date | null) {
  return scheduled ? Math.trunc((actual.getTime() - scheduled.getTime()) / 60000) : 0;
}

function clockDeviationStatus(actual: Date, scheduled: Date | null) {
  const minutes = clockDeviationMinutes(actual, scheduled);
  if (minutes < -5) return "early";
  if (minutes > 5) return "late";
  return "on_time";
}

function exportCsv(entries: TimesheetEntry[]) {
  const headers = ["Date", "Student", "Start", "End", "Total Hours", "Clock-in Location", "Clock-out Location", "Status"];
  const rows = entries.map((entry) => [
    entry.date,
    entry.student,
    entry.start,
    entry.end,
    entry.totalHours,
    entry.clockInLocation,
    entry.clockOutLocation,
    entry.status,
  ]);
  const csv = [headers, ...rows].map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(",")).join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `my_timesheet_${new Date().toISOString().slice(0, 10).replaceAll("-", "")}.csv`;
  anchor.click();
  URL.revokeObjectURL(url);
}

function summaryForUser(user: User, data: UserRecord | null): TeacherSummary {
  const displayName =
    data
      ? [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])].filter(Boolean).join(" ")
      : "";
  const fallback = user.displayName?.trim() || user.email?.replace(/@.*/, "") || "Teacher";
  const name = displayName || fallback;
  return {
    displayName: name,
    firstName: name.split(/\s+/)[0] || "Teacher",
    initials: initialsFromName(name),
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function arrayOfStrings(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean);
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

function hoursLabel(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value.toFixed(1);
  if (typeof value === "string" && value.trim()) return value.trim();
  return "";
}

function toTimeInput(value: string) {
  const date = parseDisplayTime(value);
  if (!date) return "";
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function fromTimeInput(value: string) {
  if (!value) return "";
  const [hourValue, minuteValue] = value.split(":").map(Number);
  if (!Number.isFinite(hourValue) || !Number.isFinite(minuteValue)) return "";
  const date = new Date();
  date.setHours(hourValue, minuteValue, 0, 0);
  return formatTime(date);
}

function parseDisplayTime(value: string) {
  const match = value.trim().match(/^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$/i);
  if (!match) return null;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const meridiem = match[3]?.toUpperCase();
  if (!Number.isFinite(hours) || !Number.isFinite(minutes) || minutes > 59) return null;
  if (meridiem === "PM" && hours < 12) hours += 12;
  if (meridiem === "AM" && hours === 12) hours = 0;
  if (hours > 23) return null;
  const date = new Date();
  date.setHours(hours, minutes, 0, 0);
  return date;
}

function mergeEntryDateAndTime(entry: TimesheetEntry, time: string, mustBeAfter?: Date | null) {
  const parsedTime = parseDisplayTime(time);
  const base = entry.parsedDate ?? entry.clockInTimestamp ?? new Date();
  if (!parsedTime) return null;
  const merged = new Date(base);
  merged.setHours(parsedTime.getHours(), parsedTime.getMinutes(), 0, 0);
  if (mustBeAfter) {
    for (let index = 0; index < 3 && merged <= mustBeAfter; index += 1) {
      merged.setDate(merged.getDate() + 1);
    }
  }
  return merged;
}

function previewDurationMs(entry: TimesheetEntry, start: string, end: string) {
  const clockIn = mergeEntryDateAndTime(entry, start);
  const clockOut = mergeEntryDateAndTime(entry, end, clockIn);
  if (!clockIn || !clockOut) return 0;
  return Math.max(0, clockOut.getTime() - clockIn.getTime());
}

function durationMsFromLabel(value: string) {
  const parts = value.split(":").map(Number);
  if (parts.length >= 2 && parts.every((part) => Number.isFinite(part))) {
    const [hours, minutes, seconds = 0] = parts;
    return Math.max(0, ((hours * 60 + minutes) * 60 + seconds) * 1000);
  }
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(0, numeric * 36e5) : 0;
}

function formatDate(date: Date) {
  return date.toLocaleDateString("en-US", { month: "2-digit", day: "2-digit", year: "numeric" });
}

function formatTime(date: Date | null) {
  if (!date) return "";
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

function formatTimeRange(start: Date | null, end: Date | null) {
  if (!start || !end) return "Schedule pending";
  return `${formatTime(start)} - ${formatTime(end)}`;
}

function formatTimesheetDate(date: Date) {
  return date.toLocaleDateString("en-US", { month: "short", day: "2-digit", year: "numeric" });
}

function formatDurationHms(durationMs: number) {
  const totalSeconds = Math.max(0, Math.floor(durationMs / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function scheduledDurationMinutes(shift: TeacherShift) {
  if (!shift.start || !shift.end) return 0;
  return Math.max(0, Math.round((shift.end.getTime() - shift.start.getTime()) / 60000));
}

function buildShiftTypeString(shift: TeacherShift) {
  const subject = shift.subject || shift.title || "Teaching Shift";
  const duration = scheduledDurationMinutes(shift);
  return duration ? `${subject} (${duration} min)` : subject;
}

function isSameDay(left: Date, right: Date) {
  return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
}

function statusColor(status: string) {
  switch (status.toLowerCase()) {
    case "approved":
      return "#10B981";
    case "pending":
      return "#F59E0B";
    case "rejected":
      return "#EF4444";
    default:
      return "#6B7280";
  }
}

function capitalize(value: string) {
  if (!value) return "";
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function startOfWeek(date: Date) {
  const normalized = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const offset = normalized.getDay() === 0 ? 6 : normalized.getDay() - 1;
  normalized.setDate(normalized.getDate() - offset);
  return normalized;
}

function addDays(date: Date, days: number) {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

function initialsFromName(name: string) {
  const parts = name.split(/\s+/).filter(Boolean);
  return (parts[0]?.[0] ?? "T").concat(parts[1]?.[0] ?? parts[0]?.[1] ?? "E").toUpperCase();
}
