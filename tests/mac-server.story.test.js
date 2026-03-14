const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { runStory, assertOrdered } = require('../src/story-runner');

function tempLogsDir(name) {
  const dir = path.join(process.cwd(), 'private', 'logs-test', name);
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

test('V2 handshake story passes from ordered logs only', { concurrency: false }, async () => {
  const result = await runStory({
    storyPath: 'tests/STORY.md',
    logsDir: tempLogsDir('pass'),
    gatewayClient: { connect: async () => ({ ok: true }) },
    tcpPort: 7878
  });

  assert.equal(result.pass, true);
  assert.equal(result.missing, undefined);
  assert.match(result.stepResults[0].result, /V2 handshake completed/);
});

test('unified log line format is canonical', { concurrency: false }, async () => {
  const result = await runStory({
    storyPath: 'tests/STORY.md',
    logsDir: tempLogsDir('format'),
    gatewayClient: { connect: async () => ({ ok: true }) },
    tcpPort: 7879
  });

  assert.ok(result.lines.length >= 8);

  const linePattern = /^\d{2}:\d{2}:\d{2}\.\d{3} \| (AUTO|MANUAL|PROD) \| (Mac|iPad) \| (LOG|ERROR) \| [^|]+ \| [^|]+ \| .+$/;
  for (const line of result.lines) {
    assert.match(line, linePattern);
  }
});

test('ordered log matcher fails deterministically for missing/out-of-order logs', () => {
  const messages = [
    'Mac server started tcp://0.0.0.0:7878',
    'ipad_started',
    'handshake_confirmed session=s-1',
    'start_received session=s-1'
  ];

  const expected = [
    'ipad_started',
    'start_received session=',
    'handshake_confirmed session='
  ];

  const result = assertOrdered(messages, expected);
  assert.equal(result.pass, false);
  assert.equal(result.missing, 'handshake_confirmed session=');
});
