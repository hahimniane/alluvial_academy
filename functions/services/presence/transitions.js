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

/**
 * Who this participant is, for the purpose of noticing they went.
 *
 * Somebody who joined through the app carries a routing id and that is the
 * best answer. Somebody who opened the Zoom link directly carries none — every
 * id field arrives empty — and an earlier version dropped them on the floor,
 * which quietly excluded exactly the people most likely to be having trouble
 * getting in. Zoom's own participant id identifies them within the meeting,
 * and their display name is the last resort.
 *
 * The id only has to be stable between two consecutive reports of the same
 * meeting, which all three are.
 */
const _identify = (person = {}) => {
  const routing = String(
    person.routingUid || person.routing_uid || person.uid || person.identity || '',
  ).trim();
  if (routing) return routing;
  const zoomUserId = person.zoomUserId ?? person.zoom_user_id;
  if (zoomUserId !== undefined && zoomUserId !== null && `${zoomUserId}`.trim()) {
    return `zoom:${`${zoomUserId}`.trim()}`;
  }
  const name = String(person.name || '').trim();
  return name ? `name:${name}` : '';
};

/** The bot reports a hub's live participants as shiftId -> [{...people}]. */
const _peopleByShift = (raw) => {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return new Map();
  const byShift = new Map();
  for (const [shiftId, people] of Object.entries(raw)) {
    if (!Array.isArray(people)) continue;
    const byUid = new Map();
    for (const person of people) {
      if (!person || typeof person !== 'object') continue;
      const uid = _identify(person);
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
 * Departures are found by walking the PREVIOUS report, not the new one. The bot
 * only lists a class while somebody is inside its room, so the moment a room
 * empties its entry disappears from the report altogether — and a version of
 * this that walked the new report recorded nothing at all when a teacher
 * dropped out, which is the one case the whole thing exists for.
 *
 * That leaves the opposite danger: a report we should not believe. A bot that
 * has lost sight of the breakout rooms reports them as empty, and trusting it
 * would manufacture a drop-out for every person in every class at once. Such a
 * report is refused outright by the caller rather than read as an exodus — see
 * `reportIsBlind`.
 */
function diffLiveParticipants(previousRaw, nextRaw) {
  const previous = _peopleByShift(previousRaw);
  const next = _peopleByShift(nextRaw);
  const arrivals = [];
  const departures = [];

  for (const [shiftId, nowPeople] of next.entries()) {
    const before = previous.get(shiftId) || new Map();
    for (const [uid, person] of nowPeople.entries()) {
      if (!before.has(uid)) arrivals.push({ shiftId, ...person });
    }
  }

  for (const [shiftId, before] of previous.entries()) {
    const nowPeople = next.get(shiftId) || new Map();
    for (const [uid, person] of before.entries()) {
      if (!nowPeople.has(uid)) departures.push({ shiftId, ...person });
    }
  }

  return { arrivals, departures };
}

/**
 * Whether this report is one we can believe about who is in a room.
 *
 * The bot reads the breakout rooms from inside the meeting. When that reading
 * comes back empty while rooms are supposed to be open, the bot has gone blind
 * rather than the rooms having emptied — the same corruption the watchdog
 * already resets hubs for. Believing it would record every person in every
 * class dropping out in the same second.
 */
function reportIsBlind({ stats = {}, expectedRooms = 0 } = {}) {
  const liveRoomCount = Number(stats.liveRoomCount);
  return Number.isFinite(liveRoomCount) && liveRoomCount === 0 && expectedRooms > 0;
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
  reportIsBlind,
  classifyDepartures,
  buildAbsences,
};
