# Version 1 Spec — iPhone Log Viewer

## Goal
Connect iPhone app to the Mac server and display live logs.

v1 is display-only. No voice, no command execution UI, no chat.

## Scope

### Mac server (producer)
- Keep v0 unified logging format and session log files.
- Expose log stream over TCP JSON lines.
- On iPhone connect, send handshake with:
  - `sessionNumber`
  - `totalLogs`
  - `totalUptime`
  - `todayUptime`
- Stream new logs as they are produced.

### iPhone app (consumer)
- Connect to Mac server via configurable host/port.
- Show connection state: `connecting | connected | failed`.
- Parse and render incoming log messages in a list.
- Display the same core log fields:
  - timestamp
  - mode
  - device
  - type
  - file
  - function
  - message
- Keep recent in-memory log buffer (e.g. last 1000 entries).

## Protocol (v1)
JSON lines over TCP.

### Server -> iPhone
- Handshake:
```json
{ "type": "handshake", "sessionNumber": 1, "totalLogs": 10, "totalUptime": 1000, "todayUptime": 500 }
```
- Log event:
```json
{
  "type": "log",
  "timestamp": "2026-03-14T13:45:00.000Z",
  "mode": "PROD",
  "device": "Mac",
  "logType": "LOG",
  "fileName": "mac-server",
  "functionName": "connectGateway",
  "message": "Connected to OpenClaw Gateway"
}
```

### iPhone -> Server
- Start/reconnect signal:
```json
{ "type": "start" }
```

## Story tests (v1)
1. iPhone connects -> receives handshake -> UI shows connected.
2. Server emits log -> iPhone list appends log row with correct fields.
3. Connection drop -> UI shows failed/reconnecting state.
4. Reconnect -> handshake again -> stream resumes.

## TDD plan
1. Add failing parser test for handshake/log message decoding.
2. Add failing connection-state test (`connecting -> connected`).
3. Add failing list-append test when a log arrives.
4. Add failing reconnect-state test.
5. Implement minimal code per step until green.

## Non-goals
- No command sending from iPhone.
- No gateway control from iPhone.
- No audio/transcription/TTS.
- No test orchestration UI.

## Done criteria
- iPhone reliably shows live Mac logs.
- Reconnect works without app restart.
- All v1 story tests pass.
