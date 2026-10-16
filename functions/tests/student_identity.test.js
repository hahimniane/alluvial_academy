const {normalizeName, sameChild} = require('../utils/student_identity');

test('names match regardless of case, accents and spacing', () => {
  expect(normalizeName(' Mariama-Barry ')).toBe('mariamabarry');
  expect(normalizeName('Aïssata')).toBe('aissata');
});

test('the same child under the same guardian is recognised', () => {
  const existing = {first_name: 'Hassimiou', last_name: 'Diallo', guardian_ids: ['P1'], user_type: 'student'};
  expect(sameChild({firstName: 'hassimiou', lastName: 'DIALLO', guardianIds: ['P1']}, existing)).toBe(true);
  expect(sameChild({firstName: 'Hassimiou', lastName: 'Diallo', guardianIds: ['P1', 'P2']}, existing)).toBe(true);
});

test('a name alone never merges two children', () => {
  const existing = {first_name: 'Ibrahim', last_name: 'Diallo', guardian_ids: ['P1']};
  expect(sameChild({firstName: 'Ibrahim', lastName: 'Diallo', guardianIds: ['P9']}, existing)).toBe(false);
  expect(sameChild({firstName: 'Ibrahim', lastName: 'Diallo', guardianIds: []}, existing)).toBe(false);
  expect(sameChild({firstName: 'Ibrahim', lastName: 'Diallo', guardianIds: ['P1']}, {first_name: 'Ibrahim', last_name: 'Diallo', guardian_ids: []})).toBe(false);
});

test('a different child of the same parent is not the same', () => {
  expect(sameChild({firstName: 'Fatou', lastName: 'Diallo', guardianIds: ['P1']}, {first_name: 'Ibrahim', last_name: 'Diallo', guardian_ids: ['P1']})).toBe(false);
});

test('an application with a first name only still finds the child under the same guardian', () => {
  const existing = {first_name: 'Isa', last_name: 'Jallow', guardian_ids: ['P1'], user_type: 'student'};
  expect(sameChild({firstName: 'Isa', lastName: '', guardianIds: ['P1']}, existing)).toBe(true);
  expect(sameChild({firstName: 'Isa', lastName: undefined, guardianIds: ['P1']}, existing)).toBe(true);
  // but never across guardians, and never a different first name
  expect(sameChild({firstName: 'Isa', lastName: '', guardianIds: ['P9']}, existing)).toBe(false);
  expect(sameChild({firstName: 'Aminah', lastName: '', guardianIds: ['P1']}, existing)).toBe(false);
  // a surname given by the application still has to match
  expect(sameChild({firstName: 'Isa', lastName: 'Bah', guardianIds: ['P1']}, existing)).toBe(false);
});
