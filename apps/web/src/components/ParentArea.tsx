"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { collection, doc, getDocFromServer, getDocs, limit, query, serverTimestamp, updateDoc, where } from "firebase/firestore";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  BookMarked,
  BookOpen,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  FileText,
  GraduationCap,
  GripVertical,
  LayoutDashboard,
  Loader2,
  LogOut,
  Menu,
  MessageSquare,
  MonitorPlay,
  MoreHorizontal,
  Pencil,
  ReceiptText,
  RotateCcw,
  Search,
  Settings,
  ShieldCheck,
  Star,
  UserRound,
  Users,
  Video,
  X,
  type LucideIcon,
} from "lucide-react";
import { auth, db } from "@/lib/firebase";
import { ConfirmDialog, type ConfirmRequest } from "@/components/ConfirmDialog";
import { FlutterRedirect } from "@/components/FlutterRedirect";
import { adoptRemoteLocale, useLocale } from "@/lib/i18n";
import { allRolesOf } from "@/lib/roles";
import { clearParentSession, cachedParentSession, patchCachedParentSession, resolveParentSession, type ParentSession } from "@/lib/parentSession";
import {
  PARENT_SIDEBAR_SECTIONS,
  PARENT_WEB_SCREENS,
  PRESENCE_INTERVAL_MS,
  SIDEBAR_PREFS_KEY,
  SIDEBAR_RAIL_KEY,
  activeParentItemId,
  applySidebarPreferences,
  autoCollapseForSection,
  filterSidebar,
  parseSidebarPreferences,
  presenceWriteDue,
  reorderSections,
  roleColor,
  roleDisplayName,
  serializeSidebarPreferences,
  sidebarLabel,
  type ParentIconKey,
  type ParentSidebarItem,
  type SectionState,
  isPushedParentPage,
} from "@/lib/parentWeb";

// ─── Session context ───────────────────────────────────────────────────────

const ParentSessionContext = createContext<ParentSession | null>(null);
type SessionPatch = Partial<Pick<ParentSession, "displayName" | "greeting" | "language">>;
const ParentSessionUpdateContext = createContext<(patch: SessionPatch) => void>(() => undefined);

/** Updates the signed-in parent's name or language everywhere on screen (top bar, greeting). */
export function useUpdateParentSession() {
  return useContext(ParentSessionUpdateContext);
}

/** The signed-in parent. Only available inside the parent area. */
export function useParentSession(): ParentSession {
  const session = useContext(ParentSessionContext);
  if (!session) throw new Error("useParentSession must be used inside ParentArea");
  return session;
}

type GateState =
  | { kind: "checking" }
  | { kind: "signedOut" }
  | { kind: "notSetUp" }
  | { kind: "error"; message: string }
  | { kind: "elsewhere" }
  | { kind: "ready"; session: ParentSession };

/**
 * Who may see the parent area: a signed-in account that holds the parent role,
 * is opening as parent (the role Flutter would open with), and that
 * settings/parent_web_cutover has moved. Everyone else is handed to /app/,
 * where Flutter opens the dashboard their active role calls for — so nothing
 * changes for any parent until the switch names them.
 */
export function ParentArea({ children }: { children: ReactNode }) {
  const [gate, setGate] = useState<GateState>(() => {
    const cached = cachedParentSession();
    return cached && admits(cached) ? { kind: "ready", session: cached } : { kind: "checking" };
  });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setGate({ kind: "signedOut" });
        return;
      }
      const result = await resolveParentSession(user);
      if (result.status === "noRecord") return setGate({ kind: "notSetUp" });
      if (result.status === "error") return setGate({ kind: "error", message: result.message });
      adoptRemoteLocale(result.session.language);
      setGate(admits(result.session) ? { kind: "ready", session: result.session } : { kind: "elsewhere" });
    });
  }, [attempt]);

  const updateSession = useCallback((patch: SessionPatch) => {
    patchCachedParentSession(patch);
    setGate((current) => (current.kind === "ready" ? { kind: "ready", session: { ...current.session, ...patch } } : current));
  }, []);

  const retry = useCallback(() => {
    clearParentSession();
    setGate({ kind: "checking" });
    setAttempt((value) => value + 1);
  }, []);

  if (gate.kind === "ready") {
    return (
      <ParentSessionContext.Provider value={gate.session}>
        <ParentSessionUpdateContext.Provider value={updateSession}>
          <ParentShell session={gate.session}>{children}</ParentShell>
        </ParentSessionUpdateContext.Provider>
      </ParentSessionContext.Provider>
    );
  }
  if (gate.kind === "elsewhere") return <FlutterRedirect />;
  return <ParentGatePrompt gate={gate} onRetry={retry} />;
}

function admits(session: ParentSession) {
  return session.isParent && session.activeRole === "parent" && session.onWeb;
}

/** A-001 loading, A-002 account not set up, A-003 profile error. */
function ParentGatePrompt({ gate, onRetry }: { gate: GateState; onRetry: () => void }) {
  const fr = useLocale() === "fr";
  if (gate.kind === "checking") {
    return (
      <main className="grid min-h-screen place-items-center bg-[#F8FAFC]" aria-busy="true">
        <div className="grid justify-items-center gap-4">
          <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" className="h-16 w-16 rounded-2xl object-contain" />
          <Loader2 className="animate-spin text-[#0386FF]" size={28} />
          <p className="text-sm font-medium text-[#6B7280]">{fr ? "Chargement du profil utilisateur..." : "Loading user profile..."}</p>
        </div>
      </main>
    );
  }
  const signOutAndLeave = async () => {
    clearParentSession();
    await signOut(auth);
    window.location.assign("/");
  };
  const copy =
    gate.kind === "signedOut"
      ? { title: fr ? "Connexion requise" : "Sign in required", body: fr ? "Connectez-vous pour ouvrir votre espace parent." : "Sign in to open your parent dashboard." }
      : gate.kind === "notSetUp"
        ? {
            title: fr ? "Compte non configuré" : "Account Not Set Up",
            body: fr
              ? "Votre compte n'a pas encore été configuré. Veuillez contacter un administrateur."
              : "Your account has not been set up yet. Please contact an administrator.",
          }
        : {
            title: fr ? "Erreur de chargement du profil" : "Error Loading Profile",
            body: fr
              ? "Nous n'avons pas pu charger votre compte. Vérifiez votre connexion et réessayez."
              : "We could not load your account. Check your connection and try again.",
          };
  return (
    <main className="grid min-h-screen place-items-center bg-[#F8FAFC] px-4 py-10 text-[#111827]">
      <section className="w-full max-w-md rounded-2xl border border-[#E5E7EB] bg-white p-6 text-center shadow-sm">
        <h1 className="text-xl font-bold">{copy.title}</h1>
        <p className="mt-2 text-sm leading-6 text-[#6B7280]">{copy.body}</p>
        <div className="mt-5 flex flex-wrap justify-center gap-2">
          {gate.kind === "signedOut" ? (
            <Link href="/login/" className="inline-flex min-h-11 items-center rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">
              {fr ? "Se connecter" : "Sign In"}
            </Link>
          ) : (
            <>
              <button type="button" onClick={onRetry} className="inline-flex min-h-11 items-center rounded-xl bg-[#0386FF] px-5 text-sm font-bold text-white">
                {fr ? "Réessayer" : "Retry"}
              </button>
              <button
                type="button"
                onClick={() => void signOutAndLeave()}
                className="inline-flex min-h-11 items-center rounded-xl border border-[#E5E7EB] px-5 text-sm font-bold text-[#DC2626]"
              >
                {fr ? "Déconnexion" : "Sign Out"}
              </button>
            </>
          )}
        </div>
      </section>
    </main>
  );
}

// ─── Shell ─────────────────────────────────────────────────────────────────

const ICONS: Record<ParentIconKey, LucideIcon> = {
  dashboard: LayoutDashboard,
  chat: MessageSquare,
  classes: Video,
  recordings: MonitorPlay,
  curriculum_books: BookOpen,
  quran: BookMarked,
  invoices: ReceiptText,
  payments: CreditCard,
  forms: FileText,
  profile: UserRound,
  settings: Settings,
};

const ROLE_ICONS: Record<string, LucideIcon> = {
  admin: ShieldCheck,
  super_admin: ShieldCheck,
  teacher: GraduationCap,
  parent: Users,
  student: UserRound,
};

/** Text from app_en.arb / app_fr.arb that the Flutter parent shell translates. */
function shellText(fr: boolean) {
  return {
    appTitle: fr ? "Académie Alluwal" : "Alluwal Education Hub",
    menu: "Menu",
    profile: fr ? "Profil" : "Profile",
    signOut: fr ? "Déconnexion" : "Sign Out",
    signOutConfirm: fr ? "Êtes-vous sûr de vouloir vous déconnecter ?" : "Are you sure you want to sign out?",
    resetLayout: fr ? "Réinitialiser la mise en page" : "Reset Layout",
    switchFailed: fr ? "Impossible de changer de rôle. Veuillez réessayer." : "Failed to switch role. Please try again.",
    rolesChanged: fr ? "Les rôles de votre compte ont changé." : "Your account roles have changed.",
  };
}

type Toast = { text: string; color: string } | null;

const SECTION_IDS = PARENT_SIDEBAR_SECTIONS.map((section) => section.id);

function ParentShell({ session, children }: { session: ParentSession; children: ReactNode }) {
  const pathname = usePathname() ?? "/parent/";
  const fr = useLocale() === "fr";
  const text = shellText(fr);
  const activeItem = activeParentItemId(pathname);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmRequest | null>(null);
  const [toast, setToast] = useState<Toast>(null);
  const roles = useWatchedRoles(session, (message) => setToast({ text: message, color: "#F59E0B" }), text.rolesChanged);
  usePresenceHeartbeat(session.uid);

  // Close the drawer when the page changes (Flutter pops it on selection).
  useEffect(() => setDrawerOpen(false), [pathname]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 3000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const askSignOut = () =>
    setConfirm({
      title: text.signOut,
      body: text.signOutConfirm,
      confirmLabel: text.signOut,
      onConfirm: () => void signOutParent(),
    });

  const toastNode = toast ? (
    <div
      role="status"
      className="fixed bottom-6 left-1/2 z-[120] -translate-x-1/2 rounded-xl px-4 py-3 text-sm font-semibold text-white shadow-xl"
      style={{ backgroundColor: toast.color }}
    >
      {toast.text}
    </div>
  ) : null;

  // Flutter pushes the child page (and the pages opened from the dashboard)
  // over the whole shell; the session watchers above keep running.
  if (isPushedParentPage(pathname)) {
    return (
      <main className="h-screen select-text overflow-y-auto bg-[#F8FAFC] text-[#111827]">
        {children}
        {toastNode}
      </main>
    );
  }

  return (
    <main className="flex h-screen flex-col overflow-hidden bg-[#F8FAFC] text-[#111827]">
      <header className="flex min-h-14 shrink-0 items-center gap-2 bg-white px-2 min-[900px]:min-h-16 min-[900px]:px-8">
        <button
          type="button"
          onClick={() => setDrawerOpen(true)}
          title={text.menu}
          aria-label={text.menu}
          className="grid h-11 w-11 place-items-center rounded-full text-[#111827] hover:bg-black/5 min-[900px]:hidden"
        >
          <Menu size={24} />
        </button>
        <Link href="/parent/" className="flex min-w-0 items-center gap-3">
          <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="" width={40} height={40} className="h-10 w-10 shrink-0 object-contain" />
          <span className="truncate text-lg font-bold text-[#111827]">{text.appTitle}</span>
        </Link>
        <div className="ml-auto flex items-center gap-1 min-[900px]:gap-4">
          <RoleChips roles={roles} onFailed={() => setToast({ text: text.switchFailed, color: "#DC2626" })} />
          <AccountMenu name={session.displayName} text={text} onSignOut={askSignOut} />
        </div>
      </header>

      <div className="flex min-h-0 flex-1">
        <div className="hidden min-[900px]:flex">
          <ParentSidebar activeItem={activeItem} canCollapse />
        </div>
        <div className="min-h-0 min-w-0 flex-1 select-text overflow-y-auto" aria-label="Parent page content">
          {children}
        </div>
      </div>

      {drawerOpen ? (
        <section className="fixed inset-0 z-[80] min-[900px]:hidden" aria-label={text.menu}>
          <button type="button" aria-label="Close menu" onClick={() => setDrawerOpen(false)} className="absolute inset-0 bg-black/50" />
          <aside className="absolute inset-y-0 left-0 flex max-w-[86vw] bg-white shadow-2xl">
            <ParentSidebar activeItem={activeItem} canCollapse={false} />
          </aside>
        </section>
      ) : null}

      <ConfirmDialog request={confirm} onClose={() => setConfirm(null)} />
      {toastNode}
    </main>
  );
}

async function signOutParent() {
  // A-026: clear the cached account, sign out, leave for the public site.
  clearParentSession();
  try {
    await signOut(auth);
  } finally {
    window.location.assign("/");
  }
}

/**
 * A-023: one chip per role, the active one filled in its role colour. Choosing
 * another role saves it the way Flutter's switcher does and opens the app, which
 * then shows that role's dashboard (A-012).
 */
function RoleChips({ roles, onFailed }: { roles: string[] | null; onFailed: () => void }) {
  const [switching, setSwitching] = useState<string | null>(null);
  if (!roles) {
    return (
      <span className="grid h-9 w-9 place-items-center" aria-label="Loading roles">
        <Loader2 className="animate-spin text-[#0386FF]" size={20} />
      </span>
    );
  }
  const shown = roles.length > 1 ? roles : ["parent"];
  const choose = (role: string) => {
    if (role === "parent" || switching) return;
    setSwitching(role);
    try {
      window.localStorage.setItem("flutter.active_user_role", JSON.stringify(role));
    } catch {
      setSwitching(null);
      onFailed();
      return;
    }
    clearParentSession();
    window.location.assign("/app/");
  };
  return (
    <div className="flex items-center gap-1.5" role={roles.length > 1 ? "group" : undefined} aria-label="Roles">
      {shown.map((role) => {
        const active = role === "parent";
        const Icon = ROLE_ICONS[role] ?? UserRound;
        return (
          <button
            key={role}
            type="button"
            onClick={() => choose(role)}
            aria-pressed={active}
            className={`inline-flex min-h-9 items-center gap-1.5 rounded-full px-4 text-xs font-semibold transition ${
              active ? "text-white shadow-sm" : "border border-[#D1D5DB] bg-[#E5E7EB] text-[#4B5563] hover:bg-[#D1D5DB]"
            }`}
            style={active ? { backgroundColor: roleColor(role) } : undefined}
          >
            <Icon size={16} />
            {roleDisplayName(role)}
            {switching === role ? <Loader2 size={12} className="animate-spin" /> : null}
          </button>
        );
      })}
    </div>
  );
}

/** A-025: person icon, name on wide screens, menu with Profile and Sign Out. */
function AccountMenu({ name, text, onSignOut }: { name: string; text: ReturnType<typeof shellText>; onSignOut: () => void }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement | null>(null);
  useEffect(() => {
    if (!open) return;
    const close = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) setOpen(false);
    };
    window.addEventListener("mousedown", close);
    return () => window.removeEventListener("mousedown", close);
  }, [open]);
  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Account menu"
        onClick={() => setOpen((value) => !value)}
        className="flex min-h-11 items-center gap-2 rounded-xl px-1 hover:bg-black/5"
      >
        <span className="grid h-8 w-8 place-items-center rounded-full bg-[#EFF6FF] text-[#1D4ED8] min-[900px]:h-10 min-[900px]:w-10">
          <UserRound size={20} />
        </span>
        <span className="hidden max-w-[220px] truncate text-sm font-semibold text-[#111827] min-[900px]:inline">{name}</span>
        <ChevronDown size={18} className="text-[#6B7280]" />
      </button>
      {open ? (
        <div role="menu" className="absolute right-0 top-12 z-50 w-48 rounded-xl border border-[#E5E7EB] bg-white py-2 shadow-xl">
          {PARENT_WEB_SCREENS.has("profile") ? (
            <Link
              href="/parent/profile/"
              role="menuitem"
              onClick={() => setOpen(false)}
              className="flex min-h-11 items-center gap-3 px-4 text-sm text-[#111827] hover:bg-[#F3F4F6]"
            >
              <UserRound size={20} className="text-[#6B7280]" />
              {text.profile}
            </Link>
          ) : null}
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              setOpen(false);
              onSignOut();
            }}
            className="flex min-h-11 w-full items-center gap-3 px-4 text-left text-sm text-[#DC2626] hover:bg-[#FEF2F2]"
          >
            <LogOut size={20} />
            {text.signOut}
          </button>
        </div>
      ) : null}
    </div>
  );
}

// ─── Sidebar ───────────────────────────────────────────────────────────────

type ShownItem = ParentSidebarItem & { shownLabel: string };
type ShownSection = { id: string; title: string; items: ShownItem[] };

function readStorage(key: string) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key: string, value: string | null) {
  try {
    if (value === null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    // The layout still works for this visit.
  }
}

/**
 * A-017 … A-022: the parent sidebar — sections in the Flutter order, search,
 * pinned favourites, section folding, drag-to-reorder, Reset Layout and the
 * icon rail. Layout preferences live in the same browser keys Flutter uses, so
 * a parent's sidebar looks the same in both apps.
 */
function ParentSidebar({ activeItem, canCollapse }: { activeItem: ParentIconKey; canCollapse: boolean }) {
  const fr = useLocale() === "fr";
  const text = shellText(fr);
  const [sections, setSections] = useState<SectionState[]>(() => applySidebarPreferences(SECTION_IDS, null));
  const [favorites, setFavorites] = useState<Set<string>>(new Set());
  const [manualExpanded, setManualExpanded] = useState<Set<string>>(new Set(SECTION_IDS));
  const [loaded, setLoaded] = useState(false);
  const [railCollapsed, setRailCollapsed] = useState(false);
  const [railHover, setRailHover] = useState(false);
  const [editLayout, setEditLayout] = useState(false);
  const [search, setSearch] = useState("");
  const [dragIndex, setDragIndex] = useState<number | null>(null);

  const sectionOf = (itemId: string) => PARENT_SIDEBAR_SECTIONS.find((section) => section.items.some((item) => item.id === itemId))?.id ?? null;

  // Load once: saved order, folding and favourites, untouched — Flutter only
  // re-folds when the parent picks another item, never when the sidebar loads.
  useEffect(() => {
    const prefs = parseSidebarPreferences(readStorage(SIDEBAR_PREFS_KEY));
    const restored = applySidebarPreferences(SECTION_IDS, prefs);
    const manual = new Set(restored.filter((section) => section.expanded).map((section) => section.id));
    setManualExpanded(manual);
    setSections(restored);
    setFavorites(new Set(prefs?.favoritedItemIds ?? []));
    setRailCollapsed(readStorage(SIDEBAR_RAIL_KEY) === "true");
    setLoaded(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Moving to another page folds the sections the parent did not open by hand.
  useEffect(() => {
    if (!loaded) return;
    setSections((current) => autoCollapseForSection(current, sectionOf(activeItem), manualExpanded));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeItem]);

  const save = (nextSections: SectionState[], nextFavorites: Set<string>) => {
    writeStorage(
      SIDEBAR_PREFS_KEY,
      serializeSidebarPreferences({
        sectionOrder: nextSections.map((section) => section.id),
        sectionExpansionState: Object.fromEntries(nextSections.map((section) => [section.id, section.expanded])),
        favoritedItemIds: [...nextFavorites],
      }),
    );
  };

  const toggleSection = (id: string) => {
    const next = sections.map((section) => (section.id === id ? { ...section, expanded: !section.expanded } : section));
    const nowExpanded = next.find((section) => section.id === id)?.expanded;
    setManualExpanded((current) => {
      const updated = new Set(current);
      if (nowExpanded) updated.add(id);
      else updated.delete(id);
      return updated;
    });
    setSections(next);
    save(next, favorites);
  };

  const toggleFavorite = (id: string) => {
    const next = new Set(favorites);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setFavorites(next);
    save(sections, next);
  };

  const moveSection = (from: number, to: number) => {
    const next = reorderSections(sections, from, to);
    setSections(next);
    save(next, favorites);
  };

  const resetLayout = () => {
    writeStorage(SIDEBAR_PREFS_KEY, null);
    const defaults = applySidebarPreferences(SECTION_IDS, null);
    setSections(defaults);
    setManualExpanded(new Set(SECTION_IDS));
    setFavorites(new Set());
  };

  const toggleRail = () => {
    if (!canCollapse) return;
    const next = !railCollapsed;
    setRailCollapsed(next);
    setRailHover(false);
    writeStorage(SIDEBAR_RAIL_KEY, next ? "true" : "false");
  };

  // Displayed sections in the parent's order, limited to screens that exist on the web.
  const shown: ShownSection[] = sections
    .map((state) => PARENT_SIDEBAR_SECTIONS.find((section) => section.id === state.id)!)
    .map((section) => ({
      id: section.id,
      title: sidebarLabel(section, fr ? "fr" : "en"),
      items: section.items
        .filter((item) => PARENT_WEB_SCREENS.has(item.id))
        .map((item) => ({ ...item, shownLabel: sidebarLabel(item, fr ? "fr" : "en") })),
    }))
    .filter((section) => section.items.length > 0);
  const expandedById = new Map(sections.map((section) => [section.id, section.expanded]));
  const favoriteItems = shown.flatMap((section) => section.items).filter((item) => favorites.has(item.id));

  if (canCollapse && railCollapsed) {
    const wide = railHover;
    return (
      <nav
        aria-label="Parent navigation"
        onMouseEnter={() => setRailHover(true)}
        onMouseLeave={() => setRailHover(false)}
        className={`flex h-full flex-col border-r border-[#E5E7EB] bg-white transition-[width] duration-200 ${wide ? "w-[200px]" : "w-[72px]"}`}
      >
        <div className="flex h-16 items-center justify-center border-b border-[#E5E7EB]">
          <button type="button" onClick={toggleRail} aria-label="Expand sidebar" title="Expand sidebar" className="grid h-9 w-9 place-items-center rounded-lg text-[#6B7280] hover:bg-black/5">
            <ChevronRight size={22} />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto py-2">
          {shown.map((section, index) => (
            <div key={section.id}>
              {index > 0 ? <div className="mx-auto my-2 h-px w-8 bg-[#E5E7EB]" aria-hidden="true" /> : null}
              {section.items.map((item) => {
                const Icon = ICONS[item.id];
                const selected = item.id === activeItem;
                return (
                  <Link
                    key={item.id}
                    href={item.href}
                    title={item.shownLabel}
                    aria-label={item.shownLabel}
                    aria-current={selected ? "page" : undefined}
                    className={`mx-2 my-0.5 flex h-11 items-center gap-3 rounded-[10px] ${wide ? "px-3" : "justify-center"} ${
                      selected ? "bg-[#EFF6FF]" : "hover:bg-[#F9FAFB]"
                    }`}
                  >
                    <Icon size={20} style={{ color: selected ? "#0386FF" : item.color }} />
                    {wide ? <span className={`truncate text-sm ${selected ? "font-semibold text-[#0386FF]" : "font-medium text-[#374151]"}`}>{item.shownLabel}</span> : null}
                  </Link>
                );
              })}
            </div>
          ))}
        </div>
      </nav>
    );
  }

  const searching = search.trim().length > 0;
  const visible = filterSidebar(
    shown.map((section) => ({ ...section, items: section.items.map((item) => ({ ...item, label: item.shownLabel })) })),
    search,
  );

  return (
    <nav aria-label="Parent navigation" className="flex h-full w-[260px] flex-col border-r border-[#E5E7EB] bg-white shadow-[2px_0_10px_rgba(0,0,0,0.03)]">
      <div className="flex h-16 shrink-0 items-center justify-between border-b border-[#E5E7EB] px-4">
        <p className="text-xl font-bold tracking-tight text-[#111827]">{text.menu}</p>
        <div className="flex items-center">
          <button
            type="button"
            onClick={() => setEditLayout((value) => !value)}
            aria-pressed={editLayout}
            aria-label={editLayout ? "Finish reordering sections" : "Reorder sections"}
            className="grid h-9 w-9 place-items-center rounded-lg text-[#6B7280] hover:bg-black/5"
          >
            {editLayout ? <GripVertical size={22} /> : <Pencil size={20} />}
          </button>
          <button
            type="button"
            onClick={toggleRail}
            aria-label="Collapse sidebar"
            className="grid h-9 w-9 place-items-center rounded-lg text-[#6B7280] hover:bg-black/5"
          >
            <ChevronLeft size={24} />
          </button>
        </div>
      </div>

      <div className="px-3 py-2">
        <div className="relative">
          <Search size={18} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" aria-hidden="true" />
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search..."
            aria-label="Search menu"
            className="h-9 w-full rounded-[10px] border border-[#E5E7EB] pl-9 pr-9 text-sm outline-none placeholder:text-xs placeholder:text-[#9CA3AF] focus:border-[1.5px] focus:border-[#0386FF]"
          />
          {searching ? (
            <button type="button" onClick={() => setSearch("")} aria-label="Clear search" className="absolute right-1 top-1/2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-md text-[#6B7280] hover:bg-black/5">
              <X size={18} />
            </button>
          ) : null}
        </div>
      </div>

      {favoriteItems.length > 0 ? (
        <div className="mx-3 rounded-xl border border-[#E5E7EB] bg-[#F9FAFB] p-3">
          <p className="mb-2 flex items-center gap-2 text-xs font-bold tracking-wide text-[#6B7280]">
            <Star size={16} className="fill-[#F59E0B] text-[#F59E0B]" />
            Favorites
          </p>
          <div className="max-h-[180px] overflow-y-auto">
            {favoriteItems.map((item) => (
              <SidebarRow key={item.id} item={item} selected={item.id === activeItem} favorited onToggleFavorite={toggleFavorite} inFavorites />
            ))}
          </div>
        </div>
      ) : null}

      <div className="flex-1 overflow-y-auto py-2">
        {visible.map((section) => {
          const index = sections.findIndex((state) => state.id === section.id);
          const expanded = searching || expandedById.get(section.id) !== false;
          return (
            <div
              key={section.id}
              className={`mb-2 ${editLayout && dragIndex === index ? "opacity-50" : ""}`}
              draggable={editLayout && !searching}
              onDragStart={() => setDragIndex(index)}
              onDragEnd={() => setDragIndex(null)}
              onDragOver={(event) => {
                if (editLayout && dragIndex !== null) event.preventDefault();
              }}
              onDrop={(event) => {
                event.preventDefault();
                if (dragIndex === null || dragIndex === index) return;
                // Dropping on a section places the dragged one where that section was.
                moveSection(dragIndex, dragIndex < index ? index + 1 : index);
                setDragIndex(null);
              }}
            >
              <button
                type="button"
                onClick={() => toggleSection(section.id)}
                aria-expanded={expanded}
                className="mx-1 flex w-[calc(100%-8px)] items-center gap-2 rounded-lg px-3.5 py-2.5 text-left hover:bg-[#F9FAFB]"
              >
                {editLayout ? <GripVertical size={16} className="cursor-grab text-[#9CA3AF]" aria-hidden="true" /> : null}
                <span className="flex-1 truncate text-[11px] font-bold uppercase tracking-[0.08em] text-[#9CA3AF]">{section.title}</span>
                <ChevronDown size={18} className={`text-[#9CA3AF] transition-transform ${expanded ? "rotate-180" : ""}`} />
              </button>
              {editLayout && !searching ? (
                <span className="sr-only">
                  <button type="button" onClick={() => index > 0 && moveSection(index, index - 1)}>
                    Move {section.title} up
                  </button>
                  <button type="button" onClick={() => index < sections.length - 1 && moveSection(index, index + 2)}>
                    Move {section.title} down
                  </button>
                </span>
              ) : null}
              {expanded
                ? section.items.map((item) => (
                    <SidebarRow key={item.id} item={item} selected={item.id === activeItem} favorited={favorites.has(item.id)} onToggleFavorite={toggleFavorite} />
                  ))
                : null}
            </div>
          );
        })}
      </div>

      <div className="border-t border-[#E5E7EB] bg-[#F9FAFB] px-3 py-3">
        <button type="button" onClick={resetLayout} className="inline-flex items-center gap-2 rounded-lg px-3 py-2.5 text-xs font-medium text-[#9CA3AF] hover:bg-black/5">
          <RotateCcw size={16} />
          {text.resetLayout}
        </button>
      </div>
    </nav>
  );
}

function SidebarRow({
  item,
  selected,
  favorited,
  onToggleFavorite,
  inFavorites = false,
}: {
  item: ShownItem;
  selected: boolean;
  favorited: boolean;
  onToggleFavorite: (id: string) => void;
  inFavorites?: boolean;
}) {
  const Icon = ICONS[item.id];
  return (
    <div
      className={`flex items-center gap-1 rounded-[10px] py-1.5 pl-3 pr-1 transition-colors ${inFavorites ? "my-0.5" : "mx-2.5 my-0.5"} ${
        selected ? "border border-[#0386FF]/20 bg-[#EFF6FF]" : "border border-transparent"
      }`}
    >
      <Link href={item.href} aria-current={selected ? "page" : undefined} className="flex min-w-0 flex-1 items-center gap-3 rounded-[10px] py-1">
        <span className="grid place-items-center rounded-lg p-1.5" style={{ backgroundColor: selected ? "rgba(3,134,255,0.1)" : hexAlpha(item.color, 0.1) }}>
          <Icon size={18} style={{ color: selected ? "#0386FF" : item.color }} />
        </span>
        <span className={`min-w-0 flex-1 truncate text-sm tracking-tight ${selected ? "font-semibold text-[#0386FF]" : "font-medium text-[#374151]"}`}>{item.shownLabel}</span>
        {selected ? <MoreHorizontal size={16} className="text-[#0386FF]/50" aria-hidden="true" /> : null}
      </Link>
      <button
        type="button"
        onClick={() => onToggleFavorite(item.id)}
        title={favorited ? "Unpin" : "Pin"}
        aria-label={`${favorited ? "Unpin" : "Pin"} ${item.shownLabel}`}
        className="grid h-7 w-7 shrink-0 place-items-center rounded-md hover:bg-black/5"
      >
        <Star size={18} className={favorited ? "fill-[#F59E0B] text-[#F59E0B]" : "text-[#9CA3AF]"} />
      </button>
    </div>
  );
}

function hexAlpha(hex: string, alpha: number) {
  const value = hex.replace("#", "");
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${alpha})`;
}

// ─── Background behaviour ──────────────────────────────────────────────────

/**
 * A-011: mark the parent online every minute while the area is open, and
 * offline when the tab is hidden or closed — the presence-only update the
 * Flutter dashboard makes, with the same 20-second floor between writes.
 * Chat shows these as the online dot.
 */
function usePresenceHeartbeat(uid: string) {
  useEffect(() => {
    if (!uid) return;
    let last: number | null = null;
    let timer: number | null = null;
    const write = (online: boolean) => {
      const now = Date.now();
      if (!presenceWriteDue(last, now)) return;
      last = now;
      void updateDoc(doc(db, "users", uid), { is_online: online, last_seen: serverTimestamp() }).catch(() => {});
    };
    const start = () => {
      if (timer !== null) window.clearInterval(timer);
      write(true);
      timer = window.setInterval(() => write(true), PRESENCE_INTERVAL_MS);
    };
    const stop = () => {
      if (timer !== null) window.clearInterval(timer);
      timer = null;
      write(false);
    };
    const onVisibility = () => (document.visibilityState === "visible" ? start() : stop());
    start();
    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("pagehide", stop);
    return () => {
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("pagehide", stop);
      stop();
    };
  }, [uid]);
}

/**
 * A-024: re-read the account every 30 seconds. If it loses a role the chips
 * shrink; if it is no longer a parent, or drops to a single role that is not
 * parent, the parent is told and taken to the app as that role.
 */
function useWatchedRoles(session: ParentSession, notify: (message: string) => void, message: string): string[] | null {
  const [roles, setRoles] = useState<string[] | null>(session.roles);
  const previous = useRef<string[]>(session.roles);
  const notifyRef = useRef(notify);
  notifyRef.current = notify;

  useEffect(() => {
    let cancelled = false;
    const check = async () => {
      try {
        let data: Record<string, unknown> | undefined;
        const snap = await getDocFromServer(doc(db, "users", session.uid));
        if (snap.exists()) data = snap.data();
        else {
          const email = auth.currentUser?.email?.trim().toLowerCase();
          if (email) {
            const found = await getDocs(query(collection(db, "users"), where("e-mail", "==", email), limit(1)));
            data = found.docs[0]?.data();
          }
        }
        if (cancelled || !data) return;
        const next = allRolesOf(data);
        const before = previous.current;
        previous.current = next;
        setRoles(next);
        const primary = String(data.user_type ?? "").trim().toLowerCase();
        const lostParent = !next.includes("parent");
        const droppedToOther = before.length > 1 && next.length <= 1 && primary !== "parent";
        if ((lostParent || droppedToOther) && primary) {
          notifyRef.current(message);
          try {
            window.localStorage.setItem("flutter.active_user_role", JSON.stringify(primary));
          } catch {}
          clearParentSession();
          window.setTimeout(() => window.location.assign("/app/"), 3000);
        }
      } catch {
        // Keep the chips we have; the next check tries again.
      }
    };
    const timer = window.setInterval(() => void check(), 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, [session.uid, message]);

  return useMemo(() => roles, [roles]);
}
