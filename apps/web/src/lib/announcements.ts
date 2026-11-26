/**
 * School announcements (Firestore `announcements`), shared by the teacher,
 * student and parent home pages. Pure helpers only, so they run under
 * node:test; Firestore reads live in announcementsData.ts.
 *
 * Mirrors lib/core/models/announcement.dart in the Flutter app.
 */
export const ANNOUNCEMENT_ROLES = ["teacher", "student", "parent", "admin"] as const;
export type AnnouncementRole = (typeof ANNOUNCEMENT_ROLES)[number];

export const ANNOUNCEMENT_TITLE_MAX = 120;
export const ANNOUNCEMENT_BODY_MAX = 2000;

export type Announcement = {
  id: string;
  title: string;
  body: string;
  audience: AnnouncementRole[];
  pinned: boolean;
  expiresAt: Date | null;
  createdAt: Date | null;
  createdByName: string;
  status: "published" | "archived";
};

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/** A Firestore Timestamp, a Date or epoch millis. */
function dateOf(value: unknown): Date | null {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "number" && Number.isFinite(value)) return new Date(value);
  if (value && typeof value === "object" && typeof (value as { toDate?: unknown }).toDate === "function") {
    const date = (value as { toDate: () => Date }).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  return null;
}

export function audienceOf(value: unknown): AnnouncementRole[] {
  if (!Array.isArray(value)) return [];
  const roles = new Set<AnnouncementRole>();
  for (const entry of value) {
    const role = text(entry).toLowerCase();
    if ((ANNOUNCEMENT_ROLES as readonly string[]).includes(role)) roles.add(role as AnnouncementRole);
  }
  return ANNOUNCEMENT_ROLES.filter((role) => roles.has(role));
}

/** A document as an Announcement, or null when it has no title. */
export function parseAnnouncement(id: string, data: Record<string, unknown>): Announcement | null {
  const title = text(data.title);
  if (!title) return null;
  return {
    id,
    title,
    body: typeof data.body === "string" ? data.body.trim() : "",
    audience: audienceOf(data.audience),
    pinned: data.pinned === true,
    expiresAt: dateOf(data.expires_at),
    createdAt: dateOf(data.created_at),
    createdByName: text(data.created_by_name),
    status: data.status === "published" ? "published" : "archived",
  };
}

export function isActiveAnnouncement(item: Announcement, now: Date): boolean {
  if (item.status !== "published") return false;
  return !item.expiresAt || item.expiresAt.getTime() > now.getTime();
}

/** Published, unexpired, addressed to `role`; pinned first, then newest first. */
export function activeAnnouncements(items: Announcement[], role: AnnouncementRole, now: Date): Announcement[] {
  return items
    .filter((item) => isActiveAnnouncement(item, now) && item.audience.includes(role))
    .sort((a, b) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      return (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0);
    });
}

/** The pinned announcement to pop up: the newest pinned one not yet seen. */
export function nextUnseenPinned(active: Announcement[], seenIds: ReadonlySet<string>): Announcement | null {
  return active.find((item) => item.pinned && !seenIds.has(item.id)) ?? null;
}
