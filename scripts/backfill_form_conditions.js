/**
 * One-off: copy "show only if" rules from a legacy form onto the template it
 * was migrated to.
 *
 * scripts/migrate_forms_to_templates.js did not copy `conditionalLogic`, so the
 * migrated "Student Follow up - CEO" template shows every question. This copies
 * each rule from the legacy `form/LdIvdtPcMBgIDYFxYkKy` question onto the
 * matching question of `form_templates/qQGJVFwS45QqrUJwJisK` — matched by
 * question id when the migration kept it, otherwise by label — and points the
 * rule at the template's id for the question it depends on.
 *
 * Dry run by default: prints what it would change and writes nothing.
 *
 * Usage:
 *   SERVICE_ACCOUNT=/path/to/service-account.json node scripts/backfill_form_conditions.js
 *   SERVICE_ACCOUNT=/path/to/service-account.json node scripts/backfill_form_conditions.js --apply
 *
 * Optional: --legacy=<form id> --template=<form_templates id> to run it for
 * another pair.
 */

const path = require('path');
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const argValue = (name, fallback) => {
  const match = args.find((arg) => arg.startsWith(`--${name}=`));
  return match ? match.slice(name.length + 3) : fallback;
};
const LEGACY_FORM_ID = argValue('legacy', 'LdIvdtPcMBgIDYFxYkKy');
const TEMPLATE_ID = argValue('template', 'qQGJVFwS45QqrUJwJisK');

const serviceAccountPath = process.env.SERVICE_ACCOUNT;
if (!serviceAccountPath) {
  console.error('Set SERVICE_ACCOUNT to the path of a service-account JSON file.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(serviceAccountPath))),
});
const db = admin.firestore();

/** [key, field] pairs for fields stored as an id-keyed map or as a list. */
function fieldEntries(fields) {
  if (Array.isArray(fields)) {
    return fields.map((field, index) => [String((field && field.id) || `field_${index}`), field || {}]);
  }
  if (fields && typeof fields === 'object') return Object.entries(fields);
  return [];
}

function normalizeLabel(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function labelOf(field) {
  return field.label || field.question || field.name || '';
}

function hasRule(logic) {
  return Boolean(logic && typeof logic === 'object' && logic.dependsOnFieldId && logic.condition);
}

/** The template key for a legacy question: same id, then same inner id, then a unique label match. */
function makeMatcher(templateEntries) {
  const byKey = new Map(templateEntries.map(([key]) => [key, key]));
  const byInnerId = new Map(
    templateEntries.filter(([, field]) => field && field.id).map(([key, field]) => [String(field.id), key]),
  );
  const byLabel = new Map();
  for (const [key, field] of templateEntries) {
    const label = normalizeLabel(labelOf(field || {}));
    if (!label) continue;
    byLabel.set(label, byLabel.has(label) ? null : key);
  }
  return (legacyKey, legacyField) => {
    if (byKey.has(legacyKey)) return { key: byKey.get(legacyKey), how: 'id' };
    const innerId = legacyField && legacyField.id ? String(legacyField.id) : legacyKey;
    if (byInnerId.has(innerId)) return { key: byInnerId.get(innerId), how: 'id' };
    const label = normalizeLabel(labelOf(legacyField || {}));
    const byLabelKey = label ? byLabel.get(label) : undefined;
    if (byLabelKey) return { key: byLabelKey, how: 'label' };
    return null;
  };
}

function sameRule(a, b) {
  return JSON.stringify(a || null) === JSON.stringify(b || null);
}

async function main() {
  console.log(`${apply ? 'APPLY' : 'DRY RUN'}: form/${LEGACY_FORM_ID} -> form_templates/${TEMPLATE_ID}\n`);

  const [legacySnap, templateSnap] = await Promise.all([
    db.collection('form').doc(LEGACY_FORM_ID).get(),
    db.collection('form_templates').doc(TEMPLATE_ID).get(),
  ]);
  if (!legacySnap.exists) throw new Error(`form/${LEGACY_FORM_ID} not found`);
  if (!templateSnap.exists) throw new Error(`form_templates/${TEMPLATE_ID} not found`);

  const legacy = legacySnap.data();
  const template = templateSnap.data();
  if (template.migratedFrom && template.migratedFrom !== LEGACY_FORM_ID) {
    throw new Error(`Template migratedFrom is ${template.migratedFrom}, not ${LEGACY_FORM_ID}; refusing.`);
  }
  console.log(`Legacy:   "${legacy.title || legacy.name || ''}"`);
  console.log(`Template: "${template.name || ''}" (v${template.version || 1}, ${template.isActive === false ? 'inactive' : 'active'})\n`);

  const legacyEntries = fieldEntries(legacy.fields);
  const templateEntries = fieldEntries(template.fields);
  const legacyById = new Map(legacyEntries);
  const match = makeMatcher(templateEntries);
  const templateFieldByKey = new Map(templateEntries);

  const planned = [];
  let skipped = 0;
  for (const [legacyKey, legacyField] of legacyEntries) {
    const logic = legacyField && legacyField.conditionalLogic;
    if (!hasRule(logic)) continue;

    const target = match(legacyKey, legacyField);
    if (!target) {
      console.log(`  SKIP "${labelOf(legacyField)}" (${legacyKey}): no matching template question`);
      skipped++;
      continue;
    }
    const parentKey = String(logic.dependsOnFieldId);
    const parentTarget = match(parentKey, legacyById.get(parentKey));
    if (!parentTarget) {
      console.log(`  SKIP "${labelOf(legacyField)}" (${legacyKey}): question it depends on (${parentKey}) has no match`);
      skipped++;
      continue;
    }

    const rule = {
      dependsOnFieldId: parentTarget.key,
      condition: logic.condition,
      expectedValue: logic.expectedValue === undefined ? null : logic.expectedValue,
      expectedValues: logic.expectedValues === undefined ? null : logic.expectedValues,
      isVisible: typeof logic.isVisible === 'boolean' ? logic.isVisible : true,
    };
    const current = (templateFieldByKey.get(target.key) || {}).conditionalLogic;
    if (sameRule(current, rule)) {
      console.log(`  OK   "${labelOf(legacyField)}": already has this rule`);
      continue;
    }

    const parentLabel = labelOf(templateFieldByKey.get(parentTarget.key) || {});
    console.log(
      `  SET  "${labelOf(templateFieldByKey.get(target.key) || legacyField)}" [${target.key}, matched by ${target.how}]\n` +
        `       show ${rule.isVisible ? 'only if' : 'unless'} "${parentLabel}" [${parentTarget.key}] ${rule.condition} ` +
        `${JSON.stringify(rule.expectedValues && rule.expectedValues.length ? rule.expectedValues : rule.expectedValue)}` +
        (current ? `\n       (replaces ${JSON.stringify(current)})` : ''),
    );
    planned.push({ key: target.key, rule });
  }

  console.log(`\n${planned.length} rule(s) to write, ${skipped} skipped.`);
  if (!planned.length) return;
  if (!apply) {
    console.log('Dry run only. Re-run with --apply to write.');
    return;
  }

  const ref = db.collection('form_templates').doc(TEMPLATE_ID);
  if (Array.isArray(template.fields)) {
    const byKey = new Map(planned.map((item) => [item.key, item.rule]));
    const fields = template.fields.map((field, index) => {
      const key = String((field && field.id) || `field_${index}`);
      return byKey.has(key) ? { ...field, conditionalLogic: byKey.get(key) } : field;
    });
    await ref.update({ fields, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  } else {
    const updates = [];
    for (const { key, rule } of planned) {
      updates.push(new admin.firestore.FieldPath('fields', key, 'conditionalLogic'), rule);
    }
    updates.push('updatedAt', admin.firestore.FieldValue.serverTimestamp());
    await ref.update(...updates);
  }
  console.log(`Wrote ${planned.length} rule(s) to form_templates/${TEMPLATE_ID}.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  });
