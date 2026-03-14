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

test('Connect story passes from ordered logs only', async () => {
  const result = await runStory({
    storyPath: 'tests/STORY.md',
    logsDir: tempLogsDir('pass'),
    gatewayClient: { connect: async () => ({ ok: true }) }
  });

  assert.equal(result.pass, true);
  assert.equal(result.missing, undefined);
  assert.equal(result.stepResults[0].result, 'Connected to OpenClaw Gateway');
});

test('unified log line format is canonical', async () => {
  const result = await runStory({
    storyPath: 'tests/STORY.md',
    logsDir: tempLogsDir('format'),
    gatewayClient: { connect: async () => ({ ok: true }) }
  });

  const lines = fs.readFileSync(result.logPath, 'utf8').trim().split('\n');
  assert.ok(lines.length >= 4);

  const linePattern = /^\d{2}:\d{2}:\d{2}\.\d{3} \| (AUTO|MANUAL|PROD) \| Mac \| (LOG|ERROR) \| [^|]+ \| [^|]+ \| .+$/;
  for (const line of lines) {
    assert.match(line, linePattern);
  }
});

test('ordered log matcher fails deterministically for missing/out-of-order logs', () => {
  const messages = [
    'Mac server started',
    'Connecting to OpenClaw Gateway',
    'Received command: gateway.connect',
    'Connected to OpenClaw Gateway'
  ];

  const expected = [
    'Mac server started',
    'Received command: gateway.connect',
    'Connecting to OpenClaw Gateway',
    'Connected to OpenClaw Gateway'
  ];

  const result = assertOrdered(messages, expected);
  assert.equal(result.pass, false);
  assert.equal(result.missing, 'Connecting to OpenClaw Gateway');
});
