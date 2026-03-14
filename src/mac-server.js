const net = require('node:net');
const { createLogger } = require('./logger');
const { createGatewayClient } = require('./gateway-client');

function randomSessionId() {
  return `s-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function createMacServer({ mode = 'PROD', logsDir, gatewayClient, tcpHost = '0.0.0.0', tcpPort = 7878 } = {}) {
  const logger = createLogger({ mode, device: 'Mac', logsDir });
  const gateway = gatewayClient || createGatewayClient();

  let tcpServer;

  function startTcpServer() {
    return new Promise((resolve, reject) => {
      tcpServer = net.createServer((socket) => {
        const sessionId = randomSessionId();
        let buffer = '';

        logger.log(`tcp_connection_opened session=${sessionId}`, 'mac-server', 'startTcpServer');

        socket.on('data', (chunk) => {
          buffer += chunk.toString('utf8');
          let idx;
          while ((idx = buffer.indexOf('\n')) >= 0) {
            const line = buffer.slice(0, idx).trim();
            buffer = buffer.slice(idx + 1);
            if (!line) continue;

            if (line === 'start') {
              logger.log(`start_received session=${sessionId}`, 'mac-server', 'startTcpServer');
              socket.write(`${JSON.stringify({ type: 'handshake_ack', sessionId, ready: true })}\n`);
              logger.log(`handshake_ack session=${sessionId} ready=true`, 'mac-server', 'startTcpServer');
              continue;
            }

            if (line === 'ping hello' || line === `ping hello|${sessionId}`) {
              logger.log(`ping_hello_received session=${sessionId}`, 'mac-server', 'startTcpServer');
              socket.write(`${JSON.stringify({ type: 'pong', sessionId })}\n`);
              logger.log(`pong_sent session=${sessionId}`, 'mac-server', 'startTcpServer');
              continue;
            }

            logger.error(`unknown_client_message session=${sessionId} payload=${line}`, 'mac-server', 'startTcpServer');
          }
        });

        socket.on('error', (err) => {
          logger.error(`socket_error session=${sessionId} error=${err.message}`, 'mac-server', 'startTcpServer');
        });
      });

      tcpServer.once('error', reject);
      tcpServer.listen(tcpPort, tcpHost, () => {
        logger.log(`Mac server started tcp://${tcpHost}:${tcpPort}`, 'mac-server', 'start');
        resolve();
      });
    });
  }

  async function start() {
    await startTcpServer();
    return { status: 'running', logFile: logger.sessionLogPath, tcpHost, tcpPort };
  }

  async function stop() {
    if (!tcpServer) return;
    await new Promise((resolve) => tcpServer.close(() => resolve()));
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

  return { start, stop, handleCommand, logger, tcpHost, tcpPort };
}

module.exports = { createMacServer };
