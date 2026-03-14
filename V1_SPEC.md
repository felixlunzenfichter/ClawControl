# Version 1 Spec — iPhone Log Display Only

## Goal
Connect iPhone app to the Mac server and **only display logs**.

That is all for v1.

## Scope

### Mac server
- Expose log stream over TCP JSON lines.
- On iPhone connect, start sending log events.
- No extra dashboard data in v1 (no uptime, no counters, no stats).

### iPhone app
- Connect to Mac server via host/port.
- Render incoming logs in a simple list.
- Display only these fields per row:
  - timestamp
  - type (`LOG|ERROR`)
  - file
  - function
  - message
- Keep a bounded in-memory buffer (e.g. last 1000 logs).

## Protocol (v1 minimal)
JSON lines over TCP.

### Server -> iPhone
```json
{
  "type": "log",
  "timestamp": "2026-03-14T13:45:00.000Z",
  "logType": "LOG",
  "fileName": "mac-server",
  "functionName": "connectGateway",
  "message": "Connected to OpenClaw Gateway"
}
```

### iPhone -> Server
```json
{ "type": "start" }
```

## Story tests (v1)
1. iPhone connects and receives logs.
2. Incoming log is appended to UI list with correct fields.
3. Error log (`ERROR`) is rendered distinctly.
4. If disconnected and reconnected, log stream continues.

## Non-goals
- No command sending.
- No handshake stats/uptime/tests counters.
- No gateway controls in UI.
- No audio/transcription/TTS.

## Done criteria
- iPhone reliably shows live logs from Mac server.
- Nothing beyond log display is implemented in v1.
