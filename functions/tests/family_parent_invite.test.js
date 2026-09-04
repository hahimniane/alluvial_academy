jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
  onDocumentWritten: (_path, fn) => fn,
}));

const {_mergeIdList, _formatNameList} = require('../handlers/enrollments');

describe('inviting the parent of a family class', () => {
  test('the clicked child stays first, and duplicates collapse', () => {
    expect(_mergeIdList('enr_1', ['enr_2', 'enr_1', 'enr_3'])).toEqual(['enr_1', 'enr_2', 'enr_3']);
  });

  test('a caller that sends only the singular id is unchanged', () => {
    expect(_mergeIdList('enr_1', undefined)).toEqual(['enr_1']);
    expect(_mergeIdList('enr_1', [])).toEqual(['enr_1']);
  });

  test('blank entries are dropped rather than written to', () => {
    expect(_mergeIdList('enr_1', ['', '  ', null])).toEqual(['enr_1']);
  });

  test('the email names one child plainly and several readably', () => {
    expect(_formatNameList(['Amina'])).toBe('Amina');
    expect(_formatNameList(['Amina', 'Yusuf'])).toBe('Amina and Yusuf');
    expect(_formatNameList(['Amina', 'Yusuf', 'Ibrahim'])).toBe('Amina, Yusuf and Ibrahim');
  });

  test('a child with no name on record does not leave a dangling separator', () => {
    expect(_formatNameList(['Amina', ''])).toBe('Amina');
    expect(_formatNameList([])).toBe('');
  });
});
