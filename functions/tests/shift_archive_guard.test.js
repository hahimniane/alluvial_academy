/**
 * Hard line: nothing that computes a period from teaching shifts may read the
 * live collection alone. Classes older than 60 days live in
 * `teaching_shifts_archive`; a live-only range query silently drops them and
 * the numbers it feeds (pay, invoices, attendance) come out short.
 *
 * Range queries on `shift_start` must go through utils/shifts_in_range.js.
 * The files below predate the rule and deal with upcoming or in-flight
 * classes only; do not add to this list to make a money path pass.
 */
const fs = require('fs');
const path = require('path');

const ALLOWED_LIVE_ONLY = new Set([
  'shifts.js',            // generating and reminding upcoming shifts
  'zoom.js',              // live-class hubs for classes happening now
  'ai_tutor.js',          // seat checks for the current day
  'migration_livekit.js', // one-off migration
  'circles.js',
  'forms.js',
  'users.js',
  'shift_archive.js',     // the archiver itself
]);

const rangePattern = /collection\('teaching_shifts'\)[\s\S]{0,400}?shift_start'\s*,\s*'>=?'/g;

test('period computations read live + archive through shifts_in_range', () => {
  const dir = path.join(__dirname, '..', 'handlers');
  const offenders = [];
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith('.js') || ALLOWED_LIVE_ONLY.has(file)) continue;
    const source = fs.readFileSync(path.join(dir, file), 'utf8');
    if (rangePattern.test(source)) offenders.push(file);
    rangePattern.lastIndex = 0;
  }
  expect(offenders).toEqual([]);
});
