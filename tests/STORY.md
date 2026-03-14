# Story (LOCKED)

```json
[
  {
    "action": "V2 startup handshake",
    "clientAction": "v2.handshake",
    "result": "V2 handshake completes with pong in same session",
    "expectedLogs": [
      "Mac server started tcp://",
      "ipad_started",
      "start_received session=",
      "handshake_ack session=",
      "handshake_confirmed session=",
      "ping hello",
      "ping_hello_received session=",
      "pong_sent session=",
      "pong_received_same_session"
    ]
  }
]
```
