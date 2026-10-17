/**
 * Putting a submission's answers back in question order.
 *
 * A form response stores its answers as a map keyed by question id, and
 * Firestore hands map keys back in no particular order, so a viewer that walks
 * the map shows questions shuffled. The template still knows the order — each
 * question carries an `order`, or failing that its position in the stored
 * list — so viewers sort by that. Answers whose question is no longer on the
 * template keep their stored order and go last.
 */

export type FieldLayout = {
  labels: Record<string, string>;
  /** Question id -> rank (0 = first question). */
  order: Record<string, number>;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function trimmed(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

/** The stored `order` when it is a real number — 0 included. */
export function storedOrder(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

/** Template fields in either stored shape (list or id-keyed map) as [id, data] pairs. */
export function fieldEntries(fields: unknown): Array<[string, Record<string, unknown>]> {
  if (Array.isArray(fields)) {
    return fields.map((item, index) => {
      const data = asRecord(item);
      return [trimmed(data.id) || `field_${index}`, data];
    });
  }
  return Object.entries(asRecord(fields)).map(([id, item]) => [id, asRecord(item)]);
}

/** Labels and question order for a template's `fields`, whichever shape they are stored in. */
export function buildFieldLayout(fields: unknown): FieldLayout {
  const entries = fieldEntries(fields);
  const labels: Record<string, string> = {};
  const ranked = entries.map(([id, data], position) => {
    const label = trimmed(data.label) || trimmed(data.question) || trimmed(data.name);
    if (id && label) labels[id] = label;
    return { id, position, order: storedOrder(data.order) ?? position };
  });
  ranked.sort((a, b) => a.order - b.order || a.position - b.position);
  const order: Record<string, number> = {};
  ranked.forEach((item, rank) => {
    if (item.id && !(item.id in order)) order[item.id] = rank;
  });
  return { labels, order };
}

/** A submission's answers sorted by question order; unknown questions last, in stored order. */
export function orderResponseEntries<T>(responses: Record<string, T>, order: Record<string, number>): Array<[string, T]> {
  return Object.entries(responses)
    .map((entry, position) => ({ entry, position, rank: Object.prototype.hasOwnProperty.call(order, entry[0]) ? order[entry[0]] : Number.POSITIVE_INFINITY }))
    .sort((a, b) => (a.rank === b.rank ? a.position - b.position : a.rank < b.rank ? -1 : 1))
    .map((item) => item.entry);
}
