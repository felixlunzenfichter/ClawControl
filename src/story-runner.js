const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { createMacServer } = require('./mac-server');
const { createLogger } = require('./logger');

function parseStory(storyPath) {
  const content = fs.readFileSync(storyPath, 'utf8');
  const match = content.match(/```json\s*([\s\S]*?)\s*```/);
  if (!match) throw new Error('No JSON story block found in STORY.md');
  return JSON.parse(match[1]);
}

function messagesFromLog(logText) {
  return logText
    .split('\n')
    .filter(Boolean)
    .map((line) => line.split(' | ').slice(6).join(' | '));
}

function parseTimePrefix(line) {
  const match = line.match(/^(\d{2}):(\d{2}):(\d{2})\.(\d{3})/);
  if (!match) return Number.MAX_SAFE_INTEGER;
  const [, hh, mm, ss, ms] = match;
  return Number(hh) * 3_600_000 + Number(mm) * 60_000 + Number(ss) * 1_000 + Number(ms);
}

function messagesFromLogsDir(logsDir) {
  const files = fs.readdirSync(logsDir)
    .filter((n) => n.endsWith('.log'))
    .sort((a, b) => Number(a.replace('.log', '')) - Number(b.replace('.log', '')));

  const rows = [];
  for (const file of files) {
    const fileOrder = Number(file.replace('.log', ''));
    const fullPath = path.join(logsDir, file);
    const text = fs.readFileSync(fullPath, 'utf8').trim();
    if (!text) continue;
    const fileLines = text.split('\n');
    fileLines.forEach((line, idx) => {
      rows.push({ line, t: parseTimePrefix(line), fileOrder, idx });
    });
  }

  rows.sort((a, b) => (a.t - b.t) || (a.fileOrder - b.fileOrder) || (a.idx - b.idx));
  const lines = rows.map((r) => r.line);

  return {
    lines,
    messages: lines.map((line) => line.split(' | ').slice(6).join(' | '))
  };
}

function assertOrdered(logMessages, expected) {
  let cursor = 0;
  for (const pattern of expected) {
    let found = false;
    while (cursor < logMessages.length) {
      if (logMessages[cursor].includes(pattern)) {
        found = true;
        cursor += 1;
        break;
      }
      cursor += 1;
    }
    if (!found) return { pass: false, missing: pattern };
  }
  return { pass: true };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function readLineFromSocket(socket, timeoutMs = 2000) {
  return new Promise((resolve, reject) => {
    let timer;
    let buffer = '';

    const cleanup = () => {
      clearTimeout(timer);
      socket.off('data', onData);
      socket.off('error', onErr);
    };

    const onData = (chunk) => {
      buffer += chunk.toString('utf8');
      const idx = buffer.indexOf('\n');
      if (idx >= 0) {
        const line = buffer.slice(0, idx).trim();
        cleanup();
        resolve(line);
      }
    };

    const onErr = (err) => {
      cleanup();
      reject(err);
    };

    timer = setTimeout(() => {
      cleanup();
      reject(new Error('Timed out waiting for socket line'));
    }, timeoutMs);

    socket.on('data', onData);
    socket.on('error', onErr);
  });
}

async function runV2HandshakeClient({ mode = 'PROD', logsDir, host, port }) {
  const logger = createLogger({ mode, device: 'iPad', logsDir });

  const socket = await new Promise((resolve, reject) => {
    const s = net.createConnection({ host, port }, () => resolve(s));
    s.once('error', reject);
  });

  logger.log('ipad_started', 'v2-client', 'runV2HandshakeClient');
  socket.write('start\n');

  const ackRaw = await readLineFromSocket(socket);
  const ack = JSON.parse(ackRaw);
  if (ack.type !== 'handshake_ack' || !ack.sessionId || ack.ready !== true) {
    throw new Error(`Unexpected handshake ack: ${ackRaw}`);
  }

  logger.log(`handshake_confirmed session=${ack.sessionId}`, 'v2-client', 'runV2HandshakeClient');
  await sleep(5);
  logger.log('ping hello', 'v2-client', 'runV2HandshakeClient');
  await sleep(5);
  socket.write(`ping hello|${ack.sessionId}\n`);

  const pongRaw = await readLineFromSocket(socket);
  const pong = JSON.parse(pongRaw);
  if (pong.type !== 'pong') throw new Error(`Unexpected pong payload: ${pongRaw}`);
  if (pong.sessionId !== ack.sessionId) {
    throw new Error(`Pong session mismatch: expected ${ack.sessionId}, got ${pong.sessionId}`);
  }

  logger.log('pong_received_same_session', 'v2-client', 'runV2HandshakeClient');
  socket.end();

  return { sessionId: ack.sessionId, logPath: logger.sessionLogPath };
}

async function runStory({ storyPath = path.join('tests', 'STORY.md'), logsDir = path.join('private', 'logs'), gatewayClient, mode = 'PROD', tcpPort = 7878 } = {}) {
  const story = parseStory(storyPath);
  const server = createMacServer({ mode, logsDir, gatewayClient, tcpPort });
  const stepResults = [];

  await server.start();

  try {
    for (const step of story) {
      if (step.command) {
        const res = await server.handleCommand({
          type: 'command',
          commandId: `${Date.now()}-${Math.random()}`,
          action: step.command,
          payload: {}
        });
        stepResults.push({ action: step.action, result: res.message });
      }

      if (step.clientAction === 'v2.handshake') {
        const res = await runV2HandshakeClient({ mode, logsDir, host: server.tcpHost, port: server.tcpPort });
        stepResults.push({ action: step.action, result: `V2 handshake completed (${res.sessionId})` });
      }
    }

    const { lines, messages } = messagesFromLogsDir(logsDir);
    const allExpected = story.flatMap((s) => s.expectedLogs || []);
    const ordered = assertOrdered(messages, allExpected);

    return {
      pass: ordered.pass,
      missing: ordered.missing,
      logPath: server.logger.sessionLogPath,
      stepResults,
      messages,
      lines
    };
  } finally {
    await server.stop();
  }
}

module.exports = { runStory, parseStory, messagesFromLog, assertOrdered, messagesFromLogsDir };
