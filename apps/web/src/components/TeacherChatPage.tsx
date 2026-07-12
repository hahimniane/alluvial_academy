"use client";

import { onAuthStateChanged, type User } from "firebase/auth";
import { addDoc, collection, doc, getDoc, getDocs, limit, onSnapshot, orderBy, query, serverTimestamp, setDoc, Timestamp, updateDoc, where, writeBatch } from "firebase/firestore";
import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, GraduationCap, Lock, Menu, MessageSquare, Mic, Paperclip, School, Search, Send, ShieldCheck, Shuffle, Square, Users } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { auth, db, storage } from "@/lib/firebase";
import { getCurrentUserRecord, isCurrentUserTeacher } from "@/lib/userRoles";
import { TeacherAccessPrompt, TeacherShell, openTeacherMobileMenu } from "@/components/TeacherDashboardHome";

type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type ChatTab = "recent" | "contacts";
type UserRecord = Record<string, unknown>;

type TeacherSummary = {
  displayName: string;
  firstName: string;
  initials: string;
};

type ChatPreview = {
  id: string;
  displayName: string;
  email: string;
  lastMessage: string;
  lastMessageTime: Date | null;
  unreadCount: number;
  isGroup: boolean;
  participants: string[];
};

type ContactRecord = {
  id: string;
  displayName: string;
  email: string;
  role: string;
  group: string;
};

type Conversation = {
  id: string;
  displayName: string;
  email: string;
  isGroup: boolean;
  isSupport: boolean;
  participants: string[];
};

type ChatMessageRecord = {
  id: string;
  senderId: string;
  senderName: string;
  content: string;
  timestamp: Date | null;
  messageType: string;
  metadata: Record<string, unknown>;
};

const groupOrder = ["Administrators", "Students", "Parents", "Teachers", "Other"];
const adminSupportId = "admin_support";

export function TeacherChatPage() {
  const [access, setAccess] = useState<AccessState>("checking");
  const [summary, setSummary] = useState<TeacherSummary>({ displayName: "Teacher", firstName: "Teacher", initials: "TE" });
  const [activeTab, setActiveTab] = useState<ChatTab>("recent");
  const [search, setSearch] = useState("");
  const [chats, setChats] = useState<ChatPreview[]>([]);
  const [contacts, setContacts] = useState<ContactRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<ChatMessageRecord[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [draft, setDraft] = useState("");
  const [sendError, setSendError] = useState("");
  const [sending, setSending] = useState(false);
  const [attachmentSending, setAttachmentSending] = useState(false);
  const requestedContactOpened = useRef("");

  useEffect(() => {
    let mounted = true;
    return onAuthStateChanged(auth, async (nextUser) => {
      if (!mounted) return;
      setUser(nextUser);
      setChats([]);
      setContacts([]);
      setConversation(null);
      setMessages([]);
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

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
        const [loadedChats, loadedContacts] = await Promise.all([loadTeacherChats(nextUser.uid), loadTeacherContacts(nextUser.uid)]);
        if (!mounted) return;
        setChats(loadedChats);
        setContacts(loadedContacts);
      } catch {
        if (mounted) {
          setChats([]);
          setContacts([]);
        }
      } finally {
        if (mounted) setLoading(false);
      }
    });
  }, []);

  useEffect(() => {
    if (access !== "allowed" || !user) return undefined;
    return subscribeTeacherChats(user.uid, setChats);
  }, [access, user]);

  useEffect(() => {
    const handlePopState = () => {
      if (!conversation) return;
      setConversation(null);
      setMessages([]);
      setDraft("");
      setSendError("");
    };
    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, [conversation]);

  useEffect(() => {
    if (!conversation) return undefined;
    setMessagesLoading(true);
    setSendError("");
    const messagesQuery = query(
      collection(db, "chats", conversation.id, "messages"),
      orderBy("timestamp", "desc"),
      limit(50),
    );
    return onSnapshot(
      messagesQuery,
      (snapshot) => {
        const nextMessages = snapshot.docs
          .map((entry) => normalizeMessage(entry.id, entry.data() as Record<string, unknown>))
          .filter((message) => message.content || message.messageType !== "text")
          .reverse();
        setMessages(nextMessages);
        setMessagesLoading(false);
      },
      () => {
        setMessages([]);
        setMessagesLoading(false);
        setSendError("Unable to load this conversation.");
      },
    );
  }, [conversation]);

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

  const openChat = async (chat: ChatPreview) => {
    setSendError("");
    openConversation({
      id: chat.id,
      displayName: chat.displayName,
      email: chat.email,
      isGroup: chat.isGroup,
      isSupport: false,
      participants: chat.participants,
    });
    if (user) {
      await markChatRead(chat.id, user.uid).catch(() => undefined);
      setChats((current) => current.map((item) => item.id === chat.id ? {...item, unreadCount: 0} : item));
    }
  };

  const openContact = async (contact: ContactRecord) => {
    if (!user) return;
    setSendError("");
    const chatId = directChatId(user.uid, contact.id);
    await ensureChat(chatId, [user.uid, contact.id], "individual");
    openConversation({
      id: chatId,
      displayName: contact.displayName,
      email: contact.email,
      isGroup: false,
      isSupport: false,
      participants: [user.uid, contact.id],
    });
    await markChatRead(chatId, user.uid).catch(() => undefined);
  };

  useEffect(() => {
    if (!user || !contacts.length || typeof window === "undefined") return;
    const requestedId = new URLSearchParams(window.location.search).get("contact")?.trim() ?? "";
    if (!requestedId || requestedContactOpened.current === requestedId) return;
    const contact = contacts.find((item) => item.id === requestedId);
    if (!contact) return;
    requestedContactOpened.current = requestedId;
    void openContact(contact);
  }, [contacts, user]);

  const openSupport = async () => {
    if (!user) return;
    setSendError("");
    const chatId = directChatId(user.uid, adminSupportId);
    await ensureChat(chatId, [user.uid, adminSupportId], "admin_support");
    openConversation({
      id: chatId,
      displayName: "Admin Support",
      email: "",
      isGroup: false,
      isSupport: true,
      participants: [user.uid, adminSupportId],
    });
    await markChatRead(chatId, user.uid).catch(() => undefined);
  };

  const openConversation = (nextConversation: Conversation) => {
    if (!conversation) window.history.pushState({teacherChatConversation: true}, "", window.location.href);
    setConversation(nextConversation);
  };

  const sendMessage = async () => {
    const content = draft.trim();
    if (!user || !conversation || !content || sending) return;
    setSending(true);
    setSendError("");
    setDraft("");
    try {
      await sendChatMessage({
        chatId: conversation.id,
        currentUser: user,
        senderName: summary.displayName,
        content,
        participants: conversation.participants,
        chatType: conversation.isSupport ? "admin_support" : conversation.isGroup ? "group" : "individual",
      });
      setChats((current) => mergeSentPreview(current, conversation, content));
    } catch {
      setDraft(content);
      setSendError("Message could not be sent. Please try again.");
    } finally {
      setSending(false);
    }
  };

  const sendAttachment = async (file: File, duration = 0) => {
    if (!user || !conversation || attachmentSending) return;
    setAttachmentSending(true);
    setSendError("");
    try {
      const messageType = file.type.startsWith("image/") ? "image" : file.type.startsWith("video/") ? "video" : file.type.startsWith("audio/") ? "voice" : "file";
      const folder = messageType === "image" ? "chat_images" : messageType === "video" ? "chat_videos" : messageType === "voice" ? "chat_voice" : "chat_files";
      const fileName = `${Date.now()}_${safeChatFileName(file.name || `${messageType}.webm`)}`;
      const storageRef = ref(storage, `${folder}/${user.uid}/${fileName}`);
      await uploadBytes(storageRef, file, {contentType: file.type || undefined});
      const fileUrl = await getDownloadURL(storageRef);
      const content = messageType === "image" ? "📷 Photo" : messageType === "video" ? "🎥 Video" : messageType === "voice" ? "🎤 Voice message" : `📎 ${file.name}`;
      await sendChatMessage({
        chatId: conversation.id,
        currentUser: user,
        senderName: summary.displayName,
        content,
        participants: conversation.participants,
        chatType: conversation.isSupport ? "admin_support" : conversation.isGroup ? "group" : "individual",
        messageType,
        metadata: {file_url: fileUrl, file_name: file.name || fileName, file_size: file.size, mime_type: file.type, ...(duration ? {duration} : {})},
      });
      setChats((current) => mergeSentPreview(current, conversation, content));
    } catch {
      setSendError("Attachment could not be sent. Please try again.");
    } finally {
      setAttachmentSending(false);
    }
  };

  if (access !== "allowed") return <TeacherAccessPrompt access={access} />;

  return (
    <TeacherShell activeLabel="Chat" breadcrumb="Communication / Chat" summary={summary}>
      <main className="relative min-h-[calc(100vh-56px)] bg-white text-[#111827]">
        <MobileTeacherTopBar summary={summary} />

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

        <section className="min-h-[calc(100vh-245px)] pb-10">
          {loading ? (
            <LoadingMessages />
          ) : activeTab === "recent" ? (
            <RecentChats chats={filteredChats} search={search} onOpen={openChat} />
          ) : (
            <ContactsList groups={groupedContacts} search={search} onOpen={openContact} onOpenSupport={openSupport} />
          )}
        </section>

        {conversation ? (
          <ConversationPanel
            conversation={conversation}
            messages={messages}
            currentUserId={user?.uid ?? ""}
            loading={messagesLoading}
            draft={draft}
            sending={sending}
            error={sendError}
            attachmentSending={attachmentSending}
            onDraftChange={setDraft}
            onClose={() => window.history.back()}
            onSend={sendMessage}
            onAttachment={sendAttachment}
          />
        ) : null}
      </main>
    </TeacherShell>
  );
}

function MobileTeacherTopBar({ summary }: { summary: TeacherSummary }) {
  return (
    <header className="grid min-h-[64px] grid-cols-[48px_1fr_80px] items-center bg-white px-3 lg:hidden">
      <button type="button" aria-label="Open teacher menu" onClick={openTeacherMobileMenu} className="grid h-11 w-11 place-items-center rounded-xl text-[#111827]">
        <Menu size={24} />
      </button>
      <div className="min-w-0 text-center text-[16px] font-semibold text-[#111827]">Alluwal Academy</div>
      <div className="flex items-center justify-end gap-3">
        <button type="button" aria-label="Open teacher account options" onClick={openTeacherMobileMenu} className="grid h-9 w-9 place-items-center rounded-xl text-[#111827]"><Shuffle size={17} /></button>
        <span className="grid h-8 w-8 place-items-center rounded-full bg-[#009688] text-[12px] font-black text-white">{summary.initials}</span>
      </div>
    </header>
  );
}

function ChatTabButton({ active, onClick, children }: { active: boolean; onClick: () => void; children: string }) {
  return (
    <button type="button" onClick={onClick} className={`min-h-9 rounded-lg text-sm font-semibold ${active ? "bg-white text-[#0386FF] shadow-sm" : "text-[#64748B]"}`}>
      {children}
    </button>
  );
}

function RecentChats({ chats, search, onOpen }: { chats: ChatPreview[]; search: string; onOpen: (chat: ChatPreview) => void }) {
  if (chats.length === 0) {
    return (
      <EmptyChatState
        title={search.trim() ? "No chats found" : "No conversations yet"}
        subtitle={search.trim() ? "Try a different search term" : "Start a conversation by browsing all users"}
      />
    );
  }

  return (
    <div className="px-3 py-2">
      {chats.map((chat) => (
        <ChatRow key={chat.id} chat={chat} onOpen={() => onOpen(chat)} />
      ))}
    </div>
  );
}

function ContactsList({
  groups,
  search,
  onOpen,
  onOpenSupport,
}: {
  groups: { group: string; contacts: ContactRecord[] }[];
  search: string;
  onOpen: (contact: ContactRecord) => void;
  onOpenSupport: () => void;
}) {
  const showSupport = !search.trim() || "admin support".includes(search.trim().toLowerCase());
  if (groups.length === 0 && !showSupport) {
    return <EmptyChatState title="No contacts match your search" subtitle="Try a different search term" />;
  }

  return (
    <div className="px-3 py-2">
      {showSupport ? (
        <>
          <div className="flex items-center gap-2 px-2 py-3">
            <span className="grid h-6 w-6 place-items-center rounded-md bg-[#FEE2E2] text-[#EF4444]">
              <ShieldCheck size={15} />
            </span>
            <h2 className="text-[13px] font-bold tracking-wide text-[#6B7280]">Support</h2>
          </div>
          <SupportContactRow onOpen={onOpenSupport} />
          {groups.length ? <div className="mx-4 my-3 border-t border-[#E5E7EB]" /> : null}
        </>
      ) : null}
      {groups.map(({ group, contacts }) => (
        <div key={group}>
          <div className="flex items-center gap-2 px-2 py-3">
            <span className={`grid h-6 w-6 place-items-center rounded-md text-xs ${groupHeaderStyle(group)}`}>
              <GroupIcon group={group} />
            </span>
            <h2 className="text-[13px] font-bold tracking-wide text-[#6B7280]">{group}</h2>
            <span className="rounded-full bg-[#F1F5F9] px-2 py-0.5 text-xs font-semibold text-[#64748B]">{contacts.length}</span>
          </div>
          {contacts.map((contact) => (
            <ContactRow key={contact.id} contact={contact} onOpen={() => onOpen(contact)} />
          ))}
        </div>
      ))}
    </div>
  );
}

function SupportContactRow({ onOpen }: { onOpen: () => void }) {
  return (
    <button type="button" onClick={onOpen} className="mb-4 flex min-h-[64px] w-full items-center gap-4 rounded-xl border border-[#FECACA] bg-white px-4 text-left shadow-sm transition hover:border-[#EF4444] hover:bg-[#FEF2F2]">
      <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-[#EF4444] text-white">
        <ShieldCheck size={24} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-base font-semibold text-[#111827]">Admin Support</div>
        <div className="truncate text-sm text-[#6B7280]">Message the school administrators</div>
      </div>
      <span className="text-xl text-[#9CA3AF]">›</span>
    </button>
  );
}

function ChatRow({ chat, onOpen }: { chat: ChatPreview; onOpen: () => void }) {
  return (
    <button type="button" onClick={onOpen} className="mb-2 flex min-h-[78px] w-full items-center gap-4 rounded-xl border border-[#EEF2F7] bg-white px-4 text-left shadow-sm transition hover:border-[#BFDBFE] hover:bg-[#F8FBFF]">
      <Avatar label={chat.displayName} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-base font-semibold text-[#111827]">{chat.displayName}</div>
        <div className="truncate text-sm text-[#6B7280]">{chat.lastMessage || chat.email || (chat.isGroup ? "Group chat" : "Conversation")}</div>
      </div>
      {chat.unreadCount > 0 ? <span className="rounded-full bg-[#0386FF] px-2 py-1 text-xs font-bold text-white">{chat.unreadCount}</span> : null}
    </button>
  );
}

function ContactRow({ contact, onOpen }: { contact: ContactRecord; onOpen: () => void }) {
  return (
    <button type="button" onClick={onOpen} className="mb-2 flex min-h-[88px] w-full items-center gap-4 rounded-xl border border-[#EEF2F7] bg-white px-4 text-left shadow-sm transition hover:border-[#BFDBFE] hover:bg-[#F8FBFF]">
      <Avatar label={contact.displayName} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-base font-semibold text-[#111827]">{contact.displayName}</div>
        <span className={`mt-2 inline-flex rounded-md border px-2 py-0.5 text-xs font-bold ${rolePillStyle(contact.role)}`}>{roleLabel(contact.role)}</span>
      </div>
      <span className="text-xl text-[#9CA3AF]">›</span>
    </button>
  );
}

function ConversationPanel({
  conversation,
  messages,
  currentUserId,
  loading,
  draft,
  sending,
  error,
  attachmentSending,
  onDraftChange,
  onClose,
  onSend,
  onAttachment,
}: {
  conversation: Conversation;
  messages: ChatMessageRecord[];
  currentUserId: string;
  loading: boolean;
  draft: string;
  sending: boolean;
  error: string;
  attachmentSending: boolean;
  onDraftChange: (value: string) => void;
  onClose: () => void;
  onSend: () => void;
  onAttachment: (file: File, duration?: number) => Promise<void>;
}) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const recordingStartedAtRef = useRef(0);
  const chunksRef = useRef<Blob[]>([]);
  const [recording, setRecording] = useState(false);
  const [recordingError, setRecordingError] = useState("");

  const toggleRecording = async () => {
    if (recording) {
      recorderRef.current?.stop();
      setRecording(false);
      return;
    }
    try {
      setRecordingError("");
      const stream = await navigator.mediaDevices.getUserMedia({audio: true});
      const recorder = new MediaRecorder(stream);
      chunksRef.current = [];
      recorder.ondataavailable = (event) => { if (event.data.size) chunksRef.current.push(event.data); };
      recorder.onstop = () => {
        const duration = Math.max(1, Math.round((Date.now() - recordingStartedAtRef.current) / 1000));
        const mimeType = recorder.mimeType || "audio/webm";
        const file = new File(chunksRef.current, `voice_${Date.now()}.webm`, {type: mimeType});
        stream.getTracks().forEach((track) => track.stop());
        void onAttachment(file, duration);
      };
      recorderRef.current = recorder;
      recordingStartedAtRef.current = Date.now();
      recorder.start();
      setRecording(true);
    } catch {
      setRecording(false);
      setRecordingError("Microphone access is required to record a voice message.");
    }
  };
  return (
    <aside className="fixed inset-0 z-40 flex bg-white lg:left-auto lg:w-[460px] lg:border-l lg:border-[#E5E7EB] lg:shadow-2xl">
      <div className="flex min-h-0 w-full flex-col">
        <header className="flex min-h-[72px] items-center gap-3 border-b border-[#E5E7EB] bg-white px-4">
          <button type="button" onClick={onClose} aria-label="Back to chats" className="grid h-10 w-10 place-items-center rounded-xl text-[#334155] hover:bg-[#F1F5F9]">
            <ArrowLeft size={21} />
          </button>
          <Avatar label={conversation.displayName} />
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-base font-bold text-[#111827]">{conversation.displayName}</h2>
            <p className="truncate text-sm text-[#64748B]">{conversation.isSupport ? "School administrators" : conversation.email || (conversation.isGroup ? "Group chat" : "Conversation")}</p>
          </div>
        </header>

        <div className="min-h-0 flex-1 overflow-y-auto bg-[#F8FAFC] px-4 py-5">
          {loading ? (
            <div className="grid h-full min-h-[360px] place-items-center text-sm font-semibold text-[#64748B]">Loading conversation...</div>
          ) : messages.length === 0 ? (
            <div className="grid h-full min-h-[360px] place-items-center text-center">
              <div>
                <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-[#DBEAFE] text-[#0386FF]">
                  <MessageSquare size={28} />
                </div>
                <h3 className="mt-4 text-base font-bold text-[#111827]">No messages yet</h3>
                <p className="mt-2 text-sm text-[#64748B]">Send a message to begin chatting with {conversation.displayName}.</p>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              {messages.map((message) => (
                <MessageBubble key={message.id} message={message} mine={message.senderId === currentUserId} />
              ))}
            </div>
          )}
        </div>

        <footer className="border-t border-[#E5E7EB] bg-white p-4">
          {error ? <p className="mb-2 rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{error}</p> : null}
          {recordingError ? <p className="mb-2 rounded-lg bg-[#FEF2F2] px-3 py-2 text-sm font-semibold text-[#DC2626]">{recordingError}</p> : null}
          <div className="flex items-end gap-2">
            <input ref={fileInputRef} type="file" className="sr-only" aria-label="Attach a file" onChange={(event) => { const file = event.target.files?.[0]; event.target.value = ""; if (file) void onAttachment(file); }} />
            <button type="button" aria-label="Attach file" onClick={() => fileInputRef.current?.click()} disabled={attachmentSending || recording} className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl border border-[#E5E7EB] text-[#475569] disabled:opacity-50"><Paperclip size={20} /></button>
            <button type="button" aria-label={recording ? "Stop voice recording" : "Record voice message"} onClick={() => void toggleRecording()} disabled={attachmentSending} className={`grid h-12 w-12 shrink-0 place-items-center rounded-2xl border ${recording ? "border-red-300 bg-red-50 text-red-600" : "border-[#E5E7EB] text-[#475569]"} disabled:opacity-50`}>
              {recording ? <Square size={17} fill="currentColor" /> : <Mic size={20} />}
            </button>
            <textarea
              value={draft}
              onChange={(event) => onDraftChange(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  onSend();
                }
              }}
              placeholder="Type a message..."
              aria-label="Type a message"
              rows={1}
              className="max-h-32 min-h-12 flex-1 resize-none rounded-2xl border border-[#E5E7EB] bg-[#F8FAFC] px-4 py-3 text-sm text-[#111827] outline-none focus:border-[#0386FF] focus:ring-2 focus:ring-[#BFDBFE]"
            />
            <button
              type="button"
              onClick={onSend}
              disabled={sending || !draft.trim()}
              aria-label="Send message"
              className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-[#0386FF] text-white shadow-sm disabled:cursor-not-allowed disabled:bg-[#BFDBFE]"
            >
              <Send size={20} />
            </button>
          </div>
        </footer>
      </div>
    </aside>
  );
}

function MessageBubble({ message, mine }: { message: ChatMessageRecord; mine: boolean }) {
  const fileUrl = stringValue(message.metadata.file_url ?? message.metadata.fileUrl);
  const fileName = stringValue(message.metadata.file_name ?? message.metadata.fileName) || "Attachment";
  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div className={`max-w-[82%] rounded-2xl px-4 py-3 shadow-sm ${mine ? "rounded-br-md bg-[#0386FF] text-white" : "rounded-bl-md bg-white text-[#111827]"}`}>
        {!mine ? <p className="mb-1 text-xs font-bold text-[#64748B]">{message.senderName || "Sender"}</p> : null}
        {message.messageType === "image" && fileUrl ? <img src={fileUrl} alt={message.content || fileName} className="mb-2 max-h-64 w-full rounded-xl object-contain" /> : null}
        {message.messageType === "video" && fileUrl ? <video src={fileUrl} controls className="mb-2 max-h-64 w-full rounded-xl" /> : null}
        {message.messageType === "voice" && fileUrl ? <audio src={fileUrl} controls className="mb-2 max-w-full" /> : null}
        {message.messageType === "file" && fileUrl ? <a href={fileUrl} target="_blank" rel="noreferrer" className={`mb-2 block rounded-lg px-3 py-2 text-sm font-bold underline ${mine ? "bg-white/15" : "bg-[#EFF6FF] text-[#0369A1]"}`}>{fileName}</a> : null}
        <p className="whitespace-pre-wrap text-sm leading-6">{message.content}</p>
        <p className={`mt-1 text-right text-[11px] ${mine ? "text-white/75" : "text-[#94A3B8]"}`}>{message.timestamp ? shortMessageTime(message.timestamp) : "Sending..."}</p>
      </div>
    </div>
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

function GroupIcon({ group }: { group: string }) {
  const Icon = iconForGroup(group);
  return <Icon size={15} />;
}

async function loadTeacherChats(uid: string) {
  const snap = await getDocs(query(collection(db, "chats"), where("participants", "array-contains", uid), limit(80))).catch(() => null);
  const rows: ChatPreview[] = [];
  snap?.docs.forEach((docSnap) => {
    const chat = normalizeChat(docSnap.id, docSnap.data() as Record<string, unknown>, uid);
    if (chat) rows.push(chat);
  });
  const withUnread = await Promise.all(rows.map(async (chat) => ({...chat, unreadCount: await loadUnreadCount(chat.id, uid)})));
  return withUnread.sort((a, b) => (b.lastMessageTime?.getTime() ?? 0) - (a.lastMessageTime?.getTime() ?? 0));
}

function subscribeTeacherChats(uid: string, onChange: (chats: ChatPreview[]) => void) {
  let revision = 0;
  return onSnapshot(
    query(collection(db, "chats"), where("participants", "array-contains", uid), limit(80)),
    async (snapshot) => {
      const currentRevision = ++revision;
      const rows = snapshot.docs
        .map((entry) => normalizeChat(entry.id, entry.data() as Record<string, unknown>, uid))
        .filter((chat): chat is ChatPreview => chat !== null);
      const withUnread = await Promise.all(rows.map(async (chat) => ({...chat, unreadCount: await loadUnreadCount(chat.id, uid)})));
      if (currentRevision !== revision) return;
      onChange(withUnread.sort((a, b) => (b.lastMessageTime?.getTime() ?? 0) - (a.lastMessageTime?.getTime() ?? 0)));
    },
  );
}

async function loadUnreadCount(chatId: string, uid: string) {
  const unread = await getDocs(query(collection(db, "chats", chatId, "messages"), where("is_read", "==", false), limit(100))).catch(() => null);
  return unread?.docs.filter((entry) => {
    const data = entry.data() as Record<string, unknown>;
    return stringValue(data.sender_id ?? data.senderId) !== uid;
  }).length ?? 0;
}

async function markChatRead(chatId: string, uid: string) {
  const unread = await getDocs(query(collection(db, "chats", chatId, "messages"), where("is_read", "==", false), limit(100))).catch(() => null);
  const incoming = unread?.docs.filter((entry) => {
    const data = entry.data() as Record<string, unknown>;
    return stringValue(data.sender_id ?? data.senderId) !== uid;
  }) ?? [];
  if (incoming.length) {
    const batch = writeBatch(db);
    incoming.forEach((entry) => batch.update(entry.ref, {is_read: true}));
    await batch.commit();
  }
  await updateDoc(doc(db, "chats", chatId), {[`last_read_by.${uid}`]: serverTimestamp()}).catch(() => undefined);
}

async function loadTeacherContacts(uid: string) {
  const [adminContacts, relationshipContacts] = await Promise.all([loadAdminContacts(uid), loadRelationshipContacts(uid)]);
  const byId = new Map<string, ContactRecord>();
  [...adminContacts, ...relationshipContacts].forEach((contact) => {
    if (contact.id !== uid) byId.set(contact.id, contact);
  });
  return Array.from(byId.values()).sort((a, b) => groupOrder.indexOf(a.group) - groupOrder.indexOf(b.group) || a.displayName.localeCompare(b.displayName));
}

async function loadAdminContacts(uid: string) {
  const [admins, superAdmins] = await Promise.all([
    getDocs(query(collection(db, "users"), where("user_type", "==", "admin"), limit(50))).catch(() => null),
    getDocs(query(collection(db, "users"), where("user_type", "==", "super_admin"), limit(50))).catch(() => null),
  ]);
  const rows: ContactRecord[] = [];
  admins?.docs.forEach((docSnap) => rows.push(normalizeContact(docSnap.id, docSnap.data() as Record<string, unknown>)));
  superAdmins?.docs.forEach((docSnap) => rows.push(normalizeContact(docSnap.id, docSnap.data() as Record<string, unknown>)));
  return rows.filter((contact) => contact.id !== uid);
}

async function loadRelationshipContacts(uid: string) {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const [snake, camel] = await Promise.all([
    getDocs(query(collection(db, "teaching_shifts"), where("teacher_id", "==", uid), limit(120))).catch(() => null),
    getDocs(query(collection(db, "teaching_shifts"), where("teacherId", "==", uid), limit(120))).catch(() => null),
  ]);
  const studentIds = new Set<string>();
  [snake, camel].forEach((snap) => {
    snap?.docs.forEach((entry) => {
      const data = entry.data() as Record<string, unknown>;
      if (stringValue(data.status).toLowerCase() === "cancelled") return;
      const shiftEnd = dateValue(data.shift_end ?? data.shiftEnd ?? data.end);
      if (shiftEnd && shiftEnd < cutoff) return;
      arrayOfStrings(data.student_ids ?? data.studentIds).forEach((studentId) => studentIds.add(studentId));
    });
  });

  const rows: ContactRecord[] = [];
  const parentIds = new Set<string>();
  for (const studentId of studentIds) {
    const studentSnap = await getDoc(doc(db, "users", studentId)).catch(() => null);
    if (!studentSnap?.exists()) continue;
    const student = normalizeContact(studentSnap.id, studentSnap.data() as Record<string, unknown>);
    rows.push(student);
    arrayOfStrings((studentSnap.data() as Record<string, unknown>).guardian_ids ?? (studentSnap.data() as Record<string, unknown>).guardianIds).forEach((parentId) => parentIds.add(parentId));
  }

  for (const parentId of parentIds) {
    const parentSnap = await getDoc(doc(db, "users", parentId)).catch(() => null);
    if (!parentSnap?.exists()) continue;
    rows.push(normalizeContact(parentSnap.id, parentSnap.data() as Record<string, unknown>));
  }

  return rows;
}

async function ensureChat(chatId: string, participants: string[], chatType: string) {
  const chatRef = doc(db, "chats", chatId);
  const existing = await getDoc(chatRef);
  if (existing.exists()) {
    const data = existing.data() as Record<string, unknown>;
    const storedParticipants = arrayOfStrings(data.participants);
    if (chatType === "admin_support" && (!storedParticipants.includes(adminSupportId) || data.chat_type !== "admin_support")) {
      await updateDoc(chatRef, { participants, chat_type: "admin_support", updated_at: serverTimestamp() });
    }
    return;
  }
  await setDoc(chatRef, {
    participants,
    chat_type: chatType,
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  });
}

async function sendChatMessage({
  chatId,
  currentUser,
  senderName,
  content,
  participants,
  chatType,
  messageType = "text",
  metadata = null,
}: {
  chatId: string;
  currentUser: User;
  senderName: string;
  content: string;
  participants: string[];
  chatType: string;
  messageType?: string;
  metadata?: Record<string, unknown> | null;
}) {
  if (!navigator.onLine) throw new Error("You appear to be offline. Reconnect and try again.");
  const chatRef = doc(db, "chats", chatId);
  const messageData = {
    sender_id: currentUser.uid,
    sender_name: senderName || currentUser.email || "Unknown",
    sender_profile_picture: currentUser.photoURL || null,
    content,
    timestamp: serverTimestamp(),
    is_read: false,
    message_type: messageType,
    metadata,
  };

  const existing = await getDoc(chatRef);
  if (!existing.exists()) {
    await setDoc(chatRef, {
      participants,
      chat_type: chatType,
      created_at: serverTimestamp(),
      updated_at: serverTimestamp(),
      last_message: messageData,
    });
  } else {
    await updateDoc(chatRef, {
      updated_at: serverTimestamp(),
      last_message: messageData,
    });
  }
  await addDoc(collection(db, "chats", chatId, "messages"), messageData);
}

function normalizeChat(id: string, data: Record<string, unknown>, uid: string): ChatPreview | null {
  const participants = arrayOfStrings(data.participants);
  if (participants.includes("admin_support")) return null;
  const last = objectValue(data.last_message);
  const lastMessage = stringValue(last.content ?? data.last_message_text ?? data.lastMessage);
  if (!lastMessage) return null;
  const fallbackName = participants.find((participant) => participant !== uid) || "Conversation";
  return {
    id,
    displayName: stringValue(data.group_name ?? data.name ?? data.displayName) || fallbackName,
    email: stringValue(data.email),
    lastMessage,
    lastMessageTime: dateValue(last.timestamp ?? data.last_message_time ?? data.updated_at),
    unreadCount: numberValue(data.unread_count),
    isGroup: data.chat_type === "group" || data.is_group === true,
    participants,
  };
}

function normalizeMessage(id: string, data: Record<string, unknown>): ChatMessageRecord {
  return {
    id,
    senderId: stringValue(data.sender_id ?? data.senderId),
    senderName: stringValue(data.sender_name ?? data.senderName),
    content: stringValue(data.content),
    timestamp: dateValue(data.timestamp),
    messageType: stringValue(data.message_type ?? data.messageType) || "text",
    metadata: objectValue(data.metadata),
  };
}

function safeChatFileName(value: string) {
  return value.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(-120) || "attachment";
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

function iconForGroup(group: string): LucideIcon {
  if (group === "Administrators") return ShieldCheck;
  if (group === "Students") return GraduationCap;
  if (group === "Parents") return Users;
  if (group === "Teachers") return School;
  return Users;
}

function groupForRole(role: string) {
  if (role.includes("admin") || role === "super_admin") return "Administrators";
  if (role.includes("student")) return "Students";
  if (role.includes("parent") || role.includes("guardian")) return "Parents";
  if (role.includes("teacher")) return "Teachers";
  return "Other";
}

function roleLabel(role: string) {
  if (role.includes("admin") || role === "super_admin") return "Administrator";
  if (role.includes("teacher")) return "Teacher";
  if (role.includes("student")) return "Student";
  if (role.includes("parent")) return "Parent";
  if (role.includes("guardian")) return "Guardian";
  return role ? role.replace(/^./, (letter) => letter.toUpperCase()) : "User";
}

function rolePillStyle(role: string) {
  if (role.includes("admin") || role === "super_admin") return "border-[#FECACA] bg-[#FEF2F2] text-[#EF4444]";
  if (role.includes("teacher")) return "border-[#BFDBFE] bg-[#EFF6FF] text-[#0386FF]";
  if (role.includes("student")) return "border-[#BBF7D0] bg-[#F0FDF4] text-[#16A34A]";
  if (role.includes("parent")) return "border-[#FED7AA] bg-[#FFF7ED] text-[#F97316]";
  return "border-[#E5E7EB] bg-[#F8FAFC] text-[#64748B]";
}

function groupHeaderStyle(group: string) {
  if (group === "Administrators") return "bg-[#FEE2E2] text-[#EF4444]";
  if (group === "Students") return "bg-[#DCFCE7] text-[#16A34A]";
  if (group === "Parents") return "bg-[#FFEDD5] text-[#F97316]";
  if (group === "Teachers") return "bg-[#DBEAFE] text-[#0386FF]";
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
  if (Array.isArray(value)) return value.map((item) => stringValue(item)).filter(Boolean);
  const single = stringValue(value);
  return single ? [single] : [];
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function directChatId(a: string, b: string) {
  return [a, b].sort().join("_");
}

function mergeSentPreview(chats: ChatPreview[], conversation: Conversation, content: string) {
  const preview: ChatPreview = {
    id: conversation.id,
    displayName: conversation.displayName,
    email: conversation.email,
    lastMessage: content,
    lastMessageTime: new Date(),
    unreadCount: 0,
    isGroup: conversation.isGroup,
    participants: conversation.participants,
  };
  return [preview, ...chats.filter((chat) => chat.id !== conversation.id)];
}

function shortMessageTime(date: Date) {
  return new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit" }).format(date);
}

function initialsFromName(source: string) {
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "TE";
}
