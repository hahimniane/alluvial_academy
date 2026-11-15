"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from "react";
import {
  AlertCircle,
  ArrowLeft,
  Ban,
  Camera,
  Check,
  CheckCheck,
  Copy,
  CornerUpLeft,
  FileText,
  Forward,
  Image as ImageIcon,
  Info,
  Loader2,
  Lock,
  LogOut,
  MapPin,
  MessageCircle,
  MoreVertical,
  Pencil,
  Plus,
  Send,
  SmilePlus,
  Trash2,
  UserPlus,
  Users,
  Video,
  X,
  Eraser,
} from "lucide-react";
import { useParentSession } from "@/components/ParentArea";
import { PersonAvatar } from "@/components/ParentChatPage";
import { useLocale } from "@/lib/i18n";
import {
  ADMIN_SUPPORT_ID,
  DOCUMENT_EXTENSIONS,
  QUICK_REACTIONS,
  bubbleTime,
  canDeleteForEveryone,
  canEdit,
  displayName,
  fileSize,
  hiddenForMe,
  lastSeenText,
  mapsLink,
  nextReaction,
  parentCanMessage,
  personFromDoc,
  previewText,
  reactionCounts,
  relationshipBanner,
  roleLabel,
  splitMentions,
  teachesActively,
  type ChatMessage,
  type ChatPerson,
  type ChatRow,
} from "@/lib/parentChat";
import {
  clearForMe,
  deleteForEveryone,
  editMessage,
  fetchUser,
  forwardMessage,
  groupMembers,
  hideForMe,
  leaveGroup,
  loadChildShifts,
  markRead,
  otherHasWritten,
  sendFile,
  sendLocation,
  sendMessage,
  setBlocked,
  setReaction,
  watchChat,
  watchMessages,
  watchRecent,
  type Target,
} from "@/lib/parentChatData";
import { parentChatText, type ParentChatText } from "@/lib/parentChatText";
import { PARENT_ROUTES } from "@/lib/parentWeb";

type Kind = "direct" | "group" | "support";
type Toast = { text: string; tone: "ok" | "error" | "info"; undo?: () => void } | null;
type Permission = "checking" | "allowed" | "locked";

const MORE_EMOJIS = "😀 😃 😄 😁 😆 😅 🤣 😊 😇 🙂 😉 😍 🥰 😘 😋 😎 🤩 🥳 😏 😌 😴 🤔 🤗 🤭 😐 😶 🙄 😬 😔 😟 😕 🙁 😣 😫 😩 🥺 😭 😤 😠 😡 🤯 😳 😱 😨 😥 🤒 🤕 🤧 👏 🙌 👐 🤲 🤝 🙏 💪 👀 👋 ✌️ 🤞 👌 👆 👇 💯 🔥 ⭐ 🌟 ✨ 💫 🎈 🎁 🏆 📚 ✏️ 🕌 🌙 ☀️ 🌹 💐 💚 💙 💜 🧡 💛 🤍 ✅ ❌ ❓ ❗".split(" ");

/**
 * One conversation (ChatScreen + MessageBubble, C-417…C-453), as a full page
 * over the shell. 1:1, group and Admin Support threads share it.
 */
export default function ParentConversationPage() {
  const session = useParentSession();
  const router = useRouter();
  const params = useSearchParams();
  const chatId = params?.get("id") ?? "";
  const kind = (params?.get("kind") as Kind) || "direct";
  const withId = params?.get("with") ?? "";
  const fr = useLocale() === "fr";
  const text = parentChatText(fr);
  const uid = session.uid;

  const [other, setOther] = useState<{ person: ChatPerson; data: Record<string, unknown> } | null>(null);
  const [chat, setChat] = useState<Record<string, unknown> | null>(null);
  const [messages, setMessages] = useState<ChatMessage[] | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [permission, setPermission] = useState<Permission>(kind === "direct" ? "checking" : "allowed");
  const [teaches, setTeaches] = useState(false);
  const [inbound, setInbound] = useState(false);
  const [blocked, setBlockedState] = useState(false);
  const [members, setMembers] = useState<ChatPerson[]>([]);
  const [toast, setToast] = useState<Toast>(null);
  const [dialog, setDialog] = useState<ReactNode>(null);
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null);
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  const notify = useCallback((next: Toast) => setToast(next), []);
  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), toast.undo ? 5000 : 2500);
    return () => window.clearTimeout(timer);
  }, [toast]);

  // The other person (1:1) — read once, as Flutter freezes the header's presence.
  useEffect(() => {
    if (kind !== "direct" || !withId) return;
    let active = true;
    void fetchUser(withId).then((data) => {
      if (active && data) setOther({ person: personFromDoc(withId, data, new Date()), data });
    });
    return () => {
      active = false;
    };
  }, [kind, withId]);

  useEffect(() => (chatId ? watchChat(chatId, setChat) : undefined), [chatId]);

  useEffect(() => {
    if (!chatId) return;
    return watchMessages(
      chatId,
      (list) => setMessages(list),
      () => setLoadError(true),
    );
  }, [chatId]);

  // C-422: mark incoming messages read on open and on every new one.
  const unreadIncoming = useMemo(() => (messages ?? []).some((m) => !m.isRead && m.senderId !== uid && !hiddenForMe(m, uid)), [messages, uid]);
  useEffect(() => {
    if (chatId && unreadIncoming) void markRead(chatId, uid).catch(() => undefined);
  }, [chatId, uid, unreadIncoming]);
  useEffect(() => {
    if (chatId) void markRead(chatId, uid).catch(() => undefined);
  }, [chatId, uid]);

  // C-416: who the parent may message; inbound messages unlock the composer.
  useEffect(() => {
    if (kind !== "direct" || !withId) return;
    let active = true;
    void Promise.all([loadChildShifts(uid).catch(() => []), otherHasWritten(chatId, withId)]).then(([shifts, wrote]) => {
      if (!active) return;
      setTeaches(teachesActively(shifts, withId, new Date()));
      setInbound(wrote);
    });
    return () => {
      active = false;
    };
  }, [kind, withId, uid, chatId]);
  const wroteHere = (messages ?? []).some((m) => m.senderId === withId);
  useEffect(() => {
    if (kind !== "direct") return;
    if (!other) return;
    setPermission(parentCanMessage(other.data, teaches, inbound || wroteHere) ? "allowed" : "locked");
  }, [kind, other, teaches, inbound, wroteHere]);

  useEffect(() => {
    if (kind !== "direct" || !withId) return;
    void fetchUser(uid).then((me) => setBlockedState(((me?.blocked_users as unknown[]) ?? []).map(String).includes(withId)));
  }, [kind, withId, uid]);

  const participants = useMemo(() => {
    const stored = ((chat?.participants as unknown[]) ?? []).map(String);
    if (stored.length) return stored;
    if (kind === "support") return [uid, ADMIN_SUPPORT_ID];
    return [uid, withId].filter(Boolean);
  }, [chat, kind, uid, withId]);

  useEffect(() => {
    if (kind !== "group" || participants.length === 0) return;
    let active = true;
    void groupMembers(participants).then((list) => active && setMembers(list));
    return () => {
      active = false;
    };
  }, [kind, participants]);

  const target: Target = { chatId, kind, participants };
  const myName = session.displayName;
  const visible = useMemo(() => [...(messages ?? [])].filter((m) => !hiddenForMe(m, uid)).reverse(), [messages, uid]);

  const title = kind === "support" ? "Admin Support" : kind === "group" ? String(chat?.group_name ?? "") || "Unnamed Group" : other ? displayName(other.person) : "";
  const isGroupAdmin = kind === "group" && ((chat?.admin_ids as unknown[]) ?? []).map(String).includes(uid);

  const back = () => router.push(PARENT_ROUTES.chat);

  // ─── Actions ────────────────────────────────────────────────────────────
  const send = async (content: string) => {
    const reply = replyTo;
    setReplyTo(null);
    try {
      await sendMessage(target, uid, content, "text", reply ? { reply_to: { message_id: reply.id, content: reply.content, sender_name: reply.senderName } } : null);
      return true;
    } catch {
      setReplyTo(reply);
      notify({ text: "Message could not be sent. Please try again.", tone: "error" });
      return false;
    }
  };

  const openActions = (m: ChatMessage) => {
    if (m.type === "system") return;
    const mine = m.senderId === uid;
    setDialog(
      <MessageMenu
        message={m}
        text={text}
        canCopy={m.type === "text" && !m.deletedForEveryone}
        canEdit={canEdit(m, uid)}
        deleted={m.deletedForEveryone}
        onClose={() => setDialog(null)}
        onReact={() => setDialog(<ReactionSheet current={m.reactions[uid]} onPick={(e) => void react(m, e)} onClose={() => setDialog(null)} />)}
        onReply={() => {
          setReplyTo(m);
          setDialog(null);
        }}
        onCopy={async () => {
          setDialog(null);
          await navigator.clipboard.writeText(m.content).catch(() => undefined);
          notify({ text: text.copied, tone: "ok" });
        }}
        onForward={() => setDialog(<ForwardDialog uid={uid} currentChatId={chatId} message={m} text={text} onClose={() => setDialog(null)} onSend={(row) => void doForward(m, row)} />)}
        onEdit={() => setDialog(<EditDialog initial={m.content} onClose={() => setDialog(null)} onSave={(v) => void doEdit(m, v)} />)}
        onDelete={() =>
          setDialog(
            <DeleteSheet
              forEveryone={mine && canDeleteForEveryone(m, uid, new Date())}
              onClose={() => setDialog(null)}
              onForMe={() => void doHide(m)}
              onForEveryone={() => void doDeleteAll(m)}
            />,
          )
        }
      />,
    );
  };

  const react = async (m: ChatMessage, emoji: string) => {
    setDialog(null);
    try {
      await setReaction(chatId, m.id, uid, nextReaction(m.reactions[uid], emoji));
    } catch {
      notify({ text: "Failed to update reaction", tone: "error" });
    }
  };
  const doForward = async (m: ChatMessage, row: ChatRow) => {
    setDialog(null);
    try {
      await forwardMessage({ chatId: row.chatId, kind: row.kind, participants: row.participants }, uid, m, m.senderName);
      notify({ text: "Message forwarded", tone: "ok" });
    } catch {
      notify({ text: "Failed to forward message", tone: "error" });
    }
  };
  const doEdit = async (m: ChatMessage, value: string) => {
    setDialog(null);
    const trimmed = value.trim();
    if (!trimmed || trimmed === m.content) return;
    try {
      await editMessage(chatId, m, trimmed);
      notify({ text: "Message edited", tone: "ok" });
    } catch {
      notify({ text: "Failed to edit message", tone: "error" });
    }
  };
  const doHide = async (m: ChatMessage) => {
    setDialog(null);
    try {
      await hideForMe(chatId, m, uid, true);
      notify({ text: text.deletedForYou, tone: "info", undo: () => void hideForMe(chatId, m, uid, false) });
    } catch {
      notify({ text: "Could not delete this message.", tone: "error" });
    }
  };
  const doDeleteAll = async (m: ChatMessage) => {
    setDialog(null);
    try {
      await deleteForEveryone(chatId, m.id, uid, myName);
      notify({ text: "Message deleted", tone: "ok" });
    } catch {
      notify({ text: "Could not delete for everyone. The time limit may have expired.", tone: "error" });
    }
  };

  const menuItems: Array<{ key: string; label: string; icon: typeof Info; run: () => void; danger?: boolean }> = [
    {
      key: "clear",
      label: text.clearChat,
      icon: Eraser,
      run: () =>
        setDialog(
          <Confirm
            title={text.clearChat}
            body={text.clearChatConfirm}
            confirm={text.clear}
            danger
            onClose={() => setDialog(null)}
            onConfirm={async () => {
              setDialog(null);
              try {
                await clearForMe(chatId, uid);
                notify({ text: "Chat cleared", tone: "ok" });
              } catch {
                notify({ text: "Failed to clear chat", tone: "error" });
              }
            }}
          />,
        ),
    },
  ];
  if (kind === "direct" && withId) {
    menuItems.push({
      key: "block",
      label: blocked ? "Unblock User" : text.blockUser,
      icon: Ban,
      danger: !blocked,
      run: () =>
        setDialog(
          <Confirm
            title={blocked ? "Unblock User" : text.blockUser}
            body={blocked ? `Unblock ${title}? They will be able to message you again.` : `Are you sure you want to block ${title}? They will no longer be able to send you messages.`}
            confirm={blocked ? "Unblock" : text.block}
            danger={!blocked}
            onClose={() => setDialog(null)}
            onConfirm={async () => {
              setDialog(null);
              try {
                await setBlocked(uid, withId, !blocked);
                notify({ text: `${title} ${blocked ? "unblocked" : "blocked"}`, tone: "ok" });
                setBlockedState(!blocked);
              } catch {
                notify({ text: "Failed to block user", tone: "error" });
              }
            }}
          />,
        ),
    });
  }
  if (kind === "group") {
    menuItems.push(
      { key: "info", label: text.groupInfo, icon: Info, run: () => setDialog(<GroupInfo chat={chat} members={members} text={text} onClose={() => setDialog(null)} />) },
      { key: "edit", label: "Edit Group", icon: Pencil, run: () => notify({ text: "Only group administrators can edit group info", tone: "error" }) },
      { key: "add", label: text.addMembers, icon: UserPlus, run: () => notify({ text: "Only group administrators can add members", tone: "error" }) },
      { key: "members", label: "Manage Members", icon: Users, run: () => setDialog(<MembersDialog chat={chat} members={members} uid={uid} onClose={() => setDialog(null)} />) },
      {
        key: "leave",
        label: "Leave Group",
        icon: LogOut,
        danger: true,
        run: () =>
          setDialog(
            <Confirm
              title="Leave Group"
              body={`Are you sure you want to leave "${title}"? You will no longer receive messages from this group.`}
              confirm="Leave"
              danger
              onClose={() => setDialog(null)}
              onConfirm={async () => {
                setDialog(null);
                try {
                  await leaveGroup(chatId, uid, myName);
                  notify({ text: "You have left the group", tone: "ok" });
                  back();
                } catch {
                  notify({ text: "Failed to leave group", tone: "error" });
                }
              }}
            />,
          ),
      },
    );
  }

  // ─── Render ─────────────────────────────────────────────────────────────
  const banner = kind === "support" ? "Admin Support" : kind === "direct" ? relationshipBanner(other?.data ?? null, teaches, inbound || wroteHere) : null;

  return (
    <div className="flex h-screen flex-col bg-[#F8FAFC]">
      <Header kind={kind} title={title} other={other?.person ?? null} chat={chat} now={now} text={text} onBack={back} menu={menuItems} />
      <MessageList
        messages={visible}
        loading={messages === null && !loadError}
        error={loadError}
        uid={uid}
        kind={kind}
        title={title}
        now={now}
        text={text}
        onActions={openActions}
        onToggleReaction={(m, e) => void react(m, e)}
        onImage={(url) => setDialog(<ImageViewer url={url} onClose={() => setDialog(null)} />)}
        onVideo={(url, caption) => setDialog(<VideoViewer url={url} caption={caption} onClose={() => setDialog(null)} />)}
      />
      {banner ? (
        <div className="flex items-center gap-2 bg-[#F0F9FF] px-4 py-2 text-xs font-medium text-[#0369A1]">
          <Info size={14} />
          {banner}
        </div>
      ) : null}
      {kind === "direct" && blocked ? (
        <div className="border-t border-[#E5E7EB] bg-white px-4 py-4 text-center text-sm text-[#6B7280]">You blocked {title}. Unblock to resume the conversation.</div>
      ) : permission === "checking" ? (
        <div className="flex items-center gap-3 border-t border-[#E5E7EB] bg-white px-6 py-5 text-sm text-[#6B7280]">
          <Loader2 size={20} className="animate-spin text-[#0386FF]" />
          Checking chat permissions…
        </div>
      ) : permission === "locked" ? (
        <div className="flex items-center gap-3 border-t border-[#FECACA] bg-[#FEF2F2] p-4 text-sm text-[#DC2626]">
          <Lock size={20} className="shrink-0 text-[#EF4444]" />
          {text.relationshipOnly}
        </div>
      ) : (
        <Composer
          target={target}
          uid={uid}
          kind={kind}
          members={members}
          replyTo={replyTo}
          onCancelReply={() => setReplyTo(null)}
          onSend={send}
          notify={notify}
          setDialog={setDialog}
          text={text}
        />
      )}
      {dialog}
      {toast ? (
        <div
          role="status"
          className="fixed bottom-24 left-1/2 z-[130] flex -translate-x-1/2 items-center gap-4 rounded-lg px-4 py-3 text-sm text-white shadow-xl"
          style={{ backgroundColor: toast.tone === "ok" ? "#16A34A" : toast.tone === "error" ? "#DC2626" : "#323232" }}
        >
          {toast.text}
          {toast.undo ? (
            <button
              type="button"
              onClick={() => {
                toast.undo?.();
                setToast(null);
              }}
              className="font-bold text-[#90CAF9]"
            >
              Undo
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

// ─── Header (C-418) ────────────────────────────────────────────────────────

function Header({
  kind,
  title,
  other,
  chat,
  now,
  text,
  onBack,
  menu,
}: {
  kind: Kind;
  title: string;
  other: ChatPerson | null;
  chat: Record<string, unknown> | null;
  now: Date;
  text: ParentChatText;
  onBack: () => void;
  menu: Array<{ key: string; label: string; icon: typeof Info; run: () => void; danger?: boolean }>;
}) {
  const [open, setOpen] = useState(false);
  let status: ReactNode;
  if (kind === "group") {
    status = <span className="rounded border border-[#059669]/20 bg-[#059669]/10 px-1.5 py-0.5 text-[10px] font-semibold text-[#059669]">{String(chat?.group_description ?? "") || "Group chat"}</span>;
  } else if (kind === "support") {
    status = <span className="text-xs text-[#94A3B8]">{text.administrator}</span>;
  } else if (other?.isOnline) {
    status = <span className="rounded border border-[#10B981]/20 bg-[#10B981]/10 px-1.5 py-0.5 text-[10px] font-semibold text-[#10B981]">{text.online}</span>;
  } else if (other?.lastSeen) {
    status = <span className="text-xs text-[#94A3B8]">Last sent {lastSeenText(other.lastSeen, now)}</span>;
  } else {
    status = <span className="text-xs text-[#94A3B8]">{other?.role ? roleLabel(other.role, other.jobTitle) : "Offline"}</span>;
  }
  return (
    <header className="relative z-20 flex h-[72px] shrink-0 items-center gap-4 border-b border-[#F1F5F9] bg-white px-4">
      <button type="button" onClick={onBack} aria-label={text.close} className="grid h-10 w-10 place-items-center rounded-xl bg-[#F1F5F9] text-[#374151] hover:bg-[#E2E8F0]">
        <ArrowLeft size={22} />
      </button>
      {kind === "support" ? (
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-[14px] border-[1.5px] border-[#0386FF]/15 bg-[#0386FF]/10 text-base font-bold text-[#0386FF]">AS</span>
      ) : (
        <PersonAvatar name={kind === "group" ? title : other?.name ?? title} email={other?.email ?? ""} picture={other?.profilePicture ?? null} group={kind === "group"} online={!!other?.isOnline} size={44} />
      )}
      <div className="min-w-0 flex-1">
        <p className="truncate text-[17px] leading-tight font-bold text-[#111827]">{title}</p>
        <div className="mt-0.5">{status}</div>
      </div>
      <div className="relative">
        <button type="button" aria-label="More" aria-expanded={open} onClick={() => setOpen((v) => !v)} className="grid h-10 w-10 place-items-center rounded-xl bg-[#F1F5F9] text-[#64748B] hover:bg-[#E2E8F0]">
          <MoreVertical size={20} />
        </button>
        {open ? (
          <>
            <button type="button" aria-label={text.close} className="fixed inset-0 z-10 cursor-default" onClick={() => setOpen(false)} />
            <ul className="absolute top-12 right-0 z-20 min-w-[210px] overflow-hidden rounded-xl border border-[#E5E7EB] bg-white py-1 shadow-xl" role="menu">
              {menu.map((item) => (
                <li key={item.key}>
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setOpen(false);
                      item.run();
                    }}
                    className={`flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm hover:bg-[#F9FAFB] ${item.danger ? "text-[#DC2626]" : "text-[#111827]"}`}
                  >
                    <item.icon size={18} />
                    {item.label}
                  </button>
                </li>
              ))}
            </ul>
          </>
        ) : null}
      </div>
    </header>
  );
}

// ─── Messages (C-420…C-423) ────────────────────────────────────────────────

function MessageList({
  messages,
  loading,
  error,
  uid,
  kind,
  title,
  now,
  text,
  onActions,
  onToggleReaction,
  onImage,
  onVideo,
}: {
  messages: ChatMessage[];
  loading: boolean;
  error: boolean;
  uid: string;
  kind: Kind;
  title: string;
  now: Date;
  text: ParentChatText;
  onActions: (m: ChatMessage) => void;
  onToggleReaction: (m: ChatMessage, emoji: string) => void;
  onImage: (url: string) => void;
  onVideo: (url: string, caption: string) => void;
}) {
  const bottom = useRef<HTMLDivElement>(null);
  const last = messages[messages.length - 1]?.id;
  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [last]);

  if (loading) {
    return (
      <div className="grid flex-1 place-items-center" role="status" aria-label={text.loading}>
        <Loader2 size={32} className="animate-spin text-[#0386FF]" />
      </div>
    );
  }
  if (error) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-3 text-[#6B7280]">
        <AlertCircle size={40} className="text-[#EF4444]" />
        {text.errorLoading}
      </div>
    );
  }
  if (messages.length === 0) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center px-8 text-center">
        <span className="grid h-20 w-20 place-items-center rounded-full bg-[#0386FF]/10 text-[#0386FF]">
          <MessageCircle size={36} />
        </span>
        <p className="mt-4 text-lg font-semibold text-[#111827]">{text.startConversation}</p>
        <p className="mt-1.5 text-sm text-[#6B7280]">Send a message to begin chatting with {title}</p>
      </div>
    );
  }
  return (
    <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
      {messages.map((m) => (
        <Bubble key={m.id} message={m} uid={uid} kind={kind} now={now} onActions={onActions} onToggleReaction={onToggleReaction} onImage={onImage} onVideo={onVideo} />
      ))}
      <div ref={bottom} />
    </div>
  );
}

/** MessageBubble. Admin replies in the support thread show as incoming (Flutter puts them on the right in teal — B-9). */
function Bubble({
  message: m,
  uid,
  kind,
  now,
  onActions,
  onToggleReaction,
  onImage,
  onVideo,
}: {
  message: ChatMessage;
  uid: string;
  kind: Kind;
  now: Date;
  onActions: (m: ChatMessage) => void;
  onToggleReaction: (m: ChatMessage, emoji: string) => void;
  onImage: (url: string) => void;
  onVideo: (url: string, caption: string) => void;
}) {
  const hold = useRef<number | null>(null);
  if (m.type === "system") {
    return (
      <div className="my-1.5 flex justify-center px-10">
        <span className="rounded-xl bg-[#E5E7EB]/60 px-3.5 py-1.5 text-center text-xs font-medium text-[#6B7280]">{m.content}</span>
      </div>
    );
  }
  const mine = m.senderId === uid;
  const meta = m.metadata;
  const reply = meta.reply_to && typeof meta.reply_to === "object" ? (meta.reply_to as Record<string, unknown>) : null;
  const startHold = (event: ReactPointerEvent) => {
    if (event.button !== 0) return;
    hold.current = window.setTimeout(() => onActions(m), 500);
  };
  const stopHold = () => {
    if (hold.current !== null) window.clearTimeout(hold.current);
    hold.current = null;
  };
  const textColor = mine ? "text-white" : "text-[#2D3748]";
  const counts = reactionCounts(m.reactions);
  void kind;
  return (
    <div className={`mb-3 flex items-end gap-2 ${mine ? "justify-end" : "justify-start"}`}>
      {!mine ? (
        m.senderPicture ? (
          <img src={m.senderPicture} alt="" className="h-8 w-8 shrink-0 rounded-full border border-[#0386FF]/20 object-cover" />
        ) : (
          <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full border border-[#0386FF]/20 bg-[#0386FF]/10 text-xs font-semibold text-[#0386FF]">
            {(m.senderName || "?").trim().charAt(0).toUpperCase() || "?"}
          </span>
        )
      ) : null}
      <div className={`flex max-w-[70%] flex-col ${mine ? "items-end" : "items-start"}`}>
        {!mine ? <span className="mb-1 pl-1 text-xs font-medium text-[#0386FF]">{m.senderName}</span> : null}
        {reply ? (
          <div className={`mb-1 rounded-lg border-l-[3px] p-2 ${mine ? "border-[#0386FF] bg-[#0386FF]/20" : "border-[#6B7280] bg-[#F3F4F6]"}`}>
            <p className={`text-xs font-semibold ${mine ? "text-[#0386FF]" : "text-[#374151]"}`}>{String(reply.sender_name ?? "User")}</p>
            <p className="line-clamp-2 text-xs text-[#6B7280]">{String(reply.content ?? "")}</p>
          </div>
        ) : null}
        <div
          tabIndex={0}
          onPointerDown={startHold}
          onPointerUp={stopHold}
          onPointerLeave={stopHold}
          onContextMenu={(event) => {
            event.preventDefault();
            onActions(m);
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter" || event.key === "ContextMenu") {
              event.preventDefault();
              onActions(m);
            }
          }}
          aria-label="Message actions: press and hold, or right-click"
          className={`overflow-hidden shadow-[0_2px_8px_rgba(0,0,0,0.08)] outline-none focus-visible:ring-2 focus-visible:ring-[#0386FF]/50 ${mine ? "rounded-[20px] rounded-br-[4px] bg-[#0386FF]" : "rounded-[20px] rounded-bl-[4px] bg-white"}`}
        >
          <BubbleBody m={m} uid={uid} mine={mine} textColor={textColor} onImage={onImage} onVideo={onVideo} />
          <div className="flex items-center justify-end gap-1.5 px-4 pb-2.5">
            {m.isEdited && !m.deletedForEveryone ? <span className={`text-[11px] italic ${mine ? "text-white/60" : "text-[#9CA3AF]"}`}>edited</span> : null}
            <span className={`text-[11px] ${mine ? "text-white/70" : "text-[#9CA3AF]"}`}>{m.timestamp ? bubbleTime(m.timestamp, now) : ""}</span>
            {mine ? m.isRead ? <CheckCheck size={14} className="text-[#10B981]" /> : <Check size={14} className="text-white/70" /> : null}
          </div>
        </div>
        {counts.length ? (
          <div className="mt-1 flex flex-wrap gap-1">
            {counts.map(([emoji, count]) => (
              <button
                key={emoji}
                type="button"
                onClick={() => onToggleReaction(m, emoji)}
                className={`flex items-center gap-1 rounded-xl border px-2 py-1 ${m.reactions[uid] === emoji ? "border-[#0386FF] bg-[#E0F2FE]" : "border-[#E5E7EB] bg-white"}`}
              >
                <span className="text-xs">{emoji}</span>
                {count > 1 ? <span className="text-[10px] text-[#6B7280]">{count}</span> : null}
              </button>
            ))}
          </div>
        ) : null}
      </div>
    </div>
  );
}

function BubbleBody({ m, uid, mine, textColor, onImage, onVideo }: { m: ChatMessage; uid: string; mine: boolean; textColor: string; onImage: (url: string) => void; onVideo: (url: string, caption: string) => void }) {
  const meta = m.metadata;
  const url = String(meta.file_url ?? "");
  const caption = String(meta.caption ?? "");
  if (m.deletedForEveryone) {
    return (
      <p className={`flex items-center gap-2 px-4 pt-3 pb-1.5 text-sm italic ${mine ? "text-white/90" : "text-[#6B7280]"}`}>
        <Ban size={16} className={mine ? "text-white/70" : "text-[#9CA3AF]"} />
        {previewText(m, uid)}
      </p>
    );
  }
  if (m.type === "image" && url) {
    return (
      <div>
        <button type="button" onClick={() => onImage(url)} className="block">
          <img src={url} alt={caption || "Photo"} className="max-h-[250px] w-full object-cover" />
        </button>
        {caption ? <p className={`px-3 pt-2.5 text-sm ${textColor}`}>{caption}</p> : null}
      </div>
    );
  }
  if (m.type === "video" && url) {
    return (
      <div>
        <button type="button" onClick={() => onVideo(url, caption)} className="relative block">
          <video src={url} muted preload="metadata" className="max-h-[250px] w-full bg-black object-cover" />
          <span className="absolute inset-0 grid place-items-center bg-black/30 text-sm font-semibold text-white">
            <span className="flex items-center gap-2 rounded-full bg-black/50 px-3 py-1.5">
              <Video size={16} /> Open video
            </span>
          </span>
        </button>
        {caption ? <p className={`px-3 pt-2.5 text-sm ${textColor}`}>{caption}</p> : null}
      </div>
    );
  }
  if (m.type === "voice" && url) {
    return (
      <div className="px-3 pt-3">
        <audio src={url} controls preload="none" className="h-10 w-[240px] max-w-full" />
      </div>
    );
  }
  if (m.type === "file" && url) {
    const name = String(meta.file_name ?? "file");
    return (
      <a href={url} target="_blank" rel="noreferrer" className={`flex items-center gap-3 px-4 pt-3 ${textColor}`}>
        <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-lg ${mine ? "bg-white/20" : "bg-[#F3F4F6] text-[#0386FF]"}`}>
          <FileText size={22} />
        </span>
        <span className="min-w-0">
          <span className="block truncate text-sm font-semibold">{name}</span>
          <span className={`block text-xs ${mine ? "text-white/70" : "text-[#6B7280]"}`}>{fileSize(Number(meta.file_size ?? 0))}</span>
        </span>
      </a>
    );
  }
  if (m.type === "location") {
    const lat = Number(meta.latitude);
    const lng = Number(meta.longitude);
    return (
      <a href={Number.isFinite(lat) && Number.isFinite(lng) ? mapsLink(lat, lng) : undefined} target="_blank" rel="noreferrer" className={`flex items-center gap-3 px-4 pt-3 ${textColor}`}>
        <span className={`grid h-10 w-10 shrink-0 place-items-center rounded-lg ${mine ? "bg-white/20" : "bg-[#FEE2E2] text-[#DC2626]"}`}>
          <MapPin size={22} />
        </span>
        <span className="min-w-0">
          <span className={`block text-[11px] font-semibold uppercase ${mine ? "text-white/70" : "text-[#6B7280]"}`}>Pinned location</span>
          <span className="block truncate text-sm font-semibold">{String(meta.location_name ?? m.content)}</span>
          {meta.location_subtitle ? <span className={`block truncate text-xs ${mine ? "text-white/70" : "text-[#6B7280]"}`}>{String(meta.location_subtitle)}</span> : null}
        </span>
      </a>
    );
  }
  return (
    <p className={`px-4 pt-3 text-[15px] leading-normal break-words whitespace-pre-wrap ${textColor}`}>
      {splitMentions(m.content).map((part, i) =>
        part.mention ? (
          <span key={i} className={`font-bold ${mine ? "text-[#BBDEFB]" : "text-[#0386FF]"}`}>
            {part.text}
          </span>
        ) : (
          <span key={i}>{part.text}</span>
        ),
      )}
    </p>
  );
}

// ─── Composer (C-424, C-426, C-432…C-438, C-450 mentions) ──────────────────

function Composer({
  target,
  uid,
  kind,
  members,
  replyTo,
  onCancelReply,
  onSend,
  notify,
  setDialog,
  text,
}: {
  target: Target;
  uid: string;
  kind: Kind;
  members: ChatPerson[];
  replyTo: ChatMessage | null;
  onCancelReply: () => void;
  onSend: (content: string) => Promise<boolean>;
  notify: (t: Toast) => void;
  setDialog: (node: ReactNode) => void;
  text: ParentChatText;
}) {
  const [draft, setDraft] = useState("");
  const [menu, setMenu] = useState(false);
  const [uploading, setUploading] = useState(false);
  const field = useRef<HTMLTextAreaElement>(null);
  const photo = useRef<HTMLInputElement>(null);
  const camera = useRef<HTMLInputElement>(null);
  const video = useRef<HTMLInputElement>(null);
  const documentInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (replyTo) field.current?.focus();
  }, [replyTo]);

  const mentionQuery = kind === "group" ? /(?:^|\s)@(\w*)$/.exec(draft)?.[1] : undefined;
  const suggestions =
    mentionQuery === undefined
      ? []
      : [{ id: "all", name: "All" }, ...members.filter((p) => p.id !== uid).map((p) => ({ id: p.id, name: displayName(p) }))].filter((s) => s.name.toLowerCase().startsWith(mentionQuery.toLowerCase())).slice(0, 8);

  const submit = async () => {
    const content = draft.trim();
    if (!content) return;
    setDraft("");
    const ok = await onSend(content);
    if (!ok) setDraft(content);
    field.current?.focus();
  };

  const upload = async (file: File, kindOf: "image" | "video" | "file", caption = "") => {
    if (uploading) return;
    setUploading(true);
    const what = kindOf === "image" ? "image" : kindOf === "video" ? "video" : "file";
    notify({ text: `Sending ${what}...`, tone: "info" });
    try {
      await sendFile(target, uid, file, kindOf, caption);
      notify({ text: `${what === "file" ? "File" : what === "image" ? "Image" : "Video"} sent!`, tone: "ok" });
    } catch {
      notify({ text: `Failed to send ${what}`, tone: "error" });
    } finally {
      setUploading(false);
    }
  };

  const pickMedia = (file: File | undefined, kindOf: "image" | "video") => {
    if (!file) return;
    setDialog(<MediaPreview file={file} kind={kindOf} onClose={() => setDialog(null)} onSend={(caption) => {
      setDialog(null);
      void upload(file, kindOf, caption);
    }} />);
  };

  const shareLocation = () => {
    setMenu(false);
    if (!navigator.geolocation) {
      notify({ text: "Please enable location services", tone: "error" });
      return;
    }
    notify({ text: "Getting your location...", tone: "info" });
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        const subtitle = `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
        setDialog(
          <Sheet onClose={() => setDialog(null)} title="Share location">
            <button
              type="button"
              onClick={async () => {
                setDialog(null);
                try {
                  await sendLocation(target, uid, lat, lng, "Current location", subtitle);
                  notify({ text: "Location sent!", tone: "ok" });
                } catch {
                  notify({ text: "Failed to get location", tone: "error" });
                }
              }}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left hover:bg-[#F9FAFB]"
            >
              <span className="grid h-10 w-10 place-items-center rounded-full bg-[#FEE2E2] text-[#DC2626]">
                <MapPin size={20} />
              </span>
              <span>
                <span className="block text-sm font-semibold text-[#111827]">Send current location</span>
                <span className="block text-xs text-[#6B7280]">Current location · {subtitle}</span>
              </span>
            </button>
            <button type="button" onClick={() => setDialog(null)} className="mt-1 w-full rounded-xl py-2.5 text-sm font-semibold text-[#6B7280] hover:bg-[#F9FAFB]">
              {text.cancel}
            </button>
          </Sheet>,
        );
      },
      (error) => notify({ text: error.code === error.PERMISSION_DENIED ? "Location permission is required" : "Failed to get location", tone: "error" }),
      { enableHighAccuracy: true, timeout: 15_000 },
    );
  };

  const attachments: Array<{ key: string; label: string; icon: typeof Info; run: () => void }> = [
    { key: "photo", label: text.photo, icon: ImageIcon, run: () => photo.current?.click() },
    { key: "camera", label: text.camera, icon: Camera, run: () => camera.current?.click() },
    { key: "video", label: "Video", icon: Video, run: () => video.current?.click() },
    { key: "document", label: text.document, icon: FileText, run: () => documentInput.current?.click() },
    { key: "location", label: text.location, icon: MapPin, run: shareLocation },
  ];

  return (
    <div className="shrink-0 border-t border-[#E5E7EB] bg-white shadow-[0_-2px_10px_rgba(0,0,0,0.05)]">
      {replyTo ? (
        <div className="flex items-start gap-3 border-b border-[#F1F5F9] bg-[#F8FAFC] px-4 py-2">
          <CornerUpLeft size={18} className="mt-0.5 text-[#0386FF]" />
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold text-[#0386FF]">Replying to {replyTo.senderName}</p>
            <p className="line-clamp-2 text-xs text-[#6B7280]">{replyTo.content}</p>
          </div>
          <button type="button" onClick={onCancelReply} aria-label={text.cancel} className="text-[#6B7280]">
            <X size={18} />
          </button>
        </div>
      ) : null}
      {suggestions.length ? (
        <div className="flex gap-2 overflow-x-auto border-b border-[#F1F5F9] px-4 py-2">
          {suggestions.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => setDraft((d) => d.replace(/@(\w*)$/, `@${s.name} `))}
              className="shrink-0 rounded-full border border-[#0386FF]/30 bg-[#EFF6FF] px-3 py-1 text-xs font-semibold text-[#0386FF]"
            >
              @{s.name}
            </button>
          ))}
        </div>
      ) : null}
      <div className="flex items-end gap-2 p-4">
        <div className="relative">
          <button
            type="button"
            aria-label="Attach"
            aria-expanded={menu}
            disabled={uploading}
            onClick={() => setMenu((v) => !v)}
            className="grid h-12 w-12 place-items-center rounded-xl text-[#6B7280] hover:bg-[#F3F4F6] disabled:opacity-50"
          >
            {uploading ? <Loader2 size={22} className="animate-spin" /> : <Plus size={24} />}
          </button>
          {menu ? (
            <>
              <button type="button" aria-label={text.close} className="fixed inset-0 z-10 cursor-default" onClick={() => setMenu(false)} />
              <ul className="absolute bottom-14 left-0 z-20 min-w-[180px] overflow-hidden rounded-xl border border-[#E5E7EB] bg-white py-1 shadow-xl" role="menu">
                {attachments.map((a) => (
                  <li key={a.key}>
                    <button
                      type="button"
                      role="menuitem"
                      onClick={() => {
                        setMenu(false);
                        a.run();
                      }}
                      className="flex w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-[#111827] hover:bg-[#F9FAFB]"
                    >
                      <a.icon size={18} className="text-[#0386FF]" />
                      {a.label}
                    </button>
                  </li>
                ))}
              </ul>
            </>
          ) : null}
        </div>
        <input ref={photo} type="file" accept="image/*" hidden onChange={(e) => (pickMedia(e.target.files?.[0], "image"), (e.target.value = ""))} />
        <input ref={camera} type="file" accept="image/*" capture="environment" hidden onChange={(e) => (pickMedia(e.target.files?.[0], "image"), (e.target.value = ""))} />
        <input ref={video} type="file" accept="video/*" hidden onChange={(e) => (pickMedia(e.target.files?.[0], "video"), (e.target.value = ""))} />
        <input
          ref={documentInput}
          type="file"
          accept={DOCUMENT_EXTENSIONS.join(",")}
          hidden
          onChange={(e) => {
            const file = e.target.files?.[0];
            e.target.value = "";
            if (file) void upload(file, "file");
          }}
        />
        <textarea
          ref={field}
          rows={1}
          value={draft}
          onChange={(event) => {
            setDraft(event.target.value);
            event.target.style.height = "auto";
            event.target.style.height = `${Math.min(120, event.target.scrollHeight)}px`;
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
              event.preventDefault();
              void submit();
            }
          }}
          placeholder={replyTo ? `Reply to ${replyTo.senderName}...` : "Type a message..."}
          aria-label="Type a message..."
          autoCapitalize="sentences"
          className="max-h-[120px] min-h-12 min-w-0 flex-1 resize-none rounded-3xl border border-[#E5E7EB] bg-[#F9FAFB] px-5 py-3 text-base text-[#111827] outline-none placeholder:text-[#9CA3AF] focus:border-[#0386FF]"
        />
        <button
          type="button"
          onClick={() => void submit()}
          disabled={!draft.trim()}
          aria-label="Send"
          className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-[#0386FF] text-white disabled:bg-[#E5E7EB] disabled:text-[#9CA3AF]"
        >
          <Send size={20} />
        </button>
      </div>
    </div>
  );
}

// ─── Dialogs and sheets ────────────────────────────────────────────────────

function Overlay({ children, onClose, align = "center" }: { children: ReactNode; onClose: () => void; align?: "center" | "bottom" }) {
  useEffect(() => {
    const key = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [onClose]);
  return (
    <div className={`fixed inset-0 z-[110] flex ${align === "bottom" ? "items-end" : "items-center"} justify-center bg-black/50 p-0 sm:p-4`} role="dialog" aria-modal="true">
      <button type="button" aria-label="Close" className="absolute inset-0 cursor-default" onClick={onClose} />
      <div className="relative w-full max-w-md">{children}</div>
    </div>
  );
}

function Sheet({ title, children, onClose }: { title?: string; children: ReactNode; onClose: () => void }) {
  return (
    <Overlay onClose={onClose} align="bottom">
      <div className="rounded-t-3xl bg-white p-4 sm:rounded-3xl">
        <div className="mx-auto mb-3 h-1 w-10 rounded bg-[#E0E0E0]" />
        {title ? <p className="mb-2 px-3 text-base font-bold text-[#111827]">{title}</p> : null}
        {children}
      </div>
    </Overlay>
  );
}

function Confirm({ title, body, confirm, danger, onClose, onConfirm }: { title: string; body: string; confirm: string; danger?: boolean; onClose: () => void; onConfirm: () => void }) {
  return (
    <Overlay onClose={onClose}>
      <div className="mx-4 rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#111827]">{title}</h2>
        <p className="mt-2 text-sm text-[#4B5563]">{body}</p>
        <div className="mt-6 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#6B7280] hover:bg-[#F3F4F6]">
            Cancel
          </button>
          <button type="button" onClick={onConfirm} className={`rounded-lg px-4 py-2 text-sm font-semibold text-white ${danger ? "bg-[#DC2626]" : "bg-[#0386FF]"}`}>
            {confirm}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

function MessageMenu({
  message,
  text,
  canCopy,
  canEdit: editable,
  deleted,
  onClose,
  onReact,
  onReply,
  onCopy,
  onForward,
  onEdit,
  onDelete,
}: {
  message: ChatMessage;
  text: ParentChatText;
  canCopy: boolean;
  canEdit: boolean;
  deleted: boolean;
  onClose: () => void;
  onReact: () => void;
  onReply: () => void;
  onCopy: () => void;
  onForward: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const items: Array<[string, typeof Info, () => void, boolean?]> = deleted
    ? [[text.delete, Trash2, onDelete, true]]
    : [
        [text.react, SmilePlus, onReact],
        [text.reply, CornerUpLeft, onReply],
        ...(canCopy ? ([[text.copy, Copy, onCopy]] as Array<[string, typeof Info, () => void]>) : []),
        [text.forward, Forward, onForward],
        ...(editable ? ([["Edit", Pencil, onEdit]] as Array<[string, typeof Info, () => void]>) : []),
        [text.delete, Trash2, onDelete, true],
      ];
  void message;
  return (
    <Sheet onClose={onClose}>
      <ul>
        {items.map(([label, Icon, run, danger]) => (
          <li key={label}>
            <button type="button" onClick={run} className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm hover:bg-[#F9FAFB] ${danger ? "text-[#DC2626]" : "text-[#111827]"}`}>
              <Icon size={20} />
              {label}
            </button>
          </li>
        ))}
      </ul>
    </Sheet>
  );
}

function ReactionSheet({ current, onPick, onClose }: { current?: string; onPick: (emoji: string) => void; onClose: () => void }) {
  const [more, setMore] = useState(false);
  return (
    <Sheet onClose={onClose}>
      <div className="flex flex-wrap justify-center gap-2 px-2 py-2">
        {QUICK_REACTIONS.map((e) => (
          <button key={e} type="button" onClick={() => onPick(e)} className={`grid h-12 w-12 place-items-center rounded-full text-2xl hover:bg-[#F3F4F6] ${current === e ? "bg-[#E0F2FE]" : ""}`}>
            {e}
          </button>
        ))}
        <button type="button" onClick={() => setMore((v) => !v)} className="grid h-12 w-12 place-items-center rounded-full bg-[#F3F4F6] text-xs font-semibold text-[#6B7280]">
          More
        </button>
      </div>
      {more ? (
        <div className="grid max-h-56 grid-cols-8 gap-1 overflow-y-auto px-2 pb-2">
          {MORE_EMOJIS.map((e) => (
            <button key={e} type="button" onClick={() => onPick(e)} className="grid h-10 place-items-center rounded-lg text-xl hover:bg-[#F3F4F6]">
              {e}
            </button>
          ))}
        </div>
      ) : null}
    </Sheet>
  );
}

function DeleteSheet({ forEveryone, onClose, onForMe, onForEveryone }: { forEveryone: boolean; onClose: () => void; onForMe: () => void; onForEveryone: () => void }) {
  return (
    <Sheet onClose={onClose}>
      <button type="button" onClick={onForMe} className="flex w-full items-start gap-3 rounded-xl px-3 py-3 text-left hover:bg-[#F9FAFB]">
        <Trash2 size={20} className="mt-0.5 text-[#6B7280]" />
        <span>
          <span className="block text-sm font-semibold text-[#111827]">Delete for me</span>
          <span className="block text-xs text-[#6B7280]">Remove this message from your view only.</span>
        </span>
      </button>
      {forEveryone ? (
        <button type="button" onClick={onForEveryone} className="flex w-full items-start gap-3 rounded-xl px-3 py-3 text-left hover:bg-[#FEF2F2]">
          <Trash2 size={20} className="mt-0.5 text-[#DC2626]" />
          <span>
            <span className="block text-sm font-semibold text-[#DC2626]">Delete for everyone</span>
            <span className="block text-xs text-[#6B7280]">Replace this message with a deleted placeholder.</span>
          </span>
        </button>
      ) : null}
    </Sheet>
  );
}

function EditDialog({ initial, onClose, onSave }: { initial: string; onClose: () => void; onSave: (value: string) => void }) {
  const [value, setValue] = useState(initial);
  return (
    <Overlay onClose={onClose}>
      <div className="mx-4 rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#111827]">Edit Message</h2>
        <textarea autoFocus value={value} onChange={(e) => setValue(e.target.value)} placeholder="Edit your message..." rows={4} className="mt-3 w-full rounded-xl border border-[#E5E7EB] p-3 text-sm outline-none focus:border-[#0386FF]" />
        <div className="mt-4 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#6B7280] hover:bg-[#F3F4F6]">
            Cancel
          </button>
          <button type="button" onClick={() => onSave(value)} className="rounded-lg bg-[#0386FF] px-4 py-2 text-sm font-semibold text-white">
            Save
          </button>
        </div>
      </div>
    </Overlay>
  );
}

function ForwardDialog({ uid, currentChatId, message, text, onClose, onSend }: { uid: string; currentChatId: string; message: ChatMessage; text: ParentChatText; onClose: () => void; onSend: (row: ChatRow) => void }) {
  const [rows, setRows] = useState<ChatRow[] | null>(null);
  const [picked, setPicked] = useState<ChatRow | null>(null);
  useEffect(() => watchRecent(uid, (list) => setRows(list.filter((r) => r.chatId !== currentChatId)), () => setRows([])), [uid, currentChatId]);
  return (
    <Overlay onClose={onClose}>
      <div className="mx-4 rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#111827]">Forward Message</h2>
        <p className="mt-3 text-xs font-semibold text-[#6B7280]">Message:</p>
        <p className="mt-1 line-clamp-3 rounded-lg bg-[#F3F4F6] p-2 text-sm text-[#374151]">{message.content}</p>
        <p className="mt-4 text-xs font-semibold text-[#6B7280]">Select a chat:</p>
        <div className="mt-2 max-h-64 overflow-y-auto">
          {rows === null ? (
            <div className="flex justify-center p-4">
              <Loader2 size={24} className="animate-spin text-[#0386FF]" />
            </div>
          ) : rows.length === 0 ? (
            <p className="p-3 text-sm text-[#6B7280]">No other chats available</p>
          ) : (
            rows.map((row) => (
              <button
                key={row.chatId}
                type="button"
                onClick={() => setPicked(row)}
                className={`flex w-full items-center gap-3 rounded-xl px-3 py-2 text-left ${picked?.chatId === row.chatId ? "bg-[#EFF6FF]" : "hover:bg-[#F9FAFB]"}`}
              >
                <PersonAvatar name={row.title} email={row.email} picture={row.picture} group={row.kind === "group"} size={40} />
                <span className="min-w-0 flex-1 truncate text-sm font-semibold text-[#111827]">{row.title}</span>
                {row.kind === "group" ? <span className="text-[11px] font-semibold text-[#059669]">Group</span> : null}
              </button>
            ))
          )}
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#6B7280] hover:bg-[#F3F4F6]">
            {text.cancel}
          </button>
          <button type="button" disabled={!picked} onClick={() => picked && onSend(picked)} className="rounded-lg bg-[#0386FF] px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">
            {text.forward}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

function MediaPreview({ file, kind, onClose, onSend }: { file: File; kind: "image" | "video"; onClose: () => void; onSend: (caption: string) => void }) {
  const [caption, setCaption] = useState("");
  const url = useMemo(() => URL.createObjectURL(file), [file]);
  useEffect(() => () => URL.revokeObjectURL(url), [url]);
  return (
    <div className="fixed inset-0 z-[115] flex flex-col bg-black" role="dialog" aria-modal="true">
      <div className="flex h-14 items-center px-2">
        <button type="button" onClick={onClose} aria-label="Cancel" className="grid h-12 w-12 place-items-center text-white">
          <ArrowLeft size={24} />
        </button>
      </div>
      <div className="grid min-h-0 flex-1 place-items-center p-4">
        {kind === "image" ? <img src={url} alt="" className="max-h-full max-w-full object-contain" /> : <video src={url} controls className="max-h-full max-w-full" />}
      </div>
      <div className="flex items-center gap-2 p-4">
        <input value={caption} onChange={(e) => setCaption(e.target.value)} placeholder="Add a caption..." className="min-w-0 flex-1 rounded-3xl bg-white/10 px-5 py-3 text-white outline-none placeholder:text-white/60" />
        <button type="button" onClick={() => onSend(caption)} aria-label="Send" className="grid h-12 w-12 place-items-center rounded-full bg-[#0386FF] text-white">
          <Send size={20} />
        </button>
      </div>
    </div>
  );
}

function ImageViewer({ url, onClose }: { url: string; onClose: () => void }) {
  const [zoom, setZoom] = useState(1);
  return (
    <div className="fixed inset-0 z-[115] flex flex-col bg-black/90" role="dialog" aria-modal="true">
      <div className="flex justify-end p-2">
        <button type="button" onClick={onClose} aria-label="Close" className="grid h-12 w-12 place-items-center text-white">
          <X size={26} />
        </button>
      </div>
      <div
        className="min-h-0 flex-1 overflow-auto"
        onWheel={(e) => {
          if (!e.ctrlKey && !e.metaKey) return;
          e.preventDefault();
          setZoom((z) => Math.min(4, Math.max(1, z - e.deltaY / 300)));
        }}
      >
        <img src={url} alt="" onClick={() => setZoom((z) => (z > 1 ? 1 : 2))} className="mx-auto max-w-none cursor-zoom-in transition-[width]" style={{ width: `${zoom * 100}%`, maxWidth: zoom === 1 ? "100%" : undefined }} />
      </div>
    </div>
  );
}

function VideoViewer({ url, caption, onClose }: { url: string; caption: string; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-[115] flex flex-col bg-black" role="dialog" aria-modal="true">
      <div className="flex justify-end p-2">
        <button type="button" onClick={onClose} aria-label="Close" className="grid h-12 w-12 place-items-center text-white">
          <X size={26} />
        </button>
      </div>
      <div className="grid min-h-0 flex-1 place-items-center">
        <video src={url} controls autoPlay className="max-h-full max-w-full" />
      </div>
      {caption ? <p className="p-4 text-center text-white">{caption}</p> : null}
    </div>
  );
}

function GroupInfo({ chat, members, text, onClose }: { chat: Record<string, unknown> | null; members: ChatPerson[]; text: ParentChatText; onClose: () => void }) {
  return (
    <Overlay onClose={onClose}>
      <div className="mx-4 rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#111827]">{text.groupInformation}</h2>
        <p className="mt-3 text-sm text-[#374151]">Name: {String(chat?.group_name ?? "") || "Unnamed Group"}</p>
        <p className="mt-1 text-sm text-[#374151]">Description: {String(chat?.group_description ?? "") || "No description"}</p>
        <p className="mt-1 text-sm text-[#374151]">Members: {members.length || ((chat?.participants as unknown[]) ?? []).length}</p>
        <div className="mt-5 flex justify-end">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#0386FF] hover:bg-[#EFF6FF]">
            {text.close}
          </button>
        </div>
      </div>
    </Overlay>
  );
}

function MembersDialog({ chat, members, uid, onClose }: { chat: Record<string, unknown> | null; members: ChatPerson[]; uid: string; onClose: () => void }) {
  const admins = ((chat?.admin_ids as unknown[]) ?? []).map(String);
  const creator = String(chat?.created_by ?? "");
  return (
    <Overlay onClose={onClose}>
      <div className="mx-4 rounded-2xl bg-white p-6 shadow-2xl">
        <h2 className="text-lg font-bold text-[#111827]">Group Members</h2>
        <ul className="mt-3 max-h-80 overflow-y-auto">
          {members.length === 0 ? (
            <li className="p-3 text-sm text-[#6B7280]">No members found</li>
          ) : (
            members.map((p) => (
              <li key={p.id} className="flex items-center gap-3 py-2">
                <PersonAvatar name={p.name} email={p.email} picture={p.profilePicture} size={40} />
                <span className="min-w-0 flex-1">
                  <span className="flex flex-wrap items-center gap-1.5 text-sm font-semibold text-[#111827]">
                    <span className="truncate">{displayName(p)}</span>
                    {p.id === uid ? <Tag>You</Tag> : null}
                    {p.id === creator ? <Tag>Creator</Tag> : null}
                    {admins.includes(p.id) ? <Tag>Admin</Tag> : null}
                  </span>
                  <span className="block text-xs text-[#6B7280]">{roleLabel(p.role, p.jobTitle)}</span>
                </span>
              </li>
            ))
          )}
        </ul>
        <div className="mt-4 flex justify-end">
          <button type="button" onClick={onClose} className="rounded-lg px-4 py-2 text-sm font-semibold text-[#0386FF] hover:bg-[#EFF6FF]">
            Close
          </button>
        </div>
      </div>
    </Overlay>
  );
}

function Tag({ children }: { children: ReactNode }) {
  return <span className="rounded bg-[#EFF6FF] px-1.5 py-0.5 text-[10px] font-semibold text-[#0386FF]">{children}</span>;
}

