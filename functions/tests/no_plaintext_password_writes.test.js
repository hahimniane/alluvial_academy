/**
 * users/{uid} is readable by every signed-in user, so no code may store a
 * password there. Student passwords go to student_credentials/{uid} through
 * services/student_credentials.js; the legacy `temp_password` field may only
 * be read (fallback) or deleted, and only by the files listed here.
 *
 * Runs in CI with the functions tests; it also scans the Flutter app and the
 * web app, which have no CI test step of their own for this.
 */
const fs = require('fs');
const path = require('path');

const repo = path.resolve(__dirname, '..', '..');

const walk = (dir, exts, skip = []) => {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name);
    if (['node_modules', '.next', 'out', 'build', '__tests__', ...skip].includes(name)) return [];
    if (fs.statSync(full).isDirectory()) return walk(full, exts, skip);
    return exts.some((ext) => name.endsWith(ext)) ? [full] : [];
  });
};

const rel = (file) => path.relative(repo, file).split(path.sep).join('/');
const mentions = (files) => files.filter((f) => /temp_password/.test(fs.readFileSync(f, 'utf8'))).map(rel);

describe('no plaintext password on user documents', () => {
  test('Cloud Functions: only the credential service names the legacy field', () => {
    const files = ['handlers', 'services', 'utils'].flatMap((d) =>
      walk(path.join(repo, 'functions', d), ['.js']));
    expect(mentions(files)).toEqual(['functions/services/student_credentials.js']);
  });

  test('the credential service only reads or deletes the legacy field', () => {
    const source = fs.readFileSync(path.join(repo, 'functions/services/student_credentials.js'), 'utf8');
    const writes = source.split('\n').filter((line) =>
      /LEGACY_PASSWORD_FIELD\]?\s*:/.test(line) && !/FieldValue\.delete\(\)/.test(line));
    expect(writes).toEqual([]);
  });

  test('handlers never put a password field on a users document', () => {
    const files = walk(path.join(repo, 'functions', 'handlers'), ['.js']);
    const offenders = files.filter((f) => /['"]?(temp_password|plain_password|password_plain)['"]?\s*:/.test(fs.readFileSync(f, 'utf8')));
    expect(offenders.map(rel)).toEqual([]);
  });

  test('Flutter app: only the core credential service names the legacy field, read-only', () => {
    const files = walk(path.join(repo, 'lib'), ['.dart'], ['l10n']);
    expect(mentions(files)).toEqual(['lib/core/services/student_credentials_service.dart']);
    const source = fs.readFileSync(path.join(repo, 'lib/core/services/student_credentials_service.dart'), 'utf8');
    expect(source).not.toMatch(/\.(update|set)\(/);
  });

  test('web app: only the read-only credential reader names the legacy field', () => {
    const files = walk(path.join(repo, 'apps', 'web', 'src'), ['.ts', '.tsx']);
    expect(mentions(files)).toEqual(['apps/web/src/lib/studentCredentials.ts']);
    const source = fs.readFileSync(path.join(repo, 'apps/web/src/lib/studentCredentials.ts'), 'utf8');
    expect(source).not.toMatch(/\b(setDoc|updateDoc|addDoc|deleteDoc|writeBatch|runTransaction)\b/);
  });
});
