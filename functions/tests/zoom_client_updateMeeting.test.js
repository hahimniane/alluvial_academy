describe('Zoom client updateMeeting', () => {
  beforeEach(() => {
    jest.resetModules();
    global.fetch = jest.fn();
  });

  test('updates breakout rooms even when some alternative hosts are invalid (1114)', async () => {
    jest.doMock('../services/zoom/config', () => ({
      getZoomConfig: () => ({
        accountId: 'acct',
        clientId: 'client',
        clientSecret: 'secret',
        hostUser: 'host@example.com',
      }),
    }));

    let altHostPatchAttempts = 0;

    global.fetch.mockImplementation(async (url, init) => {
      if (String(url).startsWith('https://zoom.us/oauth/token')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({ access_token: 'token', expires_in: 3600 }),
          text: async () => '',
        };
      }

      if (String(url).startsWith('https://api.zoom.us/v2/meetings/123')) {
        const body = init?.body ? JSON.parse(init.body) : {};
        const altHosts = body?.settings?.alternative_hosts;
        if (typeof altHosts === 'string') {
          altHostPatchAttempts += 1;
          if (altHosts.includes('bad@example.com')) {
            return {
              ok: false,
              status: 400,
              text: async () => JSON.stringify({
                code: 1114,
                message: "Unable to assign 'bad@example.com' as an alternative host because the user cannot be selected at this time",
              }),
            };
          }
        }

        return {
          ok: true,
          status: 204,
          text: async () => '',
        };
      }

      throw new Error(`Unexpected fetch: ${url}`);
    });

    const { updateMeeting } = require('../services/zoom/client');

    await expect(updateMeeting('123', {
      topic: 'Topic',
      breakoutRooms: [{ name: 'Room A', participants: [] }],
      alternativeHosts: ['good@example.com', 'bad@example.com'],
    })).resolves.toEqual({ success: true });

    expect(global.fetch).toHaveBeenCalled();
    expect(altHostPatchAttempts).toBe(2);

    const patchCalls = global.fetch.mock.calls.filter(([url]) =>
      String(url).startsWith('https://api.zoom.us/v2/meetings/123')
    );
    expect(patchCalls).toHaveLength(3);

    const primaryPayload = JSON.parse(patchCalls[0][1].body);
    expect(primaryPayload.topic).toBe('Topic');
    expect(primaryPayload.settings?.breakout_room?.rooms?.[0]?.name).toBe('Room A');

    const firstAltPayload = JSON.parse(patchCalls[1][1].body);
    expect(firstAltPayload.settings.alternative_hosts).toContain('bad@example.com');

    const secondAltPayload = JSON.parse(patchCalls[2][1].body);
    expect(secondAltPayload.settings.alternative_hosts).toBe('good@example.com');
  });
});

