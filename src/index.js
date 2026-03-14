const { createMacServer } = require('./mac-server');
const { runStory } = require('./story-runner');

async function main() {
  if (process.argv.includes('--story')) {
    const result = await runStory();
    if (!result.pass) {
      console.error(`STORY FAIL missing log: ${result.missing}`);
      process.exitCode = 1;
      return;
    }
    console.log(`STORY PASS (${result.logPath})`);
    return;
  }

  const server = createMacServer();
  await server.start();

  let stopping = false;
  const shutdown = () => {
    if (stopping) return;
    stopping = true;
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  setInterval(() => {}, 60_000);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
