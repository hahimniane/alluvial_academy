/**
 * Where a person joins a Zoom class from: the Zoom app on their computer, or
 * the web SDK on this site.
 *
 * Teachers host the class, so they are handed out to the desktop Zoom app where
 * the host controls live. Students and parents stay on the site. That split is
 * how the Flutter web app always behaved, and this mirrors
 * `_shouldPreferDesktopZoomApp` in lib/core/services/class_video_service.dart
 * clause for clause — including the hub-routing conditions, so a teacher whose
 * class is not hub-routed still joins in the browser, exactly as before.
 */
export type ZoomRouting = {
  meetingNumber?: string;
  password?: string;
  displayName?: string;
  nativeDisplayName?: string;
  routingDisplayName?: string;
  routingMode?: string;
  userRole?: string;
  autoJoinBreakoutRoom?: boolean;
};

const HOST_ROLES = new Set(["teacher", "admin", "super_admin", "admin_teacher"]);

/** Flutter gates this on a desktop platform; on the web that means "not a phone or tablet". */
export function isDesktopBrowser(userAgent: string) {
  return !/Android|iPhone|iPad|iPod|Mobile|Silk|Kindle/i.test(userAgent);
}

export function prefersDesktopZoomApp(data: ZoomRouting, userAgent: string) {
  if (!isDesktopBrowser(userAgent)) return false;
  if (data.routingMode !== "hub" || data.autoJoinBreakoutRoom !== true) return false;
  if (!(data.routingDisplayName ?? "").trim()) return false;
  return HOST_ROLES.has((data.userRole ?? "").trim().toLowerCase());
}

export function desktopZoomDisplayName(data: ZoomRouting) {
  return (
    (data.routingDisplayName ?? "").trim() ||
    (data.nativeDisplayName ?? "").trim() ||
    (data.displayName ?? "").trim() ||
    "Participant"
  );
}

/** zoommtg://zoom.us/join?... — the link that opens the installed Zoom app. */
export function buildDesktopZoomUrl(data: ZoomRouting) {
  const meetingNumber = (data.meetingNumber ?? "").replace(/\D/g, "");
  if (!meetingNumber) return "";
  const params = new URLSearchParams({ action: "join", confno: meetingNumber });
  const password = (data.password ?? "").trim();
  if (password) params.set("pwd", password);
  params.set("uname", desktopZoomDisplayName(data));
  return `zoommtg://zoom.us/join?${params.toString()}`;
}
