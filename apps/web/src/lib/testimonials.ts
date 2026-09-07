/**
 * Testimonials shown on the public home page.
 *
 * Stored one document per quote in `public_site_cms_testimonials` and served
 * to visitors through the public marketing bundle, like the team profiles.
 * Until an admin has published any, the page shows the three quotes the site
 * has always carried, so the section is never empty.
 */

export type TestimonialCategory = "parent" | "student" | "teacher" | "other";

export type PublicSiteTestimonial = {
  id: string;
  quote: string;
  name: string;
  /** What the person is to Alluwal, e.g. "Parent of two students · Bronx, NY". */
  role: string;
  category: TestimonialCategory;
  imageUrl: string | null;
  sortOrder: number;
  active: boolean;
};

export const TESTIMONIAL_CATEGORIES: { id: TestimonialCategory; label: string }[] = [
  { id: "parent", label: "Parent" },
  { id: "student", label: "Student" },
  { id: "teacher", label: "Teacher" },
  { id: "other", label: "Community" },
];

export const categoryLabel = (category: TestimonialCategory): string =>
  TESTIMONIAL_CATEGORIES.find((entry) => entry.id === category)?.label ?? "Community";

export const toCategory = (value: unknown): TestimonialCategory => {
  const text = String(value ?? "").toLowerCase();
  return text === "parent" || text === "student" || text === "teacher" ? text : "other";
};

/** The quotes the home page carried before testimonials became editable. */
export const DEFAULT_TESTIMONIALS: PublicSiteTestimonial[] = [
  {
    id: "default-abdulai-diallo",
    quote:
      "Allah directed me to Alluwal — one of the best Arabic learning institutions, with qualified teachers and leaders of true integrity.",
    name: "Abdulai Diallo",
    role: "Ustaz · Kenema, Sierra Leone",
    category: "teacher",
    imageUrl: null,
    sortOrder: 1,
    active: true,
  },
  {
    id: "default-mamadou-saidou-diallo",
    quote:
      "Alluwal is professional and well-organized — exactly the kind of environment where meaningful education can thrive.",
    name: "Mamadou Saidou Diallo",
    role: "Teacher · Morocco",
    category: "teacher",
    imageUrl: null,
    sortOrder: 2,
    active: true,
  },
  {
    id: "default-zainab-sall",
    quote:
      "I chose Alluwal because of its strong educational values, supportive leadership, and genuine commitment to student success.",
    name: "Zainab Sall",
    role: "Teacher · Turkey",
    category: "teacher",
    imageUrl: null,
    sortOrder: 3,
    active: true,
  },
];

export const normalizeTestimonial = (id: string, item: Record<string, unknown>): PublicSiteTestimonial => ({
  id,
  quote: String(item.quote ?? "").trim(),
  name: String(item.name ?? "").trim(),
  role: String(item.role ?? "").trim(),
  category: toCategory(item.category),
  imageUrl: item.imageUrl ? String(item.imageUrl) : null,
  sortOrder: Number.isFinite(Number(item.sortOrder)) ? Number(item.sortOrder) : 0,
  active: item.active !== false,
});

/**
 * What visitors see: published quotes with words and a name, in order — or
 * the built-in three when nothing has been published yet.
 */
export const publishedTestimonials = (raw: unknown): PublicSiteTestimonial[] => {
  if (!Array.isArray(raw)) return DEFAULT_TESTIMONIALS;
  const rows = raw
    .filter((item): item is Record<string, unknown> => typeof item === "object" && item !== null)
    .map((item) => normalizeTestimonial(String(item.id ?? ""), item))
    .filter((row) => row.active && row.quote && row.name)
    .sort((a, b) => a.sortOrder - b.sortOrder);
  return rows.length > 0 ? rows : DEFAULT_TESTIMONIALS;
};

/** Initials for the avatar when there is no photo: "Zainab Sall" → "ZS". */
export const initialsOf = (name: string): string =>
  name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
