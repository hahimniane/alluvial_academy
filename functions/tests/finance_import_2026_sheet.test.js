const {
  parseMoney,
  parseHours,
  excelDateToIso,
  normalizeName,
  nameSimilarity,
  matchPerson,
  median,
  stripPhone,
} = require('../scripts/finance_import_2026_sheet');

describe('finance 2026 sheet import helpers', () => {
  test('parseMoney reads numbers, flags text, ignores blanks and dashes', () => {
    expect(parseMoney(40)).toEqual({ value: 40, issue: null });
    expect(parseMoney('---')).toEqual({ value: null, issue: null });
    expect(parseMoney(' ')).toEqual({ value: null, issue: null });
    expect(parseMoney(undefined)).toEqual({ value: null, issue: null });
    expect(parseMoney('169,64').value).toBe(169.64);
    expect(parseMoney('169,64').issue).toMatch(/comma/);
    expect(parseMoney('1,234').value).toBe(1234);
    expect(parseMoney('$40').value).toBe(40);
    expect(parseMoney('paid')).toEqual({ value: null, issue: expect.stringMatching(/money cell/) });
  });

  test('parseHours reads numbers and text such as "15hrs"', () => {
    expect(parseHours(42)).toBe(42);
    expect(parseHours('15hrs')).toBe(15);
    expect(parseHours(44, '25')).toBe(69);
    expect(parseHours(undefined, undefined)).toBeNull();
  });

  test('excelDateToIso reads serial numbers and dd/mm/yyyy', () => {
    expect(excelDateToIso(46023)).toBe('2026-01-01');
    expect(excelDateToIso('14/02/2026')).toBe('2026-02-14');
    expect(excelDateToIso('soon')).toBeNull();
  });

  test('median ignores non-numbers', () => {
    expect(median([1, 3, 'x', 100])).toBe(3);
    expect(median([])).toBe(0);
  });

  test('stripPhone removes numbers from a destination', () => {
    expect(stripPhone('Liberia to contact: +231 77 027 4935')).toBe('Liberia');
    expect(stripPhone('Morroco')).toBe('Morroco');
  });

  test('normalizeName drops accents, dotless i and honorifics', () => {
    expect(normalizeName('Sheikh Ahmad Jalloh')).toBe('ahmad jalloh');
    expect(normalizeName('Iberahım Bah')).toBe('iberahim bah');
  });

  test('matchPerson matches exact and near names, and holds back ambiguous ones', () => {
    const users = [
      { uid: 'u1', name: 'Mamadou Saidou Diallo', active: true },
      { uid: 'u2', name: 'Mamadou Diallo', active: true },
      { uid: 'u3', name: 'Rahmatullaah Balde', active: true },
      { uid: 'u4', name: 'Nasrullah Jalloh', active: true },
      { uid: 'u5', name: 'Abdulai Diallo', active: true },
      { uid: 'u6', name: 'Abdulai1 Diallo', active: true },
    ];
    expect(matchPerson('Mamadou Saidou Diallo', users)).toMatchObject({ confidence: 'matched', user: { uid: 'u1' } });
    expect(matchPerson('Rahmatulahi Balde', users)).toMatchObject({ confidence: 'matched', user: { uid: 'u3' } });
    expect(matchPerson('Nasrullah', users).confidence).toBe('possible');
    expect(matchPerson('Abdulai Diallo', users).confidence).toBe('possible');
    expect(matchPerson('CEO', users).confidence).toBe('unmatched');
  });

  test('nameSimilarity prefers the closer full name', () => {
    expect(nameSimilarity('Ali Bah', 'Ali Bah')).toBeGreaterThan(nameSimilarity('Ali Bah', 'Ali Bah Diallo'));
  });
});
