'use strict';

/**
 * Turning the hub bot's view of each room into a record of who dropped out.
 *
 * The bot reports, every few seconds, who is inside each class's breakout room.
 * Comparing one report with the last gives arrivals and departures. That is the
 * only signal that sees teachers at all: teachers join through the Zoom desktop
 * app and abandon the browser page, so the 45-second browser heartbeat never
 * runs for them.
 *
 * A departure is not automatically the person's fault, and saying so would be
 * unfair — we remove people ourselves more often than their networks do. Each
 * departure therefore carries a cause:
 *
 *   platform     we did this: the bot was moving them, or the hub handed over,
 *                or a lane restarted. Never counted against anyone.
 *   simultaneous several people in one room vanished together. Real home
 *                networks do not fail in unison, so this is ours too, even when
 *                we cannot name which of our faults it was.
 *   individual   one person went while the room carried on without them. This
 *                is the teacher-network candidate — and it is only a candidate:
 *                a Zoom hiccup and a closed laptop land here too.
 *
 * Durations are stored raw and thresholds applied at read time, so the "how
 * long counts as a drop" line can be moved later from evidence instead of being
 * guessed now.
 */

/** Departures this close together are one event, not several. */
const SIMULTANEOUS_WINDOW_MS = 10 * 1000;

/** Two or more people leaving at once is not two coincidental networks. */
const SIMULTANEOUS_MIN_PEOPLE = 2;

const CAUSE_PLATFORM = 'platform';
const CAUSE_SIMULTANEOUS = 'simultaneous';
const CAUSE_INDIVIDUAL = 'individual';

/** The bot reports a hub's live participants as shiftId -> [{...people}]. */
const _peopleByShift = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return new Map();
  const byShift = new Map();
  for (const [shiftId, people] of Object.entries(raw)) {
    if (!Array.isArray(people)) continue;
    const byUid = new Map();
    for (const person of people) {
      if (!person || typeof person !== 'object') continue;
      const uid = String(person.routingUid || person.routing_uid || person.uid || person.identity || '').trim();
      if (!uid) continue;
      byUid.set(uid, {
        uid,
        name: String(person.name || '').trim() || null,
        role: String(person.role || '').trim() || null,
      });
    }
    byShift.set(String(shiftId), byUid);
  }
  return byShift;
};

/**
 * Who arrived and who left between two reports.
 *
 * A shift missing from `next` entirely means the bot stopped reporting it, not
 * that everyone left — the difference matters, because treating "no data" as
 * "empty" is how an outage gets recorded as thirty people quitting at once. Only
 * shifts present in both reports are compared.
 *
 * `everyoneIsLeaving` is the one case where that guard is wrong: when we
 * deliberately close a hub, its people really are all leaving, and it is us
 * doing it. Pass it only for a close-out, never for a report that merely
 * arrived empty.
 */
function diffLiveParticipants(previousRaw, nextRaw, { everyoneIsLeaving = false } = {}) {
  const previous = _peopleByShift(previousRaw);
  const next = _peopleByShift(nextRaw);
  const arrivals = [];
  const departures = [];

  if (everyoneIsLeaving) {
    // A deliberate close-out, not a silence. Here a missing class really does
    // mean its people are gone, because we are the ones ending it.
    for (const [shiftId, before] of previous.entries()) {
      for (const person of before.values()) departures.push({ shiftId, ...person });
    }
    return { arrivals, departures };
  }

  for (const [shiftId, nowPeople] of next.entries()) {
    const before = previous.get(shiftId);
    if (!before) continue; // first sight of this class: nothing to compare against
    for (const [uid, person] of nowPeople.entries()) {
      if (!before.has(uid)) arrivals.push({ shiftId, ...person });
    }
    for (const [uid, person] of before.entries()) {
      if (!nowPeople.has(uid)) departures.push({ shiftId, ...person });
    }
  }
  return { arrivals, departures };
}

/**
 * Why these people left, decided per departure.
 *
 * `routedUids` are the people the bot said it was about to move at this moment —
 * it names them before it moves them, so their disappearance is ours and known,
 * not inferred. `platformEvent` marks a moment we already know was ours (a hub
 * handover, a recycled page, a lane restart), which covers everyone at once.
 */
function classifyDepartures(departures, { routedUids = [], platformEvent = null } = {}) {
  const routed = new Set(routedUids.map((uid) => String(uid)));
  const countByShift = new Map();
  for (const departure of departures) {
    countByShift.set(departure.shiftId, (countByShift.get(departure.shiftId) || 0) + 1);
  }

  return departures.map((departure) => {
    const peersGoneTogether = (countByShift.get(departure.shiftId) || 1) - 1;
    let cause = CAUSE_INDIVIDUAL;
    let detail = null;

    if (platformEvent) {
      cause = CAUSE_PLATFORM;
      detail = platformEvent;
    } else if (routed.has(departure.uid)) {
      cause = CAUSE_PLATFORM;
      detail = 'bot_moved_them';
    } else if (peersGoneTogether + 1 >= SIMULTANEOUS_MIN_PEOPLE) {
      cause = CAUSE_SIMULTANEOUS;
      detail = `${peersGoneTogether + 1}_left_together`;
    }

    return { ...departure, cause, detail, peersGoneTogether };
  });
}

/**
 * Pair departures with the arrival that ended them, giving each absence a real
 * duration. An absence still open when the class ended is closed at `classEnd`
 * and marked as such: someone who never came back did not have a short drop.
 */
function buildAbsences(events, { classEnd = null } = {}) {
  const ordered = [...events].sort((a, b) => a.atMs - b.atMs);
  const open = new Map(); // `${shiftId}|${uid}` -> departure
  const absences = [];
  const key = (event) => `${event.shiftId}|${event.uid}`;

  for (const event of ordered) {
    if (event.type === 'departed') {
      // A second departure with no arrival between is the same absence.
      if (!open.has(key(event))) open.set(key(event), event);
      continue;
    }
    if (event.type !== 'arrived') continue;
    const departure = open.get(key(event));
    if (!departure) continue;
    open.delete(key(event));
    absences.push({
      shiftId: departure.shiftId,
      uid: departure.uid,
      name: departure.name ?? event.name ?? null,
      role: departure.role ?? event.role ?? null,
      cause: departure.cause,
      detail: departure.detail ?? null,
      startedAtMs: departure.atMs,
      endedAtMs: event.atMs,
      seconds: Math.max(0, Math.round((event.atMs - departure.atMs) / 1000)),
      returned: true,
    });
  }

  for (const departure of open.values()) {
    const endedAtMs = classEnd ?? null;
    absences.push({
      shiftId: departure.shiftId,
      uid: departure.uid,
      name: departure.name ?? null,
      role: departure.role ?? null,
      cause: departure.cause,
      detail: departure.detail ?? null,
      startedAtMs: departure.atMs,
      endedAtMs,
      seconds: endedAtMs === null
        ? null
        : Math.max(0, Math.round((endedAtMs - departure.atMs) / 1000)),
      returned: false,
    });
  }

  return absences.sort((a, b) => a.startedAtMs - b.startedAtMs);
}

module.exports = {
  SIMULTANEOUS_WINDOW_MS,
  SIMULTANEOUS_MIN_PEOPLE,
  CAUSE_PLATFORM,
  CAUSE_SIMULTANEOUS,
  CAUSE_INDIVIDUAL,
  diffLiveParticipants,
  classifyDepartures,
  buildAbsences,
};
