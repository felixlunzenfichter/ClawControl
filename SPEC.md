# OpenClaw Mac Server Spec (v0)

## Goal
Build a **Mac Node.js server** that:
1. starts and runs continuously,
2. connects to the OpenClaw Gateway,
3. emits structured logs,
4. runs story tests that pass/fail **only from logs**.

No iOS app in this phase.

## Architecture

### 1) Mac Server (single runtime)
- Process: Node.js service (`mac-server`)
- Responsibility: gateway connectivity + command execution + logging + story test runner
- Always-on behavior: long-running process, reconnect loop, graceful shutdown

### 2) Gateway Proxy Layer
- Mac server is the proxy/adapter to OpenClaw Gateway.
- Handles auth token, base URL, session routing, retries/backoff.
- Exposes internal command API (in-process for now):
  - `server.start`
  - `gateway.connect`

### 3) Logging System (source of truth)
Every important transition emits a structured log event:

```json
{
  "seq": 1,
  "ts": "2026-03-14T13:45:00Z",
  "level": "info",
  "category": "server|gateway|story",
  "name": "server_started",
  "commandId": null,
  "data": {}
}
```

Required event names (v0):
- `server_started`
- `command_received`
- `gateway_connect_started`
- `gateway_connected`
- `gateway_connect_failed`
- `story_step_passed`
- `story_step_failed`

### 4) Story Test System (log-based)
- Reads steps from `tests/STORY.md` (locked contract).
- Executes one step at a time.
- Waits for expected log sequence and terminal result.
- Marks pass/fail from logs only (no manual validation).

## v0 Story (first commit target)

### Story: Connect
- **Action 1**: "Server started"
  - Expected logs: `server_started`
- **Action 2**: "Connect to Gateway"
  - Command: `gateway.connect`
  - Expected logs (ordered):
    1. `command_received` (`action=gateway.connect`)
    2. `gateway_connect_started`
    3. `gateway_connected`
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
1. Add failing story test for `server_started` log.
2. Implement minimal startup logger until green.
3. Add failing story test for `gateway.connect` ordered logs + success result.
4. Implement minimal gateway connector/proxy until green.
5. Keep tests deterministic (mock gateway transport in unit tests, optional real integration test).

## Non-goals (v0)
- No iOS integration.
- No multi-conversation orchestration.
- No audio/transcription/TTS.

## Done criteria (v0)
- Running Mac server emits `server_started`.
- `gateway.connect` command produces required ordered logs.
- Story runner marks Connect story as PASS from logs.
- Failing/missing logs cause deterministic FAIL.
