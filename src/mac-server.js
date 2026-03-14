const { createLogger } = require('./logger');
const { createGatewayClient } = require('./gateway-client');

function createMacServer({ mode = 'PROD', logsDir, gatewayClient } = {}) {
  const logger = createLogger({ mode, device: 'Mac', logsDir });
  const gateway = gatewayClient || createGatewayClient();

  async function start() {
    logger.log('Mac server started', 'mac-server', 'start');
    return { status: 'running', logFile: logger.sessionLogPath };
  }

  async function handleCommand(commandEnvelope) {
    if (!commandEnvelope || commandEnvelope.type !== 'command') {
      logger.error('Invalid command envelope', 'mac-server', 'handleCommand');
      return { type: 'result', commandId: null, status: 'error', message: 'Invalid command envelope' };
    }

    logger.log(`Received command: ${commandEnvelope.action}`, 'mac-server', 'handleCommand');

    if (commandEnvelope.action === 'gateway.connect') {
      logger.log('Connecting to OpenClaw Gateway', 'mac-server', 'connectGateway');
      await gateway.connect();
      logger.log('Connected to OpenClaw Gateway', 'mac-server', 'connectGateway');
      return {
        type: 'result',
        commandId: commandEnvelope.commandId,
        status: 'success',
        message: 'Connected to OpenClaw Gateway'
      };
    }

    logger.error(`Unknown action: ${commandEnvelope.action}`, 'mac-server', 'handleCommand');
    return {
      type: 'result',
      commandId: commandEnvelope.commandId,
      status: 'error',
      message: `Unknown action: ${commandEnvelope.action}`
    };
  }

  return { start, handleCommand, logger };
}

module.exports = { createMacServer };
