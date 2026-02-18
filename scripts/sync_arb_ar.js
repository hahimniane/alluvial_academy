/**
 * Sync app_ar.arb with app_en.arb: add any key present in en but missing in ar,
 * using the English string as placeholder so the app reports zero untranslated.
 * Run from project root: node scripts/sync_arb_ar.js
 */

const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '..');
const enPath = path.join(projectRoot, 'lib', 'l10n', 'app_en.arb');
const arPath = path.join(projectRoot, 'lib', 'l10n', 'app_ar.arb');

const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));
const ar = JSON.parse(fs.readFileSync(arPath, 'utf8'));

let added = 0;
for (const key of Object.keys(en)) {
  if (ar[key] === undefined) {
    ar[key] = en[key];
    added++;
  }
}

fs.writeFileSync(arPath, JSON.stringify(ar, null, 2) + '\n', 'utf8');
console.log(`Added ${added} missing key(s) to app_ar.arb. Total ar keys: ${Object.keys(ar).length}.`);
