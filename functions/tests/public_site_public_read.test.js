jest.mock('firebase-functions/v2/https', () => ({
  onCall: (_options, fn) => fn,
  onRequest: (_options, fn) => fn,
}));

const admin = require('firebase-admin');

const buildDoc = (exists, data) => ({
  exists,
  data: () => data,
});

const buildDb = () => ({
  collection: jest.fn((name) => {
    const docs = {
      public_site_cms_pricing: buildDoc(true, { plans: [] }),
      public_site_cms_social: buildDoc(true, { instagram: 'https://example.com/i' }),
      public_site_cms_landing: buildDoc(false, null),
    };

    if (docs[name]) {
      return {
        doc: (id) => {
          expect(id).toBe('main');
          return { get: async () => docs[name] };
        },
      };
    }

    if (name === 'public_site_cms_team') {
      return {
        get: async () => ({
          docs: [
            {
              id: 'visible',
              data: () => ({
                name: 'Visible Person',
                active: true,
                linkedUserUid: 'user_1',
              }),
            },
            {
              id: 'hidden',
              data: () => ({
                name: 'Hidden Person',
                active: false,
                linkedUserUid: 'user_2',
              }),
            },
          ],
        }),
      };
    }

    throw new Error(`Unexpected collection: ${name}`);
  }),
});

const buildResponse = () => {
  const res = {
    headers: {},
    statusCode: null,
    body: null,
    set: jest.fn((key, value) => {
      res.headers[key] = value;
      return res;
    }),
    status: jest.fn((code) => {
      res.statusCode = code;
      return res;
    }),
    send: jest.fn((body) => {
      res.body = body;
      return res;
    }),
    json: jest.fn((body) => {
      res.body = body;
      return res;
    }),
  };
  return res;
};

describe('public site public read handlers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    admin.firestore.mockReturnValue(buildDb());
  });

  test('HTTP endpoint answers CORS preflight', async () => {
    const { getPublicSiteMarketingBundleHttp } = require('../handlers/public_site_public_read');
    const res = buildResponse();

    await getPublicSiteMarketingBundleHttp({ method: 'OPTIONS' }, res);

    expect(res.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(res.headers['Access-Control-Allow-Methods']).toBe('GET, OPTIONS');
    expect(res.statusCode).toBe(204);
    expect(res.send).toHaveBeenCalledWith('');
  });

  test('HTTP endpoint returns public marketing bundle', async () => {
    const { getPublicSiteMarketingBundleHttp } = require('../handlers/public_site_public_read');
    const res = buildResponse();

    await getPublicSiteMarketingBundleHttp({ method: 'GET' }, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.pricing).toEqual({ plans: [] });
    expect(res.body.social).toEqual({ instagram: 'https://example.com/i' });
    expect(res.body.landing).toBeNull();
    expect(res.body.teamMembers).toEqual([
      expect.objectContaining({
        id: 'visible',
        name: 'Visible Person',
      }),
    ]);
  });
});
