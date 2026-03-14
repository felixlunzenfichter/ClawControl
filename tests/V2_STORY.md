# V2 Story Contract

## Story: iPad↔Mac TCP handshake + same-session pong

### Ordered chain (required)
1. `ipad_started`
2. `start_received session=...`
3. `handshake_ack session=... ready=true`
4. `handshake_confirmed session=...`
5. `ping hello`
6. `pong_sent session=...`
7. `pong_received_same_session`

### Pass condition
- PASS only if the full chain appears in this exact order in canonical logs.

### Fail conditions
- iPad does not open TCP connection to Mac.
- `start` is not sent.
- `handshake_ack` is missing/invalid.
- `pong` arrives with a different session id.
- Any ordered-chain step is missing or out of order.
