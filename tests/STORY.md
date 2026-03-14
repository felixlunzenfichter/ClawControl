# Story (LOCKED)

```json
[
  { "action": "Server started", "result": "server_started" },
  {
    "action": "Connect to Gateway",
    "command": "gateway.connect",
    "result": "Connected to OpenClaw Gateway",
    "expectedLogs": [
      "command_received:gateway.connect",
      "gateway_connect_started",
      "gateway_connected"
    ]
  }
]
```
