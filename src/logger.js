const fs = require('node:fs');
const path = require('node:path');

function timePart(date = new Date()) {
  const pad = (n, size = 2) => String(n).padStart(size, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
}

function nextSessionFile(logsDir) {
  fs.mkdirSync(logsDir, { recursive: true });
  const sessions = fs
    .readdirSync(logsDir)
    .map((name) => Number(path.basename(name, '.log')))
    .filter((n) => Number.isInteger(n) && n >= 1);
  const next = sessions.length ? Math.max(...sessions) + 1 : 1;
  return path.join(logsDir, `${next}.log`);
}

function createLogger({ mode = 'PROD', device = 'Mac', logsDir = path.join('private', 'logs') } = {}) {
  const sessionLogPath = nextSessionFile(logsDir);

  function emit(type, message, fileName, functionName) {
    const line = `${timePart()} | ${mode} | ${device} | ${type} | ${fileName} | ${functionName} | ${message}`;
    fs.appendFileSync(sessionLogPath, `${line}\n`, 'utf8');
    return {
      type: type.toLowerCase(),
      message,
      fileName,
      functionName,
      timestamp: new Date().toISOString(),
      mode,
      device,
      line
    };
  }

  return {
    sessionLogPath,
    log: (message, fileName, functionName) => emit('LOG', message, fileName, functionName),
    error: (message, fileName, functionName) => emit('ERROR', message, fileName, functionName)
  };
}

module.exports = { createLogger };
