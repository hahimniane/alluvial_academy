/**
 * Weekly-hours limits for the public enrollment and pricing UI.
 *
 * The cap used to be a bare `8` repeated in five places across three
 * components, which is why raising it meant hunting for every copy. Nothing in
 * the backend enforces a maximum — this exists only to keep the picker sane and
 * catch a mis-typed number, so it lives in one place now.
 */
export const MIN_HOURS_PER_WEEK = 1;
export const MAX_HOURS_PER_WEEK = 20;

/** Clamp any requested hours (user input, or an `?hours=` URL parameter). */
export function clampHoursPerWeek(hours: number) {
  return Math.min(Math.max(hours, MIN_HOURS_PER_WEEK), MAX_HOURS_PER_WEEK);
}

/**
 * Hour choices offered as buttons on the pricing section.
 *
 * Every hour up to 8 — the range nearly all families pick from — then wider
 * steps, so heavier schedules are reachable without twenty tabs on screen.
 */
export const PRICING_HOUR_OPTIONS = [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20];
