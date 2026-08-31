/**
 * Timezone helpers mirroring the Flutter TimezoneUtils: same region grouping,
 * same "City (Zone/Id) - ABBR (UTC±HH:MM)" display format, driven by the
 * browser's own IANA database (Intl.supportedValuesOf).
 */

const PREFERRED_REGION_ORDER = [
  "UTC",
  "Africa",
  "America",
  "Antarctica",
  "Asia",
  "Atlantic",
  "Australia",
  "Europe",
  "Indian",
  "Pacific",
  "Etc",
  "Other",
];

export function allTimezones(): string[] {
  const zones = new Set<string>(
    typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : [],
  );
  zones.add("UTC");
  return [...zones].sort();
}

/** Region = first path segment (`America/New_York` → `America`); no slash → `Other`. */
export function timezonesByRegion(): Array<[string, string[]]> {
  const grouped = new Map<string, string[]>();
  for (const id of allTimezones()) {
    const region = id.includes("/") ? id.split("/")[0] : id === "UTC" ? "UTC" : "Other";
    const list = grouped.get(region) ?? [];
    list.push(id);
    grouped.set(region, list);
  }
  const ordered: Array<[string, string[]]> = [];
  for (const region of PREFERRED_REGION_ORDER) {
    const items = grouped.get(region);
    if (!items) continue;
    grouped.delete(region);
    ordered.push([region, items.sort()]);
  }
  for (const region of [...grouped.keys()].sort()) {
    ordered.push([region, grouped.get(region)!.sort()]);
  }
  return ordered;
}

export function timezoneCity(id: string): string {
  const parts = id.split("/");
  return (parts[parts.length - 1] || id).replaceAll("_", " ");
}

function tzNamePart(id: string, at: Date, style: "short" | "longOffset"): string {
  try {
    const parts = new Intl.DateTimeFormat("en-US", { timeZone: id, timeZoneName: style }).formatToParts(at);
    return parts.find((part) => part.type === "timeZoneName")?.value ?? "";
  } catch {
    return "";
  }
}

export function timezoneAbbreviation(id: string, at: Date = new Date()): string {
  return tzNamePart(id, at, "short") || id;
}

/** `GMT-04:00` / `GMT` → `-04:00` / `+00:00`. */
export function timezoneOffsetLabel(id: string, at: Date = new Date()): string {
  const raw = tzNamePart(id, at, "longOffset");
  const match = raw.match(/GMT([+-]\d{2}:\d{2})?/);
  return match?.[1] ?? "+00:00";
}

/** Flutter format: `New York (America/New_York) - EDT (UTC-04:00)`. */
export function formatTimezoneForDisplay(id: string, at: Date = new Date()): string {
  return `${timezoneCity(id)} (${id}) - ${timezoneAbbreviation(id, at)} (UTC${timezoneOffsetLabel(id, at)})`;
}

/** Legacy data stores abbreviations ("EDT") which Intl rejects — map them home. */
const TZ_FALLBACKS: Record<string, string> = {
  EDT: "America/New_York",
  EST: "America/New_York",
  CDT: "America/Chicago",
  CST: "America/Chicago",
  MDT: "America/Denver",
  MST: "America/Denver",
  PDT: "America/Los_Angeles",
  PST: "America/Los_Angeles",
  GMT: "UTC",
};

/**
 * A timezone string that Intl is guaranteed to accept. Invalid input maps via
 * the abbreviation table or falls back — Intl THROWS on bad zones, and one
 * corrupt document must never be able to crash the whole schedule page.
 */
export function safeTimezone(zone: string | null | undefined, fallback = "America/New_York"): string {
  const raw = (zone || "").trim();
  if (!raw) return fallback;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: raw });
    return raw;
  } catch {
    return TZ_FALLBACKS[raw.toUpperCase()] ?? fallback;
  }
}
