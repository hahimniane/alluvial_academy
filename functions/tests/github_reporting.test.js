// Push marker for end-to-end GitHub reporting verification.
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_config, fn) => fn,
}));

const admin = require('firebase-admin');

admin.firestore.Timestamp = {
  fromDate: (date) => ({
    __type: 'timestamp',
    iso: date.toISOString(),
    toDate: () => date,
  }),
};

admin.firestore.FieldValue = {
  serverTimestamp: () => '__SERVER_TIMESTAMP__',
};

const { __test__ } = require('../handlers/github_reporting');

describe('github reporting helpers', () => {
  test('sanitizePushPayload keeps only matching CTO commits and derives focus areas', () => {
    const payload = {
      ref: 'refs/heads/main',
      before: 'before_sha',
      after: 'after_sha',
      compare: 'https://github.com/hahimniane/alluvial_academy/compare/before...after',
      repository: {
        full_name: 'hahimniane/alluvial_academy',
        name: 'alluvial_academy',
      },
      sender: {
        login: 'hahimniane',
      },
      pusher: {
        name: 'Hassimiou Niane',
        email: 'hassimiou.niane@maine.edu',
      },
      commits: [
        {
          id: 'commit_1',
          message: 'Add Stripe payment flow for invoice lockouts',
          timestamp: '2026-04-20T12:00:00.000Z',
          url: 'https://github.com/example/commit/commit_1',
          author: {
            name: 'Hassimiou Niane',
            email: 'hassimiou.niane@maine.edu',
          },
          added: [],
          modified: [
            'functions/handlers/payments.js',
            'lib/features/parent/screens/payment_screen.dart',
          ],
          removed: [],
        },
        {
          id: 'commit_2',
          message: 'Other contributor work',
          timestamp: '2026-04-20T13:00:00.000Z',
          url: 'https://github.com/example/commit/commit_2',
          author: {
            name: 'Someone Else',
            email: 'other@example.com',
          },
          added: ['lib/features/chat/screens/chat_screen.dart'],
          modified: [],
          removed: [],
        },
      ],
    };

    const result = __test__.sanitizePushPayload(payload, {
      authorEmails: ['hassimiou.niane@maine.edu'],
      authorUsernames: ['hahimniane'],
      repositoryAllowlist: [],
    });

    expect(result.skip).toBe(false);
    expect(result.docId).toBe('after_sha');
    expect(result.event.branch).toBe('main');
    expect(result.event.commitIds).toEqual(['commit_1']);
    expect(result.event.changedFiles).toEqual([
      'functions/handlers/payments.js',
      'lib/features/parent/screens/payment_screen.dart',
    ]);
    expect(result.event.focusAreas).toEqual([
      'parent and billing experience',
      'payments backend',
    ]);
  });

  test('sanitizePushPayload accepts GitHub no-reply author emails when the sender login matches', () => {
    const payload = {
      ref: 'refs/heads/main',
      before: 'before_sha',
      after: 'after_sha',
      repository: {
        full_name: 'hahimniane/alluvial_academy',
        name: 'alluvial_academy',
      },
      sender: {
        login: 'hahimniane',
      },
      pusher: {
        name: 'Hashim Niane',
        email: 'hassimiou.niane@maine.edu',
      },
      commits: [
        {
          id: 'commit_noreply',
          message: 'Tune weekly engineering automation',
          timestamp: '2026-04-20T14:00:00.000Z',
          url: 'https://github.com/example/commit/commit_noreply',
          author: {
            name: 'Hashim Niane',
            email: 'hashimniane@users.noreply.github.com',
          },
          added: [],
          modified: ['scripts/create_cto_weekly_engineering_template.js'],
          removed: [],
        },
      ],
    };

    const result = __test__.sanitizePushPayload(payload, {
      authorEmails: ['hassimiou.niane@maine.edu'],
      authorUsernames: ['hahimniane'],
      repositoryAllowlist: [],
    });

    expect(result.skip).toBe(false);
    expect(result.event.commitIds).toEqual(['commit_noreply']);
    expect(result.event.focusAreas).toEqual(['project scripts']);
  });

  test('buildWeeklyWorkSummary stays high level and uses focus areas plus commit messages', () => {
    const summary = __test__.buildWeeklyWorkSummary([
      {
        id: 'commit_1',
        message: 'Add Stripe payment flow for invoice lockouts',
        files: [
          'functions/handlers/payments.js',
          'lib/features/parent/screens/payment_screen.dart',
        ],
      },
      {
        id: 'commit_2',
        message: 'Improve dashboard navigation for admins',
        files: [
          'lib/features/dashboard/screens/dashboard.dart',
        ],
      },
    ]);

    expect(summary).toContain('Worked mainly on');
    expect(summary).toContain('parent and billing experience');
    expect(summary).toContain('payments backend');
    expect(summary).toContain('dashboard updates');
    expect(summary).toContain('- Add Stripe payment flow for invoice lockouts');
    expect(summary).toContain('- Improve dashboard navigation for admins');
    expect(summary.toLowerCase()).not.toContain('commits');
    expect(summary.toLowerCase()).not.toContain('times worked');
  });

  test('buildWeeklyWorkSummary falls back to file-based work areas when commit messages are weak', () => {
    const summary = __test__.buildWeeklyWorkSummary([
      {
        id: 'commit_1',
        message: 'update',
        files: [
          'functions/handlers/payments.js',
          'lib/features/parent/screens/payment_screen.dart',
        ],
      },
      {
        id: 'commit_2',
        message: 'wip',
        files: [
          'lib/features/dashboard/screens/dashboard.dart',
        ],
      },
    ]);

    expect(summary).toContain('Worked mainly on');
    expect(summary).toContain('payments backend');
    expect(summary).toContain('parent and billing experience');
    expect(summary).toContain('dashboard updates');
    expect(summary).toContain('Main work areas:');
    expect(summary).toContain('- Payments backend.');
    expect(summary).toContain('- Parent and billing experience.');
    expect(summary.toLowerCase()).not.toContain('\n- update');
    expect(summary.toLowerCase()).not.toContain('\n- wip');
  });

  test('collectCommitsFromEvents dedupes shared commits across multiple push events', () => {
    const result = __test__.collectCommitsFromEvents([
      {
        id: 'event_1',
        commits: [
          {
            id: 'commit_shared',
            message: 'Shared commit',
            timestamp: '2026-04-20T10:00:00.000Z',
            files: ['functions/handlers/payments.js'],
          },
        ],
      },
      {
        id: 'event_2',
        commits: [
          {
            id: 'commit_shared',
            message: 'Shared commit',
            timestamp: '2026-04-20T10:00:00.000Z',
            files: ['functions/handlers/payments.js'],
          },
          {
            id: 'commit_new',
            message: 'New commit',
            timestamp: '2026-04-20T11:00:00.000Z',
            files: ['lib/features/dashboard/screens/dashboard.dart'],
          },
        ],
      },
    ]);

    expect(result.eventIds).toEqual(['event_1', 'event_2']);
    expect(result.commits.map((commit) => commit.id)).toEqual([
      'commit_new',
      'commit_shared',
    ]);
  });

  test('buildFormSubmission targets the CTO template with minimal fields', () => {
    const submission = __test__.buildFormSubmission({
      templateId: 'cto_weekly_engineering_report',
      formName: 'CTO Weekly Engineering Report',
      reporter: {
        uid: 'user_123',
        email: 'hassimiou.niane@maine.edu',
        name: 'Hassimiou Niane',
      },
      periodStart: new Date('2026-04-13T00:00:00.000Z'),
      periodEnd: new Date('2026-04-20T00:00:00.000Z'),
      workSummary: 'Worked mainly on payments and dashboard updates.',
      eventDocIds: ['event_1'],
      commitIds: ['commit_1'],
    });

    expect(submission.formId).toBe('cto_weekly_engineering_report');
    expect(submission.templateId).toBe('cto_weekly_engineering_report');
    expect(submission.formType).toBe('weekly');
    expect(submission.frequency).toBe('weekly');
    expect(submission.userId).toBe('user_123');
    expect(submission.responses).toEqual({
      report_date: '19/04/2026',
      reporter_name: 'Hassimiou Niane',
      work_summary: 'Worked mainly on payments and dashboard updates.',
      follow_up: '',
    });
    expect(submission.reportDate).toBe('19/04/2026');
    expect(submission.yearMonth).toBe('2026-04');
    expect(submission.githubEventIds).toEqual(['event_1']);
    expect(submission.githubCommitIds).toEqual(['commit_1']);
  });
});
