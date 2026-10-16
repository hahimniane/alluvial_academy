/**
 * Whether two student records describe the same child.
 *
 * Names are compared without case, accents, spaces or punctuation, so
 * "Mariama  Barry" and "mariama-barry" match. A match only counts as the same
 * child when the two records share a guardian: many families share Diallo or
 * Bah, and a name alone must never merge two different children.
 */
const normalizeName = (value) => String(value || '')
  .normalize('NFD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z]/g, '');

const sameChild = ({firstName, lastName, guardianIds}, existing) => {
  const guardians = new Set((guardianIds || []).map(String).filter(Boolean));
  if (!guardians.size) return false;
  const theirs = Array.isArray(existing.guardian_ids) ? existing.guardian_ids.map(String) : [];
  if (!theirs.some((g) => guardians.has(g))) return false;
  if (normalizeName(existing.first_name) !== normalizeName(firstName)) return false;
  // Many applications give the child's first name only ("Isa", "Aminah"),
  // while the account the parent already has carries the family name. Within
  // one guardian's children a first name is identifying enough; demanding the
  // surname here created a second account for the same child, which admins
  // then deleted by hand, leaving the application pointing at nothing.
  if (!normalizeName(lastName)) return true;
  return normalizeName(existing.last_name) === normalizeName(lastName);
};

module.exports = {normalizeName, sameChild};
