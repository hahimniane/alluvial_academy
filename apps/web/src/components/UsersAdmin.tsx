"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import {
  Archive,
  Bot,
  Briefcase,
  Download,
  Edit3,
  Filter,
  KeyRound,
  Lock,
  LogIn,
  Plus,
  Search,
  ShieldCheck,
  Trash2,
  UserRound,
  Users,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type UserTab = "users" | "admins";
type UserFilter = "all" | "teacher" | "student" | "parent" | "active" | "archived" | "never_logged_in";

type DirectoryUser = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  countryCode: string;
  phone: string;
  userType: string;
  kioskCode: string;
  studentCode: string;
  dateAdded: string;
  lastLogin: string;
  isAdminTeacher: boolean;
  isActive: boolean;
  aiTutorEnabled: boolean;
  tontineEnabled: boolean;
  secondaryRoles: string[];
  guardianIds: string[];
  childrenIds: string[];
};

const userFilters: { id: UserFilter; label: string }[] = [
  { id: "all", label: "All Users" },
  { id: "teacher", label: "Teachers" },
  { id: "student", label: "Students" },
  { id: "parent", label: "Parents" },
  { id: "active", label: "Active Users" },
  { id: "archived", label: "Archived Users" },
  { id: "never_logged_in", label: "Never Logged In" },
];

export function UsersAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [users, setUsers] = useState<DirectoryUser[]>([]);
  const [activeTab, setActiveTab] = useState<UserTab>("users");
  const [activeFilter, setActiveFilter] = useState<UserFilter>("all");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");
  const [filterOpen, setFilterOpen] = useState(false);
  const [parentPickerOpen, setParentPickerOpen] = useState(false);
  const [selectedParentId, setSelectedParentId] = useState("");
  const [parentSearch, setParentSearch] = useState("");

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
        setUsers(await loadUsers());
      } catch (error) {
        if (mounted) setMessage(error instanceof Error ? error.message : "Could not load users.");
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const studentIdsByParentId = useMemo(() => {
    const map = new Map<string, Set<string>>();
    const addStudent = (parentId: string, studentId: string) => {
      if (!parentId || !studentId) return;
      const existing = map.get(parentId) ?? new Set<string>();
      existing.add(studentId);
      map.set(parentId, existing);
    };

    users.forEach((directoryUser) => {
      if (directoryUser.userType.toLowerCase() === "parent") {
        directoryUser.childrenIds.forEach((studentId) => addStudent(directoryUser.id, studentId));
      }
      if (directoryUser.userType.toLowerCase() === "student") {
        directoryUser.guardianIds.forEach((parentId) => addStudent(parentId, directoryUser.id));
      }
    });

    return new Map(Array.from(map.entries()).map(([parentId, studentIds]) => [parentId, Array.from(studentIds)]));
  }, [users]);

  const filteredUsers = useMemo(() => {
    const selectedParentStudentIds = selectedParentId ? (studentIdsByParentId.get(selectedParentId) ?? []) : [];
    return users.filter((directoryUser) => {
      const admin = isAdminUser(directoryUser);
      if (selectedParentId) {
        if (directoryUser.userType.toLowerCase() !== "student") return false;
        if (!selectedParentStudentIds.includes(directoryUser.id)) return false;
      } else {
        if (activeTab === "users" && admin) return false;
        if (activeTab === "admins" && !admin) return false;
      }
      if (activeFilter === "teacher" || activeFilter === "student" || activeFilter === "parent") {
        if (directoryUser.userType.toLowerCase() !== activeFilter) return false;
      }
      if (activeFilter === "active" && !directoryUser.isActive) return false;
      if (activeFilter === "archived" && directoryUser.isActive) return false;
      if (activeFilter === "never_logged_in" && !hasNeverLoggedIn(directoryUser)) return false;
      if (!matchesSearch(directoryUser, search)) return false;
      return true;
    });
  }, [activeFilter, activeTab, search, selectedParentId, studentIdsByParentId, users]);

  const parentOptions = useMemo(() => {
    return users
      .filter((directoryUser) => directoryUser.userType.toLowerCase() === "parent")
      .map((directoryUser) => ({
        user: directoryUser,
        studentCount: studentIdsByParentId.get(directoryUser.id)?.length ?? 0,
      }))
      .sort((a, b) => {
        if (b.studentCount !== a.studentCount) return b.studentCount - a.studentCount;
        return displayName(a.user).localeCompare(displayName(b.user));
      });
  }, [studentIdsByParentId, users]);

  const filteredParentOptions = useMemo(() => {
    const term = parentSearch.trim().toLowerCase();
    if (!term) return parentOptions;
    return parentOptions.filter(({ user: parent }) => {
      return displayName(parent).toLowerCase().includes(term) || parent.email.toLowerCase().includes(term) || parent.id.toLowerCase().includes(term);
    });
  }, [parentOptions, parentSearch]);

  const selectedParent = selectedParentId ? users.find((directoryUser) => directoryUser.id === selectedParentId) : undefined;

  const regularCount = users.filter((directoryUser) => !isAdminUser(directoryUser)).length;
  const adminCount = users.filter(isAdminUser).length;

  function exportCsv() {
    const headers = ["First Name", "Last Name", "Email", "Mobile Phone", "User Type", "Kiosk Code", "Date Added", "Last Login"];
    const rows = filteredUsers.map((directoryUser) => [
      directoryUser.firstName,
      directoryUser.lastName,
      directoryUser.email,
      `${directoryUser.countryCode}${directoryUser.phone}`,
      directoryUser.userType,
      directoryUser.kioskCode,
      directoryUser.dateAdded,
      directoryUser.lastLogin,
    ]);
    const csv = [headers, ...rows]
      .map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(","))
      .join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `users_${new Date().toISOString().slice(0, 10).replaceAll("-", "")}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  if (access !== "allowed") {
    return <UsersAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Users" breadcrumb="People / Users">
      <main className="min-h-[calc(100vh-56px)] bg-[#F1F1F1] text-[#111827]">
        <header className="lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center bg-white px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <span className="h-0.5 w-4 bg-current" />
              <span className="-mt-5 h-0.5 w-4 bg-current" />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Academy</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">
              {initialsFor(user)}
            </span>
          </div>
        </header>

        <section className="px-2 pb-2 pt-1">
          <div className="rounded-[10px] bg-white px-3 py-2">
            <div className="flex items-center gap-2">
              <UserRound size={18} className="text-[#1D8BFF]" />
              <h1 className="text-lg font-bold text-[#273142]">User Management</h1>
            </div>
          </div>
        </section>

        <section className="overflow-x-auto px-2 pb-2">
          <div className="flex min-w-max items-center justify-center gap-2">
            <div className="relative">
              <button
                type="button"
                onClick={() => setFilterOpen((current) => !current)}
                className="inline-flex min-h-[34px] items-center gap-2 rounded-[10px] border border-[#0386FF] bg-white px-3 text-[13px] font-semibold text-[#0386FF]"
              >
                <Filter size={17} />
                Filter
              </button>
              {filterOpen ? (
                <div className="absolute left-0 z-30 mt-2 w-56 overflow-hidden rounded-xl border border-[#E2E8F0] bg-white py-1 shadow-xl">
                  {userFilters.map((filter) => (
                    <button
                      key={filter.id}
                      type="button"
                      onClick={() => {
                        setActiveFilter(filter.id);
                        setSelectedParentId("");
                        setFilterOpen(false);
                      }}
                      className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm ${activeFilter === filter.id ? "bg-[#EFF6FF] text-[#0386FF]" : "text-[#2D3748] hover:bg-[#F8FAFC]"}`}
                    >
                      <span className="h-2 w-2 rounded-full bg-current" />
                      {filter.label}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>
            <label className="relative block h-[34px] w-[220px]">
              <Search aria-hidden="true" className="absolute left-3 top-1/2 -translate-y-1/2 text-[#334155]" size={19} />
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search"
                aria-label="Search users"
                className="h-full w-full rounded-[10px] border border-[#E2E8F0] bg-white pl-10 pr-3 text-base outline-none focus:border-[#0386FF]"
              />
            </label>
            <button
              type="button"
              onClick={exportCsv}
              className="inline-flex min-h-[34px] items-center rounded-[10px] border border-[#0386FF] bg-white px-3 text-[13px] font-semibold text-[#0386FF]"
            >
              Export
            </button>
            <button
              type="button"
              onClick={() => setActiveFilter("never_logged_in")}
              className="inline-flex min-h-[34px] items-center gap-1 rounded-[10px] bg-[#F59E0B] px-3 text-xs font-semibold text-white"
            >
              <LogIn size={16} />
              Users Didn&apos;t Log In Yet
            </button>
            <button
              type="button"
              onClick={() => {
                setParentSearch("");
                setParentPickerOpen(true);
              }}
              className="inline-flex min-h-[34px] items-center gap-1 rounded-[10px] bg-[#9333EA] px-3 text-xs font-semibold text-white"
            >
              <Users size={16} />
              Filter By Parent
            </button>
            <Link
              href="/app/#/login"
              className="inline-flex min-h-[34px] items-center gap-1 rounded-[10px] bg-[#0386FF] px-3 text-xs font-bold text-white"
            >
              <Plus size={16} />
              Add Users
            </Link>
          </div>
        </section>

        {message ? (
          <div className="mx-2 mb-2 rounded-xl border border-[#BFDBFE] bg-[#EFF6FF] px-4 py-3 text-sm font-semibold text-[#1D4ED8]">
            {message}
          </div>
        ) : null}

        {selectedParentId ? (
          <div className="mx-2 mb-2 flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[#E9D5FF] bg-[#FAF5FF] px-4 py-3 text-sm font-semibold text-[#6B21A8]">
            <span>
              Parent filter: {selectedParent ? displayName(selectedParent) : selectedParentId} ({studentIdsByParentId.get(selectedParentId)?.length ?? 0} students)
            </span>
            <button
              type="button"
              onClick={() => setSelectedParentId("")}
              className="inline-flex min-h-8 items-center gap-1 rounded-lg bg-white px-3 text-xs font-bold text-[#6B21A8] shadow-sm"
            >
              <X size={14} />
              Clear
            </button>
          </div>
        ) : null}

        <section className="mx-2 mb-2 rounded-xl bg-white p-1 shadow-sm">
          <div className="grid grid-cols-2 rounded-[10px] bg-[#F8FAFC] p-0.5">
            <button
              type="button"
              onClick={() => {
                setActiveTab("users");
                setSelectedParentId("");
              }}
              className={`min-h-[48px] rounded-lg text-sm font-bold ${activeTab === "users" ? "border border-[#DBEAFE] bg-white text-[#0386FF]" : "text-[#4B5563]"}`}
            >
              USERS ({regularCount})
            </button>
            <button
              type="button"
              onClick={() => {
                setActiveTab("admins");
                setSelectedParentId("");
              }}
              className={`min-h-[48px] rounded-lg text-sm font-bold ${activeTab === "admins" ? "border border-[#DBEAFE] bg-white text-[#0386FF]" : "text-[#4B5563]"}`}
            >
              ADMINS ({adminCount})
            </button>
          </div>

          {loading ? (
            <div className="grid min-h-[360px] place-items-center">
              <div className="h-10 w-10 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
            </div>
          ) : (
            <div className="mt-1 overflow-x-auto">
              <table className="min-w-[940px] table-fixed border-collapse text-left text-xs text-[#374151]">
                <colgroup>
                  <col className="w-[72px]" />
                  <col className="w-[72px]" />
                  <col className="w-[140px]" />
                  <col className="w-[100px]" />
                  <col className="w-[72px]" />
                  <col className="w-[60px]" />
                  <col className="w-[64px]" />
                  <col className="w-[60px]" />
                  <col className="w-[300px]" />
                </colgroup>
                <thead>
                  <tr className="border-y border-[#CBD5E1] bg-white">
                    {["First Na...", "Last Na...", "Email", "Mobile Phone", "User Type", "Kiosk ...", "Date A...", "Last L...", "Actions"].map((heading) => (
                      <th key={heading} className="px-4 py-3 font-semibold">
                        {heading}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filteredUsers.length === 0 ? (
                    <tr>
                      <td colSpan={9} className="px-4 py-20 text-center text-base font-semibold text-[#6B7280]">
                        No users found
                      </td>
                    </tr>
                  ) : (
                    filteredUsers.map((directoryUser) => <UserRow key={directoryUser.id} user={directoryUser} adminTab={activeTab === "admins"} />)
                  )}
                </tbody>
              </table>
            </div>
          )}
        </section>

        {parentPickerOpen ? (
          <ParentFilterDialog
            parents={filteredParentOptions}
            parentSearch={parentSearch}
            selectedParentId={selectedParentId}
            onParentSearchChange={setParentSearch}
            onClose={() => setParentPickerOpen(false)}
            onClear={() => {
              setSelectedParentId("");
              setParentPickerOpen(false);
            }}
            onSelect={(parentId) => {
              setSelectedParentId(parentId);
              setActiveTab("users");
              setActiveFilter("all");
              setSearch("");
              setParentPickerOpen(false);
            }}
          />
        ) : null}
      </main>
    </AdminDashboardShell>
  );
}

function ParentFilterDialog({
  parents,
  parentSearch,
  selectedParentId,
  onParentSearchChange,
  onClose,
  onClear,
  onSelect,
}: {
  parents: { user: DirectoryUser; studentCount: number }[];
  parentSearch: string;
  selectedParentId: string;
  onParentSearchChange: (value: string) => void;
  onClose: () => void;
  onClear: () => void;
  onSelect: (parentId: string) => void;
}) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 px-4 py-6" role="presentation">
      <section role="dialog" aria-modal="true" aria-labelledby="parent-filter-title" className="flex max-h-[86vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl">
        <header className="flex items-center justify-between border-b border-[#E2E8F0] px-5 py-4">
          <div>
            <h2 id="parent-filter-title" className="text-lg font-black text-[#111827]">
              Filter By Parent
            </h2>
            <p className="mt-1 text-sm font-medium text-[#64748B]">Choose a parent to view their linked students.</p>
          </div>
          <button type="button" aria-label="Close parent filter" onClick={onClose} className="grid h-10 w-10 place-items-center rounded-xl text-[#475569] hover:bg-[#F8FAFC]">
            <X size={20} />
          </button>
        </header>

        <div className="border-b border-[#E2E8F0] p-4">
          <label className="relative block">
            <Search aria-hidden="true" className="absolute left-3 top-1/2 -translate-y-1/2 text-[#64748B]" size={18} />
            <input
              value={parentSearch}
              onChange={(event) => onParentSearchChange(event.target.value)}
              placeholder="Search parents"
              aria-label="Search parents"
              className="h-11 w-full rounded-xl border border-[#CBD5E1] bg-white pl-10 pr-3 text-sm font-semibold outline-none focus:border-[#0386FF]"
            />
          </label>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto p-2">
          {parents.length === 0 ? (
            <div className="px-4 py-14 text-center text-sm font-semibold text-[#64748B]">No parents found</div>
          ) : (
            parents.map(({ user: parent, studentCount }) => {
              const selected = selectedParentId === parent.id;
              return (
                <button
                  key={parent.id}
                  type="button"
                  onClick={() => onSelect(parent.id)}
                  className={`flex w-full items-center justify-between gap-4 rounded-xl px-4 py-3 text-left hover:bg-[#F8FAFC] ${selected ? "bg-[#F3E8FF]" : ""}`}
                >
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-black text-[#111827]">{displayName(parent)}</span>
                    <span className="block truncate text-xs font-semibold text-[#64748B]">{parent.email || parent.id}</span>
                  </span>
                  <span className="shrink-0 rounded-full bg-[#EEF2FF] px-3 py-1 text-xs font-black text-[#4338CA]">
                    {studentCount} {studentCount === 1 ? "student" : "students"}
                  </span>
                </button>
              );
            })
          )}
        </div>

        <footer className="flex justify-end gap-2 border-t border-[#E2E8F0] px-5 py-4">
          <button type="button" onClick={onClear} className="min-h-10 rounded-xl border border-[#CBD5E1] bg-white px-4 text-sm font-bold text-[#475569]">
            Clear parent filter
          </button>
          <button type="button" onClick={onClose} className="min-h-10 rounded-xl bg-[#0386FF] px-4 text-sm font-bold text-white">
            Done
          </button>
        </footer>
      </section>
    </div>
  );
}

function UserRow({ user, adminTab }: { user: DirectoryUser; adminTab: boolean }) {
  const archived = !user.isActive;
  return (
    <tr className={`border-b border-[#CBD5E1] ${archived ? "bg-[#F8FAFC] text-[#94A3B8]" : "bg-white"}`}>
      <td className="truncate px-4 py-3">{user.firstName}</td>
      <td className="truncate px-4 py-3">{user.lastName}</td>
      <td className="truncate px-4 py-3">{user.email}</td>
      <td className="truncate px-4 py-3">{[user.countryCode, user.phone].filter(Boolean).join("")}</td>
      <td className="px-4 py-3">
        <RolePill userType={user.userType} admin={adminTab || isAdminUser(user)} />
      </td>
      <td className="truncate px-4 py-3">{user.kioskCode}</td>
      <td className="truncate px-4 py-3">{shortDate(user.dateAdded)}</td>
      <td className="truncate px-4 py-3">{shortDate(user.lastLogin)}</td>
      <td className="px-4 py-2">
        <div className="flex items-center gap-1">
          {archived ? <ActionIcon icon={Archive} label={`Restore ${displayName(user)}`} color="#10B981" /> : null}
          {user.userType.toLowerCase() === "student" ? <ActionIcon icon={KeyRound} label={`View credentials for ${displayName(user)}`} color="#06B6D4" /> : null}
          {(user.userType.toLowerCase() === "student" || user.userType.toLowerCase() === "teacher") && !archived ? (
            <ActionIcon icon={Bot} label={`${user.aiTutorEnabled ? "Disable" : "Enable"} AI Tutor for ${displayName(user)}`} color={user.aiTutorEnabled ? "#10B981" : "#9CA3AF"} />
          ) : null}
          {!archived ? <ActionIcon icon={Users} label={`${user.tontineEnabled ? "Disable" : "Enable"} Tontine for ${displayName(user)}`} color={user.tontineEnabled ? "#10B981" : "#9CA3AF"} /> : null}
          {!archived ? <ActionIcon icon={Edit3} label={`Edit ${displayName(user)}`} color="#0386FF" /> : null}
          {user.userType.toLowerCase() === "teacher" && !user.isAdminTeacher ? <ActionIcon icon={Briefcase} label={`Promote ${displayName(user)}`} color="#F59E0B" /> : null}
          {!archived ? <ActionIcon icon={Archive} label={`Archive ${displayName(user)}`} color="#F59E0B" /> : null}
          <ActionIcon icon={Trash2} label={`Delete ${displayName(user)}`} color="#EF4444" />
          {user.userType.toLowerCase() === "teacher" && user.isAdminTeacher ? <ActionIcon icon={ShieldCheck} label={`${displayName(user)} is already admin teacher`} color="#10B981" /> : null}
        </div>
      </td>
    </tr>
  );
}

function RolePill({ userType, admin }: { userType: string; admin: boolean }) {
  const normalized = admin ? "admin" : userType.toLowerCase();
  const style =
    normalized === "teacher"
      ? "bg-[#DBEAFE] text-[#1D4ED8]"
      : normalized === "student"
        ? "bg-[#DCFCE7] text-[#15803D]"
        : normalized === "parent"
          ? "bg-[#F3E8FF] text-[#7E22CE]"
          : "bg-[#FEE2E2] text-[#B91C1C]";
  return <span className={`inline-flex rounded-full px-2 py-1 text-[11px] font-semibold ${style}`}>{admin ? "admin" : userType || "user"}</span>;
}

function ActionIcon({ icon: Icon, label, color }: { icon: LucideIcon; label: string; color: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      className="grid h-8 w-8 shrink-0 place-items-center rounded-lg border border-black/10 bg-white hover:bg-[#F8FAFC]"
      style={{ color }}
    >
      <Icon size={16} />
    </button>
  );
}

function UsersAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before managing users."
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

async function loadUsers() {
  const snap = await getDocs(query(collection(db, "users"), limit(300)));
  return snap.docs.map((docSnap) => normalizeUser(docSnap.id, docSnap.data() as Record<string, unknown>));
}

function normalizeUser(id: string, data: Record<string, unknown>): DirectoryUser {
  const userType = stringValue(data.user_type ?? data.userType);
  const kioskCode = stringValue(data.kiosk_code) || (userType === "student" ? id : "");
  return {
    id,
    firstName: stringValue(data.first_name ?? data.firstName),
    lastName: stringValue(data.last_name ?? data.lastName),
    email: stringValue(data["e-mail"] ?? data.email),
    countryCode: stringValue(data.country_code ?? data.countryCode),
    phone: stringValue(data.phone_number ?? data.phoneNumber),
    userType,
    kioskCode,
    studentCode: stringValue(data.student_code ?? data.studentCode ?? data.student_id) || kioskCode,
    dateAdded: dateString(data.date_added ?? data.dateAdded),
    lastLogin: dateString(data.last_login ?? data.lastLogin),
    isAdminTeacher: data.is_admin_teacher === true,
    isActive: data.is_active !== false,
    aiTutorEnabled: data.ai_tutor_enabled === true,
    tontineEnabled: data.tontine_enabled === true,
    secondaryRoles: Array.isArray(data.secondary_roles) ? data.secondary_roles.map((role) => stringValue(role)).filter(Boolean) : [],
    guardianIds: arrayOfStrings(data.guardian_ids ?? data.guardianIds),
    childrenIds: arrayOfStrings(data.children_ids ?? data.childrenIds),
  };
}

function isAdminUser(user: DirectoryUser) {
  const type = user.userType.toLowerCase();
  return type === "admin" || type === "super_admin" || user.isAdminTeacher || user.secondaryRoles.some((role) => ["admin", "super_admin"].includes(role.toLowerCase()));
}

function hasNeverLoggedIn(user: DirectoryUser) {
  const login = user.lastLogin.toLowerCase();
  return !login || login === "never" || login === "n/a" || login === "-" || login === "null" || login.includes("1970-01-01");
}

function matchesSearch(user: DirectoryUser, search: string) {
  const term = search.trim().toLowerCase();
  if (!term) return true;
  const fullName = `${user.firstName} ${user.lastName}`.toLowerCase();
  const reversedName = `${user.lastName} ${user.firstName}`.toLowerCase();
  const phoneDigits = `${user.countryCode}${user.phone}`.replace(/\D/g, "");
  const termDigits = term.replace(/\D/g, "");
  return (
    user.firstName.toLowerCase().includes(term) ||
    user.lastName.toLowerCase().includes(term) ||
    user.email.toLowerCase().includes(term) ||
    user.studentCode.toLowerCase().includes(term) ||
    user.id.toLowerCase().includes(term) ||
    fullName.includes(term) ||
    reversedName.includes(term) ||
    (termDigits.length > 0 && phoneDigits.includes(termDigits))
  );
}

function displayName(user: DirectoryUser) {
  return [user.firstName, user.lastName].filter(Boolean).join(" ") || user.studentCode || user.email || user.id;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function arrayOfStrings(value: unknown) {
  return Array.isArray(value) ? value.map((entry) => stringValue(entry)).filter(Boolean) : [];
}

function dateString(value: unknown) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string" && value.trim()) return value.trim();
  return "Never";
}

function shortDate(value: string) {
  if (!value || value === "Never") return "Never";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toISOString().slice(0, 10);
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Admin";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "AD";
}
