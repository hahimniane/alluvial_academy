const fs = require('fs');
const path = require('path');

describe('bot_controller.html', () => {
  const htmlPath = path.join(__dirname, '..', 'bot_controller.html');
  const html = fs.readFileSync(htmlPath, 'utf8');
  const inlineScripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
    .map((match) => match[1]);

  test('inline scripts parse', () => {
    expect(inlineScripts.length).toBeGreaterThan(0);
    for (const script of inlineScripts) {
      expect(() => new Function(script)).not.toThrow();
    }
  });

  test('opens breakout rooms with auto-routing options', () => {
    expect(html).toContain('isAutoJoinRoom: true');
    expect(html).toContain('isBackToMainSessionEnabled: false');
    expect(html).toContain('needCountDown: false');
    expect(html).toContain("zoomCall('openBreakoutRooms', { options: desiredRoomOptions })");
  });
});
