# V2 Story Contract

## Story: Startup ping/pong in same conversation thread

### Step 1 — Startup auto-send
- App starts.
- Expected action: app sends exactly `ping hello` once.

### Step 2 — Conversation reply
- Same conversation thread receives a reply containing `pong`.

### Pass condition
- Story passes only when `pong` is observed in the **same thread** as startup `ping hello`.

### Fail conditions
- `ping hello` not sent.
- `ping hello` sent more than once on startup.
- `pong` never observed.
- `pong` observed in a different thread.
