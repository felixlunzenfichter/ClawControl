# V2_SPEC.md

Goal: replace chat-thread ping/pong with a direct iPad↔Mac TCP handshake story on local network.

## Canonical V2 story
1. iPad starts and opens TCP connection to Mac server (local network).
2. iPad sends `start` and first log `ipad_started`.
3. Mac replies `handshake_ack` (session id + ready).
4. iPad logs `handshake_confirmed`.
5. iPad sends `ping hello` event/log to Mac.
6. Mac replies `pong` in the same session.
7. iPad logs `pong_received_same_session`.
8. Story PASS only when this ordered chain appears in logs.

## Logging contract (unchanged)
Each log line must stay in canonical format:
`timestamp | mode | device | type | file | function | message`

## Done criteria
- Mac server accepts TCP client from iPad on LAN.
- iPad runs the handshake flow on startup.
- Ordered V2 chain is visible in logs and validated by story runner.
- Logs screen continues to parse and render canonical log lines.
