# OpenClaw Mac Server Spec (v0)

## Goal
Build a **Mac Node.js server** that:
1. starts and runs continuously,
2. connects to the OpenClaw Gateway,
3. uses the **same logging structure as `realtime-claude`**,
4. runs story tests that pass/fail **only from logs**.

No iOS app in this phase.

## Architecture

### 1) Mac Server (single runtime)
- Process: Node.js service (`mac-server`)
- Responsibility: gateway connectivity + command execution + unified logging + story test runner
- Always-on behavior: long-running process, reconnect loop, graceful shutdown

### 2) Gateway Proxy Layer
- Mac server is the proxy/adapter to OpenClaw Gateway.
- Handles auth token, base URL, session routing, retries/backoff.
- Exposes command API (in-process for v0):
  - `server.start`
  - `gateway.connect`

## Logging System (must match realtime-claude structure)

### A) Canonical persisted log line format
Use the same unified line format used in `realtime-claude/scripts/mac-server.js`:

```text
HH:MM:SS.mmm | MODE | DEVICE | TYPE | FILE | FUNCTION | MESSAGE
```

Where:
- `MODE`: `AUTO | MANUAL | PROD`
- `DEVICE`: `Mac` (for this project phase)
- `TYPE`: `LOG | ERROR`
- `FILE`: short logical source name (e.g. `mac-server`, `gateway-client`)
- `FUNCTION`: function/source context
- `MESSAGE`: human-readable event text

### B) JSON message envelope (for transport/internal bus)
Follow same style as realtime-claude message routing:

```json
{ "type": "log", "message": "...", "fileName": "mac-server", "functionName": "connectGateway", "timestamp": "2026-03-14T13:45:00.000Z", "mode": "PROD", "device": "Mac" }
```

```json
{ "type": "error", "message": "...", "fileName": "mac-server", "functionName": "connectGateway", "timestamp": "2026-03-14T13:45:00.000Z", "mode": "PROD", "device": "Mac" }
```

### C) Session log files
- Persist logs under `private/logs/`
- One session file per server run (incremental): `private/logs/<n>.log`
- Append every log in unified line format

## Story Test System (log-based)
- Reads steps from `tests/STORY.md` (locked contract).
- Executes one step at a time.
- Waits for expected log **messages/patterns** in order.
- Marks pass/fail from logs only (no manual validation).

## v0 Story (first commit target)

### Story: Connect
- **Action 1**: "Server started"
  - Expected log message: `Mac server started`
- **Action 2**: "Connect to Gateway"
  - Command: `gateway.connect`
  - Expected logs (ordered message patterns):
    1. `Received command: gateway.connect`
    2. `Connecting to OpenClaw Gateway`
    3. `Connected to OpenClaw Gateway`
  - Result: "Connected to OpenClaw Gateway"

## Command/Result contract

### Command
```json
{ "type": "command", "commandId": "uuid", "action": "gateway.connect", "payload": {} }
```

### Result
```json
{ "type": "result", "commandId": "uuid", "status": "success|error", "message": "..." }
```

## TDD plan (strict)
1. Add failing story test for startup log line.
2. Implement minimal startup + unified logger until green.
3. Add failing story test for `gateway.connect` ordered logs + success result.
4. Implement minimal gateway connector/proxy until green.
5. Keep tests deterministic (mock gateway transport for unit tests; optional real integration test).

## Non-goals (v0)
- No iOS integration.
- No multi-conversation orchestration.
- No audio/transcription/TTS.

## Done criteria (v0)
- Running Mac server creates session log and emits startup line in unified format.
- `gateway.connect` produces expected ordered log message patterns.
- Story runner marks Connect story as PASS from logs.
- Missing/out-of-order logs produce deterministic FAIL.
