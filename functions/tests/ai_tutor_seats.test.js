const seats = require('../utils/ai_tutor_seats');

const settings = seats.normalizeSettings({seats: 10, windowStart: '15:00', windowEnd: '23:00', timezone: 'America/New_York', maxBookingsPerDay: 2});
// A Tuesday, 16:30 New York time (EDT = UTC-4).
const NOW = new Date('2026-09-08T20:30:00Z');

describe('settings', () => {
  test('missing or bad values fall back to the defaults', () => {
    const s = seats.normalizeSettings({seats: 'ten', windowStart: '25:00', timezone: 'Mars/Olympus'});
    expect(s.seats).toBe(10);
    expect(s.windowStart).toBe('15:00');
    expect(s.timezone).toBe('America/New_York');
    expect(s.enabled).toBe(true);
  });
});

describe('slots', () => {
  test('a slot key is the hour in the tutor timezone', () => {
    expect(seats.slotKeyFor(NOW, settings)).toBe('2026-09-08T16');
  });

  test('the window admits whole hours only', () => {
    expect(seats.slotInWindow('2026-09-08T15', settings)).toBe(true);
    expect(seats.slotInWindow('2026-09-08T22', settings)).toBe(true);
    expect(seats.slotInWindow('2026-09-08T23', settings)).toBe(false);
    expect(seats.slotInWindow('2026-09-08T14', settings)).toBe(false);
  });

  test('upcoming slots start next hour and skip outside the window', () => {
    const keys = seats.upcomingSlotKeys(NOW, settings, 1);
    expect(keys[0]).toBe('2026-09-08T17');
    expect(keys).toContain('2026-09-08T22');
    expect(keys).not.toContain('2026-09-08T23');
    expect(keys).toContain('2026-09-09T15');
    expect(keys).not.toContain('2026-09-09T14');
  });
});

describe('booking', () => {
  const ok = (over = {}) => seats.bookingProblem({slotKey: '2026-09-08T18', now: NOW, settings, existing: [], slotCount: 0, ...over});

  test('a free future hour inside the window can be booked', () => {
    expect(ok()).toBeNull();
  });

  test('an hour that has begun cannot be booked', () => {
    expect(ok({slotKey: '2026-09-08T16'})).toMatch(/already started/);
  });

  test('outside the window is refused with the hours shown', () => {
    expect(ok({slotKey: '2026-09-09T09'})).toMatch(/15:00–23:00/);
  });

  test('a full hour is refused', () => {
    expect(ok({slotCount: 10})).toMatch(/full/);
  });

  test('two bookings a day is the limit, and no hour twice', () => {
    const two = [{slotKey: '2026-09-08T19'}, {slotKey: '2026-09-08T21'}];
    expect(ok({existing: two})).toMatch(/2 hours a day/);
    expect(ok({existing: [{slotKey: '2026-09-08T18'}]})).toMatch(/already have/);
    // A different day starts a fresh allowance.
    expect(ok({slotKey: '2026-09-09T18', existing: two})).toBeNull();
  });

  test('switched off refuses everything', () => {
    expect(ok({settings: {...settings, enabled: false}})).toMatch(/switched off/);
  });
});

describe('starting now', () => {
  const start = (over = {}) => seats.startProblem({now: NOW, settings, activeCount: 0, slotBookings: [], myBooking: null, activeForMe: false, ...over});

  test('a walk-in gets a seat when one is free', () => {
    expect(start()).toBeNull();
  });

  test('seats promised to others this hour are held back from walk-ins', () => {
    const held = Array.from({length: 4}, () => ({started: false}));
    expect(start({activeCount: 6, slotBookings: held})).toMatch(/taken this hour/);
    // Once those bookers have started, they are counted as active, not held.
    expect(start({activeCount: 9, slotBookings: held.map((b) => ({...b, started: true}))})).toBeNull();
  });

  test('a booking for this hour is honoured even when walk-ins are turned away', () => {
    const held = Array.from({length: 9}, () => ({started: false}));
    expect(start({activeCount: 0, slotBookings: held, myBooking: {slotKey: '2026-09-08T16'}})).toBeNull();
  });

  test('outside the window a walk-in is refused', () => {
    expect(start({now: new Date('2026-09-09T13:00:00Z')})).toMatch(/available/);
  });

  test('resuming your own live session is always allowed', () => {
    expect(start({activeCount: 10, activeForMe: true})).toBeNull();
  });
});

describe('the clock', () => {
  test('a walk-in session runs the full length', () => {
    expect(seats.sessionExpiry(NOW, settings, null).toISOString()).toBe('2026-09-08T21:30:00.000Z');
  });

  test('a booked session ends at the end of its hour', () => {
    expect(seats.sessionExpiry(NOW, settings, {slotKey: '2026-09-08T16'}).toISOString()).toBe('2026-09-08T21:00:00.000Z');
  });
});

describe('the conversation sent to the model', () => {
  test('keeps only recent, well-formed turns', () => {
    const many = Array.from({length: 40}, (_, i) => ({role: i % 2 ? 'assistant' : 'user', text: `turn ${i}`}));
    const out = seats.trimHistory([...many, {role: 'system', text: 'x'}, {role: 'user', text: '   '}], settings);
    expect(out).toHaveLength(16);
    expect(out[0].text).toBe('turn 24');
  });

  test('the phone is told which voice to use', () => {
    expect(seats.languageOf('What is wudu?')).toBe('en');
    expect(seats.languageOf('ما هو الوضوء؟')).toBe('ar');
    expect(seats.languageOf("Qu'est-ce que la prière pour les enfants ?")).toBe('fr');
  });

  test('the prompt names the student and forbids invented verses', () => {
    const p = seats.SYSTEM_PROMPT({studentName: 'Amina', language: 'en'});
    expect(p).toMatch(/Amina/);
    expect(p).toMatch(/Never invent/);
  });
});
