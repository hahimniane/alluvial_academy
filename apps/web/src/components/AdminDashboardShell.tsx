"use client";

import Link from "next/link";
import { onAuthStateChanged, type User } from "firebase/auth";
import { collection, doc, getDoc, getDocs, limit, query, where } from "firebase/firestore";
import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Activity,
  Bell,
  BookOpen,
  Bug,
  CalendarClock,
  ChevronUp,
  ClipboardCheck,
  ClipboardList,
  FileText,
  Grid3X3,
  LayoutDashboard,
  MessageSquare,
  Podcast,
  Play,
  ReceiptText,
  RotateCcw,
  School,
  Search,
  Settings,
  Shield,
  Star,
  UserRoundPlus,
  Users,
  Video,
  X,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { auth, db } from "@/lib/firebase";

type SidebarItem = {
  label: string;
  icon: LucideIcon;
  href: string;
  color: string;
};

type SidebarSection = {
  title: string;
  items: SidebarItem[];
};

type UserRecord = Record<string, unknown>;

type ShellUserSummary = {
  displayName: string;
  initials: string;
  roles: string[];
};

const sidebarSections: SidebarSection[] = [
  {
    title: "Overview",
    items: [{ label: "Dashboard", icon: LayoutDashboard, href: "/admin/", color: "#0386FF" }],
  },
  {
    title: "People",
    items: [
      { label: "Users", icon: Users, href: "/admin/users/", color: "#10B981" },
      { label: "Student Applicants", icon: School, href: "/admin/student-applicants/", color: "#8B5CF6" },
      { label: "Teacher Applicants", icon: UserRoundPlus, href: "/admin/teacher-applicants/", color: "#F59E0B" },
    ],
  },
  {
    title: "Operations",
    items: [
      { label: "Shifts", icon: CalendarClock, href: "/admin/shifts/", color: "#F59E0B" },
      { label: "Timesheets", icon: ReceiptText, href: "/admin/timesheets/", color: "#8B5CF6" },
      { label: "Tasks", icon: ClipboardCheck, href: "/admin/tasks/", color: "#14B8A6" },
      { label: "Audits", icon: ClipboardList, href: "/admin/audits/", color: "#0386FF" },
    ],
  },
  {
    title: "Communication",
    items: [
      { label: "Chat", icon: MessageSquare, href: "/admin/chat/", color: "#A646F2" },
      { label: "Classes", icon: Video, href: "/admin/classes/", color: "#2D8CFF" },
      { label: "Routing Control", icon: Activity, href: "/admin/routing-control/", color: "#14B8A6" },
      { label: "Recordings", icon: Video, href: "/admin/recordings/", color: "#0E72ED" },
      { label: "Surah Podcasts", icon: Podcast, href: "/admin/surah-podcasts/", color: "#0E72ED" },
      { label: "Curriculum Books", icon: BookOpen, href: "/admin/curriculum-books/", color: "#0F766E" },
      { label: "Notifications", icon: Bell, href: "/admin/notifications/", color: "#F43F5E" },
    ],
  },
  {
    title: "Forms",
    items: [
      { label: "Form Builder", icon: Settings, href: "/admin/form-builder/", color: "#F97316" },
      { label: "All Submissions", icon: ClipboardList, href: "/admin/all-submissions/", color: "#0EA5E9" },
      { label: "Submit Form", icon: FileText, href: "/admin/submit-form/", color: "#EC4899" },
    ],
  },
  {
    title: "Finance",
    items: [{ label: "Invoices", icon: ReceiptText, href: "/admin/invoices/", color: "#10B981" }],
  },
  {
    title: "Website",
    items: [{ label: "Pricing & public team", icon: Users, href: "/admin/public-site-cms/", color: "#059669" }],
  },
  {
    title: "Savings",
    items: [{ label: "Circles", icon: Users, href: "/admin/circles/", color: "#10B981" }],
  },
  {
    title: "System",
    items: [
      { label: "Settings", icon: Settings, href: "/app/#/login", color: "#6B7280" },
      { label: "Test Audit Génération", icon: Play, href: "/app/#/login", color: "#10B981" },
      { label: "Roles (Test)", icon: Shield, href: "/app/#/login", color: "#64748B" },
      { label: "Debug", icon: Bug, href: "/app/#/login", color: "#64748B" },
    ],
  },
];

export function AdminDashboardShell({
  activeLabel,
  breadcrumb,
  children,
}: {
  activeLabel: string;
  breadcrumb: string;
  children: ReactNode;
}) {
  const [searchQuery, setSearchQuery] = useState("");
  const [collapsedSections, setCollapsedSections] = useState<Set<string>>(new Set());
  const [favoritedItems, setFavoritedItems] = useState<Set<string>>(new Set());
  const [userSummary, setUserSummary] = useState<ShellUserSummary>({
    displayName: "Administrator",
    initials: "AD",
    roles: ["Administrator", "Teacher"],
  });
  const normalizedSearch = searchQuery.trim().toLowerCase();
  const allSidebarItems = useMemo(() => sidebarSections.flatMap((section) => section.items), []);
  const favoriteSidebarItems = allSidebarItems.filter((item) => favoritedItems.has(item.label));
  const visibleSidebarSections = useMemo(() => {
    if (!normalizedSearch) return sidebarSections;

    return sidebarSections
      .map((section) => {
        const titleMatches = section.title.toLowerCase().includes(normalizedSearch);
        const matchedItems = section.items.filter((item) => item.label.toLowerCase().includes(normalizedSearch));
        if (!titleMatches && matchedItems.length === 0) return null;
        return { ...section, items: titleMatches ? section.items : matchedItems };
      })
      .filter((section): section is SidebarSection => section !== null);
  }, [normalizedSearch]);

  useEffect(() => {
    let isMounted = true;
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        if (isMounted) {
          setUserSummary({
            displayName: "Administrator",
            initials: "AD",
            roles: ["Administrator", "Teacher"],
          });
        }
        return;
      }

      const fallback = userSummaryFromAuth(user);
      if (isMounted) setUserSummary(fallback);

      try {
        const userRecord = await findUserRecord(user);
        if (isMounted && userRecord) setUserSummary(userSummaryFromRecord(user, userRecord));
      } catch {
        if (isMounted) setUserSummary(fallback);
      }
    });

    return () => {
      isMounted = false;
      unsubscribe();
    };
  }, []);

  function toggleSection(title: string) {
    setCollapsedSections((current) => {
      const next = new Set(current);
      if (next.has(title)) next.delete(title);
      else next.add(title);
      return next;
    });
  }

  function resetSidebarLayout() {
    setSearchQuery("");
    setCollapsedSections(new Set());
    setFavoritedItems(new Set());
  }

  function toggleFavoriteItem(label: string) {
    setFavoritedItems((current) => {
      const next = new Set(current);
      if (next.has(label)) next.delete(label);
      else next.add(label);
      return next;
    });
  }

  return (
    <main className="min-h-screen bg-[#F1F4F8] text-[#0F172A]">
      <div className="flex min-h-screen">
        <aside className="hidden w-[260px] shrink-0 flex-col border-r border-black/10 bg-white lg:flex">
          <div className="flex min-h-14 items-center justify-center border-b border-black/5 px-4">
            <img src="/assets/Alluwal_Education_Hub_Logo.png" alt="Alluwal Education Hub" className="h-12 w-auto object-contain" />
          </div>
          <div className="flex items-center justify-between border-b border-black/10 px-4 py-3">
            <p className="text-[21px] font-black text-[#0F172A]">Menu</p>
            <button type="button" className="grid h-8 w-8 place-items-center rounded-xl text-[#64748B] hover:bg-[#F8FAFC]" aria-label="Collapse sidebar">
              <ChevronUp size={18} className="-rotate-90" />
            </button>
          </div>
          <div className="px-3 py-3">
            <label className="sr-only" htmlFor="admin-shell-search">
              Search dashboard
            </label>
            <div className="relative">
              <Search aria-hidden="true" className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[#94A3B8]" size={16} />
              <input
                id="admin-shell-search"
                placeholder="Search..."
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                className="h-10 w-full rounded-xl border border-black/10 bg-white px-9 text-sm text-[#334155] outline-none focus:border-[#0386FF]"
              />
              {searchQuery.trim() ? (
                <button
                  type="button"
                  aria-label="Clear search"
                  onClick={() => setSearchQuery("")}
                  className="absolute right-2 top-1/2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-lg text-[#94A3B8] hover:bg-black/5 hover:text-[#334155]"
                >
                  <X size={15} />
                </button>
              ) : null}
            </div>
          </div>
          <nav className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Admin dashboard navigation">
            {favoriteSidebarItems.length > 0 ? (
              <SidebarFavorites
                items={favoriteSidebarItems}
                favoritedItems={favoritedItems}
                activeLabel={activeLabel}
                onToggleFavorite={toggleFavoriteItem}
              />
            ) : null}
            {visibleSidebarSections.map((section) => {
              const isCollapsed = !normalizedSearch && collapsedSections.has(section.title);
              return (
                <div key={section.title} className="mb-3">
                  <button
                    type="button"
                    onClick={() => toggleSection(section.title)}
                    className="flex min-h-9 w-full items-center gap-2 rounded-xl px-2 text-left text-[10px] font-black uppercase tracking-[0.14em] text-[#94A3B8] hover:bg-[#F8FAFC]"
                    aria-expanded={!isCollapsed}
                    aria-label={`${isCollapsed ? "Expand" : "Collapse"} ${section.title}`}
                  >
                    <Grid3X3 size={14} />
                    <span className="min-w-0 flex-1 truncate">{section.title}</span>
                    <ChevronUp size={16} className={`transition-transform ${isCollapsed ? "rotate-0" : "rotate-180"}`} />
                  </button>
                  {!isCollapsed ? (
                    <SidebarItems
                      items={section.items}
                      favoritedItems={favoritedItems}
                      activeLabel={activeLabel}
                      onToggleFavorite={toggleFavoriteItem}
                    />
                  ) : null}
                </div>
              );
            })}
            {visibleSidebarSections.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-black/10 bg-[#F8FAFC] px-3 py-4 text-sm font-bold text-[#64748B]">
                No matching dashboard items
              </div>
            ) : null}
          </nav>
          <div className="border-t border-black/10 bg-[#F8FAFC] px-3 py-3">
            <button
              type="button"
              onClick={resetSidebarLayout}
              className="inline-flex min-h-10 items-center gap-2 rounded-xl px-3 text-xs font-bold text-[#94A3B8] hover:bg-white hover:text-[#334155]"
            >
              <RotateCcw size={15} />
              Reset Layout
            </button>
          </div>
        </aside>

        <section className="min-w-0 flex-1">
          <header className="hidden min-h-14 items-center justify-between border-b border-black/5 bg-white px-4 lg:flex">
            <p className="text-sm font-bold text-[#64748B]">{breadcrumb}</p>
            <div className="flex items-center gap-3">
              {userSummary.roles.map((role, index) => (
                <span
                  key={role}
                  className={`inline-flex min-h-9 items-center rounded-full px-4 text-xs ${
                    index === 0 ? "bg-[#EF4444] font-black text-white" : "bg-[#E5E7EB] font-bold text-[#64748B]"
                  }`}
                >
                  {role}
                </span>
              ))}
              <span className="max-w-[240px] truncate text-sm font-semibold text-[#2563EB]">{userSummary.displayName}</span>
              <span className="grid h-10 w-10 place-items-center rounded-full bg-[#009688] text-sm font-black text-white">
                {userSummary.initials}
              </span>
            </div>
          </header>
          {children}
        </section>
      </div>
    </main>
  );
}

async function findUserRecord(user: User): Promise<UserRecord | null> {
  const byUid = await getDoc(doc(db, "users", user.uid));
  if (byUid.exists()) return byUid.data() as UserRecord;

  const email = user.email?.trim().toLowerCase();
  if (!email) return null;

  const byEmailId = await getDoc(doc(db, "users", email));
  if (byEmailId.exists()) return byEmailId.data() as UserRecord;

  for (const field of ["email", "e-mail"]) {
    const snap = await getDocs(query(collection(db, "users"), where(field, "==", email), limit(1)));
    if (!snap.empty) return snap.docs[0].data() as UserRecord;
  }

  return null;
}

function userSummaryFromRecord(user: User, data: UserRecord): ShellUserSummary {
  const displayName =
    [stringValue(data.first_name ?? data["first-name"]), stringValue(data.last_name ?? data["last-name"])]
      .filter(Boolean)
      .join(" ") ||
    stringValue(data.display_name ?? data.displayName ?? data.name) ||
    userSummaryFromAuth(user).displayName;

  return {
    displayName,
    initials: initialsFor(displayName),
    roles: roleLabelsFor(data),
  };
}

function userSummaryFromAuth(user: User): ShellUserSummary {
  const displayName = user.displayName?.trim() || user.email?.trim() || "Administrator";
  return {
    displayName,
    initials: initialsFor(displayName),
    roles: ["Administrator", "Teacher"],
  };
}

function roleLabelsFor(data: UserRecord) {
  const roles = new Set<string>();
  const primaryRole = stringValue(data.user_type).toLowerCase();
  if (primaryRole === "super_admin") roles.add("Super admin");
  if (primaryRole === "admin" || data.is_admin_teacher === true) roles.add("Administrator");
  if (primaryRole === "teacher" || primaryRole === "admin" || primaryRole === "super_admin") roles.add("Teacher");
  if (Array.isArray(data.secondary_roles)) {
    data.secondary_roles.forEach((role) => {
      const normalized = stringValue(role).toLowerCase();
      if (normalized === "super_admin") roles.add("Super admin");
      if (normalized === "admin") roles.add("Administrator");
      if (normalized === "teacher") roles.add("Teacher");
    });
  }
  if (roles.size === 0) roles.add("Administrator");
  return Array.from(roles).slice(0, 2);
}

function initialsFor(displayName: string) {
  const parts = displayName
    .replace(/@.*/, "")
    .split(/[\s._-]+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const initials = parts
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
  return initials || "AD";
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function SidebarFavorites({
  items,
  favoritedItems,
  activeLabel,
  onToggleFavorite,
}: {
  items: SidebarItem[];
  favoritedItems: Set<string>;
  activeLabel: string;
  onToggleFavorite: (label: string) => void;
}) {
  return (
    <div aria-label="Pinned dashboard items" className="mb-3 rounded-2xl border border-black/10 bg-[#F8FAFC] p-3">
      <div className="mb-2 flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.14em] text-[#64748B]">
        <Star size={14} className="fill-[#F59E0B] text-[#F59E0B]" />
        Favorites
      </div>
      <SidebarItems items={items} favoritedItems={favoritedItems} activeLabel={activeLabel} onToggleFavorite={onToggleFavorite} />
    </div>
  );
}

function SidebarItems({
  items,
  favoritedItems,
  activeLabel,
  onToggleFavorite,
}: {
  items: SidebarItem[];
  favoritedItems: Set<string>;
  activeLabel: string;
  onToggleFavorite: (label: string) => void;
}) {
  return (
    <div className="grid gap-1">
      {items.map((item) => {
        const Icon = item.icon;
        const isActive = item.label === activeLabel;
        return (
          <div key={item.label} className="flex min-h-10 items-center gap-2">
            <Link
              href={item.href}
              className={`flex min-w-0 flex-1 items-center gap-3 rounded-2xl px-3 text-sm font-bold ${
                isActive ? "bg-[#E6EEF8] text-[#001E4E]" : "text-[#334155] hover:bg-[#F1F4F8]"
              }`}
            >
              <span className="grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-[#F8FAFC]">
                <Icon size={18} style={{ color: item.color }} />
              </span>
              <span className="min-w-0 flex-1 truncate">{item.label}</span>
            </Link>
            <button
              type="button"
              aria-label={`${favoritedItems.has(item.label) ? "Unpin" : "Pin"} ${item.label}`}
              onClick={() => onToggleFavorite(item.label)}
              className="grid h-8 w-8 shrink-0 place-items-center rounded-xl text-[#94A3B8] hover:bg-[#F8FAFC] hover:text-[#F59E0B]"
            >
              <Star size={17} className={favoritedItems.has(item.label) ? "fill-[#F59E0B] text-[#F59E0B]" : ""} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
