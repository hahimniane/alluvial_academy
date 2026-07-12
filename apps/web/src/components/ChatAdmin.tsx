"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, getDocs, limit, query, Timestamp, where } from "firebase/firestore";
import { useEffect, useMemo, useState } from "react";
import { Lock, MessageSquare, Search, UserPlus, Users, X } from "lucide-react";
import { AdminDashboardShell } from "@/components/AdminDashboardShell";
import { auth, db } from "@/lib/firebase";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type ChatTab = "recent" | "contacts";

type ChatPreview = {
  id: string;
  displayName: string;
  email: string;
  lastMessage: string;
  lastMessageTime: Date | null;
  unreadCount: number;
  isGroup: boolean;
  isSupport: boolean;
};

type ContactRecord = {
  id: string;
  displayName: string;
  email: string;
  role: string;
  group: string;
};

const groupOrder = ["Administrators", "Teachers", "Students", "Parents", "Other"];

export function ChatAdmin() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [user, setUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<ChatTab>("recent");
  const [search, setSearch] = useState("");
  const [chats, setChats] = useState<ChatPreview[]>([]);
  const [contacts, setContacts] = useState<ContactRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [createOpen, setCreateOpen] = useState(false);

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
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
        const [loadedChats, loadedContacts] = await Promise.all([loadChats(nextUser.uid), loadContacts(nextUser.uid)]);
        if (!mounted) return;
        setChats(loadedChats);
        setContacts(loadedContacts);
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  const filteredChats = useMemo(() => {
    const term = search.trim().toLowerCase();
    return chats.filter((chat) => {
      if (!term) return true;
      return [chat.displayName, chat.email, chat.lastMessage].some((value) => value.toLowerCase().includes(term));
    });
  }, [chats, search]);

  const groupedContacts = useMemo(() => {
    const term = search.trim().toLowerCase();
    const groups = new Map<string, ContactRecord[]>();
    contacts.forEach((contact) => {
      if (term && ![contact.displayName, contact.email, contact.role].some((value) => value.toLowerCase().includes(term))) return;
      const list = groups.get(contact.group) ?? [];
      list.push(contact);
      groups.set(contact.group, list);
    });
    return groupOrder.flatMap((group) => {
      const list = groups.get(group) ?? [];
      return list.length ? [{ group, contacts: list }] : [];
    });
  }, [contacts, search]);

  if (access !== "allowed") {
    return <ChatAccessPrompt access={access} />;
  }

  return (
    <AdminDashboardShell activeLabel="Chat" breadcrumb="Communication / Chat">
      <main className="relative min-h-[calc(100vh-56px)] bg-white text-[#111827]">
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

        <section className="border-b border-[#F3F4F6] bg-white px-4 py-2">
          <div className="rounded-[10px] bg-[#F1F5F9] p-1">
            <div className="grid grid-cols-2 gap-1">
              <ChatTabButton active={activeTab === "recent"} onClick={() => setActiveTab("recent")}>
                Recent Chats
              </ChatTabButton>
              <ChatTabButton active={activeTab === "contacts"} onClick={() => setActiveTab("contacts")}>
                My Contacts
              </ChatTabButton>
            </div>
          </div>
        </section>

        <section className="bg-white px-4 py-3">
          <label className="relative block h-12">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#9CA3AF]" size={22} />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search conversations and users..."
              aria-label="Search conversations and users"
              className="h-full w-full rounded-xl border-0 bg-[#F3F4F6] pl-12 pr-4 text-[15px] text-[#111827] outline-none ring-0 placeholder:text-[#9CA3AF] focus:ring-2 focus:ring-[#0386FF]"
            />
          </label>
        </section>

        <section className="min-h-[calc(100vh-245px)] pb-24">
          {loading ? (
            <LoadingMessages />
          ) : activeTab === "recent" ? (
            <RecentChats chats={filteredChats} search={search} />
          ) : (
            <ContactsList groups={groupedContacts} search={search} />
          )}
        </section>

        <button
          type="button"
          onClick={() => setCreateOpen(true)}
          className="fixed bottom-4 right-4 z-20 inline-flex min-h-14 items-center gap-2 rounded-2xl bg-[#0386FF] px-6 text-base font-bold text-white shadow-xl lg:bottom-4 lg:right-4"
        >
          <UserPlus size={22} />
          Create Group
        </button>

        {createOpen ? <CreateGroupDialog onClose={() => setCreateOpen(false)} contacts={contacts} /> : null}
      </main>
    </AdminDashboardShell>
  );
}

function ChatTabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: string }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`min-h-9 rounded-lg text-sm font-semibold ${active ? "bg-white text-[#0386FF] shadow-sm" : "text-[#64748B]"}`}
    >
      {children}
    </button>
  );
}

function RecentChats({ chats, search }: { chats: ChatPreview[]; search: string }) {
  if (chats.length === 0) {
    return (
      <EmptyChatState
        title={search.trim() ? "No chats found" : "No conversations yet"}
        subtitle={search.trim() ? "Try a different search term" : "Start a conversation by browsing all users"}
      />
    );
  }

  const support = chats.filter((chat) => chat.isSupport);
  const normal = chats.filter((chat) => !chat.isSupport);
  return (
    <div className="px-3 py-2">
      {support.length ? <ChatSection title="Support Inbox" tone="support" count={support.length} chats={support} /> : null}
      {support.length && normal.length ? <div className="mx-4 my-3 border-t border-[#E5E7EB]" /> : null}
      {normal.map((chat) => (
        <ChatRow key={chat.id} chat={chat} />
      ))}
    </div>
  );
}

function ContactsList({ groups, search }: { groups: { group: string; contacts: ContactRecord[] }[]; search: string }) {
  if (groups.length === 0) {
    return (
      <EmptyChatState
        title={search.trim() ? "No contacts match your search" : "No contacts available"}
        subtitle={search.trim() ? "Try a different search term" : "Your teachers, students, or administrators will appear here based on your classes"}
      />
    );
  }

  return (
    <div className="px-3 py-2">
      {groups.map(({ group, contacts }) => (
        <div key={group}>
          <div className="flex items-center gap-2 px-2 py-3">
            <span className={`grid h-6 w-6 place-items-center rounded-md text-xs ${groupHeaderStyle(group)}`}>
              <Users size={15} />
            </span>
            <h2 className="text-[13px] font-bold tracking-wide text-[#6B7280]">{group}</h2>
            <span className="rounded-full bg-[#F1F5F9] px-2 py-0.5 text-xs font-semibold text-[#64748B]">{contacts.length}</span>
          </div>
          {contacts.map((contact) => (
            <ContactRow key={contact.id} contact={contact} />
          ))}
        </div>
      ))}
    </div>
  );
}

function ChatSection({ title, tone, count, chats }: { title: string; tone: "support"; count: number; chats: ChatPreview[] }) {
  return (
    <div>
      <div className="flex items-center gap-2 px-2 py-3">
        <span className="grid h-6 w-6 place-items-center rounded-md bg-[#FEE2E2] text-[#EF4444]">
          <MessageSquare size={15} />
        </span>
        <h2 className="text-[13px] font-bold tracking-wide text-[#6B7280]">{title}</h2>
        <span className="rounded-full bg-[#F1F5F9] px-2 py-0.5 text-xs font-semibold text-[#64748B]">{count}</span>
      </div>
      {chats.map((chat) => (
        <ChatRow key={`${tone}-${chat.id}`} chat={chat} />
      ))}
    </div>
  );
}

function ChatRow({ chat }: { chat: ChatPreview }) {
  return (
    <article className="mb-2 flex min-h-[78px] items-center gap-4 rounded-xl border border-[#EEF2F7] bg-white px-4 shadow-sm">
      <Avatar label={chat.displayName} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-base font-semibold text-[#111827]">{chat.displayName}</div>
        <div className="truncate text-sm text-[#6B7280]">{chat.lastMessage || chat.email || (chat.isGroup ? "Group chat" : "Conversation")}</div>
      </div>
      {chat.unreadCount > 0 ? <span className="rounded-full bg-[#0386FF] px-2 py-1 text-xs font-bold text-white">{chat.unreadCount}</span> : null}
    </article>
  );
}

function ContactRow({ contact }: { contact: ContactRecord }) {
  return (
    <article className="mb-2 flex min-h-[88px] items-center gap-4 rounded-xl border border-[#EEF2F7] bg-white px-4 shadow-sm">
      <Avatar label={contact.displayName} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-base font-semibold text-[#111827]">{contact.displayName}</div>
        <span className={`mt-2 inline-flex rounded-md border px-2 py-0.5 text-xs font-bold ${rolePillStyle(contact.role)}`}>{roleLabel(contact.role)}</span>
      </div>
    </article>
  );
}

function Avatar({ label }: { label: string }) {
  return (
    <span className="grid h-14 w-14 shrink-0 place-items-center rounded-xl border border-[#BAE6FD] bg-[#DFF1FF] text-lg font-bold text-[#0386FF]">
      {initialsFromName(label)}
    </span>
  );
}

function EmptyChatState({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="grid min-h-[580px] place-items-center">
      <div className="px-8 text-center">
        <div className="mx-auto grid h-[120px] w-[120px] place-items-center rounded-full border border-[#BFDBFE] bg-[#E7F3FF] text-[#0386FF]">
          <MessageSquare size={50} />
        </div>
        <h1 className="mt-8 text-xl font-semibold text-[#111827]">{title}</h1>
        <p className="mt-3 text-[15px] tracking-wide text-[#6B7280]">{subtitle}</p>
      </div>
    </div>
  );
}

function LoadingMessages() {
  return (
    <div className="grid min-h-[520px] place-items-center text-center">
      <div>
        <div className="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-[#DBEAFE] border-t-[#0386FF]" />
        <p className="mt-4 text-base font-medium text-[#64748B]">Loading messages...</p>
      </div>
    </div>
  );
}

function CreateGroupDialog({ onClose, contacts }: { onClose: () => void; contacts: ContactRecord[] }) {
  return (
    <div className="fixed inset-0 z-40 grid place-items-center bg-black/35 p-4" role="dialog" aria-modal="true" aria-label="Create Group">
      <section className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-2xl">
        <div className="flex items-center gap-3">
          <h2 className="flex-1 text-xl font-bold">Create Group</h2>
          <button type="button" aria-label="Close create group" onClick={onClose} className="grid h-9 w-9 place-items-center rounded-lg hover:bg-[#F8FAFC]">
            <X size={18} />
          </button>
        </div>
        <label className="mt-4 block text-sm font-semibold">
          Group name
          <input className="mt-2 h-11 w-full rounded-xl border border-[#CBD5E1] px-3 outline-none focus:border-[#0386FF]" placeholder="Enter group name" />
        </label>
        <div className="mt-4 max-h-56 overflow-auto rounded-xl border border-[#E5E7EB]">
          {contacts.slice(0, 8).map((contact) => (
            <label key={contact.id} className="flex items-center gap-3 border-b border-[#F1F5F9] px-3 py-3 text-sm last:border-b-0">
              <input type="checkbox" className="h-5 w-5 accent-[#0386FF]" />
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold">{contact.displayName}</span>
                <span className="block truncate text-xs text-[#64748B]">{contact.email || roleLabel(contact.role)}</span>
              </span>
            </label>
          ))}
        </div>
        <p className="mt-3 text-sm text-[#64748B]">Group creation is still completed in the Flutter workflow during this migration pass.</p>
        <button type="button" onClick={onClose} className="mt-5 min-h-11 w-full rounded-xl bg-[#0386FF] text-sm font-bold text-white">
          Done
        </button>
      </section>
    </div>
  );
}

function ChatAccessPrompt({ access }: { access: AccessState }) {
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
              ? "Sign in with an administrator account before opening chat."
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

async function loadChats(uid: string) {
  const [userChats, supportChats] = await Promise.all([
    getDocs(query(collection(db, "chats"), where("participants", "array-contains", uid), limit(80))).catch(() => null),
    getDocs(query(collection(db, "chats"), where("participants", "array-contains", "admin_support"), limit(80))).catch(() => null),
  ]);
  const seen = new Set<string>();
  const rows: ChatPreview[] = [];
  userChats?.docs.forEach((docSnap) => {
    const chat = normalizeChat(docSnap.id, docSnap.data() as Record<string, unknown>, uid, false);
    if (chat && !seen.has(chat.id)) {
      seen.add(chat.id);
      rows.push(chat);
    }
  });
  supportChats?.docs.forEach((docSnap) => {
    const chat = normalizeChat(docSnap.id, docSnap.data() as Record<string, unknown>, uid, true);
    if (chat && !seen.has(chat.id)) {
      seen.add(chat.id);
      rows.push(chat);
    }
  });
  return rows.sort((a, b) => (b.lastMessageTime?.getTime() ?? 0) - (a.lastMessageTime?.getTime() ?? 0));
}

async function loadContacts(uid: string) {
  const snap = await getDocs(query(collection(db, "users"), limit(180)));
  return snap.docs
    .map((docSnap) => normalizeContact(docSnap.id, docSnap.data() as Record<string, unknown>))
    .filter((contact) => contact.id !== uid && contact.displayName !== "Unknown User")
    .sort((a, b) => groupOrder.indexOf(a.group) - groupOrder.indexOf(b.group) || a.displayName.localeCompare(b.displayName));
}

function normalizeChat(id: string, data: Record<string, unknown>, uid: string, isSupport: boolean): ChatPreview | null {
  const last = objectValue(data.last_message);
  const lastMessage = stringValue(last.content ?? data.last_message_text ?? data.lastMessage);
  if (!lastMessage && !isSupport) return null;
  const participants = arrayOfStrings(data.participants);
  const fallbackName = isSupport ? "Admin Support" : participants.find((participant) => participant !== uid && participant !== "admin_support") || "Conversation";
  return {
    id,
    displayName: stringValue(data.group_name ?? data.name ?? data.displayName) || fallbackName,
    email: stringValue(data.email),
    lastMessage,
    lastMessageTime: dateValue(last.timestamp ?? data.last_message_time ?? data.updated_at),
    unreadCount: numberValue(data.unread_count),
    isGroup: data.is_group === true,
    isSupport,
  };
}

function normalizeContact(id: string, data: Record<string, unknown>): ContactRecord {
  const first = stringValue(data.first_name ?? data.firstName);
  const last = stringValue(data.last_name ?? data.lastName);
  const name = stringValue(data.name ?? data.display_name ?? data.displayName) || [first, last].filter(Boolean).join(" ");
  const role = stringValue(data.user_type ?? data.role).toLowerCase();
  return {
    id,
    displayName: name || stringValue(data.email ?? data["e-mail"]) || "Unknown User",
    email: stringValue(data.email ?? data["e-mail"]),
    role,
    group: groupForRole(role),
  };
}

function groupForRole(role: string) {
  if (role.includes("admin")) return "Administrators";
  if (role.includes("teacher")) return "Teachers";
  if (role.includes("student")) return "Students";
  if (role.includes("parent") || role.includes("guardian")) return "Parents";
  return "Other";
}

function roleLabel(role: string) {
  if (role.includes("admin")) return "Administrator";
  if (role.includes("teacher")) return "Teacher";
  if (role.includes("student")) return "Student";
  if (role.includes("parent")) return "Parent";
  if (role.includes("guardian")) return "Guardian";
  return role ? role.replace(/^./, (letter) => letter.toUpperCase()) : "User";
}

function rolePillStyle(role: string) {
  if (role.includes("admin")) return "border-[#FECACA] bg-[#FEF2F2] text-[#EF4444]";
  if (role.includes("teacher")) return "border-[#BFDBFE] bg-[#EFF6FF] text-[#0386FF]";
  if (role.includes("student")) return "border-[#BBF7D0] bg-[#F0FDF4] text-[#16A34A]";
  if (role.includes("parent")) return "border-[#FED7AA] bg-[#FFF7ED] text-[#F97316]";
  return "border-[#E5E7EB] bg-[#F8FAFC] text-[#64748B]";
}

function groupHeaderStyle(group: string) {
  if (group === "Administrators") return "bg-[#FEE2E2] text-[#EF4444]";
  if (group === "Teachers") return "bg-[#DBEAFE] text-[#0386FF]";
  if (group === "Students") return "bg-[#DCFCE7] text-[#16A34A]";
  if (group === "Parents") return "bg-[#FFEDD5] text-[#F97316]";
  return "bg-[#F1F5F9] text-[#64748B]";
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

function objectValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function arrayOfStrings(value: unknown) {
  return Array.isArray(value) ? value.map((item) => stringValue(item)).filter(Boolean) : [];
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function initialsFor(user: User | null) {
  return initialsFromName(user?.displayName || user?.email || "Admin");
}

function initialsFromName(source: string) {
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "?";
}
