"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { httpsCallable } from "firebase/functions";
import { collection, getDocs, limit, query, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { CheckCircle2, ChevronDown, Lock, Menu, Search, XCircle } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db, functions } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type RecipientType = "individual" | "role" | "selected";
type RoleFilter = "teacher" | "student" | "parent" | "admin" | "";

type DirectoryUser = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  userType: string;
  isActive: boolean;
};

const roleOptions: { value: RoleFilter; label: string }[] = [
  { value: "", label: "All Roles" },
  { value: "teacher", label: "Teachers" },
  { value: "student", label: "Students" },
  { value: "parent", label: "Parents" },
  { value: "admin", label: "Admins" },
];

export function NotificationsAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [users, setUsers] = useState<DirectoryUser[]>([]);
  const [loadingUsers, setLoadingUsers] = useState(true);
  const [recipientType, setRecipientType] = useState<RecipientType>("individual");
  const [selectedRole, setSelectedRole] = useState<RoleFilter>("");
  const [selectedUserIds, setSelectedUserIds] = useState<string[]>([]);
  const [search, setSearch] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [sendEmail, setSendEmail] = useState(false);
  const [sending, setSending] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setError("");
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoadingUsers(false);
        return;
      }

      setAccess("checking");
      setLoadingUsers(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!mounted) return;
        if (!allowed) {
          setAccess("denied");
          setLoadingUsers(false);
          return;
        }
        setAccess("allowed");
        const loaded = await loadActiveUsers();
        if (mounted) setUsers(loaded);
      } catch (loadError) {
        if (mounted) setError(loadError instanceof Error ? loadError.message : "Error loading users.");
      } finally {
        if (mounted) setLoadingUsers(false);
      }
    });
  }, []);

  const filteredUsers = useMemo(() => {
    const term = search.trim().toLowerCase();
    return users.filter((item) => {
      const matchesRole = !selectedRole || normalizeRole(item.userType) === selectedRole;
      if (!matchesRole) return false;
      if (!term) return true;
      return [displayName(item), item.email, roleName(item.userType)].some((value) => value.toLowerCase().includes(term));
    });
  }, [search, selectedRole, users]);

  const selectedCount = selectedUserIds.length;

  if (access !== "allowed") {
    return <NotificationsAccessPrompt access={access} />;
  }

  async function handleSend() {
    setError("");
    setMessage("");
    if (!title.trim()) {
      setError("Please enter a title");
      return;
    }
    if (!body.trim()) {
      setError("Please enter a message");
      return;
    }
    if (recipientType === "role" && !selectedRole) {
      setError("Please select a role");
      return;
    }
    if (recipientType !== "role" && selectedUserIds.length === 0) {
      setError("Please select at least one recipient");
      return;
    }
    if (!auth.currentUser) {
      setError("User not authenticated");
      return;
    }

    setSending(true);
    try {
      const callable = httpsCallable(functions, "sendAdminNotification");
      const result = await callable({
        recipientType,
        recipientRole: selectedRole || null,
        recipientIds: selectedUserIds,
        notificationTitle: title.trim(),
        notificationBody: body.trim(),
        sendEmail,
        adminId: auth.currentUser.uid,
      });
      const data = result.data as { message?: string };
      setMessage(data.message || "Notification sent successfully");
      setTitle("");
      setBody("");
      setSelectedUserIds([]);
      setSendEmail(false);
    } catch (sendError) {
      setError(sendError instanceof Error ? sendError.message : "Error sending notification");
    } finally {
      setSending(false);
    }
  }

  return (
    <AdminDashboardShell activeLabel="Notifications" breadcrumb="Communication / Notifications">
      <main className="min-h-[calc(100vh-56px)] bg-[#F8FAFC] pb-6 text-[#111827]">
        <header className="border-b border-[#F3F4F6] bg-white lg:hidden">
          <div className="grid min-h-14 grid-cols-[48px_1fr_48px] items-center px-3">
            <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl">
              <Menu size={20} />
            </button>
            <div className="min-w-0 text-center">
              <div className="truncate text-sm font-black">Alluwal Academy</div>
            </div>
            <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[11px] font-black text-white">{initialsFor(user)}</span>
          </div>
        </header>

        <section className="border-b border-[#EEF2F7] bg-[#F8FAFC] px-5 py-4">
          <div className="mx-auto grid max-w-[1160px] grid-cols-[32px_1fr_32px] items-center">
            <span className="text-[#111827]">←</span>
            <h1 className="text-center text-2xl font-bold text-[#111827]">Send Notification</h1>
            <span />
          </div>
        </section>

        <section className="mx-auto grid max-w-[1160px] grid-cols-[minmax(0,3fr)_minmax(132px,2fr)] gap-6 px-4 py-6 max-[700px]:grid-cols-[minmax(0,1fr)_132px] max-[700px]:gap-6">
          <form className="rounded-xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.05)] max-[700px]:p-6" onSubmit={(event) => event.preventDefault()}>
            <h2 className="text-xl font-semibold text-[#111827] max-[700px]:text-[22px] max-[700px]:leading-8">Compose Notification</h2>
            <div className="mt-6">
              <p className="text-sm font-medium text-[#374151]">Send To</p>
              <div className="mt-2 overflow-hidden rounded-lg border border-[#E5E7EB]">
                <RecipientRow label="Individual User" value="individual" selected={recipientType === "individual"} onSelect={setRecipientType} />
                <RecipientRow label="All Users In Role" value="role" selected={recipientType === "role"} onSelect={(value) => {
                  setRecipientType(value);
                  setSelectedUserIds([]);
                }} />
                <RecipientRow label="Selected Users" value="selected" selected={recipientType === "selected"} onSelect={setRecipientType} />
              </div>
            </div>

            {recipientType === "role" ? (
              <label className="mt-4 block text-sm font-medium text-[#374151]">
                Select Role
                <select value={selectedRole} onChange={(event) => setSelectedRole(event.target.value as RoleFilter)} className="mt-2 h-12 w-full rounded-lg border border-[#E5E7EB] bg-white px-3 text-sm outline-none focus:border-[#3B82F6]">
                  <option value="">Choose a role</option>
                  <option value="teacher">Teachers</option>
                  <option value="student">Students</option>
                  <option value="parent">Parents</option>
                  <option value="admin">Admins</option>
                </select>
              </label>
            ) : null}

            <label className="mt-6 block text-sm font-medium text-[#374151]">
              Notification Title
              <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Enter Notification Title" className="mt-2 h-12 w-full rounded-lg border border-[#E5E7EB] px-4 text-base outline-none placeholder:text-[#6B7280] focus:border-[#3B82F6]" />
            </label>

            <label className="mt-4 block text-sm font-medium text-[#374151]">
              Notification Message
              <textarea value={body} onChange={(event) => setBody(event.target.value)} placeholder="Enter Notification Message" className="mt-2 min-h-[168px] w-full resize-y rounded-lg border border-[#E5E7EB] px-4 py-4 text-base outline-none placeholder:text-[#6B7280] focus:border-[#3B82F6]" />
            </label>

            <label className="mt-5 flex items-start gap-3 text-sm text-[#374151]">
              <input type="checkbox" checked={sendEmail} onChange={(event) => setSendEmail(event.target.checked)} className="mt-1 h-5 w-5 rounded border-[#4B5563]" />
              <span>
                <span className="block text-base">Also Send As Email Notification</span>
                <span className="block text-xs text-[#6B7280]">Recipients Will Receive Both Push Notification</span>
              </span>
            </label>

            {error ? (
              <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">{error}</p>
            ) : null}
            {message ? (
              <p className="mt-4 rounded-lg bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-700">{message}</p>
            ) : null}

            <button type="button" onClick={() => void handleSend()} disabled={sending} className="mt-6 flex min-h-12 w-full items-center justify-center rounded-lg bg-[#3B82F6] text-base font-semibold text-white disabled:opacity-60">
              {sending ? "Sending..." : "Send Notification"}
            </button>
          </form>

          {recipientType !== "role" ? (
            <aside className="rounded-xl bg-white p-6 shadow-[0_4px_10px_rgba(15,23,42,0.05)] max-[700px]:overflow-hidden max-[700px]:p-6">
              <h2 className="text-lg font-semibold text-[#111827] max-[700px]:text-[22px] max-[700px]:leading-8">
                {recipientType === "individual" ? "Select User" : "Select Users"}
              </h2>
              <label className="relative mt-5 block">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#4B5563]" size={20} />
                <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search users..." aria-label="Search users" className="h-12 w-full rounded-lg border border-[#E5E7EB] pl-11 pr-3 text-base outline-none placeholder:text-[#374151] focus:border-[#3B82F6] max-[700px]:pr-1" />
              </label>
              <label className="relative mt-3 block">
                <select value={selectedRole} onChange={(event) => setSelectedRole(event.target.value as RoleFilter)} aria-label="Filter by role" className="h-12 w-full appearance-none rounded-lg border border-[#E5E7EB] bg-white px-3 pr-9 text-base outline-none focus:border-[#3B82F6]">
                  {roleOptions.map((option) => (
                    <option key={option.label} value={option.value}>{option.label}</option>
                  ))}
                </select>
                <ChevronDown className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[#4B5563]" size={18} />
              </label>

              {recipientType === "selected" ? (
                <div className="mt-4 rounded-md bg-[#F3F4F6] px-3 py-2 text-sm font-medium text-[#374151]">{selectedCount} users selected</div>
              ) : null}

              <div className="mt-5 max-h-[520px] space-y-2 overflow-y-auto pr-1 max-[700px]:max-h-[470px] max-[700px]:pr-0">
                {loadingUsers ? (
                  <div className="grid min-h-24 place-items-center">
                    <div className="h-8 w-8 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#3B82F6]" />
                  </div>
                ) : filteredUsers.length === 0 ? (
                  <div className="grid min-h-28 place-items-center text-center text-sm text-[#6B7280]">No users found</div>
                ) : (
                  filteredUsers.map((directoryUser) => (
                    <UserRow
                      key={directoryUser.id}
                      user={directoryUser}
                      mode={recipientType}
                      selected={selectedUserIds.includes(directoryUser.id)}
                      onToggle={() => {
                        setSelectedUserIds((current) => {
                          if (recipientType === "individual") return [directoryUser.id];
                          return current.includes(directoryUser.id) ? current.filter((id) => id !== directoryUser.id) : [...current, directoryUser.id];
                        });
                      }}
                    />
                  ))
                )}
              </div>
            </aside>
          ) : null}
        </section>
      </main>
    </AdminDashboardShell>
  );
}

function RecipientRow({ label, value, selected, onSelect }: { label: string; value: RecipientType; selected: boolean; onSelect: (value: RecipientType) => void }) {
  return (
    <button type="button" onClick={() => onSelect(value)} className="flex min-h-[49px] w-full items-center gap-4 border-b border-[#E5E7EB] px-5 text-left text-[15px] last:border-b-0 max-[700px]:min-h-[80px] max-[700px]:px-4">
      <span className={`grid h-5 w-5 shrink-0 place-items-center rounded-full border-2 ${selected ? "border-[#0D8BFF]" : "border-[#4B5563]"}`}>
        {selected ? <span className="h-2.5 w-2.5 rounded-full bg-[#0D8BFF]" /> : null}
      </span>
      <span className="text-[#374151] max-[700px]:max-w-[76px] max-[700px]:break-words">{label}</span>
    </button>
  );
}

function UserRow({ user, mode, selected, onToggle }: { user: DirectoryUser; mode: RecipientType; selected: boolean; onToggle: () => void }) {
  return (
    <button type="button" onClick={onToggle} className="grid w-full grid-cols-[44px_minmax(0,1fr)_28px] items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-[#F8FAFC] max-[700px]:grid-cols-1 max-[700px]:justify-items-center max-[700px]:gap-1">
      <span className="grid h-10 w-10 place-items-center rounded-full text-sm font-bold text-white" style={{ backgroundColor: roleColor(user.userType) }}>
        {displayName(user).slice(0, 1).toUpperCase() || "?"}
      </span>
      <span className="min-w-0 max-[700px]:text-center">
        <span className="block truncate text-base text-[#1F2937] max-[700px]:whitespace-normal max-[700px]:break-all max-[700px]:text-sm">{displayName(user)}</span>
        <span className="block truncate text-xs text-[#6B7280] max-[700px]:whitespace-normal max-[700px]:break-all">{user.email} • {roleName(user.userType)}</span>
      </span>
      <span className="grid h-7 w-7 place-items-center text-[#374151]">
        {mode === "individual" ? (
          <span className={`grid h-[22px] w-[22px] place-items-center rounded-full border-2 ${selected ? "border-[#111827]" : "border-[#4B5563]"}`}>
            {selected ? <span className="h-2.5 w-2.5 rounded-full bg-[#111827]" /> : null}
          </span>
        ) : selected ? (
          <CheckCircle2 size={22} className="text-[#3B82F6]" />
        ) : (
          <XCircle size={22} className="text-[#CBD5E1]" />
        )}
      </span>
    </button>
  );
}

function NotificationsAccessPrompt({ access }: { access: AccessState }) {
  const checking = access === "checking";
  return (
    <main className="grid min-h-screen place-items-center bg-[#F1F4F8] px-5 text-[#0F172A]">
      <section className="w-full max-w-md rounded-[20px] border border-black/10 bg-white px-6 py-10 text-center shadow-sm">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#FEE2E2] text-[#F43F5E]">
          <Lock size={24} />
        </div>
        <h1 className="mt-4 text-xl font-bold">
          {checking ? "Checking admin access" : access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h1>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {checking
            ? "Please wait while we verify your dashboard permissions."
            : access === "signedOut"
              ? "Sign in with an administrator account before sending notifications."
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

async function loadActiveUsers() {
  const snap = await getDocs(query(collection(db, "users"), where("is_active", "==", true), limit(200)));
  return snap.docs
    .map((docSnap) => normalizeUser(docSnap.id, docSnap.data() as Record<string, unknown>))
    .sort((a, b) => displayName(a).localeCompare(displayName(b)));
}

function normalizeUser(id: string, data: Record<string, unknown>): DirectoryUser {
  return {
    id,
    firstName: stringValue(data.first_name ?? data.firstName),
    lastName: stringValue(data.last_name ?? data.lastName),
    email: stringValue(data["e-mail"] ?? data.email),
    userType: stringValue(data.user_type ?? data.userType),
    isActive: data.is_active !== false,
  };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function displayName(user: DirectoryUser) {
  return [user.firstName, user.lastName].filter(Boolean).join(" ") || user.email || user.id;
}

function normalizeRole(role: string) {
  const normalized = role.toLowerCase();
  if (normalized.includes("admin")) return "admin";
  if (normalized.includes("teacher")) return "teacher";
  if (normalized.includes("student")) return "student";
  if (normalized.includes("parent")) return "parent";
  return normalized;
}

function roleName(role: string) {
  const normalized = normalizeRole(role);
  if (normalized === "admin") return "Admin";
  if (normalized === "teacher") return "Teacher";
  if (normalized === "student") return "Student";
  if (normalized === "parent") return "Parent";
  return role || "User";
}

function roleColor(role: string) {
  const normalized = normalizeRole(role);
  if (normalized === "admin") return "#EF4444";
  if (normalized === "teacher") return "#3B82F6";
  if (normalized === "student") return "#10B981";
  if (normalized === "parent") return "#F59E0B";
  return "#6B7280";
}

function initialsFor(user: User | null) {
  const source = user?.displayName || user?.email || "Administrator";
  return source
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}
