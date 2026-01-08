#!/usr/bin/env node
/**
 * Repairs mismatched student assignments in `teaching_shifts` where a given
 * student name is present, but the corresponding `student_ids[i]` points to
 * a different UID (e.g., a sibling).
 *
 * Default is DRY-RUN (no writes). To apply updates, pass: --apply --yes
 *
 * Example:
 *   node functions/scripts/repair_shift_student_assignment.js \
 *     --project alluwal-academy \
 *     --fromUid <WRONG_UID> \
 *     --toUid <CORRECT_UID> \
 *     --targetName "Abdulai Bah" \
 *     --backup ./shift_student_repair.jsonl \
 *     --apply --yes
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const raw = argv[i];
    if (!raw.startsWith('--')) continue;
    const key = raw.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function usage(exitCode = 1) {
  // Keep output minimal; this script is often run in production terminals.
  console.log(
    [
      'Usage:',
      '  node functions/scripts/repair_shift_student_assignment.js --project <projectId> --fromUid <uid> --toUid <uid> [--targetName <full name>] [--seriesId <id>] [--onlyFuture] [--limit <n>] [--backup <path>] [--apply --yes]',
      '',
      'Notes:',
      '  - DRY-RUN by default (no writes).',
      '  - Updates only the index where student_names[i] matches targetName AND student_ids[i] == fromUid.',
      '  - Set --targetName if Firestore stores a slightly different name string.',
      '  - Use --backup to write a JSONL report (before/after) for rollback.',
    ].join('\n')
  );
  process.exit(exitCode);
}

function normalizeName(value) {
  return String(value ?? '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function asStringArray(value) {
  if (!Array.isArray(value)) return null;
  return value.map((v) => String(v));
}

function getTimestampDate(value) {
  if (!value) return null;
  if (value.toDate && typeof value.toDate === 'function') return value.toDate();
  return null;
}

function patchIdsAtMatchingNameIndex({names, ids, targetName, fromUid, toUid}) {
  if (!names || !ids) return null;
  const targetNorm = normalizeName(targetName);
  let changed = false;
  const next = ids.slice();

  for (let idx = 0; idx < names.length; idx += 1) {
    if (normalizeName(names[idx]) !== targetNorm) continue;
    if (idx >= next.length) return null;
    if (next[idx] !== fromUid) continue;
    next[idx] = toUid;
    changed = true;
  }

  return changed ? next : null;
}

async function initAdmin(projectId) {
  try {
    const serviceAccount = require(path.join(__dirname, '../../serviceAccountKey.json'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  } catch (error) {
    admin.initializeApp({projectId});
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const projectId = (args.project || 'alluwal-academy').toString();
  const fromUid = (args.fromUid || '').toString().trim();
  const toUid = (args.toUid || '').toString().trim();
  const targetNameRaw = args.targetName ? args.targetName.toString() : '';
  const seriesId = args.seriesId ? args.seriesId.toString().trim() : '';
  const onlyFuture = args.onlyFuture === true || args.onlyFuture === 'true';
  const apply = args.apply === true || args.apply === 'true';
  const yes = args.yes === true || args.yes === 'true';
  const limit = args.limit ? Number(args.limit) : null;
  const backupPath = args.backup ? args.backup.toString().trim() : '';

  if (!fromUid || !toUid) usage(1);
  if (apply && !yes) {
    console.log('Refusing to apply without --yes.');
    process.exit(1);
  }

  await initAdmin(projectId);
  const db = admin.firestore();

  let targetName = targetNameRaw.trim();
  if (!targetName) {
    const toUser = await db.collection('users').doc(toUid).get();
    if (!toUser.exists) {
      console.log(`Unable to resolve targetName: users/${toUid} not found. Provide --targetName.`);
      process.exit(1);
    }
    const data = toUser.data() || {};
    const first = String(data.first_name || '').trim();
    const last = String(data.last_name || '').trim();
    targetName = `${first} ${last}`.trim();
    if (!targetName) {
      console.log(`Unable to resolve targetName from users/${toUid}. Provide --targetName.`);
      process.exit(1);
    }
  }

  const now = new Date();
  console.log(
    `Project=${projectId} | targetName="${targetName}" | fromUid=${fromUid} -> toUid=${toUid} | mode=${apply ? 'APPLY' : 'DRY-RUN'}`
  );

  const snap = await db
    .collection('teaching_shifts')
    .where('student_names', 'array-contains', targetName)
    .get();

  console.log(`Fetched ${snap.size} shift(s) where student_names contains targetName.`);

  const candidates = [];
  const backupLines = [];
  for (const doc of snap.docs) {
    const data = doc.data() || {};

    const docSeriesId = String(
      data.recurrence_series_id || data.recurrenceSeriesId || ''
    ).trim();
    if (seriesId && docSeriesId !== seriesId) continue;

    if (onlyFuture) {
      const startDate = getTimestampDate(data.shift_start || data.shiftStart);
      if (startDate && startDate < now) continue;
    }

    const namesSnake = asStringArray(data.student_names);
    const idsSnake = asStringArray(data.student_ids);
    const namesCamel = asStringArray(data.studentNames);
    const idsCamel = asStringArray(data.studentIds);

    const patch = {};

    const patchedSnake = patchIdsAtMatchingNameIndex({
      names: namesSnake,
      ids: idsSnake,
      targetName,
      fromUid,
      toUid,
    });
    if (patchedSnake) patch.student_ids = patchedSnake;

    const patchedCamel = patchIdsAtMatchingNameIndex({
      names: namesCamel,
      ids: idsCamel,
      targetName,
      fromUid,
      toUid,
    });
    if (patchedCamel) patch.studentIds = patchedCamel;

    if (Object.keys(patch).length === 0) continue;

    const start = getTimestampDate(data.shift_start || data.shiftStart);
    const teacherName = String(data.teacher_name || data.teacherName || '').trim();
    candidates.push({
      ref: doc.ref,
      id: doc.id,
      teacherName,
      startIso: start ? start.toISOString() : '',
      seriesId: docSeriesId,
      before: {
        student_ids: idsSnake,
        studentIds: idsCamel,
      },
      after: {
        student_ids: patchedSnake || idsSnake,
        studentIds: patchedCamel || idsCamel,
      },
      patch,
    });

    if (limit != null && candidates.length >= limit) break;
  }

  console.log(`Matched ${candidates.length} shift(s) requiring student_ids repair.`);

  for (const c of candidates) {
    console.log(
      `- ${c.id} | ${c.startIso || 'unknown_start'} | ${c.teacherName || 'unknown_teacher'} | series=${c.seriesId || 'none'}`
    );
  }

  if (backupPath) {
    for (const c of candidates) {
      backupLines.push(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          project: projectId,
          shiftId: c.id,
          seriesId: c.seriesId || null,
          teacherName: c.teacherName || null,
          shiftStart: c.startIso || null,
          targetName,
          fromUid,
          toUid,
          before: c.before,
          after: c.after,
        })
      );
    }
    fs.writeFileSync(backupPath, `${backupLines.join('\n')}\n`, {encoding: 'utf8'});
    console.log(`Wrote backup report: ${backupPath}`);
  }

  if (!apply) {
    console.log('DRY-RUN complete. Re-run with --apply --yes to write updates.');
    return;
  }

  const batchSize = 400;
  let updated = 0;

  for (let i = 0; i < candidates.length; i += batchSize) {
    const chunk = candidates.slice(i, i + batchSize);
    const batch = db.batch();
    for (const c of chunk) {
      batch.update(c.ref, {
        ...c.patch,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    updated += chunk.length;
    console.log(`Committed ${updated}/${candidates.length} updates...`);
  }

  console.log(`✅ Done. Updated ${updated} shift(s).`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
