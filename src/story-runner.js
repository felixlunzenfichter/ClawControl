const fs = require('node:fs');
const path = require('node:path');
const { createMacServer } = require('./mac-server');

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

async function runStory({ storyPath = path.join('tests', 'STORY.md'), logsDir = path.join('private', 'logs'), gatewayClient, mode = 'PROD' } = {}) {
  const story = parseStory(storyPath);
  const server = createMacServer({ mode, logsDir, gatewayClient });
  const stepResults = [];

  await server.start();

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
  }

  const logText = fs.readFileSync(server.logger.sessionLogPath, 'utf8');
  const messages = messagesFromLog(logText);

  const allExpected = story.flatMap((s) => s.expectedLogs || []);
  const ordered = assertOrdered(messages, allExpected);

  return {
    pass: ordered.pass,
    missing: ordered.missing,
    logPath: server.logger.sessionLogPath,
    stepResults,
    messages
  };
}

module.exports = { runStory, parseStory, messagesFromLog, assertOrdered };
