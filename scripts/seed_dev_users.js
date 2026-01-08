#!/usr/bin/env node
/**
 * Seed dev users by calling the deployed callable function in the dev project.
 *
 * This does NOT copy prod data; it only creates new Auth users + Firestore `users/{uid}` docs.
 *
 * Usage:
 *   node scripts/seed_dev_users.js scripts/dev_seed_users.example.json
 *   node scripts/seed_dev_users.js path/to/users.json --project alluwal-dev --region us-central1 --function createUser
 */

const fs = require('node:fs');
const https = require('node:https');
const path = require('node:path');

const parseArgs = (argv) => {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) {
      args._.push(token);
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
};

const requestJson = (options, body) =>
  new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        const status = res.statusCode || 0;
        if (!data) {
          if (status >= 200 && status < 300) return resolve(null);
          return reject(new Error(`HTTP ${status} with empty response`));
        }
        let parsed;
        try {
          parsed = JSON.parse(data);
        } catch (e) {
          return reject(new Error(`HTTP ${status} non-JSON response: ${data.slice(0, 500)}`));
        }
        if (status >= 200 && status < 300) return resolve(parsed);
        return reject(new Error(`HTTP ${status}: ${JSON.stringify(parsed)}`));
      });
    });

    req.on('error', reject);
    req.setTimeout(60_000, () => {
      req.destroy(new Error('Request timed out'));
    });

    req.write(body);
    req.end();
  });

const main = async () => {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || args.h) {
    console.log(
      [
        'Usage:',
        '  node scripts/seed_dev_users.js <users.json> [--project alluwal-dev] [--region us-central1] [--function createUser]',
        '',
        'Example:',
        '  node scripts/seed_dev_users.js scripts/dev_seed_users.example.json',
      ].join('\n')
    );
    process.exit(0);
  }

  const usersFile = args._[0];
  if (!usersFile) {
    console.error('Missing users JSON file. See: scripts/dev_seed_users.example.json');
    process.exit(1);
  }

  const project = String(args.project || 'alluwal-dev').trim();
  const region = String(args.region || 'us-central1').trim();
  const functionName = String(args.function || 'createUser').trim();

  const resolvedPath = path.resolve(process.cwd(), usersFile);
  const raw = fs.readFileSync(resolvedPath, 'utf8');
  const parsed = JSON.parse(raw);
  const users = Array.isArray(parsed.users) ? parsed.users : [];

  if (users.length === 0) {
    console.error('No users found. Expected JSON shape: { "users": [ ... ] }');
    process.exit(1);
  }

  const hostname = `${region}-${project}.cloudfunctions.net`;
  const endpointPath = `/${functionName}`;

  console.log(`Seeding ${users.length} user(s) into Firebase project: ${project}`);
  console.log(`Function endpoint: https://${hostname}${endpointPath}`);

  for (const user of users) {
    const email = user?.email ? String(user.email).trim() : '';
    if (!email) {
      console.warn('Skipping user with missing email');
      // eslint-disable-next-line no-continue
      continue;
    }

    const body = JSON.stringify({ data: user });
    const options = {
      hostname,
      port: 443,
      path: endpointPath,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    try {
      const response = await requestJson(options, body);
      const result = response && typeof response === 'object' ? response.result : null;
      const uid = result && typeof result === 'object' ? result.uid : null;
      console.log(`✔ Created: ${email}${uid ? ` (uid=${uid})` : ''}`);
    } catch (e) {
      console.error(`✖ Failed: ${email}`);
      console.error(String(e && e.message ? e.message : e));
    }
  }
};

main().catch((e) => {
  console.error(String(e && e.message ? e.message : e));
  process.exit(1);
});

