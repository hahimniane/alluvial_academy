/**
 * Links between finance pages. Every link keeps the month being looked at and
 * `embed=1`, so a page opened from the overview stays inside the Flutter frame
 * on the same month.
 */

/** `/admin/finance/staff/?month=2026-09` -> same, with embed=1; adds `month` when the link has none. */
export function financeHref(href: string, month: string): string {
  const [path, query = ""] = href.split("?");
  const params = new URLSearchParams(query);
  if (!params.has("month")) params.set("month", month);
  params.set("embed", "1");
  return `${path}?${params.toString()}`;
}
