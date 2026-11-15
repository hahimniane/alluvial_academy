"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronRight, Headset, Loader2, LogIn, MessageCircle, Search, SearchX, ShieldCheck, GraduationCap, Users, AlertCircle } from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { alpha } from "@/components/ParentUi";
import { useLocale } from "@/lib/i18n";
import { directChatId, displayName, initials, listTime, matchesSearch, roleColor, roleLabel, supportCardMatches, unreadLabel, type ChatPerson, type ChatRow } from "@/lib/parentChat";
import { ensureSupportChat, loadContacts, watchRecent, type ParentContacts } from "@/lib/parentChatData";
import { parentChatText, type ParentChatText } from "@/lib/parentChatText";
import { PARENT_ROUTES } from "@/lib/parentWeb";
import { useNow } from "@/components/ParentUi";

type Recent = { state: "loading" } | { state: "error"; denied: boolean } | { state: "ready"; rows: ChatRow[] };
type Contacts = { state: "loading" } | { state: "ready"; value: ParentContacts };

/**
 * Chat (ChatPage, C-400…C-416): "Recent" (every conversation the parent is in
 * that has a message, newest first, live) and "Contacts" (Admin Support, the
 * school's administrators and the children's teachers), one search box for
 * both. Opening a conversation goes to a full page, as Flutter pushes it.
 */
export default function ParentChatPage() {
  const session = useParentSession();
  const router = useRouter();
  const fr = useLocale() === "fr";
  const text = parentChatText(fr);
  const now = useNow(30_000);
  const [tab, setTab] = useState<"recent" | "contacts">("recent");
  const [search, setSearch] = useState("");
  const [recent, setRecent] = useState<Recent>({ state: "loading" });
  const [contacts, setContacts] = useState<Contacts>({ state: "loading" });
  const [openingSupport, setOpeningSupport] = useState(false);

  useEffect(
    () =>
      watchRecent(
        session.uid,
        (rows) => setRecent({ state: "ready", rows }),
        (denied) => setRecent({ state: "error", denied }),
      ),
    [session.uid],
  );

  useEffect(() => {
    let active = true;
    // Contact errors leave only the Admin Support card, as in Flutter (C-415).
    loadContacts(session.uid)
      .then((value) => active && setContacts({ state: "ready", value }))
      .catch(() => active && setContacts({ state: "ready", value: { admins: [], teachers: [] } }));
    return () => {
      active = false;
    };
  }, [session.uid]);

  const openRow = (row: ChatRow) => router.push(PARENT_ROUTES.conversation({ id: row.chatId, kind: row.kind, with: row.otherId ?? undefined }));
  const openPerson = (person: ChatPerson) => router.push(PARENT_ROUTES.conversation({ id: directChatId(session.uid, person.id), kind: "direct", with: person.id }));
  const openSupport = async () => {
    setOpeningSupport(true);
    // Flutter logs a failed create and opens the thread anyway (C-412).
    const id = await ensureSupportChat(session.uid).catch(() => null);
    router.push(PARENT_ROUTES.conversation({ id: id ?? `${session.uid}_admin_support`, kind: "support" }));
  };

  return (
    <div className="flex min-h-full flex-col bg-white">
      <div className="border-b border-[#F5F5F5] bg-white px-4 py-2">
        <div className="flex rounded-[10px] bg-[#F1F5F9] p-1" role="tablist">
          {(["recent", "contacts"] as const).map((key) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={tab === key}
              onClick={() => setTab(key)}
              className={`h-9 flex-1 rounded-lg text-sm ${tab === key ? "bg-white font-semibold text-[#0386FF] shadow-[0_1px_4px_rgba(0,0,0,0.05)]" : "font-medium text-[#64748B]"}`}
            >
              {key === "recent" ? text.recent : text.contacts}
            </button>
          ))}
        </div>
      </div>
      <div className="px-4 py-3">
        <label className="flex h-12 items-center gap-3 rounded-xl border border-transparent bg-[#F3F4F6] px-3 focus-within:border-[1.5px] focus-within:border-[#0386FF]">
          <Search size={22} className="shrink-0 text-[#9CA3AF]" />
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={text.search}
            aria-label={text.search}
            className="min-w-0 flex-1 bg-transparent text-[15px] text-[#111827] outline-none placeholder:text-[#9CA3AF]"
          />
        </label>
      </div>
      <div className="flex-1">
        {tab === "recent" ? (
          <RecentList recent={recent} search={search} now={now} text={text} onOpen={openRow} />
        ) : (
          <ContactsList contacts={contacts} search={search} text={text} onPerson={openPerson} onSupport={() => void openSupport()} busy={openingSupport} />
        )}
      </div>
    </div>
  );
}

function EmptyState({ icon: Icon, title, body }: { icon: typeof Search; title: string; body: string }) {
  return (
    <div className="flex flex-col items-center px-8 py-16 text-center">
      <span className="grid h-20 w-20 place-items-center rounded-full bg-[#F1F5F9] text-[#94A3B8]">
        <Icon size={36} />
      </span>
      <p className="mt-4 text-lg font-semibold text-[#111827]">{title}</p>
      <p className="mt-1.5 max-w-xs text-sm text-[#64748B]">{body}</p>
    </div>
  );
}

function RecentList({ recent, search, now, text, onOpen }: { recent: Recent; search: string; now: Date; text: ParentChatText; onOpen: (row: ChatRow) => void }) {
  if (recent.state === "loading") {
    return (
      <div className="flex flex-col items-center gap-3 py-16 text-sm text-[#64748B]" role="status">
        <Loader2 size={32} className="animate-spin text-[#0386FF]" />
        {text.loading}
      </div>
    );
  }
  if (recent.state === "error") {
    return recent.denied ? <EmptyState icon={LogIn} title="Access denied" body="Please sign in to view chats" /> : <EmptyState icon={AlertCircle} title={text.wentWrong} body="Error loading chats" />;
  }
  const rows = recent.rows.filter((row) => matchesSearch({ title: row.title, email: row.email, id: row.otherId ?? row.chatId, phone: row.phone }, search));
  if (recent.rows.length === 0) return <EmptyState icon={MessageCircle} title={text.noConversations} body={text.noConversationsBody} />;
  if (rows.length === 0) return <EmptyState icon={SearchX} title={text.noChats} body={text.tryDifferent} />;
  return (
    <ul className="pb-4">
      {rows.map((row) => (
        <li key={row.chatId}>
          <ChatRowItem row={row} now={now} text={text} onOpen={() => onOpen(row)} />
        </li>
      ))}
    </ul>
  );
}

/** ChatUserListItem (C-405). */
export function PersonAvatar({ name, email, picture, group = false, online = false, size = 56 }: { name: string; email: string; picture: string | null; group?: boolean; online?: boolean; size?: number }) {
  const color = group ? "#059669" : "#0386FF";
  const [broken, setBroken] = useState(false);
  return (
    <span className="relative shrink-0" style={{ width: size, height: size }}>
      <span
        className="grid h-full w-full place-items-center overflow-hidden rounded-2xl border-[1.5px]"
        style={{ backgroundColor: alpha(color, 0.1), borderColor: alpha(color, 0.15), borderRadius: size >= 56 ? 16 : 14 }}
      >
        {group ? (
          <Users size={size >= 56 ? 28 : 22} style={{ color }} />
        ) : picture && !broken ? (
          <img src={picture} alt="" className="h-full w-full object-cover" onError={() => setBroken(true)} />
        ) : (
          <span className="font-bold" style={{ color, fontSize: size >= 56 ? 20 : 16 }}>
            {initials({ name, email })}
          </span>
        )}
      </span>
      {online && !group ? <span className="absolute right-0.5 bottom-0.5 h-4 w-4 rounded-full border-[2.5px] border-white bg-[#10B981]" aria-label="Online" /> : null}
    </span>
  );
}

function ChatRowItem({ row, now, text, onOpen }: { row: ChatRow; now: Date; text: ParentChatText; onOpen: () => void }) {
  const isGroup = row.kind === "group";
  const color = roleColor(row.role);
  return (
    <button
      type="button"
      onClick={onOpen}
      className="mx-2 my-1 flex w-[calc(100%-16px)] items-center gap-4 rounded-2xl border border-[#F1F5F9] bg-white p-4 text-left shadow-[0_2px_8px_rgba(0,0,0,0.02)] hover:bg-[#FAFCFF]"
    >
      <PersonAvatar name={row.title} email={row.email} picture={row.picture} group={isGroup} online={row.isOnline} />
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2">
          <span className="min-w-0 flex-1 truncate text-base leading-tight font-semibold text-[#111827]">{row.title}</span>
          {row.unread > 0 ? (
            <span className="min-w-6 shrink-0 rounded-xl bg-gradient-to-b from-[#0386FF] to-[#0366D6] px-2 py-1 text-center text-[11px] font-bold text-white shadow-[0_2px_4px_rgba(3,134,255,0.3)]">
              {unreadLabel(row.unread)}
            </span>
          ) : null}
        </span>
        <span className="mt-1 flex items-center gap-2">
          {isGroup ? (
            <>
              <span className="rounded-md border border-[#059669]/20 bg-[#059669]/10 px-2 py-0.5 text-[11px] font-semibold text-[#059669]">{text.groupChat}</span>
              <span className="rounded bg-[#6B7280]/10 px-1.5 py-0.5 text-[10px] font-medium text-[#6B7280]">{row.memberCount} members</span>
            </>
          ) : row.role ? (
            <span className="rounded-md border px-2 py-0.5 text-[11px] font-semibold" style={{ color, backgroundColor: alpha(color, 0.1), borderColor: alpha(color, 0.2) }}>
              {roleLabel(row.role, row.jobTitle)}
            </span>
          ) : (
            <span className="truncate text-[13px] text-[#64748B]">{row.email}</span>
          )}
        </span>
        {row.preview ? (
          <span className="mt-2 flex items-start gap-3">
            <span className="line-clamp-2 min-w-0 flex-1 text-sm leading-[1.3] text-[#64748B]">{row.preview}</span>
            {row.time ? <span className="shrink-0 rounded-md border border-[#E2E8F0] bg-[#F8FAFC] px-1.5 py-0.5 text-[11px] font-medium text-[#94A3B8]">{listTime(row.time, now)}</span> : null}
          </span>
        ) : null}
      </span>
    </button>
  );
}

function GroupHeader({ title, count, icon: Icon, color }: { title: string; count?: number; icon: typeof Users; color: string }) {
  return (
    <div className="flex items-center gap-2 px-2 pt-4 pb-2">
      <span className="grid place-items-center rounded-md p-1" style={{ backgroundColor: alpha(color, 0.1), color }}>
        <Icon size={16} />
      </span>
      <span className="text-[13px] font-semibold text-[#6B7280]">{title}</span>
      {count !== undefined ? <span className="rounded-[10px] bg-[#F1F5F9] px-2 py-0.5 text-xs font-medium text-[#64748B]">{count}</span> : null}
    </div>
  );
}

function ContactsList({
  contacts,
  search,
  text,
  onPerson,
  onSupport,
  busy,
}: {
  contacts: Contacts;
  search: string;
  text: ParentChatText;
  onPerson: (person: ChatPerson) => void;
  onSupport: () => void;
  busy: boolean;
}) {
  const showSupport = supportCardMatches(search);
  const groups = useMemo(() => {
    if (contacts.state !== "ready") return [];
    const filter = (people: ChatPerson[]) => people.filter((p) => matchesSearch({ title: displayName(p), email: p.email, id: p.id, phone: p.phone }, search));
    return [
      { title: "Administrators", icon: ShieldCheck, color: "#EF4444", people: filter(contacts.value.admins) },
      { title: "Teachers", icon: GraduationCap, color: "#0386FF", people: filter(contacts.value.teachers) },
    ].filter((g) => g.people.length > 0);
  }, [contacts, search]);
  const firstFocus = useRef<HTMLButtonElement>(null);

  if (contacts.state === "loading") {
    return (
      <div className="flex justify-center py-16" role="status" aria-label={text.loading}>
        <Loader2 size={32} className="animate-spin text-[#0386FF]" />
      </div>
    );
  }
  if (!showSupport && groups.length === 0) return <EmptyState icon={SearchX} title="No contacts match your search" body="Try a different search term" />;
  return (
    <div className="px-3 pt-2 pb-5">
      {showSupport ? (
        <>
          <div className="flex items-center gap-2 px-2 pt-2 pb-1">
            <span className="grid place-items-center rounded-md bg-[#EF4444]/10 p-1 text-[#EF4444]">
              <Headset size={16} />
            </span>
            <span className="text-[13px] font-semibold text-[#6B7280]">Support</span>
          </div>
          <button
            ref={firstFocus}
            type="button"
            onClick={onSupport}
            disabled={busy}
            className="m-1 flex w-[calc(100%-8px)] items-center gap-4 rounded-xl border border-[#EF4444]/20 bg-white px-4 py-3 text-left hover:bg-[#FFF8F8]"
          >
            <span className="grid h-12 w-12 shrink-0 place-items-center rounded-3xl bg-gradient-to-br from-[#EF4444] to-[#DC2626] text-white">
              {busy ? <Loader2 size={22} className="animate-spin" /> : <Headset size={26} />}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block text-[15px] font-semibold text-[#111827]">Admin Support</span>
              <span className="block text-[13px] text-[#6B7280]">Message the school administrators</span>
            </span>
            <ChevronRight size={18} className="text-[#9CA3AF]" />
          </button>
        </>
      ) : null}
      {groups.map((group) => (
        <section key={group.title}>
          <GroupHeader title={group.title} count={group.people.length} icon={group.icon} color={group.color} />
          <ul>
            {group.people.map((person) => {
              const color = roleColor(person.role === "teacher" ? "teacher" : "admin");
              return (
                <li key={person.id}>
                  <button
                    type="button"
                    onClick={() => onPerson(person)}
                    className="mx-1 my-1 flex w-[calc(100%-8px)] items-center gap-4 rounded-2xl border border-[#F1F5F9] bg-white p-4 text-left shadow-[0_2px_8px_rgba(0,0,0,0.02)] hover:bg-[#FAFCFF]"
                  >
                    <PersonAvatar name={person.name} email={person.email} picture={person.profilePicture} online={person.isOnline} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-base font-semibold text-[#111827]">{displayName(person)}</span>
                      {person.role ? (
                        <span className="mt-1 inline-block rounded-md border px-2 py-0.5 text-[11px] font-semibold" style={{ color: roleColor(person.role), backgroundColor: alpha(roleColor(person.role), 0.1), borderColor: alpha(roleColor(person.role), 0.2) }}>
                          {roleLabel(person.role, person.jobTitle)}
                        </span>
                      ) : (
                        <span className="mt-1 block truncate text-[13px] text-[#64748B]" style={{ color }}>
                          {person.email}
                        </span>
                      )}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}
