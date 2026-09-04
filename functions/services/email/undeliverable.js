const admin = require('firebase-admin');

const SCHOOL_DOMAIN = '@alluwaleducationhub.org';

/**
 * A student who joins without an address of their own is given an alias at the
 * school's own domain — `<student_code>@alluwaleducationhub.org` — because
 * Firebase Auth needs something to key the account on. No mailbox exists behind
 * it. Mail addressed there reaches nobody, so it is dropped before it is sent
 * rather than being fired at a domain that cannot receive it.
 *
 * Staff do hold real mailboxes on that domain (support@, billing@, and named
 * admins), so the domain alone decides nothing: the address is only treated as
 * an alias when it belongs to a student. An address with no user record behind
 * it is left alone — it is more likely a real mailbox than a student alias.
 */
const _cache = new Map();

const _isStudentRecord = (data) => {
  const type = String((data || {}).user_type || (data || {}).role || '').trim().toLowerCase();
  return type === 'student';
};

const _lookupIsStudentAlias = async (address) => {
  const db = admin.firestore();
  const users = db.collection('users');
  for (const field of ['email', 'e-mail']) {
    const snap = await users.where(field, '==', address).limit(1).get();
    if (!snap.empty) return _isStudentRecord(snap.docs[0].data());
  }
  return false;
};

/** True when mail to this address would reach nobody. */
const isUndeliverableAddress = async (address) => {
  const clean = String(address || '').trim().toLowerCase();
  if (!clean.endsWith(SCHOOL_DOMAIN)) return false;
  if (_cache.has(clean)) return _cache.get(clean);
  let result = false;
  try {
    result = await _lookupIsStudentAlias(clean);
  } catch (e) {
    // A lookup failure must not stop real mail; treat the address as deliverable.
    console.error('isUndeliverableAddress: lookup failed for', clean, '-', e.message);
    return false;
  }
  _cache.set(clean, result);
  return result;
};

/**
 * Split a nodemailer recipient field into the addresses worth sending to and
 * the ones that reach nobody. Accepts the shapes nodemailer accepts: a string,
 * a comma-separated string, an array, or `{name, address}` objects.
 */
const partitionRecipients = async (value) => {
  if (!value) return {deliverable: value, dropped: []};
  const entries = (Array.isArray(value) ? value : String(value).split(','))
    .map((entry) => (typeof entry === 'string' ? entry.trim() : entry))
    .filter(Boolean);

  const addressOf = (entry) => {
    if (typeof entry === 'string') {
      const angled = entry.match(/<([^>]+)>/);
      return (angled ? angled[1] : entry).trim().toLowerCase();
    }
    return String((entry || {}).address || '').trim().toLowerCase();
  };

  const deliverable = [];
  const dropped = [];
  for (const entry of entries) {
    // eslint-disable-next-line no-await-in-loop
    if (await isUndeliverableAddress(addressOf(entry))) dropped.push(addressOf(entry));
    else deliverable.push(entry);
  }
  return {deliverable, dropped};
};

module.exports = {isUndeliverableAddress, partitionRecipients, SCHOOL_DOMAIN};
