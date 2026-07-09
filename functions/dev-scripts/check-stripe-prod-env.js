'use strict';

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'alluwal-academy';

const parseEnvFile = (filePath) => {
  if (!fs.existsSync(filePath)) return {};

  const values = {};
  const contents = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const equalsIndex = line.indexOf('=');
    if (equalsIndex <= 0) continue;

    const key = line.slice(0, equalsIndex).trim();
    let value = line.slice(equalsIndex + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
};

const modeForKey = (value) => {
  const key = (value || '').trim();
  if (!key) return 'missing';
  if (key.startsWith('sk_live_') || key.startsWith('pk_live_')) return 'live';
  if (key.startsWith('sk_test_') || key.startsWith('pk_test_')) return 'test';
  return 'unknown';
};

const functionsDir = path.resolve(__dirname, '..');
const effectiveEnv = {
  ...process.env,
  ...parseEnvFile(path.join(functionsDir, '.env')),
  ...parseEnvFile(path.join(functionsDir, `.env.${PROJECT_ID}`)),
};

const secretMode = modeForKey(effectiveEnv.STRIPE_SECRET_KEY);
const publishableMode = modeForKey(effectiveEnv.STRIPE_PUBLISHABLE_KEY);

if (secretMode !== 'live' || publishableMode !== 'live') {
  console.error(
    `Refusing prod deploy: ${PROJECT_ID} requires live Stripe keys, ` +
      `but effective STRIPE_SECRET_KEY/STRIPE_PUBLISHABLE_KEY modes are ` +
      `${secretMode}/${publishableMode}.`
  );
  console.error(
    `Put live sk_live_/pk_live_ values in functions/.env.${PROJECT_ID} ` +
      'or remove test keys from the prod deploy environment.'
  );
  process.exit(1);
}

console.log(`Stripe prod env check passed for ${PROJECT_ID}.`);
