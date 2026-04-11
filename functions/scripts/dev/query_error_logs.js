#!/usr/bin/env node
/**
 * Query error_logs from Firestore to trace user-reported issues.
 *
 * Usage:
 *   node scripts/dev/query_error_logs.js                          # last 20 errors
 *   node scripts/dev/query_error_logs.js --email user@example.com # errors for a user
 *   node scripts/dev/query_error_logs.js --session abc12345       # errors from a session
 *   node scripts/dev/query_error_logs.js --hours 2                # errors in last 2 hours
 *   node scripts/dev/query_error_logs.js --fatal                  # fatal errors only
 */

const admin = require('firebase-admin');

// Initialize with project
if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'alluwal-academy' });
}
const db = admin.firestore();

async function main() {
  const args = process.argv.slice(2);
  const flags = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--email' && args[i + 1]) { flags.email = args[++i]; }
    else if (args[i] === '--session' && args[i + 1]) { flags.session = args[++i]; }
    else if (args[i] === '--hours' && args[i + 1]) { flags.hours = parseInt(args[++i]); }
    else if (args[i] === '--fatal') { flags.fatal = true; }
    else if (args[i] === '--limit' && args[i + 1]) { flags.limit = parseInt(args[++i]); }
    else if (args[i] === '--context' && args[i + 1]) { flags.context = args[++i]; }
  }

  const limit = flags.limit || 20;
  const hasFilters =
    Boolean(flags.email) ||
    Boolean(flags.session) ||
    Boolean(flags.fatal) ||
    Boolean(flags.context);

  let query = db.collection('error_logs').orderBy('timestamp', 'desc');

  if (flags.email) {
    query = query.where('userEmail', '==', flags.email);
    console.log(`\nFiltering by email: ${flags.email}`);
  }
  if (flags.session) {
    query = query.where('sessionId', '==', flags.session);
    console.log(`\nFiltering by session: ${flags.session}`);
  }
  if (flags.fatal) {
    query = query.where('fatal', '==', true);
    console.log(`\nFiltering: fatal errors only`);
  }
  if (flags.context) {
    query = query.where('context', '==', flags.context);
    console.log(`\nFiltering by context: ${flags.context}`);
  }

  query = query.limit(limit);

  let docs;
  try {
    const snapshot = await query.get();
    docs = snapshot.docs;
  } catch (error) {
    const needsIndex =
      error?.code === 9 ||
      String(error?.message || '').includes('FAILED_PRECONDITION') ||
      String(error?.details || '').includes('requires an index');

    if (!hasFilters || !needsIndex) {
      throw error;
    }

    const fallbackLimit = Math.max(limit * 100, 2000);
    console.warn(
      '\nContext-aware query needs a Firestore index. Falling back to in-memory filtering of recent logs.',
    );
    console.warn(`Fetching last ${fallbackLimit} error logs ordered by timestamp.\n`);

    const fallbackSnapshot = await db
      .collection('error_logs')
      .orderBy('timestamp', 'desc')
      .limit(fallbackLimit)
      .get();
    docs = fallbackSnapshot.docs;
  }

  const filteredDocs = docs.filter((doc) => {
    const d = doc.data() || {};

    if (flags.email && d.userEmail !== flags.email) return false;
    if (flags.session && d.sessionId !== flags.session) return false;
    if (flags.fatal && d.fatal !== true) return false;
    if (flags.context && d.context !== flags.context) return false;

    if (flags.hours) {
      const errorTime = d.timestamp ? d.timestamp.toDate() : new Date(d.clientTimestamp);
      const cutoff = new Date(Date.now() - flags.hours * 60 * 60 * 1000);
      if (errorTime < cutoff) return false;
    }

    return true;
  }).slice(0, limit);

  if (filteredDocs.length === 0) {
    console.log('\nNo error logs found matching your criteria.\n');
    return;
  }

  console.log(`\n${'='.repeat(80)}`);
  console.log(`  ERROR LOGS (${filteredDocs.length} results)`);
  console.log(`${'='.repeat(80)}\n`);

  filteredDocs.forEach((doc, i) => {
    const d = doc.data();
    const ts = d.timestamp ? d.timestamp.toDate().toISOString() : d.clientTimestamp || '?';

    console.log(`--- Error #${i + 1} ---`);
    console.log(`  Time:      ${ts}`);
    console.log(`  User:      ${d.userEmail || 'anonymous'} (${d.userId || 'n/a'})`);
    console.log(`  Session:   ${d.sessionId || 'n/a'}`);
    console.log(`  Platform:  ${d.platform || 'n/a'}`);
    console.log(`  Context:   ${d.context || 'n/a'}`);
    console.log(`  Fatal:     ${d.fatal ? 'YES' : 'no'}`);
    console.log(`  Error:     ${d.errorType || ''}: ${d.error || ''}`);

    if (d.breadcrumbs && d.breadcrumbs.length > 0) {
      console.log(`  Breadcrumbs (last ${d.breadcrumbs.length}):`);
      d.breadcrumbs.forEach(b => console.log(`    > ${b}`));
    }

    if (d.stackTrace) {
      // Show first 5 lines of stack trace
      const lines = d.stackTrace.split('\n').slice(0, 5);
      console.log(`  Stack trace (first 5 lines):`);
      lines.forEach(l => console.log(`    ${l}`));
    }
    console.log('');
  });

  console.log(`${'='.repeat(80)}\n`);
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
