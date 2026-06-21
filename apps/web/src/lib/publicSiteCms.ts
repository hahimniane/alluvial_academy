import { httpsCallable } from "firebase/functions";
import { functions } from "@/lib/firebase";

export type PublicSitePlanPricing = {
  session30Usd?: number;
  session60Usd?: number;
  hourlyUsd?: number;
  tutoringHrUnder4Usd?: number;
  tutoringHr4PlusUsd?: number;
  islamicHrUnder5Usd?: number;
  islamicHr5PlusUsd?: number;
  islamicBaseUsd?: number;
  islamicDiscountUsd?: number;
  islamicDiscountThreshold?: number;
  tutoringBaseUsd?: number;
  tutoringDiscountUsd?: number;
  tutoringDiscountThreshold?: number;
  groupHourlyUsd?: number;
  bullets: string[];
};

export type PublicSitePricingDoc = {
  plans: Record<string, PublicSitePlanPricing>;
};

export type PublicSiteSocialNetwork = {
  enabled: boolean;
  url: string;
};

export type PublicSiteSocialDoc = {
  instagram: PublicSiteSocialNetwork;
  facebook: PublicSiteSocialNetwork;
  tiktok: PublicSiteSocialNetwork;
};

export type PublicSiteLandingDoc = {
  heroBackgroundColorHex: string;
  heroMainImageUrl: string;
  heroLeftImageUrl: string;
  heroRightImageUrl: string;
};

export type PublicSiteTeamMember = {
  id: string;
  name: string;
  role: string;
  city: string;
  education: string;
  bio: string;
  languages: string[];
  whyAlluwal: string;
  imageUrl?: string | null;
  photoAsset?: string | null;
  linkedUserUid?: string | null;
  category: string;
  sortOrder: number;
  active: boolean;
};

export type PublicSiteMarketingBundle = {
  pricing: PublicSitePricingDoc;
  social: PublicSiteSocialDoc;
  landing: PublicSiteLandingDoc;
  teamMembers: PublicSiteTeamMember[];
};

const emptySocial = {
  instagram: { enabled: false, url: "" },
  facebook: { enabled: false, url: "" },
  tiktok: { enabled: false, url: "" },
};

export const fallbackPricing: PublicSitePricingDoc = {
  plans: {
    islamic: {
      islamicBaseUsd: 8.5,
      islamicDiscountUsd: 6.99,
      islamicDiscountThreshold: 4,
      bullets: ["Quran recitation", "Islamic studies", "Flexible 1-on-1 scheduling"],
    },
    tutoring: {
      tutoringBaseUsd: 11.99,
      tutoringDiscountUsd: 9.99,
      tutoringDiscountThreshold: 4,
      bullets: ["Math and science support", "Homework help", "Progress-centered tutoring"],
    },
    group: {
      groupHourlyUsd: 2.5,
      bullets: ["Weekend and small-group classes", "Community learning", "Affordable recurring sessions"],
    },
  },
};

export async function loadPublicMarketingBundle(): Promise<PublicSiteMarketingBundle> {
  const isLocalBrowser =
    typeof window !== "undefined" &&
    ["localhost", "127.0.0.1", "::1"].includes(window.location.hostname);
  const forceCallable = process.env.NEXT_PUBLIC_USE_CMS_CALLABLE === "1";

  if (process.env.NEXT_PUBLIC_USE_CMS_FALLBACK === "1" || (isLocalBrowser && !forceCallable)) {
    return normalizeBundle(null);
  }

  try {
    const callable = httpsCallable(functions, "getPublicSiteMarketingBundle");
    const result = await callable();
    const raw = result.data as Partial<PublicSiteMarketingBundle> | null;
    return normalizeBundle(raw);
  } catch {
    return normalizeBundle(null);
  }
}

export function photoAssetToPath(path?: string | null) {
  if (!path) return null;
  if (path.startsWith("http")) return path;
  return `/${path.replace(/^assets\//, "assets/")}`;
}

async function loadFallbackTeam(): Promise<PublicSiteTeamMember[]> {
  try {
    const response = await fetch("/assets/data/staff.json", { cache: "force-cache" });
    if (!response.ok) return [];
    const raw = (await response.json()) as PublicSiteTeamMember[];
    return raw
      .map((member) => ({ ...member, active: member.active !== false, linkedUserUid: member.linkedUserUid ?? member.id }))
      .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
  } catch {
    return [];
  }
}

async function normalizeTeam(raw: unknown) {
  if (!Array.isArray(raw)) return loadFallbackTeam();
  const rows = raw
    .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
    .map((item) => ({
      id: String(item.id ?? ""),
      name: String(item.name ?? ""),
      role: String(item.role ?? ""),
      city: String(item.city ?? ""),
      education: String(item.education ?? ""),
      bio: String(item.bio ?? ""),
      languages: Array.isArray(item.languages) ? item.languages.map(String) : [],
      whyAlluwal: String(item.whyAlluwal ?? ""),
      imageUrl: item.imageUrl ? String(item.imageUrl) : null,
      photoAsset: item.photoAsset ? String(item.photoAsset) : null,
      linkedUserUid: item.linkedUserUid ? String(item.linkedUserUid) : null,
      category: String(item.category ?? "teacher"),
      sortOrder: Number(item.sortOrder ?? 0),
      active: item.active !== false,
    }))
    .filter((member) => member.active && member.name)
    .sort((a, b) => a.sortOrder - b.sortOrder);
  return rows.length > 0 ? rows : loadFallbackTeam();
}

async function normalizeBundle(raw: Partial<PublicSiteMarketingBundle> | null): Promise<PublicSiteMarketingBundle> {
  return {
    pricing: raw?.pricing?.plans ? raw.pricing : fallbackPricing,
    social: raw?.social ?? emptySocial,
    landing: {
      heroBackgroundColorHex: raw?.landing?.heroBackgroundColorHex || "#00484E",
      heroMainImageUrl: raw?.landing?.heroMainImageUrl || "",
      heroLeftImageUrl: raw?.landing?.heroLeftImageUrl || "",
      heroRightImageUrl: raw?.landing?.heroRightImageUrl || "",
    },
    teamMembers: await normalizeTeam(raw?.teamMembers),
  };
}
