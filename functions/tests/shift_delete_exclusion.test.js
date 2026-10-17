const {__test__: {_exclusionForDeletedShift}} = require('../handlers/shift_templates');

describe('a person deleting an upcoming generated class keeps it deleted', () => {
  const now = new Date('2026-10-17T00:00:00Z');
  const shift = {
    generated_from_template: true,
    template_id: 'tpl1',
    status: 'scheduled',
    shift_start: new Date('2026-10-28T23:00:00Z'), // 7 PM New York, Oct 28
  };
  const template = {is_active: true, admin_timezone: 'America/New_York'};

  test('excludes the class date in the template timezone', () => {
    const out = _exclusionForDeletedShift({shift, template, authType: 'unknown', authId: 'ADMIN_UID', now});
    expect(out.templateId).toBe('tpl1');
    expect(out.excludedDay.toISOString()).toBe('2026-10-28T04:00:00.000Z');
  });

  test('server-side deletes (template edits, archival) change nothing', () => {
    expect(_exclusionForDeletedShift({shift, template, authType: 'service_account', authId: 'x@appspot.gserviceaccount.com', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift, template, authType: 'system', authId: 'system', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift, template, authType: 'unknown', authId: '', now})).toBeNull();
  });

  test('past, non-scheduled, one-off or inactive-template classes change nothing', () => {
    expect(_exclusionForDeletedShift({shift: {...shift, shift_start: new Date('2026-10-01T00:00:00Z')}, template, authType: 'unknown', authId: 'A', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift: {...shift, status: 'completed'}, template, authType: 'unknown', authId: 'A', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift: {...shift, generated_from_template: false}, template, authType: 'unknown', authId: 'A', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift, template: {...template, is_active: false}, authType: 'unknown', authId: 'A', now})).toBeNull();
    expect(_exclusionForDeletedShift({shift, template: null, authType: 'unknown', authId: 'A', now})).toBeNull();
  });
});
